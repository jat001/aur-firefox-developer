#!/bin/bash
# author: chat@jat.email

function error () {
    echo "$@" >&2
}

function die () {
    error "$@"
    exit 1
}

api='https://product-details.mozilla.org/1.0/firefox_versions.json'
version=$(curl $api 2>/dev/null | jq -r '.LATEST_FIREFOX_DEVEL_VERSION' 2>/dev/null)

[ -z "$version" ] && die 'Get the latest version of firefox-developer error.'
echo "Found the latest version of firefox-developer: $version"

sha512sums=$(curl "https://download-installer.cdn.mozilla.net/pub/devedition/releases/$version/SHA512SUMS" 2>/dev/null)
[ -z "$sha512sums" ] && die 'Get sha512sums of firefox-developer error.'

for package in packages/*; do
    package=${package#*/}
    pkgbuild="packages/$package/PKGBUILD"
    srcinfo="packages/$package/.SRCINFO"
    eval "$(source "$pkgbuild"; echo locale="$_locale"; echo pkgver="$pkgver")"

    [ -z "$pkgver" ] && error "Cannot get the current version of $package, ignoring." && continue
    echo "Found the current version of $package: $pkgver"
    [ "$pkgver" == "$version" ] && error "The current version of $package is the latest, ignoring." && continue

    sha512sum_i686=$(echo "$sha512sums" | awk "\$2 ~ /linux-i686\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    sha512sum_x86_64=$(echo "$sha512sums" | awk "\$2 ~ /linux-x86_64\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    [ -z "$sha512sum_i686" ] || [ -z "$sha512sum_x86_64" ] && error "Get sha512sums of $package error, ignoring." && continue
    sed -i -E "s/pkgver=.+/pkgver='$version'/; s/sha512sums_i686=.+/sha512sums_i686=('$sha512sum_i686')/; s/sha512sums_x86_64=.+/sha512sums_x86_64=('$sha512sum_x86_64')/" "$pkgbuild"

    ./mksrcinfo.sh -p "$pkgbuild" -o "$srcinfo" || continue
    git commit -a -m "Update $package to $version" && git push
done
