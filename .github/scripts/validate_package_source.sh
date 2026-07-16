#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

package_path=${1:?package path is required}
if [[ ! -d "$package_path" ]]; then
  echo "Package path is not a directory: $package_path" >&2
  exit 2
fi

if grep -R -q -F -- 'DENDRO_API_KEY' "$package_path"; then
  echo "Package source must not reference the CI-only DENDRO_API_KEY" >&2
  exit 1
fi
