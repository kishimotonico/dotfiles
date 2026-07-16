---
name: consult-claude
description: herdrセッション内の別paneで動いているClaude Code (Fable) に相談・レビュー依頼を送る。実装方針を相談したいとき、セカンドオピニオンやレビューが欲しいとき、ユーザーに「Fableに聞いて」「Claudeに相談して」と言われたときに使う。HERDR_ENV=1 のときのみ有効。
---

# consult-claude — 別paneのClaudeに相談する

herdr上では各paneが独立したエージェントとして動いている。このスキルは、同じherdrセッション内のClaude Code paneに質問やレビュー依頼を送り、返事を受け取る手順を定める。

## 前提チェック

`HERDR_ENV` が `1` でなければ、herdr外で動いているためこのスキルは使えない。その旨を伝えて終了する。

## 1. 相談先のClaude paneを探す

```bash
herdr pane list | jq '[.result.panes[] | select(.agent == "claude") | {pane_id, cwd, agent_status, terminal_title_stripped}]'
```

- 自分と同じ `cwd`（または同じプロジェクト配下）のpaneを最優先で選ぶ
- 候補が複数あって決めきれない場合はユーザーに確認する
- `agent_status` が `working` でも送信してよい（入力はキューされ、相手のターンが終わり次第処理される）
- 候補が1つもなければ、Claude paneが見つからないことをユーザーに伝えて終了する

## 2. メッセージを組み立てる

形式（**必ず1行**。改行は送信扱いになるため含めない）:

```
[consult from=$HERDR_PANE_ID] <質問・依頼の本文>。返信は herdr pane run $HERDR_PANE_ID '<返事>' で1行で送って。長くなる場合はファイルに書いてそのパスを伝えて。
```

- `from=` には自分のpane ID（環境変数 `$HERDR_PANE_ID`）を必ず入れる。これが返信先になる
- 本文が長い場合（diffやコード、詳細な背景説明など）は一時ファイルに書き出し、本文には要約とファイルパスだけを書く

```bash
cat > /tmp/consult-$$.md <<'EOF'
（相談の詳細・コード・diffなど）
EOF
```

- シングルクォートのネストに注意。本文にシングルクォートを含めない言い回しにするか、ファイル経由にする

## 3. 送信する

```bash
herdr pane run <claude_pane_id> '[consult from=... ] ...'
```

## 4. ターンを終えて返事を待つ

送信したら **ポーリングせずにターンを終了する**。ユーザーには「Fableに相談を送った。返事は次のメッセージとして届く」と伝える。

返事は相手が `herdr pane run` でこちらのpaneに書き込むため、`[reply from=<pane_id>] ...` という形式の入力メッセージとして届く。届いたらその内容を踏まえて作業を続ける。追加で聞きたいことがあれば同じ手順で送る。

## 注意

- pane IDは永続的ではない。相談のたびに `herdr pane list` で探し直すこと
- 相手のpaneの画面を `herdr pane read` でスクレイピングして返事を探さないこと。返事は必ず自paneへの入力として届く
- ユーザーの許可なく相談以外の操作（相手paneへのコマンド実行指示など）をしないこと
