---
name: codex-impl
description: Codex CLI (codex exec) に実装・修正タスクを委譲する。「Codexに実装させて」「Codexで直して」「Codexにやらせて」などの場面で使用。レビューだけ依頼したい場合は codex-review を使う。
---

# Codex Implementation

Codex CLI に実装・修正タスクを委譲し、結果をレビューして報告する。

## 手順

### 1. 依頼内容の整理

Codexはこの会話の文脈を知らない前提で、自己完結したプロンプトにまとめる。含める項目:

- 背景 / 対象ファイル / 期待する結果 / 制約
- 検証分担: Codex側で回すコマンド(例 `pnpm check` / `pnpm test`)と、委譲元側でやる検証(ブラウザ実機確認・画像生成)を明示
- レンダリング依存・バイナリ成果物(スクリーンショット等)はCodexに生成させない。別ツールで撮ると本番とレンダリングが異なり比較で落ちるので、spec記述だけ任せる

worktree隔離は、複数エージェントを並行で走らせるなら必須(作業ツリー衝突の防止)。単独なら不要。

### 2. 実行(background Bash)

実装は数分かかるので、必ず `run_in_background: true` で実行する。完了すると通知が来る。

```bash
out=$(mktemp /tmp/codex-impl.XXXXXX.jsonl)
err=$(mktemp /tmp/codex-impl.XXXXXX.err)
echo "output: $out / stderr: $err"
codex exec --json -s workspace-write "<指示>" > "$out" 2>"$err" </dev/null
```

重要:

- **stderr は別ファイルに分ける(`2>&1` 禁止)**。codex が stderr に出す `Reading additional input from stdin...` 等の非JSON行が JSONL に混じると `jq` が parse error で全滅する
- 実行中はClaudeは working tree を変更しない(並行編集事故の防止。読み取りはOK)
- `--json` は thread_id とメッセージを確実に抽出するため
- 長時間(10分以上)出力ファイルが伸びていなければフリーズの可能性。TaskStop で止めて報告する
- サンドボックス制約: `-s workspace-write` はネットワーク既定無効。ブラウザ起動や listen は EPERM で失敗するので、その検証は委譲元側で行う(手順1の検証分担)

### 3. 結果確認

完了通知が来たら抽出する。`jq -R 'fromjson? // empty'` で非JSON行が混じっても落ちない。スキーマはバージョンで変わりうるので、まず種別を確認する:

```bash
jq -rR 'fromjson? // empty | .type' "$out" | sort | uniq -c    # まずイベント種別を確認

# セッションID(反復用に控える)— thread.started イベントのトップレベル
jq -rR 'fromjson? // empty | select(.type=="thread.started").thread_id' "$out"

# Codexの最終報告 — item.completed にネストした agent_message。複数出ることがあるので最後を採る
jq -rR 'fromjson? // empty | select(.item.type=="agent_message") | .item.text' "$out" | tail -1

git status --short && git diff                                  # 実際の変更
```

Codexの自己申告を鵜呑みにせず、差分を自分でレビューする。ビルド・テスト・lintがあれば回す。

### 4. 反復(必要な場合)

修正を差し戻すときは、手順3で取った thread_id を明示して resume する:

```bash
codex exec resume <thread_id> --json -s workspace-write "<修正指示>" > "$out2" 2>"$err2" </dev/null
```

`resume --last` は使用禁止。並行で別のCodexセッション(レビューや別タスク)が動いていると、無関係なセッションを掴んで文脈が壊れるため、必ずIDを明示する。

### 5. 報告

- 何が変わったか(`file:line` 参照付き)、自分のレビュー所見、テスト結果を日本語で報告
- コミットはユーザーの指示があるまでしない

## ユーザーが進捗を見たい場合

「観戦したい」「ペインで見たい」と言われたら、background Bash の代わりに herdr のペインで実行する。`HERDR_ENV` が `1` でなければ herdr 管理下にないので、その旨を伝えて通常の background Bash で実行する。

この場合は `--json` を外して人間可読にする。session id は出力冒頭のバナー `session id: <uuid>` 行から取れる(バナーは stderr に出うるので `2>&1` でファイルにも残す。JSONL ではないので混ぜて問題ない):

```bash
out=$(mktemp /tmp/codex-impl.XXXXXX.log)
self=$(herdr pane list | jq -r --arg cwd "$PWD" '[.result.panes[] | select(.agent=="claude" and .cwd==$cwd)][0].pane_id')
pane=$(herdr pane split "$self" --direction down --no-focus | jq -r '.result.pane.pane_id')
herdr pane run "$pane" "codex exec -s workspace-write '<指示>' 2>&1 | tee $out"'; echo "CODEX""_DONE:$?"'
herdr wait output "$pane" --match 'CODEX_DONE:' --timeout 1800000
cat "$out"
```

- マーカーを `"CODEX""_DONE"` と分割するのは、コマンドの入力エコー行に `wait output` が誤マッチするのを防ぐため(出力の `CODEX_DONE:<exit code>` だけがマッチする)
- pane id は `w1:p1` のような形式。閉じると詰まって振り直されることがあるので、使う直前に `pane list` / `pane split` の応答から取る
- タイムアウト時は exit code 1 で返る。`herdr pane read "$pane" --source recent-unwrapped --lines 50` で画面を確認して状況を報告する
- 反復(手順4)が必要なら、控えた session id で同じペインに `codex exec resume <id> ...` を流用できる
- 報告が終わったら `herdr pane close "$pane"` で後始末する(ユーザーが見終わったことを確認してから)
