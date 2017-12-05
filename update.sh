#!/bin/bash
# author: chat@jat.email

source ./common.sh

force=0
while getopts 'fh' flag; do
    case $flag in
        f)
            force=1
            ;;

        h|?)
            quit "Usage: $0 [-f]"
            ;;
    esac
done

init
git submodule update --init --remote --recursive || die

for package in packages/*; do
    git -C "$package" checkout -B master origin/master

    pkgname=${package#*/}
    echo "Found package: $pkgname"

    pkgbuild="$package/PKGBUILD"
    srcinfo="$package/.SRCINFO"

    locale=$(source "$pkgbuild" && echo "$_locale$_lang")
    pkgver=$(source "$pkgbuild" && echo "$pkgver")
    pkgrel=$(source "$pkgbuild" && echo "$pkgrel")

    [ -z "$locale" ] && error 'Cannot get locale, ignoring.' && continue
    [ -z "$pkgver" ] || [ -z "$pkgrel" ] && error 'Cannot get current version, ignoring.' && continue
    echo "Found current version: $pkgver-$pkgrel"
    [ "$pkgver" == "$version" ] && [ $force -ne 1 ] && error 'Current version is the latest, ignoring.' && continue

    release=1
    [ "$pkgver" == "$version" ] && [ $force -eq 1 ] && release=$((pkgrel + 1))

    language=$(echo "$languages" | jq -r ".[\"$locale\"].English")
    [ -z "$language" ] && error "Unknown locale: $locale" && language="$locale"

    sha512sum_i686=$(echo "$sha512sums" | awk "\$2 ~ /linux-i686\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    sha512sum_x86_64=$(echo "$sha512sums" | awk "\$2 ~ /linux-x86_64\/$locale\/firefox-${version}\.tar\.bz2/ { print \$1 }")
    [ -z "$sha512sum_i686" ] || [ -z "$sha512sum_x86_64" ] && error 'Cannot get sha512sums, ignoring.' && continue

    (find "$package" -mindepth 1 -maxdepth 1 -not -path "$package/.git" -exec rm -fr {} \; && cp -r templates/* "$package" && sed -i "s/#locale#/$locale/; s/#language#/$language/; s/#pkgver#/$version/; s/#pkgrel#/$release/; s/#sha512sum_i686#/$sha512sum_i686/; s/#sha512sum_x86_64#/$sha512sum_x86_64/" "$pkgbuild" && ./mksrcinfo.sh -p "$pkgbuild" -o "$srcinfo") || continue
    git -C "$package" add -A && git -C "$package" commit -am "Update version: {$pkgver-$pkgrel} -> {$version-$release}"
done

git diff --quiet && quit 'No package needs to update, exiting.'
git commit -am "[skip ci] New version: {$version}" && retry git push --recurse-submodules=on-demand
