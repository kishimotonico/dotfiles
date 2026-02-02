# 🚧 dotfiless

WIP: まだ中途半端だけど、とりあえず

## 使い方

```
chezmoi init https://github.com/kishimotonico/dotfiles.git
chezmoi diff
chezmoi apply
```

## テスト

```
docker build -t dotfiles-test -f tests/Dockerfile .
docker run -it dotfiles-test bash

# bash in container
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ~/dotfiles
```
