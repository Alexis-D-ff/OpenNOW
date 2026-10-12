#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
socket=${1:-${OPENNOW_MEDIACODEC_SOCKET:-}}
if [[ -z "$socket" ]]; then
    printf 'Usage: %s SOCKET\n' "$0" >&2
    exit 2
fi
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
ffmpeg -hide_banner -loglevel error -f lavfi -i color=c=black:s=1280x720:r=60 \
    -frames:v 1 -c:v libx264 -profile:v baseline -pix_fmt yuv420p \
    -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
    -x264-params 'aud=1:repeat-headers=1:scenecut=0' -f h264 "$fixture/black.h264"
cargo run --manifest-path "$root/native/opennow-streamer/Cargo.toml" \
    -p opennow-streamer-platform-linux --example mediacodec_smoke -- \
    "$socket" "$fixture/black.h264"
