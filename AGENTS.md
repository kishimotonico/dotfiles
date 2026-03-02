# AGENTS.md

このリポジトリはchezmoi dotfilesです。主にWSL2上のUbuntu環境向けに設定を管理しています。

## 基本操作

README.mdを参照

## 構造

- `run_once_*.sh`: 初回実行スクリプト (APTセットアップ、mise導入・インストール)
- `dot_*`: ホームディレクトリに配置されるファイル (chezmoi命名規則)
- `dot_config/`: `~/.config/` 配下の設定 (git, claude, mise, starship, zellij)
- `scripts/`: AWS関連のヘルパースクリプト
- `.chezmoi.toml.tmpl`: git名とメールアドレスをプロンプトで設定

## mise管理ツール

`dot_config/mise/config.toml`でツール一覧を管理:
- CLI: aws-cli, fzf, jq, gh, lazygit, zoxide等
- dev: node 24, go, uv, pnpm
- npm global: biome, devcontainers/cli, aws-cdk等
- AI: claude, gemini
- その他: starship, zellij, dive, jj

## CI/CD

`.github/workflows/test.yml`でDocker上の自動テストを実行
