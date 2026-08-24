#!/bin/sh
# Point the Homebrew cask at a released version.
#
# The checksum has to match the archive GitHub actually serves. A local `make zip`
# will not do: CI builds and ad-hoc-signs its own copy, so the bytes differ. Either
# hand this the archive that was published, or let it fetch the released one.
#
#   sh Tools/update-cask.sh                          # latest release, fetched
#   sh Tools/update-cask.sh v1.2.0                   # a specific tag, fetched
#   sh Tools/update-cask.sh v1.2.0 dist/Unhitch.zip  # hash an archive already on disk
set -eu

cask=Casks/unhitch.rb
tag="${1:-$(gh release view --repo Zawaer/unhitch --json tagName --jq .tagName)}"
version="${tag#v}"
archive="${2:-}"

if [ -z "$archive" ]; then
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	archive="$tmp/Unhitch.zip"
	curl -fsSL -o "$archive" \
		"https://github.com/Zawaer/unhitch/releases/download/${tag}/Unhitch.zip"
fi

sha="$(shasum -a 256 "$archive" | cut -d' ' -f1)"

/usr/bin/sed -i '' \
	-e "s/^  version \".*\"\$/  version \"${version}\"/" \
	-e "s/^  sha256 \".*\"\$/  sha256 \"${sha}\"/" \
	"$cask"

echo "${cask}: version ${version}, sha256 ${sha}"
