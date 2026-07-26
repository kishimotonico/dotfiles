---
name: cursor-impl
description: Cursor Agent CLI (cursor-agent -p) に実装・修正・調査タスクを委譲する。「Cursorに実装させて」「Composerにやらせて」「Cursorで直して」などの場面で使用。Codexに依頼する場合は codex-impl、OpenCodeなら opencode-impl を使う。
---

# Cursor Agent Implementation

Cursor Agent CLI に実装・修正タスクを委譲し、結果をレビューして報告する。やることは codex-impl / opencode-impl と同じで、依頼先が Cursor Agent という違いだけ。

**`--model composer-2.5` を必ず明示する**。省略時は `~/.config/cursor/cli-config.json` の `selectedModel` に従うため、ユーザーが対話TUIで選んだ設定に引きずられる。そこには `fast` パラメータが入っていることがあり、無指定だと料金の高い `Composer 2.5 Fast` になる。他のモデルを使うのはユーザーが指定したときだけ(`cursor-agent --list-models` で一覧が出る)。

## 権限フラグ(先に読む)

ここを間違えると静かに失敗するので、フラグの意味を把握してから実行する。2026.07.23-e383d2b で実測した挙動:

- `--trust` は必須。付けないと "Workspace Trust Required" を表示して**何もせず正常終了(exit 0)**する。空振りに気付きにくい
- 権限フラグなしの `-p` では、ファイル編集は通るが **Shell がすべて拒否される**。「テストは実行できませんでした」と報告してくるので、検証させたいなら `--auto-review` を付ける
- `--auto-review` はサーバ側分類器が安全な操作を自動実行する。ただし `sudo rm -rf <path>` すら承認を挟まず実行に回した。**安全弁として当てにしない**
- `--force` / `--yolo` は全許可。`--auto-review` で足りるので原則使わない
- `--sandbox enabled` は WSL では効かなかった。ワークスペース外(ホームディレクトリ直下)への書き込みが素通りする。**隔離を期待しない**
- `-p` では承認待ちでハングしない。実行できない操作は失敗としてモデルに返り、代替を試すか報告してくる

`--auto-review` は Shell を通すので、実質的にユーザー権限をそのままモデルに渡すのと同じ。プロンプトに書いた禁止事項は安全境界にならない。自分が管理している信頼済みリポジトリ、本番の資格情報が無い環境、普段使いでないブラウザプロファイル、この条件が揃うときに使う。外部由来のコードを動かす場合や、本番・共有環境に接続できる状態では使わない。

隔離が要る作業(ワークスペース外に触れる、複数エージェントの並行実行)は `-w, --worktree <name>` を使う。`~/.cursor/worktrees/<repo>/<name>` に git worktree を作るので、終わったら `git worktree remove` で片付ける。

## 手順

### 1. 依頼内容の整理

Cursorはこの会話の文脈を知らない前提で、自己完結したプロンプトにまとめる。含める項目:

- 背景 / 対象ファイル / 期待する結果 / 制約
- 検証分担: Cursor側で回すコマンドと、委譲元側でやる検証(ブラウザ実機確認・画像生成)を明示
- **「git commit・git add はしないこと」を明記**(コミットは委譲元側で行う)
- レンダリング依存・バイナリ成果物(スクリーンショット等)は生成させない

調査だけを頼むなら `--mode plan`(分析と計画の提案)か `--mode ask`(Q&A)を付ける。どちらも読み取り専用なので、書き換えられる心配なく投げられる。

### 2. 実行(background Bash)

実装は数分かかるので、必ず `run_in_background: true` で実行する。プロジェクトディレクトリから実行する。

```bash
out=$(mktemp /tmp/cursor-impl.XXXXXX.jsonl)
err=$(mktemp /tmp/cursor-impl.XXXXXX.err)
echo "output: $out / stderr: $err"
cursor-agent -p --trust --auto-review --model composer-2.5 --output-format stream-json "<指示>" > "$out" 2>"$err" </dev/null
```

**`--output-format json` は使わない**。全部終わってから単一オブジェクトを一度に吐くので、終わるまで出力が完全に無音になる。10分級の作業だとフリーズか作業中か区別が付かない。`stream-json` なら1行ずつ流れてくるうえ、最後の `result` 行に `json` と同じ内容がそのまま入るので、失うものがない。

- 実行中はClaudeは working tree を変更しない(並行編集事故の防止。読み取りはOK)
- 生存確認は `wc -l "$out"` か `tail -2 "$out"`。行が増えていれば動いている
- 長時間(10分以上)行数が伸びていなければフリーズの可能性。TaskStop で止めて報告する
- `--stream-partial-output` はテキストをトークン単位に刻むだけで、行数が無駄に増えて読みにくい。人間が横で眺めるとき以外は付けない

### 3. 結果確認

**先に差分を見る。`.result` を読むのは後**。Cursorの最終報告は良く書けたMarkdownレポートなので、先に読むとそのフレーミングに引きずられて差分レビューが甘くなる。

```bash
git status --short && git diff                 # まず自分の目で見る
```

そのうえでログから拾う:

```bash
# 触ったファイル(自己申告ではなくツール呼び出しの記録)
jq -rR 'fromjson? // empty | .tool_call.editToolCall.args.path // .tool_call.writeToolCall.args.path // empty' "$out" | sort -u

# 実際に走らせたコマンド(検証を飛ばしていないかの確認)
jq -rR 'fromjson? // empty | .tool_call.shellToolCall.args.command // empty' "$out" | sort -u

# 実際に使われたモデルと作業ディレクトリ
jq -cR 'fromjson? // empty | select(.type=="system") | {model, cwd, session_id}' "$out"

# 最終報告・失敗判定・トークン消費(result行は json 形式の出力と同一)
jq -rR 'fromjson? // empty | select(.type=="result") | .result' "$out"
jq -cR 'fromjson? // empty | select(.type=="result") | {is_error, subtype, session_id, usage}' "$out"
```

`is_error` が false でも、Shell拒否で検証を飛ばしていることがある。テストを回したと報告しているのに shellToolCall の一覧が空なら、報告と証跡が食い違っているので確認する(イベントのスキーマが変わって抽出できていないだけ、という可能性もある)。いずれにせよCursorの自己申告を鵜呑みにせず、ビルド・テスト・lintは自分でも回す。

モデル名は `system` 行にしか出ない。`result` 行に `model` フィールドは無いので、そちらを見ると常に null になる。同じ `system` 行の `permissionMode` は `--auto-review` を付けても `default` のままなので当てにしない。

作業ログの全文は `~/.cursor/projects/<パスをスラグ化したもの>/agent-transcripts/<session_id>/<session_id>.jsonl` に残る。ツール呼び出し単位で追える。

### 4. 反復(必要な場合)

修正を差し戻すときは、手順3で取ったセッションIDを明示して継続する:

```bash
cursor-agent -p --resume <session_id> --trust --auto-review --model composer-2.5 --output-format stream-json "<修正指示>" > "$out2" 2>"$err2" </dev/null
```

`--continue`(直前セッションの継続)は使用禁止。並行で別セッションが動いていると無関係なセッションを掴むため、必ずIDを明示する。継続時も `session_id` は同じ値が返る。

### 5. 報告

- 何が変わったか(`file:line` 参照付き)、自分のレビュー所見、テスト結果を日本語で報告
- コミットはユーザーの指示があるまでしない

## ユーザーが進捗を見たい場合

「観戦したい」「ペインで見たい」と言われたら、background Bash の代わりに herdr のペインで実行する。`HERDR_ENV` が `1` でなければ herdr 管理下にないので、その旨を伝えて通常の background Bash で実行する。

```bash
out=$(mktemp /tmp/cursor-impl.XXXXXX.log)
self=$(herdr pane list | jq -r --arg cwd "$PWD" '[.result.panes[] | select(.agent=="claude" and .cwd==$cwd)][0].pane_id')
pane=$(herdr pane split "$self" --direction down --no-focus | jq -r '.result.pane.pane_id')
herdr pane run "$pane" "cursor-agent -p --trust --auto-review --model composer-2.5 '<指示>' 2>&1 | tee $out"'; echo "CURSOR""_DONE:$?"'
herdr wait output "$pane" --match 'CURSOR_DONE:' --timeout 1800000
cat "$out"
```

- ペインで見せるときは `--output-format` を外してテキスト出力にする。この場合セッションIDは出力に出ないので、反復が必要なら transcript のディレクトリ名から拾う

    ```bash
    basename "$(ls -1td ~/.cursor/projects/*/agent-transcripts/*/ | head -1)"
    ```

    最終更新が最新のものを採るだけなので、並行して別セッションを走らせているときは当てにならない

- マーカーを `"CURSOR""_DONE"` と分割するのは、入力エコー行への誤マッチ防止(出力の `CURSOR_DONE:<exit code>` だけがマッチする)
- タイムアウト時は `herdr pane read "$pane" --source recent-unwrapped --lines 50` で画面を確認して状況を報告する
- 報告が終わったら `herdr pane close "$pane"` で後始末する(ユーザーが見終わったことを確認してから)
