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

SSH_CONFIG = Path('~/.ssh/config').expanduser()
DIRECTIVE = r'^\s*#<\|(?P<name>.+)\|> ?(?P<cmd>.*)'

def command_execute(command: str) -> Optional[str]:
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        return None

    return result.stdout.decode('utf-8').strip()

def rewrite_config(config_text: str) -> str:
    old_lines = config_text.splitlines()
    new_lines = []

    i = 0
    while i < len(old_lines) - 1:
        current_line = old_lines[i]
        next_line = old_lines[i + 1]

        m1 = re.match(DIRECTIVE, current_line)
        m2 = re.match(r'^\s*HostName\s+(?P<hostname>.+)', next_line)

        if not m1 or not m2:
            new_lines.append(current_line)
            i += 1
            continue

        name = m1.group('name')
        cmd = m1.group('cmd')
        hostname = m2.group('hostname')
        
        print(f"{name}: コマンド `{cmd}` を実行します")
        result = command_execute(cmd)

        if result is None:
            print(f"    エラーになりました")
            new_lines.append(current_line)
            i += 2
            continue

        if result.strip() == '':
            print(f"    実行結果が空でした")
            new_lines.append(current_line)
            i += 2
            continue

        print(f"    '{hostname}' -> '{result}'")
        new_lines.append(current_line)
        new_lines.append(next_line.replace(hostname, result))
        i += 2
        
    return '\n'.join(new_lines)

def main():
    config_text = SSH_CONFIG.read_text(encoding='utf-8')
    config_text = rewrite_config(config_text)
    SSH_CONFIG.write_text(config_text, encoding='utf-8')

if __name__ == '__main__':
    main()
