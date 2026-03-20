# 🚧 dotfiless

WIP: まだ中途半端だけど、とりあえず

## 使い方

### セットアップ

```
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply kishimotonico
```

### 日常での操作

```
# ローカルの変更をdotfilesに取り込む
chezmoi re-add

# ローカルの新規ファイルをdotfilesに追加
chezmoi add <file>

# dotfilesの変更をローカルに適用
chezmoi diff
chezmoi apply
```

## テスト

```
export GITHUB_TOKEN=$(gh auth token)

docker build -t dotfiles-test -f tests/Dockerfile .
docker run --rm -it -e GITHUB_TOKEN dotfiles-test bash

# bash in container
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ~/dotfiles
```
