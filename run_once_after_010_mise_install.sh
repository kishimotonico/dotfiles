#!/bin/bash

echo "Installing mise packages..."

# Add mise to PATH
export PATH="$HOME/.local/bin:$PATH"

# Install packages defined in mise config
mise install
