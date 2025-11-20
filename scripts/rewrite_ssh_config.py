#!/usr/bin/env python3
from typing import List, Optional
from pathlib import Path
import subprocess
import re

"""

OpenSSH configのIPアドレスを動的に書き換えるツールです

### 使い方

~/.ssh/config に `#<|name|> ` の後に続けて、CLIのコマンドを記載します。

```
Host example1-prod-bastion
    #<|example1|> aws --profile example1 ec2 describe-instances --filters 'Name=tag:Name,Values=hoge-bastion' --query 'Reservations[].Instances[].PublicIpAddress' --output text
    HostName 127.1.2.3
```

シェルでこのスクリプトを実行すると、`HostName` の値がコマンドの実行結果に置き換わります。

```bash
$ uv run --with=InquirerPy rewrite_ssh_config.py
```

"""

from typing import List, Optional, Dict
from pathlib import Path
from dataclasses import dataclass
import subprocess
import re
import sys
from InquirerPy.prompts.fuzzy import FuzzyPrompt

SSH_CONFIG = Path('~/.ssh/config').expanduser()
DIRECTIVE = r'^\s*#<\|(?P<name>.+)\|> ?(?P<cmd>.*)'
HOSTNAME_PATTERN = re.compile(r'^(\s*HostName\s+)(.*)', re.IGNORECASE)

@dataclass
class UpdateTask:
    name: str
    command: str
    target_line_index: int  # 書き換え対象の行番号（0始まり）
    indent_prefix: str      # "    HostName " の部分（インデント含む）

def command_execute(command: str) -> Optional[str]:
    """
    コマンドを実行し、標準出力を文字列として返します。
    """
    try:
        result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            err_msg = result.stderr.decode('utf-8').strip()
            if err_msg:
                print(f"\n[Error] Command: {command}\n[Stderr] {err_msg}", file=sys.stderr)
            return None
        return result.stdout.decode('utf-8').strip()
    except Exception as e:
        print(f"\n[Exception] {e}", file=sys.stderr)
        return None

def analyze_tasks(lines: List[str]) -> List[UpdateTask]:
    """
    全行を解析し、更新可能なタスクのリストを返します。
    """
    tasks = []

    for i, line in enumerate(lines):
        match = re.match(DIRECTIVE, line)
        if not match:
            continue

        if i + 1 >= len(lines):
            continue

        target_line_index = i + 1
        target_line = lines[target_line_index]

        hn_match = HOSTNAME_PATTERN.match(target_line)
        if hn_match:
            tasks.append(UpdateTask(
                name=match.group('name'),
                command=match.group('cmd'),
                target_line_index=target_line_index,
                indent_prefix=hn_match.group(1)
            ))

    return tasks

def select_tasks(tasks: List[UpdateTask]) -> List[UpdateTask]:
    """
    InquirerPyを使って実行するタスクを選択させます。
    単一選択モードです。
    """
    if not tasks:
        return []

    # タスクを名前ごとにグループ化
    tasks_by_name: Dict[str, List[UpdateTask]] = {}
    for task in tasks:
        if task.name not in tasks_by_name:
            tasks_by_name[task.name] = []
        tasks_by_name[task.name].append(task)

    # 選択肢の作成 (名前の一覧)
    choices = sorted(list(tasks_by_name.keys()))

    print("\n[選択] 更新したいディレクティブを選んでください")

    try:
        # multiselect=False により単一選択モードになります
        selected_name = FuzzyPrompt(
            message="Directives:",
            choices=choices,
            multiselect=False,
            instruction="[↑/↓] 移動, [Enter] 決定, [Ctrl+C] キャンセル",
        ).execute()

        # キャンセルや未選択(None)の場合は空リストを返す
        if not selected_name:
            return []

        # 選択された名前に紐づく全タスクを返す
        return tasks_by_name[selected_name]

    except KeyboardInterrupt:
        # Ctrl+C が押された場合は空リストを返してキャンセル扱いにする
        return []

def apply_updates(lines: List[str], tasks: List[UpdateTask]) -> List[str]:
    """
    タスクリストに従ってコマンドを実行し、linesを書き換えます。
    """
    new_lines = lines.copy()

    print("\n--- コマンド実行開始 ---")

    # 実行順序を行番号順にソート
    sorted_tasks = sorted(tasks, key=lambda t: t.target_line_index)

    for task in sorted_tasks:
        print(f"[{task.name}] 更新中... ", end='', flush=True)

        new_ip = command_execute(task.command)

        if new_ip:
            new_lines[task.target_line_index] = f"{task.indent_prefix}{new_ip}"
            print(f"成功 -> {new_ip}")
        else:
            print("失敗 (変更なし)")

    return new_lines

def main():
    try:
        if not SSH_CONFIG.exists():
            print(f"設定ファイルが見つかりません: {SSH_CONFIG}")
            return

        # 1. 読み込み & 解析
        config_text = SSH_CONFIG.read_text(encoding='utf-8')
        lines = config_text.splitlines()
        all_tasks = analyze_tasks(lines)

        if not all_tasks:
            print("更新対象のディレクティブが見つかりませんでした。")
            return

        # 2. 選択 (単一選択)
        target_tasks = select_tasks(all_tasks)

        if not target_tasks:
            print("\nキャンセルされました。")
            return

        # 3. 実行 & 書き換え
        updated_lines = apply_updates(lines, target_tasks)

        # 4. 保存
        new_config_text = '\n'.join(updated_lines) + '\n'

        if config_text != new_config_text:
            SSH_CONFIG.write_text(new_config_text, encoding='utf-8')
            print("\n設定ファイルを更新しました。")
        else:
            print("\n変更点はありませんでした。")

    except KeyboardInterrupt:
        print("\n\n処理を中断しました。")
        sys.exit(0)

if __name__ == '__main__':
    main()