#!/bin/bash
# Confirm a Mach-O is x86_64 and declares macOS 12.0 as its minimum, and that
# frameworks missing on macOS 12 are weak-linked (or absent).
# Usage: scripts/check-macos12-binary.sh <executable> [<executable>...]
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <mach-o>..." >&2
    exit 2
fi

fail=0
for bin in "$@"; do
    echo "== $bin"
    info="$(xcrun lipo -info "$bin")"
    echo "$info"
    if ! grep -q 'architecture: x86_64' <<<"$info" && ! grep -q 'x86_64' <<<"$info"; then
        echo "ERROR: $bin is not x86_64" >&2
        fail=1
    fi
    if grep -q 'arm64' <<<"$info"; then
        echo "ERROR: $bin also contains arm64 (want a pure Intel slice)" >&2
        fail=1
    fi
    xcrun vtool -show-build "$bin"
    # Every build version must be minos 12.0. SDK may be newer.
    minos="$(xcrun vtool -show-build "$bin" | awk '/minos/ { print $2 }')"
    if [[ -z "$minos" ]]; then
        echo "ERROR: no minos in $bin" >&2
        fail=1
    fi
    while read -r ver; do
        [[ -z "$ver" ]] && continue
        case "$ver" in
            12.0|12.0.0) ;;
            *)
                echo "ERROR: $bin minos is $ver, want 12.0" >&2
                fail=1
                ;;
        esac
    done <<<"$minos"

    # Strong links to frameworks that are absent on macOS 12.0 crash at launch.
    # ScreenCaptureKit arrives in 12.3, Translation in 15, FoundationModels in 26.
    libs="$(xcrun otool -L "$bin")"
    echo "$libs" | awk '/FoundationModels|Translation\.framework|ScreenCaptureKit|Observation\.framework/'
    # otool -L marks weak dylibs with "(weak)". A line naming one of these
    # frameworks without "(weak)" is a strong link.
    if awk '
        /FoundationModels|Translation\.framework|ScreenCaptureKit|Observation\.framework/ && !/\(weak\)/ { bad=1 }
        END { exit bad ? 0 : 1 }
    ' <<<"$libs"; then
        echo "ERROR: $bin strongly links a framework that is not on macOS 12.0" >&2
        echo "$libs" | awk '/FoundationModels|Translation\.framework|ScreenCaptureKit|Observation\.framework/' >&2
        fail=1
    fi
done

exit "$fail"
