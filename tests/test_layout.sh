#!/data/data/com.termux/files/usr/bin/bash

set -e

source src/utils.sh
source src/layout.sh
source src/dashboard.sh

ui_init

# A valid layout must pass.
if ! ui_validate_layout; then
    printf 'FAIL: valid layout was rejected\n' >&2
    exit 1
fi

# Break the layout invariant deliberately.
UI_VALUE_WIDTH=$((UI_VALUE_WIDTH - 1))

# An invalid layout must fail validation.
if ui_validate_layout; then
    printf 'FAIL: invalid layout was accepted\n' >&2
    exit 1
fi

# Renderer must not produce output for an invalid layout.
render_output=""

if render_output=$(ui_render); then
    printf 'FAIL: invalid layout was rendered\n' >&2
    exit 1
fi

if [[ -n "$render_output" ]]; then
    printf 'FAIL: invalid layout produced terminal output\n' >&2
    exit 1
fi

printf 'PASS: layout validation\n'
