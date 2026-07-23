#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl dpkg gnugrep gnused coreutils jq nix
# shellcheck shell=bash

set -euo pipefail

nur="$(git rev-parse --show-toplevel)"
path="$nur/pkgs/mdatp/default.nix"
repository_root="https://packages.microsoft.com/ubuntu"
package_path="prod/pool/main/m/mdatp"

old_ubuntu_version=$(sed -nE 's/^[[:space:]]*ubuntuVersion = "([^"]+)";.*/\1/p' "$path")
old_version=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "$path")
old_amd64_hash=$(sed -nE 's/^[[:space:]]*x86_64-linux = "(sha256-[^"]+)";.*/\1/p' "$path")
old_arm64_hash=$(sed -nE 's/^[[:space:]]*aarch64-linux = "(sha256-[^"]+)";.*/\1/p' "$path")

# A release is stable only when its filename has no ring suffix and both
# supported architectures are present. Inspect all Ubuntu repositories so the
# package follows a release when Microsoft moves it to a newer Ubuntu version.
mapfile -t ubuntu_versions < <(
    curl -fsSL "$repository_root/" \
        | sed -nE 's@.*href="([0-9]+\.[0-9]+)/".*@\1@p' \
        | sort -Vr
)

new_ubuntu_version=""
new_version=""

for ubuntu_version in "${ubuntu_versions[@]}"; do
    if ! package_index=$(curl -fsSL "$repository_root/$ubuntu_version/$package_path/" 2>/dev/null); then
        continue
    fi

    while IFS= read -r candidate; do
        if ! grep -Fq "href=\"mdatp_${candidate}_arm64.deb\"" <<<"$package_index"; then
            continue
        fi

        if [[ -z "$new_version" ]] || dpkg --compare-versions "$candidate" gt "$new_version"; then
            new_ubuntu_version="$ubuntu_version"
            new_version="$candidate"
        fi
    done < <(
        sed -nE 's@.*href="mdatp_([0-9]+(\.[0-9]+)*)_amd64\.deb".*@\1@p' <<<"$package_index"
    )
done

if [[ -z "$new_ubuntu_version" || -z "$new_version" ]]; then
    echo "Error: Could not resolve a stable, multi-architecture mdatp release" >&2
    exit 1
fi

if [[ "$old_ubuntu_version" == "$new_ubuntu_version" && "$old_version" == "$new_version" ]]; then
    echo "Current Ubuntu $old_ubuntu_version package $old_version is up-to-date"
    exit 0
fi

amd64_url="$repository_root/$new_ubuntu_version/$package_path/mdatp_${new_version}_amd64.deb"
arm64_url="$repository_root/$new_ubuntu_version/$package_path/mdatp_${new_version}_arm64.deb"
new_amd64_hash=$(nix store prefetch-file --json "$amd64_url" | jq -er .hash)
new_arm64_hash=$(nix store prefetch-file --json "$arm64_url" | jq -er .hash)

echo "Updating mdatp: Ubuntu $old_ubuntu_version/$old_version -> Ubuntu $new_ubuntu_version/$new_version"

sed -i \
    -e "s|ubuntuVersion = \"$old_ubuntu_version\";|ubuntuVersion = \"$new_ubuntu_version\";|" \
    -e "s|version = \"$old_version\";|version = \"$new_version\";|" \
    -e "s|x86_64-linux = \"$old_amd64_hash\";|x86_64-linux = \"$new_amd64_hash\";|" \
    -e "s|aarch64-linux = \"$old_arm64_hash\";|aarch64-linux = \"$new_arm64_hash\";|" \
    "$path"

echo "Updated mdatp to Ubuntu $new_ubuntu_version package $new_version"
