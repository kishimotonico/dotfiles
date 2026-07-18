---
name: pane-consult
description: herdr pane間のエージェント相談プロトコル。「[consult from=<pane_id>] …」形式のメッセージを受け取ったとき、または別paneのエージェント(Codexなど)に相談・返信したいときに使う。HERDR_ENV=1 のときのみ有効。
---

# pane-consult — pane間の相談プロトコル

herdr上のpane間メッセージングは `herdr-msg`（`~/.local/bin/herdr-msg`）に集約されている。pane探索・メッセージ整形・Enter取りこぼしを避ける分割送信はスクリプト側がやるので、以下のコマンドをそのまま使えばよい。

```bash
herdr-msg list [agent]                  # 自分以外のエージェント一覧 (jsonl)
herdr-msg consult <agent|pane_id|terminal_id> <本文>  # 相談を送る
herdr-msg pick <agent>                  # 自動選択結果のterminal_idを表示 (送信しない)
herdr-msg reply <reply_address> <本文>  # 相談への返信
herdr-msg send <agent_target> <text>    # 整形なしの1行送信
```

## 相談を受け取ったとき

`[consult from=<返信先アドレス>] <質問・依頼>` 形式のメッセージが届いたら:

1. 通常のツールで質問に答える。ユーザーへの報告はいつもどおり行う
2. 送信元に返信する: `from=` の値（通常は `term_...@<agent_session_id>`。旧形式のpane IDや `pane_id@terminal_id` のこともある）をそのままコピーして `herdr-msg reply <そのアドレス> '<返事を1行で>'` とする
3. 返事が長くなる場合（レビュー結果・コード・diffなど）は一時ファイルに書き出し、1行の要約とファイルパスだけを送る

## こちらから相談するとき

```bash
herdr-msg consult codex '<相談内容を1行で>'
```

- agent名（`claude` / `codex` など）を渡すと **同一タブ > 同一cwd** の優先順で対象を自動選択する。**同一タブ・同一cwdのどちらにも一致する候補がない場合は、候補が1つでも自動選択せず** 候補一覧（`title` に相手の作業内容が出る）を出して exit 2 になる。絞り込み後も複数残って決めきれない場合も同様に exit 2 になる。いずれの場合も候補のterminal IDを指定して再実行する: `herdr-msg consult <terminal_id> '<本文>'`。送信前に選択先だけ確かめたいときは `herdr-msg pick <agent>`
- 送信したら**ポーリングせずターンを終了する**。返事は `[reply from=…]` 形式の入力メッセージとして届く
- 相談内容が長い場合は一時ファイルに書き出し、本文には要約とファイルパスだけを書く

## 注意

- メッセージは必ず1行。改行を含むと `herdr-msg` がエラーで拒否する（長い内容はファイル経由）
- シェル上で適切にクォートする（本文にシングルクォートを含む場合はダブルクォートで囲むなど）。複雑ならファイル経由にする
- 相手が読んだか確認するために相手のpaneを `herdr pane read` しないこと。送った入力はキューされ、相手のターンが終わり次第処理される
- 相手が `working` でも送ってよい（キューされる）
- pane IDは永続的でない。新しい相談では、live terminalを追跡するterminal IDを返信先に使う
- `herdr-msg reply` はterminal IDから現在のpane IDを引き直し、agent session IDも一致する場合だけ送信する。送信元paneが閉じられた場合や、同じterminalで別セッションが始まった場合はエラーになる
- herdr管理のClaude／Codex integration hookがagent session IDを報告していない環境では、返信先はterminal IDだけになる。この場合もpane ID再割当には追従するが、別セッションへの切り替わりは検出できない
- `herdr-msg` はherdrが検出済みのagent専用。素のshellや起動直後で未検出のagentへは、検出を待ってから送る
- エージェントTUI宛に `herdr pane run` を使わないこと。herdrのバージョンによってはEnterが取りこぼされ、入力欄にテキストが残る。`herdr-msg` は分割送信でこれを回避している（シェル宛は `pane run` でよい）

対になるCodex側の手順は `~/.config/codex/skills/consult-claude/SKILL.md` にある。
