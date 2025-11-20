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
$ uv run rewrite_ssh_config.py
```

"""

from typing import List, Optional
from pathlib import Path
from dataclasses import dataclass
import subprocess
import re
import sys

SSH_CONFIG = Path('~/.ssh/config').expanduser()
SSH_CONFIG = Path('test_config')
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
            print(f"\n[Error] Command: {command}\n[Stderr] {result.stderr.decode('utf-8')}", file=sys.stderr)
            return None
        return result.stdout.decode('utf-8').strip()
    except Exception as e:
        print(f"\n[Exception] {e}", file=sys.stderr)
        return None

def analyze_tasks(lines: List[str]) -> List[UpdateTask]:
    """
    1. 全行を解析
    2. ディレクティブ行を見つけたら、次の行がHostNameか確認
    3. 更新タスクのリストを返す
    """
    tasks = []
    
    for i, line in enumerate(lines):
        # ディレクティブ行かチェック
        match = re.match(DIRECTIVE, line)
        if not match:
            continue
            
        # 最終行の場合は次は存在しないのでスキップ
        if i + 1 >= len(lines):
            continue
            
        # 次の行（書き換え対象）をチェック
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
        else:
            print(f"[Warning] Directive found for '{match.group('name')}' but next line is not 'HostName'. Skipped.")

    return tasks

def apply_updates(lines: List[str], tasks: List[UpdateTask]) -> List[str]:
    """
    タスクリストに従ってコマンドを実行し、linesを直接書き換える
    """
    # linesのコピーを作成（念のため）
    new_lines = lines.copy()
    
    print("\n--- Executing Commands ---")
    
    for task in tasks:
        print(f"Updating [{task.name}] ... ", end='', flush=True)
        
        new_ip = command_execute(task.command)
        
        if new_ip:
            # 行を完全に置き換える（インデント + 新しいIP）
            new_lines[task.target_line_index] = f"{task.indent_prefix}{new_ip}"
            print(f"OK -> {new_ip}")
        else:
            print("FAILED (Keep original)")
            
    return new_lines

def main():
    if not SSH_CONFIG.exists():
        print(f"Config file not found: {SSH_CONFIG}")
        return

    print(f"Reading config from: {SSH_CONFIG}")
    config_text = SSH_CONFIG.read_text(encoding='utf-8')
    
    # 行単位に分割（改行コードは削除されるが、後でjoinで復元する）
    lines = config_text.splitlines()
    
    # 1. 解析
    tasks = analyze_tasks(lines)
    
    if not tasks:
        print("No update directives found.")
        return

    # 2. 確認表示 (ユーザーへのサマリ)
    print(f"\nFound {len(tasks)} directives:")
    for task in tasks:
        # 表示用にコマンドが長すぎる場合は省略してもよい
        short_cmd = (task.command[:60] + '...') if len(task.command) > 60 else task.command
        print(f" - [{task.name}] will update line {task.target_line_index + 1}")
        print(f"   Command: {short_cmd}")

    # 3. 実行 & 書き換え
    # ここで "Continue? [Y/n]" のようなインタラクションを入れることも可能です
    updated_lines = apply_updates(lines, tasks)
    
    # 4. ファイル書き込み
    new_config_text = '\n'.join(updated_lines) + '\n'
    
    if config_text != new_config_text:
        SSH_CONFIG.write_text(new_config_text, encoding='utf-8')
        print("\nConfig updated successfully.")
    else:
        print("\nNo changes made.")

if __name__ == '__main__':
    main()