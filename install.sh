#!/bin/bash -eu
echo "setup Ubuntu on WSL2..."

sudo sed -i.bak -e 's!http://archive.ubuntu.com/ubuntu/!http://jp.archive.ubuntu.com/ubuntu/!g' /etc/apt/sources.list
sudo apt update -y
sudo apt upgrade -y

sudo apt install -y \
    whois \
    rename \
    p7zip-full \
    zip \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    jq \
    powerline

# Node.js
if ! type volta > /dev/null 2>&1; then
    curl https://get.volta.sh | bash
    volta install node@18 # AWS CDK(v2)が、Node.js v20 非推奨のため v18 をインストール
    npm install -g npm@10.4.0
fi

# AWS CLI
if ! type aws > /dev/null 2>&1; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
        && unzip awscliv2.zip \
        && sudo ./aws/install \
        && rm -rf aws awscliv2.zip
fi

if ! type session-manager-plugin > /dev/null 2>&1; then
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" \
        && sudo dpkg -i session-manager-plugin.deb \
        && rm session-manager-plugin.deb
fi

if [ ! -e /usr/local/bin/_awsp ]; then
    npm install -g awsp
fi

# GitHub CLI
if ! type gh > /dev/null 2>&1; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
        && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y

    # ログイン操作が必要なためコメントアウト
    # gh auth login
    # gh extension install github/gh-copilot
fi

# git-secrets
if ! type git-secrets > /dev/null 2>&1; then
    sudo sh -c "cd /tmp && git clone https://github.com/awslabs/git-secrets.git && cd git-secrets && make install"
fi

