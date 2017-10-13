#!/bin/bash
# author: chat@jat.email

function error () {
    printf "==> ERROR: $1\n" "${@:2}" >&2
}

function die () {
    error "$@"
    exit 1
}

api='https://product-details.mozilla.org/1.0/firefox_versions.json'
version=$(curl $api 2>/dev/null | jq -r '.LATEST_FIREFOX_DEVEL_VERSION' 2>/dev/null)

[ -z "$version" ] && die 'Get the latest version of firefox-developer error.'

for package in packages/*; do
    pkgbuild="packages/$package/PKGBUILD"

    [ -z "$pkgver" ] && error "Cannot get the current version of $package, ignoring." && continue
    [ "$pkgver" == "$version" ] && error "The current version of $package is the latest, ignoring." && continue

    sed 's//' "$pkgbuild"
    ./mksrcinfo.sh || continue
done
