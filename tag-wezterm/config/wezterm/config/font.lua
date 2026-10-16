local wezterm = require("wezterm")

return {
	font = wezterm.font_with_fallback({
		"MonoLisa Nerd Font Mono",
                "Hiragino Sans GB",
		"PingFang SC",
		"Maple Mono NF",
		"FiraCode Nerd Font Mono",
	}),
	font_size = 18.0,
}
