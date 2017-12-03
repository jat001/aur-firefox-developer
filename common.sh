#!/bin/bash
# author: chat@jat.email

error () {
    echo "$@" >&2
}

quit () {
    [ ${#@} -gt 0 ] && echo "$@"
    exit 0
}

die () {
    [ ${#@} -gt 0 ] && error "$@"
    exit 1
}

retry () {
    for _ in {1..3}; do "$@" && return 0; done
    return 1
}

init () {
    workdir='/tmp/aur-firefox-developer'
    rm -fr "$workdir" && mkdir -p "$workdir"

    api_languages='https://product-details.mozilla.org/1.0/languages.json'
    api_versions='https://product-details.mozilla.org/1.0/firefox_versions.json'

    languages=$(curl -s $api_languages)
    version=$(curl -s $api_versions | jq -r '.LATEST_FIREFOX_DEVEL_VERSION' 2>/dev/null)

    [ -z "$languages" ] && die 'Cannot get available languages.'
    [ -z "$version" ] && die 'Cannot get the latest version.'
    echo "Found the latest version: $version"

    wget -O "$workdir/SHA512SUMS" "https://download-installer.cdn.mozilla.net/pub/devedition/releases/$version/SHA512SUMS"
    wget -O "$workdir/SHA512SUMS.asc" "https://download-installer.cdn.mozilla.net/pub/devedition/releases/$version/SHA512SUMS.asc"
    (gpg --import mozilla-software-releases.key && gpg --verify "$workdir/SHA512SUMS.asc" "$workdir/SHA512SUMS") || die

    sha512sums=$(<"$workdir/SHA512SUMS")
    [ -z "$sha512sums" ] && die 'Cannot get sha512sums.'
}
