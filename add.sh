#!/bin/bash
# author: chat@jat.email

source ./common.sh

init
languages=$(echo "$languages" | jq -c 'to_entries[]' 2>/dev/null)

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

    (rm -fr "$package" && cp -r templates "$package" && sed -i "s/#locale#/$locale/; s/#language#/$language/; s/#pkgver#/$version/; s/#pkgrel#/1/; s/#sha512sum_i686#/$sha512sum_i686/; s/#sha512sum_x86_64#/$sha512sum_x86_64/" "$pkgbuild" && ./mksrcinfo.sh -p "$pkgbuild" -o "$srcinfo") || continue
    (git -C "$package" init && git -C "$package" remote add origin "$aur_git" && git -C "$package" add -A && git -C "$package" commit -m "Initial version: {$version}" && git -C "$package" push -u origin master && git submodule add -b master "$aur_git" "packages/$pkgname") || continue

    echo "* [$pkgname]($aur_http) ![version](http://badge.kloud51.com/aur/v/$pkgname.svg)" >>README.md
    packages+=("$pkgname")
done <<<"$languages"

[ ${#packages[@]} -eq 0 ] && quit 'No package needs to add, exiting.'
git commit -am "[skip ci] ${#packages[*]} new packages: ${packages[*]}" && retry git push
