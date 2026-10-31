#!/bin/zsh
# ruff, pyright and shellcheck over the hub's own code (development/adr/0015). Run from the repository root.
set -u
uvx ruff check --select F,B,E9 --output-format concise launcher/hub scripts apps/bundler
t=$(mktemp -d); cp launcher/hub "$t/hub.py"; echo '{"typeCheckingMode":"standard","pythonVersion":"3.12"}' > "$t/pyrightconfig.json"
(cd "$t" && npx -y pyright@latest hub.py | tail -3); rm -rf "$t"
shellcheck -f gcc -S warning scripts/*.sh toolchains/provision.sh toolchains/mt-env
