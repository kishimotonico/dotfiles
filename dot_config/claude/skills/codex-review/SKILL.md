---
name: codex-review
description: Codex CLI (codex exec review) でコードレビューを実行し、結果を要約して報告する。「Codexにレビューしてもらって」「セカンドオピニオンが欲しい」、実装完了後のレビュー依頼などの場面で使用。引数で --base <branch> / --commit <sha> / 自由文の追加指示を指定可能。
---

# Codex Review

Codex CLI にリポジトリのコードレビューを依頼し、結果を日本語で要約して報告する。

## 手順

### 1. レビュー対象の決定

引数から判断する:

- 引数なし → `--uncommitted`(staged + unstaged + untracked をレビュー)
- `--base <branch>` → そのブランチとの差分をレビュー
- `--commit <sha>` → そのコミットの変更をレビュー
- 上記以外の自由文 → レビュー指示として PROMPT 引数に渡す(対象フラグと併用可)

### 2. 差分の存在確認

`git status --short` や `git diff` で対象に差分があることを確認する。なければその旨を報告して終了。

### 3. レビュー実行(background Bash)

レビューは数分かかるので、必ず `run_in_background: true` で実行する。完了すると通知が来るのでポーリングは不要。

```bash
out=$(mktemp /tmp/codex-review.XXXXXX.md)
echo "output: $out"
codex exec review --uncommitted --color never > "$out" 2>&1
```

注意:

- レビューは read-only なので、他の作業(working tree の編集を除く読み取り系)と並行してよい
- レビュー実行中は working tree を変更しない(レビュー対象が変わってしまう)
- 長時間(10分以上)出力ファイルが伸びていなければフリーズの可能性。TaskStop で止めて状況を報告する

### 4. 結果の報告

完了通知が来たら出力ファイルを読み、以下の形式で報告する:

- 指摘を重要度順に日本語で要約(`file:line` 参照付き)
- 各指摘の妥当性を自分でもコードを見て軽く検証し、同意できない指摘・誤検知と思われる指摘はそう明記する
- 修正するかはユーザーの判断に委ねる(勝手に修正しない)

## ユーザーが進捗を見たい場合

「観戦したい」「ペインで見たい」と言われたら、background Bash の代わりに tmux-agent を使う:

```bash
tmux-agent ask review -- codex exec review --uncommitted --color never
tmux-agent wait review --timeout 900   # .done ファイルで完了判定
cat "$(tmux-agent outfile review)"
tmux-agent kill review                  # 報告後に後始末
```
