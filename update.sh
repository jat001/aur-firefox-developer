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

languages=$(curl -s $api_languages)
version=$(curl -s $api_versions | jq -r '.LATEST_FIREFOX_DEVEL_VERSION' 2>/dev/null)

[ -z "$languages" ] && die 'Cannot get available languages.'
[ -z "$version" ] && die 'Cannot get the latest version.'
echo "Found the latest version: $version"

sha512sums=$(curl -s "https://download-installer.cdn.mozilla.net/pub/devedition/releases/$version/SHA512SUMS")
[ -z "$sha512sums" ] && die 'Cannot get sha512sums.'

git submodule update --init --remote --recursive || die

for package in packages/*; do
    git -C "$package" checkout -B master origin/master

    pkgname=${package#*/}
    echo "Found package: $pkgname"

    pkgbuild="$package/PKGBUILD"
    srcinfo="$package/.SRCINFO"

    locale=$(source "$pkgbuild" && echo "$_locale")
    pkgver=$(source "$pkgbuild" && echo "$pkgver")

    [ -z "$locale" ] && error 'Cannot get locale, ignoring.' && continue
    [ -z "$pkgver" ] && error 'Cannot get current version, ignoring.' && continue
    echo "Found current version: $pkgver"
    [ "$pkgver" == "$version" ] && error 'Current version is the latest, ignoring.' && continue

    language=$(echo "$languages" | jq -r ".[\"$locale\"].English")
    [ -z "$language" ] && error "Unknown locale: $locale" && language="$locale"

    sha512sum_i686=$(echo "$sha512sums" | awk "\$2 ~ /linux-i686\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    sha512sum_x86_64=$(echo "$sha512sums" | awk "\$2 ~ /linux-x86_64\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    [ -z "$sha512sum_i686" ] || [ -z "$sha512sum_x86_64" ] && error 'Cannot get sha512sums, ignoring.' && continue

    (find "$package" -mindepth 1 -maxdepth 1 -not -path "$package/.git" -exec rm -fr {} \; && cp -r templates/* "$package" && sed -i "s/#locale#/$locale/; s/#language#/$language/; s/#pkgver#/$version/; s/#sha512sum_i686#/$sha512sum_i686/; s/#sha512sum_x86_64#/$sha512sum_x86_64/" "$pkgbuild" && ./mksrcinfo.sh -p "$pkgbuild" -o "$srcinfo") || continue
    git -C "$package" commit -am "Update version: {$pkgver} -> {$version}"
done

git diff --quiet && quit 'No package needs to update, exiting.'
git commit -am "[skip ci] New version: {$version}" && git push --recurse-submodules=on-demand
