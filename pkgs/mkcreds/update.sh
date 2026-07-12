#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix
# shellcheck shell=bash

set -euo pipefail

nur="$(git rev-parse --show-toplevel)"
path="$nur/pkgs/mkcreds/default.nix"
api_url="https://api.github.com/repos/codgician/mkcreds"

release="$(
  curl -fsSL "$api_url/releases?per_page=100" |
    jq -cer '
      [ .[]
        | select(.draft == false and .prerelease == false)
        | select(.tag_name | test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$"))
      ]
      | max_by(.published_at)
    '
)"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#v}"
old_version="$(sed -nE 's/^  version = "([^"]+)";$/\1/p' "$path")"

if [[ "$version" == "$old_version" ]]; then
  echo "mkcreds $version is up to date"
  exit 0
fi

ref="$(curl -fsSL "$api_url/git/ref/tags/$tag")"
if [[ "$(jq -r '.object.type' <<<"$ref")" == "tag" ]]; then
  rev="$(curl -fsSL "$(jq -er '.object.url' <<<"$ref")" | jq -er '.object | select(.type == "commit") | .sha')"
else
  rev="$(jq -er '.object | select(.type == "commit") | .sha' <<<"$ref")"
fi

src_hash="$(
  env -u DENDRO_API_KEY nix-prefetch-url --unpack "https://github.com/codgician/mkcreds/archive/$rev.tar.gz" |
    env -u DENDRO_API_KEY nix hash convert --hash-algo sha256 --to sri
)"

sed -i -E \
  -e 's|version = "[^"]+";|version = "'"$version"'";|' \
  -e 's|rev = "[^"]+";|rev = "'"$rev"'";|' \
  -e '0,/hash = "sha256-[^"]+";/s//hash = "'"$src_hash"'";/' \
  -e 's|cargoHash = "sha256-[^"]+";|cargoHash = lib.fakeHash;|' \
  "$path"

set +e
build_log="$(env -u DENDRO_API_KEY nix build --no-link "$nur#mkcreds" 2>&1)"
build_status=$?
set -e

if [[ $build_status -eq 0 ]]; then
  echo "Expected cargo dependency hash calculation to fail" >&2
  exit 1
fi

cargo_hash="$(printf '%s\n' "$build_log" | sed -nE 's/.*got:[[:space:]]*(sha256-[A-Za-z0-9+/=]+).*/\1/p' | sed -n '$p')"
if [[ -z "$cargo_hash" ]]; then
  printf '%s\n' "$build_log" >&2
  exit 1
fi

sed -i -E 's|cargoHash = lib\.fakeHash;|cargoHash = "'"$cargo_hash"'";|' "$path"

echo "Updated mkcreds: $old_version -> $version"
