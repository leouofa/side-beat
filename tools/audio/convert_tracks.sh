#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SRC="${ROOT_DIR}/tracks/Big Zeus.m4a"
DST="${ROOT_DIR}/tracks/Big Zeus.mp3"

if [[ -f "${SRC}" ]]; then
  /opt/homebrew/bin/ffmpeg -y -loglevel error -i "${SRC}" -codec:a libmp3lame -qscale:a 2 "${DST}"
  echo "Converted: ${DST}"
else
  echo "Source file not found: ${SRC}" >&2
  exit 1
fi
