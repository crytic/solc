#!/bin/env bash
set -e

root=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
mapfile -t versions < "$root/versions"
architectures=( "linux-amd64" "macosx-amd64" "windows-amd64")

# Refresh lists of versions available for each architecture
function refresh_lists {
  for arch in "${architectures[@]}"
  do
    dir="$root/$arch"
    if [[ ! -d "$dir" ]]
    then mkdir -p "$dir"
    fi
    list="$dir/list-latest.json"
    if [[ -f  "$list" ]]
    then
      rm -f "$list.backup"
      mv "$list" "$list.backup"
    fi
    url="https://binaries.soliditylang.org/${arch}/list.json"
    echo "Fetching updated list of available versions for arch $arch from $url"
    if wget -q "$url" -O "$list"
    then rm -f "$list.backup"
    else
      echo "Failed to download updated list of available versions for $arch"
      mv "$list.backup" "$list"
    fi
  done
}
# refresh_lists

function read_list {
  arch="$1"
  version="$2"
  key="$3"
  for list in latest legacy
  do
    listfile="$root/$arch/list-$list.json"
    if [[ ! -f "$listfile" ]]
    then continue # list type doesn't exist for this arch
    fi
    if [[ "$(jq '.releases."'"$version"'"' "$listfile")" == "null" ]]
    then continue # version doesn't exist in this list
    else jq '.builds[] | select(.version=="'"$version"'" ) | .'"$key" "$listfile" | tr -d '"'
    fi
  done
}

function verify_sha256 {
  arch="$1"
  version="$2"
  target="$root/$arch/solc-v$version"
  if [[ ! -f "$target" ]]
  then
    echo "File does not exist at $target"
    exit 1
  fi
  actual_sha256="0x$(sha256sum "$target" | cut -d " " -f 1)"
  expected_sha256="$(read_list "$arch" "$version" "sha256")"
  if [[ "$expected_sha256" != "$actual_sha256" ]]
  then
    echo "OH NO, VERY BAD, SHA256 hashes do not match for $target"
    echo "expected:$expected_sha256 != actual:$actual_sha256"
    exit 1
  fi
}

function getUrl {
  arch="$1"
  version="$2"
  path="$(read_list "$arch" "$version" "path")"
  url="https://binaries.soliditylang.org/${arch}/${path}"
}

# Install any missing solc binaries from the list of supported versions
for arch in "${architectures[@]}"
do
  for version in "${versions[@]}"
  do
    list="$root/$arch/list.json"
    target="$root/$arch/solc-v$version"
    # echo "Checking $target"
    if [[ -f "$target" ]]
    then
      verify_sha256 "$arch" "$version"
      echo "$target has a valid sha256 hash"
    else
      echo "solc-v$version for $arch is missing, attempting to download it now.."
      path="$(read_list "$arch" "$version" "path")"
      url="https://binaries.soliditylang.org/${arch}/${path}"
      wget -q "$url" -O "$target"
      verify_sha256 "$arch" "$version"
      echo "solc-v$version has been downloaded & its sha256 hash has been validated"
    fi
  done
done
