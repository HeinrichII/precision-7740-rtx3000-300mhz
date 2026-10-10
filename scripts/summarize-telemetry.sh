#!/usr/bin/env bash
set -euo pipefail

if (( $# == 0 )); then
  echo "Usage: $0 TELEMETRY.csv [...]" >&2
  exit 2
fi

for file in "$@"; do
  printf '%s\n' "$file"
  awk -F',' '
    NR > 1 {
      gpu = $3 + 0
      enc = $4 + 0
      gfx = $5 + 0
      mem = $7 + 0
      vid = $8 + 0
      power = $9 + 0
      temp = $11 + 0

      if (gpu > max_gpu) max_gpu = gpu
      if (enc > max_enc) max_enc = enc
      if (gfx > max_gfx) max_gfx = gfx
      if (min_gfx == 0 || gfx < min_gfx) min_gfx = gfx
      if (mem > max_mem) max_mem = mem
      if (vid > max_vid) max_vid = vid
      if (power > max_power) max_power = power
      if (temp > max_temp) max_temp = temp

      if (gpu >= 90) {
        loaded++
        if (gfx == 300) loaded_at_300++
      }
    }
    END {
      printf "samples=%d max_gpu=%g max_encoder=%g graphics=%g..%g " \
             "memory_max=%g video_max=%g power_max=%.2f temp_max=%g " \
             "loaded=%d loaded_at_300=%d\n", \
             NR - 1, max_gpu, max_enc, min_gfx, max_gfx, max_mem, \
             max_vid, max_power, max_temp, loaded, loaded_at_300
    }
  ' "$file"
done
