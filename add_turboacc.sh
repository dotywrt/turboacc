#!/usr/bin/env bash

trap 'rm -rf "$TMPDIR"' EXIT
TMPDIR=$(mktemp -d) || exit 1

LOCAL_PACKAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --local-pkg)
            LOCAL_PACKAGE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if ! [ -d "./package" ]; then
    echo "./package not found"
    exit 1
fi

VERSION_NUMBER=$(sed -n '/VERSION_NUMBER:=$(if $(VERSION_NUMBER),$(VERSION_NUMBER),.*)/p' include/version.mk | sed -e 's/.*$(VERSION_NUMBER),//' -e 's/)//')
kernel_versions="$(find "./include" | sed -n '/kernel-[0-9]/p' | sed -e "s@./include/kernel-@@" | sed ':a;N;$!ba;s/\n/ /g')"

if [ -z "$kernel_versions" ]; then
    kernel_versions="$(find "./target/linux/generic" | sed -n '/kernel-[0-9]/p' | sed -e "s@./target/linux/generic/kernel-@@" | sed ':a;N;$!ba;s/\n/ /g')"
fi

if [ -z "$kernel_versions" ]; then
    echo "Error: Unable to get kernel version"
    exit 1
fi

echo "kernel version: $kernel_versions"

if [ -d "./package/turboacc" ]; then
    echo "./package/turboacc already exists, delete it? [Y/N]"
    read -r answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        rm -rf "./package/turboacc"
    else
        exit 0
    fi
fi

git clone --depth=1 --single-branch https://github.com/dotywrt/turboacc "$TMPDIR/turboacc/turboacc" || exit 1

if [ -n "$LOCAL_PACKAGE" ]; then
    cp -RT "$LOCAL_PACKAGE" "$TMPDIR/package" || exit 1
else
    git clone --depth=1 --single-branch --branch "package" https://github.com/dotywrt/turboacc "$TMPDIR/package" || exit 1
fi

cp -r "$TMPDIR/turboacc/turboacc/luci-app-turboacc" "$TMPDIR/turboacc/luci-app-turboacc"
rm -rf "$TMPDIR/turboacc/turboacc"

cp -r "$TMPDIR/package/nft-fullcone" "$TMPDIR/turboacc/nft-fullcone" || exit 1

for kernel_version in $kernel_versions; do

    if [ "$kernel_version" = "6.12" ] || \
       [ "$kernel_version" = "6.6" ] || \
       [ "$kernel_version" = "6.1" ] || \
       [ "$kernel_version" = "5.15" ]; then
        patch_952="952-add-net-conntrack-events-support-multiple-registrant.patch"
        patch_952_path="./target/linux/generic/hack-$kernel_version/$patch_952"
    elif [ "$kernel_version" = "5.10" ]; then
        patch_952="952-net-conntrack-events-support-multiple-registrant.patch"
        patch_952_path="./target/linux/generic/hack-$kernel_version/$patch_952"
    else
        echo "Unsupported kernel version: $kernel_version"
        exit 1
    fi

    rm -f "$patch_952_path"

    cp -f "$TMPDIR/package/hack-$kernel_version/$patch_952" "$patch_952_path"

    if ! grep -q "CONFIG_NF_CONNTRACK_CHAIN_EVENTS" "./target/linux/generic/config-$kernel_version"; then
        echo "# CONFIG_NF_CONNTRACK_CHAIN_EVENTS is not set" >> "./target/linux/generic/config-$kernel_version"
    fi
done

cp -r "$TMPDIR/turboacc" "./package/turboacc"

echo "Finish (SFE removed completely)"
exit 0
