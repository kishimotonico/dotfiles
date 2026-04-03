# AGENTS.md

このリポジトリはchezmoi dotfilesです。主にWSL2上のUbuntu環境向けに設定を管理しています。

## 基本操作

README.mdを参照

## コミットメッセージ

- 日本語
- 軽微な修正の場合 `[Add|Update|Fix|Remove] ~/file-path: かんたんな説明（任意）`
    - e.g. `Add ~/.config/foo/baz`
    - e.g. `Update ~/.config/foo/bar: ほげふがした`
    - コミットメッセージ本文は省略してもOK
- それ以外、Conventional Commitsに従う

## CI/CD

`.github/workflows/test.yml`でDocker上の自動テストを実行
