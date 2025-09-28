#!/bin/bash

echo "setup Ubuntu on WSL2..."

. /etc/lsb-release

if [ "${DISTRIB_RELEASE%%.*}" -ge 24 ]; then
    # Ubuntu 24.04 LTS 以降
    APT_SOURCE_FILE=/etc/apt/sources.list.d/ubuntu.sources
else
    # それより以前
    APT_SOURCE_FILE=/etc/apt/sources.list
fi
sudo sed -i.bak -r 's@http://(jp\.)?archive\.ubuntu\.com/ubuntu/?@https://ftp.udx.icscoe.jp/Linux/ubuntu/@g' $APT_SOURCE_FILE

sudo apt update -y
sudo apt upgrade -y

# apt install
sudo apt install -y \
    rename \
    zip \
    unzip \
    whois \
    nmap \
    build-essential
