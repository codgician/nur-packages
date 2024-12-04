#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git curl jq nodejs prefetch-npm-deps

nur="$(git rev-parse --show-toplevel)"
path="$nur/pkgs/aiursoft-tracer/default.nix"
prefetch=$(nix-prefetch-git --url https://github.com/AiursoftWeb/Tracer --no-deepClone)

new_rev=$(echo $prefetch | jq '.rev')
old_rev="$(sed -nE 's/\s*rev = "(.*)".*/\1/p' $path)"

if [[ "$new_rev" == "$old_rev" ]]; then
    echo "Current revision $old_rev is up-to-date."
    exit 0
fi

# Update the revision
# update-source-version aiursoft-tracer "$new_rev"
sha256=$(echo $prefetch | jq '.sha256')
sed -i -e "s,rev = \"$old_rev\",rev = \"$new_rev\"," \
    -e "s,hash = \"sha256-.*\",hash = \"$sha256\"," "$path" 

# Fetch npm deps
tmpdir=$(mktemp -d)
curl -O --output-dir $tmpdir "https://raw.githubusercontent.com/AiursoftWeb/Tracer/$new_rev/src/wwwroot/package-lock.json"
pushd $tmpdir
npm i --package-lock-only
npm_hash=$(prefetch-npm-deps package-lock.json)
sed -i 's#npmDepsHash = "[^"]*"#npmDepsHash = "'"$npm_hash"'"#' $path
popd
rm -rf $tmpdir

# Update nuget deps
eval "$(nix-build . -A aiursoft-tracer.fetch-deps --no-out-link)"