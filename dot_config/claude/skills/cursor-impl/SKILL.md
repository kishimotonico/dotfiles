---
name: cursor-impl
description: Cursor Agent CLI (cursor-agent -p) に実装・修正・調査タスクを委譲する。「Cursorに実装させて」「Composerにやらせて」「Cursorで直して」などの場面で使用。Codexに依頼する場合は codex-impl、OpenCodeなら opencode-impl を使う。
---

# Cursor Agent Implementation

Cursor Agent CLI に実装・修正タスクを委譲し、結果をレビューして報告する。やることは codex-impl / opencode-impl と同じで、依頼先が Cursor Agent という違いだけ。

**`--model composer-2.5` を必ず明示する**。省略時は `~/.config/cursor/cli-config.json` の `selectedModel`(対話TUIの選択に引きずられる。`fast` 付きだと料金の高い `Composer 2.5 Fast`)に従う。他のモデルを使うのはユーザーが指定したときだけ(`cursor-agent --list-models` で一覧が出る)。

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

Cursorはこの会話の文脈を知らない前提で、自己完結したプロンプトにまとめる。背景 / 対象ファイル / 期待する結果 / 制約 / 検証分担(Cursor側で回すコマンドと、委譲元側でやる検証)を含め、レンダリング依存・バイナリ成果物(スクリーンショット等)は生成させない。

Cursorの報告・テスト名・ACチェックは実態より強く出る傾向がある。末尾に次の定型ブロックを貼る(書き漏れた項目で実際に違反・水増しが起きている):

```markdown
## 制約(必ず守ること)

- git commit / git add / git push はしないこと(コミットは委譲元側で行う)
- 指定したディレクトリの外のファイルを変更しないこと
- テストを通すために本番の実装・仕様を変えないこと。テストは実装の振る舞いを記述する
  もの。仕様変更が必要だと判断したら、変更せずに報告すること
- 「◯◯は環境制約でできない」と報告する場合は、実行したコマンドとエラー全文を添えること
- 受け入れ条件をチェックするときは根拠を書くこと。「テストを追加した」ではなく、その
  テストが何を観測して合否を決めるかを書く。追加したテストは、検証対象を一時的に壊して
  赤くなることを確認し(負の検証)、元に戻したうえで、どこを壊して何が落ちたかを報告すること
```

- 計測を依頼するときは、測る区間を明示し、生ログ(タイムスタンプ付き)の添付と複数回の実測を要求する。指定しないと、測りやすい区間の最良1サンプルが代表値として返ってくる
- 調査だけを頼むなら `--mode plan`(分析と計画の提案)か `--mode ask`(Q&A)。どちらも読み取り専用なので、書き換えられる心配なく投げられる

### 2. 実行(background Bash)

実装は数分かかるので、必ず `run_in_background: true` で実行する。

```bash
cd /abs/path/to/project || exit 1
out=$(mktemp /tmp/cursor-impl.XXXXXX.jsonl)
err=$(mktemp /tmp/cursor-impl.XXXXXX.err)
echo "cwd: $PWD / output: $out / stderr: $err / done: $out.done / pid: $out.pid"
echo $$ > "$out.pid"
timeout 1800 cursor-agent -p --trust --auto-review --model composer-2.5 --output-format stream-json "<指示>" > "$out" 2>"$err" </dev/null
echo "exit=$?" > "$out.done"
```

- 冒頭の絶対パス `cd` は省略しない。シェルのcwdは直前のコマンドに引きずられるため、`cd` なしだと無関係なディレクトリで実装が走る事故が起きる(実績3回)
- 起動コマンドに `rm -f` 等の後始末を混ぜない。権限プロンプトで全体が止まる。mktemp は毎回新しいファイルを作るので旧ログを消す必要もない
- コマンド文字列の中で cursor-agent を `&` で背景化しない。ラッパーシェルが即終了し、子の cursor-agent が道連れになる
- `$out.done` は完了フラグ、`$out.pid` は生存確認用。background の完了通知はターン境界やコンテキスト要約をまたぐと拾い損ねるので、ファイルだけで判定できるようにしておく
- `timeout 1800` は無応答のまま居座るのを防ぐ保険(タイムアウト時は `exit=124`)
- 起動を確認したら `head -1 "$out"` で `session_id` を控える。`$out` のパスを失っても(要約・/tmp掃除)復旧できる
- `--output-format json` は使わない。終了まで完全に無音で、フリーズと作業中の区別が付かない。`stream-json` なら1行ずつ流れ、最後の `result` 行に `json` と同じ内容が入る
- 実行中はClaudeは working tree を変更しない(並行編集事故の防止。読み取りはOK)

#### 状態確認

プロセスの終了とタスクの完了は別物。done・result・プロセス生存の3点を突き合わせる:

```bash
cat "$out.done" 2>/dev/null || echo "done未出力"
jq -cR 'fromjson? // empty | select(.type=="result") | {is_error, subtype}' "$out"   # Cursorの完了報告
kill -0 "$(cat "$out.pid")" 2>/dev/null && echo "生存" || echo "停止"
ls -l --time-style=+%H:%M "$out"        # 最終書込時刻
```

| 状態 | 判断 |
|---|---|
| done有り + result有り | 正常完了。手順3へ |
| done有り + result無し | 異常終了。ストリームが途中で切れている。「異常終了からの復旧」へ |
| done無し + プロセス停止 | 道連れの異常終了(親が死ぬと done は書かれない)。同じく復旧へ |
| done無し + プロセス生存 | 実行中。最終書込が10分以上前ならフリーズの可能性、TaskStop で止めて報告 |
| done無し + result有り | 出力のフラッシュ待ち。数秒後に再確認 |

- 生存確認に `pgrep -f "cursor-agent"` は使わない。確認コマンド自身・並行セッション・終了後も残留する `worker-server`(正常終了でも残る)に誤マッチする。行数の増加も傍証止まり(過去の増加を現在の進行と取り違える)
- 生存しているのに進まないときは stdin 待ちを疑う(`</dev/null` の付け忘れが典型)。`pstree -p "$(cat "$out.pid")"` で本体PIDを出し、`ps -o etime,time -p <PID>` で経過時間だけ伸びてCPU時間が `00:00:00` のままなら該当
- 完了通知の取りこぼし対策に、番犬を別の background Bash で張っておくと確実:

    ```bash
    until [ -f "$out.done" ]; do sleep 10; done; echo "cursor finished: $(cat "$out.done")"
    ```

### 3. 結果確認

確認の順序: **① `system` 行で cwd とモデル → ② 差分を自分の目で → ③ `.result` は最後**。Cursorの最終報告は良く書けたMarkdownレポートなので、先に読むとそのフレーミングに引きずられて差分レビューが甘くなる。

```bash
# ① 意図した場所・モデルで動いたか。モデル名とcwdはsystem行にしか出ない
#    (result行のmodelは常にnull。system行のpermissionModeは--auto-reviewでもdefaultのままで当てにならない)
jq -cR 'fromjson? // empty | select(.type=="system") | {model, cwd, session_id}' "$out"

# ② 差分。新規ファイル(re-exportのshim・一時ファイルの残骸)はdiffに出ないのでstatusで拾う
git status --short --untracked-files=all && git diff
```

そのうえでログから拾う:

```bash
# 触ったファイル(自己申告ではなくツール呼び出しの記録)
jq -rR 'fromjson? // empty | .tool_call.editToolCall.args.path // .tool_call.writeToolCall.args.path // empty' "$out" | sort -u

# 実際に走らせたコマンド(検証を飛ばしていないかの確認)
jq -rR 'fromjson? // empty | .tool_call.shellToolCall.args.command // empty' "$out" | sort -u

# 最終報告・失敗判定・トークン消費(result行は json 形式の出力と同一)
jq -rR 'fromjson? // empty | select(.type=="result") | .result' "$out"
jq -cR 'fromjson? // empty | select(.type=="result") | {is_error, subtype, session_id, usage}' "$out"
```

`is_error` が false でも、Shell拒否で検証を飛ばしていることがある。テストを回したと報告しているのに shellToolCall の一覧が空なら、報告と証跡が食い違っているので確認する(イベントのスキーマが変わって抽出できていないだけ、という可能性もある)。負の検証を指示した場合は、壊した→落ちた→戻した、の一連が shellToolCall と diff に残っているかまで見る。いずれにせよCursorの自己申告を鵜呑みにせず、ビルド・テスト・lintは自分でも回す。

作業ログの全文は `~/.cursor/projects/<パスをスラグ化したもの>/agent-transcripts/<session_id>/<session_id>.jsonl` に残る。ツール呼び出し単位で追える。

### 異常終了からの復旧

呼び出し元の Claude Code プロセスが終了・再起動すると、background の cursor-agent は道連れで殺される(result 行なし・stderr 空が典型)。Cursor 側の障害ではないので、作業内容を手で再構成せず `--resume` で Cursor 自身の文脈ごと再開する:

```bash
sid=$(jq -rR 'fromjson? // empty | select(.type=="system") | .session_id' "$out" | head -1)   # system行は最初に出るので途中死でも残る
git status --short --untracked-files=all && git diff --stat   # 作業ツリーの中間状態を確認
```

そのうえで手順4と同じ形で `--resume "$sid"` を実行する。続きの指示には「これは中断による中間状態であり、設計の誤りではない」と明記する。書かないと、型エラー等の壊れた状態を見て既存実装を作り直しにかかる。

出力が数百KB規模になりそうな依頼は、実装 / テスト / 検証 などで複数ラウンドに分ける。中断で失うのが最後の区間だけで済む。

### 4. 反復(必要な場合)

修正を差し戻すときは、手順3で取ったセッションIDを明示して継続する。差し戻しの指示には、直すものと合わせて**維持するもの**(前ラウンドの成果で触ってほしくない部分)を明記する。ラウンドを重ねると、指摘と無関係な良い成果まで巻き戻してくることがある。

```bash
cd /abs/path/to/project || exit 1
out2=$(mktemp /tmp/cursor-impl.XXXXXX.jsonl); err2=$(mktemp /tmp/cursor-impl.XXXXXX.err)
echo $$ > "$out2.pid"
timeout 1800 cursor-agent -p --resume <session_id> --trust --auto-review --model composer-2.5 --output-format stream-json "<修正指示>" > "$out2" 2>"$err2" </dev/null
echo "exit=$?" > "$out2.done"
```

`--continue`(直前セッションの継続)は使用禁止。並行で別セッションが動いていると無関係なセッションを掴むため、必ずIDを明示する。継続時も `session_id` は同じ値が返る。

### 5. 報告

何が変わったか(`file:line` 参照付き)、自分のレビュー所見、テスト結果を報告する。

## ユーザーが進捗を見たい場合

「観戦したい」「ペインで見たい」と言われたら、background Bash の代わりに herdr のペインで実行する。手順は [references/herdr-watch.md](references/herdr-watch.md) を読む。
