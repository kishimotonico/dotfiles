#!/bin/bash

echo "setup mise..."

if ! type mise > /dev/null 2>&1; then
    curl https://mise.run | sh
fi

# install packages
mise install
