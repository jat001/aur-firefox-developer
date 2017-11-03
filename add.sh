#!/bin/bash
# author: chat@jat.email

function error () {
    echo "$@" >&2
}

function quit () {
    [ ${#@} -gt 0 ] && echo "$@"
    exit 0
}

function die () {
    [ ${#@} -gt 0 ] && error "$@"
    exit 1
}

api_languages='https://product-details.mozilla.org/1.0/languages.json'
api_versions='https://product-details.mozilla.org/1.0/firefox_versions.json'

languages=$(curl -s $api_languages | jq -c 'to_entries[]' 2>/dev/null)
version=$(curl -s $api_versions | jq -r '.LATEST_FIREFOX_DEVEL_VERSION' 2>/dev/null)

[ -z "$languages" ] && die 'Cannot get available languages.'
[ -z "$version" ] && die 'Cannot get the latest version.'
echo "Found the latest version: $version"

sha512sums=$(curl -s "https://download-installer.cdn.mozilla.net/pub/devedition/releases/$version/SHA512SUMS")
[ -z "$sha512sums" ] && die 'Cannot get sha512sums.'

workdir='/tmp/aur-firefox-developer'
rm -fr "$workdir" && mkdir -p "$workdir"

packages=()
while read -r language; do
    locale=$(echo "$language" | jq -r '.key')
    language=$(echo "$language" | jq -r '.value.English')
    echo "Found language: $language"

    sha512sum_i686=$(echo "$sha512sums" | awk "\$2 ~ /linux-i686\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    sha512sum_x86_64=$(echo "$sha512sums" | awk "\$2 ~ /linux-x86_64\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    [ -z "$sha512sum_i686" ] || [ -z "$sha512sum_x86_64" ] && error 'Cannot get sha512sums, ignoring.' && continue

    pkgname="firefox-developer-${locale,,}"
    package="$workdir/$pkgname"
    echo "New package: $pkgname"

    aur_http="https://aur.archlinux.org/packages/$pkgname/"
    aur_git="ssh://aur@aur.archlinux.org/$pkgname.git"
    curl -fso /dev/null "$aur_http" && error 'Package exists, ignoring.' && continue

    pkgbuild="$package/PKGBUILD"
    srcinfo="$package/.SRCINFO"

    (cp -r templates "$package" && sed -i "s/#locale#/$locale/; s/#language#/$language/; s/#pkgver#/$version/; s/#sha512sum_i686#/$sha512sum_i686/; s/#sha512sum_x86_64#/$sha512sum_x86_64/" "$pkgbuild" && ./mksrcinfo.sh -p "$pkgbuild" -o "$srcinfo") || continue
    (git -C "$package" init && git -C "$package" remote add origin "$aur_git" && git -C "$package" add -A && git -C "$package" commit -m "Initial version: {$version}" && git -C "$package" push -u origin master && git submodule add -b master "$aur_git" "packages/$pkgname") || continue

    echo "* [$pkgname]($aur_http) ![version](http://badge.kloud51.com/aur/v/$pkgname.svg)" >>README.md
    packages+=("$pkgname")
done <<<"$languages"

[ ${#packages[@]} -eq 0 ] && quit 'No package needs to add, exiting.'
git commit -am "[skip ci] ${#packages[*]} new packages: ${packages[*]}" && git push
