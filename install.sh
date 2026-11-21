#!/bin/sh

set -eu

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE="$SOURCE_DIR/pwf"
PREFIX=${PREFIX:-"$HOME/.local"}
TARGET_DIR="$PREFIX/bin"
TARGET="$TARGET_DIR/pwf"

if [ ! -f "$SOURCE" ] || [ ! -x "$SOURCE" ]; then
    printf '%s\n' "Error: executable not found: $SOURCE" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
        printf '%s\n' "Already installed: $TARGET"
        exit 0
    fi
    printf '%s\n' "Error: refusing to replace existing path: $TARGET" >&2
    exit 1
fi

ln -s "$SOURCE" "$TARGET"
printf '%s\n' "Installed pwf at: $TARGET"
printf '%s\n' "Ensure $TARGET_DIR is on PATH before invoking pwf."
