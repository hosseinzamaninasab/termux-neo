#!/data/data/com.termux/files/usr/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/layout.sh"
source "$SCRIPT_DIR/render.sh"
source "$SCRIPT_DIR/dashboard.sh"
source "$SCRIPT_DIR/status.sh"
