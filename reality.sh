#!/usr/bin/env bash
set -euo pipefail

installer=$(mktemp)
trap 'rm -f -- "$installer"' EXIT
curl -fsSL https://raw.githubusercontent.com/LuckyGoodwin/reality-setup/main/install.sh -o "$installer"
bash "$installer" "$@"
