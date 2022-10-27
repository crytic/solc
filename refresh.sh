#!/bin/env bash
set -e

good="✅"
wip="⏳"
bad="❌"
warn="⚠️ "

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
    # Download a new latest list from the solc team
    latest_list="$dir/list-latest.json"
    if [[ -f  "$latest_list" ]]
    then
      rm -f "$latest_list.backup"
      mv "$latest_list" "$latest_list.backup"
    fi
    url="https://binaries.soliditylang.org/${arch}/list.json"
    echo "$wip Fetching updated list of available versions for arch $arch from $url"
    if wget -q "$url" -O "$latest_list"
    then
      echo "$good Successfully refreshed the solc list for $arch"
      rm -f "$latest_list.backup"
    else
      echo "$bad Failed to download updated list of available versions for $arch"
      mv "$latest_list.backup" "$latest_list"
    fi
    # Merge latest & legacy lists into one master list
    legacy_list="$dir/list-legacy.json"
    master_list="$dir/list.json"
    if [[ -f "$legacy_list" ]]
    then
      if [[ -f "$master_list" ]]
      then
        rm -f "$master_list.backup"
        mv "$master_list" "$master_list.backup"
      fi
      if jq -s '{ builds: [.[1].builds + .[0].builds | unique_by(.version)], releases: [.[0].releases + .[1].releases], latestRelease: .[0].latestRelease }' "$latest_list" "$legacy_list" > "$master_list"
      then
        rm -f "$master_list.backup"
      else
        rm -f "$master_list"
        mv "$master_list.backup" "$master_list"
        echo "$bad Failed to merge solc version lists into one master list"
        exit 1
      fi
    else cp -f "$latest_list" "$master_list"
    fi
  done
}
refresh_lists

function read_list {
  arch="$1"
  version="$2"
  key="$3"
  for list in legacy latest
  do
    listfile="$root/$arch/list-$list.json"
    if [[ ! -f "$listfile" ]]
    then continue # list type doesn't exist for this arch
    fi
    if [[ "$(jq '.releases."'"$version"'"' "$listfile")" == "null" ]]
    then continue # version doesn't exist in this list
    else
      jq '.builds[] | select(.version=="'"$version"'" ) | .'"$key" "$listfile" | tr -d '"'
      break
    fi
  done
}

function verify_sha256 {
  arch="$1"
  version="$2"
  target="$root/$arch/solc-v$version"
  if [[ ! -f "$target" ]]
  then
    echo "$bad File does not exist at $target"
    exit 1
  fi
  actual_sha256="0x$(sha256sum "$target" | cut -d " " -f 1)"
  expected_sha256="$(read_list "$arch" "$version" "sha256")"
  if [[ "$expected_sha256" != "$actual_sha256" ]]
  then
    echo "$bad OH NO, VERY BAD, SHA256 hashes do not match for $arch solc-v$version"
    echo "$bad expected:$expected_sha256 != actual:$actual_sha256"
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
    if [[ -f "$target" ]]
    then
      verify_sha256 "$arch" "$version"
      echo "$good solc-v$version for $arch is present & its sha256 hash has been validated"
    else
      path="$(read_list "$arch" "$version" "path")"
      if [[ -z "$path" ]]
      then
        echo "$warn solc-v$version is not available for $arch"
        continue
      fi
      echo "$wip solc-v$version for $arch is missing, attempting to download it now.."
      url="https://binaries.soliditylang.org/${arch}/${path}"
      wget -q "$url" -O "$target"
      verify_sha256 "$arch" "$version"
      echo "$good solc-v$version for $arch was successfully downloaded & its sha256 hash has been validated"
    fi
  done
done
