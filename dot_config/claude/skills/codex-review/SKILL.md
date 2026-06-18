---
name: codex-review
description: Codex CLI (codex exec review) でコードレビューを実行し、結果を要約して報告する。「Codexにレビューしてもらって」「セカンドオピニオンが欲しい」、実装完了後のレビュー依頼などの場面で使用。引数で --base <branch> / --commit <sha> / 自由文の追加指示を指定可能。
---

# Codex Review

Codex CLI にリポジトリのコードレビューを依頼し、結果を日本語で要約して報告する。

検証済みバージョン: codex-cli 0.140.0。メジャー更新でフラグが変わりうるため、コマンドが即エラーで落ちたら `codex exec review --help` で利用可能なフラグを確認すること。

## 手順

### 1. レビュー対象の決定

引数から判断する。コマンドは次の2パターンのいずれかになる(スコープフラグと自由文 PROMPT は **併用できない**。codex 側で排他になっており、併用すると `the argument '--uncommitted' cannot be used with '[PROMPT]'` のように即エラー終了する):

- 自由文なし → スコープフラグのみ
    - 引数なし → `codex exec review --uncommitted`(staged + unstaged + untracked をレビュー)
    - `--base <branch>` → `codex exec review --base <branch>`(そのブランチとの差分)
    - `--commit <sha>` → `codex exec review --commit <sha>`(そのコミットの変更)
- 自由文あり → `codex exec review '<指示文>'`(スコープフラグは付けない)
    - レビュー対象スコープは指示文の本文に自然言語で書く(例:「uncommitted な変更(staged/unstaged/untracked)を対象に〜」)
    - デフォルトスコープが working tree なので、PROMPT 単独でも uncommitted 変更がレビューされる

### 2. 差分の存在確認

`git status --short` や `git diff` で対象に差分があることを確認する。なければその旨を報告して終了。

### 3. レビュー実行(background Bash)

レビューは数分かかるので、必ず `run_in_background: true` で実行する。完了すると通知が来るのでポーリングは不要。

```bash
out=$(mktemp /tmp/codex-review.XXXXXX.md)
err=$(mktemp /tmp/codex-review.XXXXXX.err)
echo "output: $out / stderr: $err"
codex exec review --uncommitted > "$out" 2>"$err" </dev/null
```

自由文ありのときはスコープフラグを付けず PROMPT 単独で実行する:

```bash
codex exec review '<scope を含む指示文>' > "$out" 2>"$err" </dev/null
```

注意:

- stderr は `2>&1` で混ぜず別ファイルに分ける(codexが `Reading additional input from stdin...` 等の非JSON行を stderr に出すため。レビュー本文を汚さない)
- 色制御が必要なら `NO_COLOR=1` を環境変数で渡す(`--color` オプションは存在しない)
- 起動が即エラーで落ちたら、未知フラグ(`--color` 等)やフラグと PROMPT の併用が原因。該当フラグを外してリトライする。フラグが不明なときは `codex exec review --help` で確認する

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
tmux-agent ask review -- codex exec review --uncommitted
tmux-agent wait review --timeout 900   # .done ファイルで完了判定
cat "$(tmux-agent outfile review)"
tmux-agent kill review                  # 報告後に後始末
```
