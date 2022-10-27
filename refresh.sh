#!/bin/env bash
set -e

root=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
mapfile -t versions < "$root/versions"
architectures=( "linux-amd64" "macosx-amd64" "windows-amd64")

function getUrl {
  arch="$1"
  version="$2"
  if [[ -n "$version" ]]
  # if version was provided, get that binary
  then echo "https://binaries.soliditylang.org/${arch}/${version}"
  # else get the list of all available binary versions
  else echo "https://binaries.soliditylang.org/${arch}/list.json"
  fi
}

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
    url="$(getUrl "$arch")"
    echo "Fetching updated list of available versions for arch $arch from $url"
    if wget -q "$url" -O "$list"
    then rm -f "$list.backup"
    else
      echo "Failed to download updated list of available versions for $arch"
      mv "$list.backup" "$list"
    fi
  done
}
refresh_lists

function get_expected_sha256 {
  arch="$1"
  version="$2"
  for list in latest legacy
  do
    long_version=$(jq '.releases."'"$v"'"' "$list")
    if [[ "$long_version" == "null" ]]
    then continue
    else
      echo "got long version: $long_version"
      return
    fi
  done
}

# Install any missing solc binaries from the list of supported versions
for arch in "${architectures[@]}"
do
  for v in "${versions[@]}"
  do
    echo "Searching/Verifying solc version $v for $arch"
    list="$root/$arch/list.json"
    target="$root/$arch/solc-v$v"
    if [[ -f "$target" ]]
    then
      expected_sha256=$(get_expected_sha256 "$arch" "$v")
      echo "Target DOES exist for $long_version with expected hash: $expected_sha256"
    else echo "Target does NOT exist at $target"
    fi
    exit # TODO remove after debugging
  done
done

latest
legacy



# 
# 
# function getDigest {
#   distro="$1"
#   curl -Ls "$(getUrl "$distro").sha256" | cut -d " " -f 1
# }
# 
# bin="$root/bin"
# cache="$root/.cache"
# tmp="$root/.tmp"
# mkdir -p "$bin" "$cache" "$tmp"
# 
# ( cd "$tmp" || exit
# 
#   for distro in "${distros[@]}";
#   do
# 
#     # Download tarballs for each distro (unless cached)
#     outfile="echidna-${version}-${distro}.tar.gz"
#     if [[ ! -f "$cache/$outfile" ]]
#     then
#       echo "No tarball exists at $cache/$outfile"
#       url="$(getUrl "$distro")"
#       echo "Fetching echidna v${version} for ${distro}"
#       wget "$url" --output-document "$outfile"
#       digest="$(getDigest "$distro")"
#       echo "expected sha256: $digest"
#       received_digest=$(sha256sum "$outfile" | cut -d " " -f 1)
#       if [[ "$digest" != "$received_digest" ]]
#       then echo "Error, expected digest != received digest: ${digest} != $received_digest" && exit 1
#       fi
#       echo "Checksum matches, saving this tarball to a local cache"
#       mv "$outfile" "$cache"
#     fi
# 
#     # Unpack tarballs for each distro (unless bins are present)
#     cd "$bin" || exit
#     dir="echidna/${version}/${distro}"
#     mkdir -p "$dir"
#     cd "$dir" || exit
#     if [[ -f "echidna-test" ]]
#     then
#       echo "Echidna $version binary for $distro already exists"
#     else
#       tarball="$cache/$outfile"
#       echo "Unpacking contents of $tarball to $(pwd)"
#       tar -xzf "$tarball"
#       if [[ -d "echidna-test" ]]
#       then
#         mv -f echidna-test echidna-dir
#         mv -f echidna-dir/* .
#         rmdir echidna-dir
#       fi
#     fi
# 
#     cd "$tmp" || exit # reset cwd before the next loop
#   done
# 
# )
# 
# rm -rf "$tmp"
