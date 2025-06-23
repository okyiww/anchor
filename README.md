# Anchor

> This project is a reliable anchor for maintaining system RC files, instilling confidence in me, powered by [rcm](https://github.com/thoughtbot/rcm)

## rcm commands

- mkrc -v

  use `mkrc -v [dot file path]` to quickly manage the dot file

- lsrc

  this command is used to list the currently managed dot files

- rcdn -v

  this command is used to unbind the soft connection of all your dot files

- rcup -v

  this command is used to apply the soft link of all dot files

## usage

```
git clone --depth 1 git@github.com:okyiww/anchor.git ~/.dotfiles

rcup -v
rcup -t wezterm
```

## preview

```
.
├── tag-wezterm
├── gitconfig
├── LICENSE
├── p10k.zsh
├── rcrc
├── README.md
├── tmux.conf
└── zshrc
```

# License

Ths project is [MIT licensed](./LICENSE).
