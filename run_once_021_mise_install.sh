#!/bin/bash

echo "mise install..."

export PATH="$HOME/.local/bin:$PATH"
mise install || echo "warning: some tools may have failed to install on this architecture"
