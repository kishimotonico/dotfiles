# 🚧 dotfiless

WIP: まだ中途半端だけど、とりあえず

## 使い方

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply kishimotonico
```

## テスト

```
export GITHUB_TOKEN=$(gh auth token)

docker build -t dotfiles-test -f tests/Dockerfile .
docker run --rm -it -e GITHUB_TOKEN dotfiles-test bash

# bash in container
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ~/dotfiles
```
