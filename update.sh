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

name='firefox-developer'
api='https://product-details.mozilla.org/1.0/firefox_versions.json'
version=$(curl $api 2>/dev/null | jq -r '.LATEST_FIREFOX_DEVEL_VERSION' 2>/dev/null)

[ -z "$version" ] && die "Cannot get the latest version of $name."
echo "Found the latest version of $name: $version"

sha512sums=$(curl "https://download-installer.cdn.mozilla.net/pub/devedition/releases/$version/SHA512SUMS" 2>/dev/null)
[ -z "$sha512sums" ] && die "Cannot get sha512sums of $name."

git submodule update --init --remote --recursive || die

for package in packages/*; do
    git -C "$package" checkout master

    pkgname=${package#*/}
    pkgbuild="$package/PKGBUILD"
    srcinfo="$package/.SRCINFO"

    locale=$(source "$pkgbuild" && echo "$_locale")
    pkgver=$(source "$pkgbuild" && echo "$pkgver")

    [ -z "$locale" ] && error "Cannot get the locale of $pkgname, ignoring." && continue
    [ -z "$pkgver" ] && error "Cannot get the current version of $pkgname, ignoring." && continue
    echo "Found the current version of $pkgname: $pkgver"
    [ "$pkgver" == "$version" ] && error "The current version of $pkgname is the latest, ignoring." && continue

    sha512sum_i686=$(echo "$sha512sums" | awk "\$2 ~ /linux-i686\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    sha512sum_x86_64=$(echo "$sha512sums" | awk "\$2 ~ /linux-x86_64\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    [ -z "$sha512sum_i686" ] || [ -z "$sha512sum_x86_64" ] && error "Cannot get sha512sums of $pkgname, ignoring." && continue

    sed -i -E "s/pkgver=.+/pkgver='$version'/; s/pkgrel=.+/pkgrel='1'/; s/sha512sums_i686=.+/sha512sums_i686=('$sha512sum_i686')/; s/sha512sums_x86_64=.+/sha512sums_x86_64=('$sha512sum_x86_64')/" "$pkgbuild"

    ./mksrcinfo.sh -p "$pkgbuild" -o "$srcinfo" || continue
    git -C "$package" commit -a -m "Update version: {$pkgver} -> {$version}"
done

git diff --quiet && quit 'No package needs to update, exiting.'
git commit -a -m "[skip ci] New version: {$version}" && git push --recurse-submodules=on-demand
