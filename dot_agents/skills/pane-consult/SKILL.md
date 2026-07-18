---
name: pane-consult
description: herdr pane間の相談・返信プロトコル。「[consult from=…]」「[reply from=…]」を受け取ったとき、または別paneのエージェントへ相談・返信するときに使う。HERDR_ENV=1 のときのみ有効。
---

# pane-consult

herdr内のエージェントとの連絡には `herdr-msg` を使う。

```bash
herdr-msg consult <agent|terminal_id> '<相談>'
herdr-msg reply <fromの値> '<返事>'
herdr-msg list [agent]
herdr-msg pick <agent>
```

## 受信

`[consult from=<address>]` を受け取ったら依頼に対応し、結果を次のコマンドで返す。

```bash
herdr-msg reply <address> '<返事を1行で>'
```

回答本文はreplyへ集約し、自paneのユーザーには対応したことを簡潔に報告する。長い内容は一時ファイルへ書き、replyには要約とパスだけを入れる。

`[reply from=…]` は原則として会話の終点とする。質問、追加依頼、修正報告が含まれる場合だけ対応し、受領確認やお礼だけの返信は送らない。

## 送信

- agent名を渡すと同一タブ > 同一cwdの順で自動選択される。決められずexit 2になったら、候補のterminal IDを指定して再実行する
- 相手がworkingでも送信できる
- 送信後はポーリングも `pane read` もせず、ターンを終える
- メッセージは1行にする。複雑な引用や長文はファイル経由にする
- `herdr-msg` はherdrが検出済みのagent専用
