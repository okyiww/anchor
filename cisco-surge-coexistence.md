# Cisco Secure Client 与 Surge Mac 共存配置说明（AI 执行手册）

> 本文档是一份零上下文的交接文档。读完即可直接执行，无需向用户追问背景。
> 目标机器：macOS，安装了 Cisco Secure Client（公司 VPN，网关 `vpn-oa.eccom.com.cn`）和 Surge Mac（翻墙代理，系统代理端口 127.0.0.1:6152/6153）。

## 一、任务目标

让 **Cisco Secure Client**（连公司内网）和 **Surge**（系统代理模式，不开增强模式）在 macOS 上**同时正常工作**：

- Surge 开启状态下，Cisco 能正常完成建连（不再卡在"正在建立连接"后超时）；
- Cisco 连接状态下，Surge 的代理流量正常（浏览器翻墙可用）；
- Cisco 连接状态下，公司内网域名和资源可访问（如 `https://eapd.eccom.com.cn/`）。

最终交付物：修改后的 Surge 配置文件，以及验证通过的检查清单（见第六节）。

## 二、背景与根因（为什么默认会冲突）

冲突发生在三层，理解这三层才能判断每一步在修什么：

1. **建连层**：Cisco Secure Client 在 macOS 上建立 VPN 隧道时会读取系统代理设置。若系统代理指向 Surge（HTTP/SOCKS 127.0.0.1:6152/6153），Cisco 发往 VPN 网关的 TLS/DTLS 握手流量会被送进 Surge，被 Surge 的接管逻辑干扰，约 37 秒后超时。症状：Cisco 界面卡在"正在与 xxx 建立连接"，日志（`~/.cisco/vpn/log/UIHistory_*.txt`）显示"连接尝试超时。请验证互联网连接"。
   - 注意：Cisco 首次连接弹出的证书警告（"证书与服务器名称不匹配/不受信任"）是**公司自签证书的正常现象**，与用户操作无关，勾"始终信任"即可，不要误判为故障。
2. **路由层**：Cisco 连接后创建自己的 utun 虚拟网卡（历史上是 `utun5`）并下发内网路由。该公司 VPN 是**分流隧道（split tunnel）**：只把内网网段（如 `10.2/16`、`10.0.3/24`、`10.3.x`、`10.5.x`）路由进隧道，**不抢系统默认路由**。这是能够共存的前提，执行时应先验证这一点（见第四节第 0 步）。
3. **DNS 层**：Surge 完全抛弃系统 DNS 解析器，只使用自己配置的 DNS（本例为阿里 223.6.6.6 / DoH）。而公司内网域名（`*.eccom.com.cn`）只存在于公司内网 DNS（历史上为 `10.2.52.105`、`10.2.52.82`），公网 DNS 查不到。症状：走 Surge 代理时访问内网域名提示"找不到"/NXDOMAIN。
   - 公司 VPN 连接后，macOS 系统解析器通过 Split DNS 机制已能正确解析内网域名（`scutil --dns` 可见 `domain: eccom.com.cn` 的 resolver）。因此修法是把这类域名在 Surge 里交回系统解析器。

## 三、已知事实（历史勘察数据，执行时须重新验证）

| 项目 | 历史值 | 验证方式 |
|---|---|---|
| VPN 网关域名 | `vpn-oa.eccom.com.cn` | Cisco 客户端界面 / `~/.cisco/vpn/log/` 最新 UIHistory 日志 |
| 网关 IP | `210.5.150.101` | `nslookup vpn-oa.eccom.com.cn`（应解析到上海电信 IP） |
| 公司内网 DNS | `10.2.52.105`, `10.2.52.82` | Cisco 连接后 `scutil --dns` |
| Cisco 虚拟网卡 | `utun5` | Cisco 连接后 `netstat -rn -f inet` / `ifconfig` |
| Surge 配置文件 | `~/Library/Application Support/Surge/Profiles/okyiww network proxy.conf` | `ls ~/Library/Application Support/Surge/Profiles/*.conf` |
| Surge 配置性质 | 托管配置（`#!MANAGED-CONFIG ... strict=false`），本地修改被允许且在刷新时基本保留 | 读配置文件第 1 行 |
| Surge 系统代理端口 | HTTP 6152，SOCKS 6153 | `scutil --proxy` |
| 目标公司域名 | `*.eccom.com.cn`（内网如 eapd、vpn-oa；公网如 www） | 用户内网地址簿 |
| 机器上同时存在 | Tailscale（utun0）、AdGuard（可能安装） | `ifconfig` / `ps aux`，排查干扰时认得它们 |

若重新验证时网关 IP、公司 DNS、utun 编号与历史值不同，**以新值为准**替换下文配置中的所有对应位置。

## 四、执行步骤

### 第 0 步：勘察与备份（只读，不改任何东西）

```bash
# Surge 配置文件位置与托管标记
ls ~/Library/Application Support/Surge/Profiles/
head -1 ~/Library/Application Support/Surge/Profiles/*.conf

# 当前系统代理（确认 Surge 在 6152/6153）
scutil --proxy | grep -E "Enable|Proxy :|Port"

# 网关 IP
nslookup vpn-oa.eccom.com.cn

# 修改前备份（必做）
cp ~/Library/Application\ Support/Surge/Profiles/<配置文件>.conf{,.bak-before-cisco-fix}
```

### 第 1 步：修改 Surge 配置

在 `~/Library/Application Support/Surge/Profiles/<配置文件>.conf` 中做以下修改。**注意：该文件是托管配置，只能增量追加/插入，绝对不要删除或重写订阅原有的行。**

1. `[General]` 段的 `skip-proxy` 列表末尾追加（保持逗号分隔）：
   ```
   vpn-oa.eccom.com.cn, 210.5.150.101
   ```
   作用：系统代理跳过 VPN 网关，Cisco 建连流量完全不进 Surge（修根因 1）。
2. `[General]` 段的 `tun-excluded-routes` 列表末尾追加：
   ```
   210.5.150.101/32
   ```
   作用：万一开了增强模式，Cisco 到网关的包也不进 Surge VIF。
3. `[General]` 段新增一行（若已存在则合并）：
   ```
   always-real-ip = vpn-oa.eccom.com.cn
   ```
   作用：增强模式下 DNS 不给网关域名返回 Fake IP。
4. `[Rule]` 段**最顶部**（在任何其他规则之前）插入：
   ```ini
   # Cisco VPN gateway bypass
   DOMAIN,vpn-oa.eccom.com.cn,DIRECT
   IP-CIDR,210.5.150.101/32,DIRECT,no-resolve
   ```
   作用：兜底，万一 Cisco 流量进入 Surge，强制直连出口。
5. 新增 `[Host]` 段（放在 `[General]` 之后即可）：
   ```ini
   [Host]
   *.eccom.com.cn = server:syslib
   ```
   作用：公司域名交回系统解析器，由 Split DNS 分流内外网（修根因 3）。

改完后让用户在 Surge 中重新加载配置（外部修改 Surge 会提示确认；或开关一次配置）。

**确认 Surge 增强模式处于关闭状态**（菜单栏 Surge 图标可查看）。增强模式不在本方案范围内，开了会把 Cisco 踢下线。

### 第 2 步：连接顺序（向用户说明，或代其执行）

1. 打开 Surge（系统代理开，增强模式关）；
2. 打开 Cisco Secure Client 连接（首次证书警告勾"始终信任"）；
3. 两者应同时可用。

### 第 3 步：验证（全部通过才算完成）

```bash
# A. Surge 代理本身可用（应返回 204）
curl -x http://127.0.0.1:6152 -s -o /dev/null -w "%{http_code}\n" --connect-timeout 8 https://www.google.com/generate_204

# B. Cisco 连接后的路由确认分流隧道（默认路由必须仍指向物理网卡 en0，
#    内网网段走 utunX；若 default 被 utun 抢走说明公司改成了全隧道，本方案不适用，需重新评估）
netstat -rn -f inet | grep -E "^default|utun"

# C. 内网域名解析（Cisco 连接状态下，应返回 10.x 内网地址）
dig eapd.eccom.com.cn +short

# D. 浏览器实测三个目标：
#    1) https://eapd.eccom.com.cn/ 能打开（内网，经系统代理 → Surge → syslib DNS → utun）
#    2) Google 能打开（外网，经 Surge 代理）
#    3) 国内网站能打开（如百度）
```

### 第 4 步：收尾

- 确认备份文件 `*.bak-before-cisco-fix` 存在且可回滚（原样复制回去 + Surge 重新加载即可）。
- 告知用户日常使用顺序（第 2 步）和注意事项（第五节）。

## 五、注意事项与边界

1. **不要开 Surge 增强模式**。开了会抢默认路由把 Cisco 踢下线。若用户日后要求增强模式共存，需追加：把 `[Host]` 改为 `*.eccom.com.cn = server:10.2.52.105, 10.2.52.82`（增强模式下 `server:syslib` 不生效），并在 `[Proxy]` 增加 `CorpVPN = direct, interface=utun5, allow-other-interface=true`、在 `[Rule]` 顶部加 `IP-CIDR,10.0.0.0/8,CorpVPN,no-resolve`。此为公司分流隧道场景的设计，需在 Cisco 连接状态下实测。
2. **托管配置刷新**：订阅每 5 小时自动刷新（`strict=false`，本地修改原则上保留）。若症状复发，先检查配置中本方案的四组改动是否还在，被冲掉则照第四节补回。
3. **网关 IP 可能变化**：若 Cisco 某天突然又卡"正在建立连接"，先 `nslookup vpn-oa.eccom.com.cn` 对比配置中的 IP，变了就替换 `skip-proxy`、`tun-excluded-routes`、`IP-CIDR` 三处。
4. **本方案的前提是公司 VPN 为分流隧道**（验证点见第 3 步 B）。若公司改为全隧道（默认路由被 utun 抢走），则 Surge 系统代理的出墙流量会被拖进公司隧道并被防火墙拦截，届时只剩三条路：OpenConnect + vpn-slice 替代官方客户端（开源方案，需评估合规风险）、把 Cisco 装进虚拟机、或与公司 IT 申请分流。
5. 机器上若还装有 AdGuard 网络扩展或其他 VPN/过滤类软件，出现奇怪问题时记得它们也会接管网络，用 `ifconfig` / `ps aux` 先认全场上的 utun 都是谁的。

## 六、交付检查清单

- [ ] Surge 配置已按第四节修改并重新加载，备份文件存在
- [ ] Cisco 在 Surge 开启状态下 10 秒内完成建连
- [ ] 内网 `https://eapd.eccom.com.cn/` 可访问
- [ ] Google / 百度均可访问
- [ ] `netstat -rn` 确认默认路由仍在 en0（分流隧道前提成立）
- [ ] 已向用户说明日常使用顺序与第五节注意事项
