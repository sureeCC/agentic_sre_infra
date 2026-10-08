#!/usr/bin/env bash
set -euo pipefail
version=1.1.6
binary=terragrunt_linux_amd64
base="https://github.com/gruntwork-io/terragrunt/releases/download/v${version}"
install_dir="${RUNNER_TEMP:?}/terragrunt-bin"
mkdir -p "$install_dir"
curl --fail --silent --show-error --location "$base/$binary" -o "$install_dir/$binary"
curl --fail --silent --show-error --location "$base/SHA256SUMS" -o "$install_dir/SHA256SUMS"
checksum=$(awk -v binary="$binary" '$2 == binary {print $1; exit}' "$install_dir/SHA256SUMS")
test -n "$checksum"
(cd "$install_dir" && echo "$checksum  $binary" | sha256sum --check --strict)
mv "$install_dir/$binary" "$install_dir/terragrunt"
chmod +x "$install_dir/terragrunt"
echo "$install_dir" >> "${GITHUB_PATH:?}"
"$install_dir/terragrunt" --version
