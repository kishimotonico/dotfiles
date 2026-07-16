---
name: pane-consult
description: herdr pane間のエージェント相談プロトコル。「[consult from=<pane_id>] …」形式のメッセージを受け取ったとき、または別paneのエージェント(Codexなど)に相談・返信したいときに使う。HERDR_ENV=1 のときのみ有効。
---

# pane-consult — pane間の相談への返信作法

herdr上の別paneのエージェント(Codexなど)は、次の形式で相談を送ってくる:

```
[consult from=<pane_id>] <質問・依頼>
```

これを受け取ったときの手順:

1. 通常のツールで質問に答える。ユーザーへの報告はいつもどおり行う
2. 送信元paneに **1行で** 返信する（改行は途中送信になるため含めない）:

```bash
herdr pane run <pane_id> '[reply from=自分のpane ID] <返事を1行で>'
```

自分のpane IDは環境変数 `$HERDR_PANE_ID` にある。

3. 返事が長くなる場合（レビュー結果・コード・diffなど）は一時ファイルに書き出し、1行の要約とファイルパスだけを送る
4. メッセージ本文にシングルクォートを含めない。言い回しを変えるかファイル経由にする
5. 相手が読んだか確認するために相手のpaneを `herdr pane read` しないこと。書き込んだ入力はキューされ、相手のターンが終わり次第処理される

## こちらから相談する場合

逆方向（自分から別paneのエージェントに相談する）も同じ形式を使う:

1. `herdr pane list` で相談先paneを探す（`agent` フィールドと `cwd` で判断。pane IDは永続的でないため毎回探し直す）
2. `[consult from=$HERDR_PANE_ID] <本文>。返信は herdr pane run $HERDR_PANE_ID で1行で送って。長い場合はファイルパスを伝えて。` を1行で `pane run` 送信
3. ポーリングせずターンを終了する。返事は `[reply from=…]` 形式の入力メッセージとして届く

対になるCodex側の手順は `~/.config/codex/skills/consult-claude/SKILL.md` にある。
