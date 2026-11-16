#!/bin/sh
# Build vendored ost + ostmac-core staticlib (release).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Pin the macOS deployment target to Package.swift's `.macOS(.v12)`. Without it,
# rustc/cc default to the host SDK version, so the staticlib's minos is newer
# than Monterey and dyld refuses the app. Keep this in sync with Package.swift.
# RUST_TARGET (for example x86_64-apple-darwin) cross-compiles the staticlib;
# the Swift package always links rust/ostmac-core/target/release.
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
# Do not strip host build artifacts (proc-macro dylibs, build scripts). rustc's
# release default `strip = "debuginfo"` runs the Xcode 27 `strip`, which leaves a
# mis-aligned LINKEDIT string pool that dyld refuses to load, so every proc-macro
# crate fails with E0463 "can't find crate" on a clean build.
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=none
TARGET_ARGS=""
if [ -n "${RUST_TARGET:-}" ]; then
    rustup target add "$RUST_TARGET"
    TARGET_ARGS="--target ${RUST_TARGET}"
fi
# shellcheck disable=SC2086
cargo build --release $TARGET_ARGS --manifest-path "$ROOT/rust/ost/Cargo.toml"
# shellcheck disable=SC2086
cargo build --release $TARGET_ARGS --manifest-path "$ROOT/rust/ostmac-core/Cargo.toml"
if [ -n "${RUST_TARGET:-}" ]; then
    mkdir -p "$ROOT/rust/ostmac-core/target/release"
    ln -sfn "../${RUST_TARGET}/release/libostmac_core.a" \
        "$ROOT/rust/ostmac-core/target/release/libostmac_core.a"
fi
ls -lh "$ROOT/rust/ostmac-core/target/release/libostmac_core.a"
