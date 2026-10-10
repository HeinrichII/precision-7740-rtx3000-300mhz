#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  echo "Usage: $0 UNIGINE_SUPERPOSITION_DIR OUTPUT_DIR" >&2
  exit 2
fi

superposition_root=$(realpath "$1")
output_dir=$(mkdir -p "$2" && realpath "$2")
benchmark_bin="$superposition_root/bin/superposition"
automation_dir="${HOME}/.Superposition/automation"

if [[ ! -x "$benchmark_bin" ]]; then
  echo "Not executable: $benchmark_bin" >&2
  exit 1
fi

telemetry_pid=
cleanup() {
  if [[ -n "${telemetry_pid:-}" ]]; then
    kill "$telemetry_pid" 2>/dev/null || true
    wait "$telemetry_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd "$superposition_root/bin"

for pass in 1 2 3; do
  marker="$output_dir/run${pass}.marker"
  touch "$marker"

  nvidia-smi \
    --query-gpu=timestamp,pstate,utilization.gpu,utilization.encoder,clocks.current.graphics,clocks.current.sm,clocks.current.memory,clocks.current.video,power.draw,clocks_event_reasons.sw_power_cap,temperature.gpu \
    --format=csv -lms 500 > "$output_dir/run${pass}-telemetry.csv" &
  telemetry_pid=$!

  __NV_PRIME_RENDER_OFFLOAD=1 \
  __GLX_VENDOR_LIBRARY_NAME=nvidia \
  "$benchmark_bin" \
    -sound_app openal \
    -system_script superposition/system_script.cpp \
    -data_path ../ \
    -engine_config ../data/superposition/unigine.cfg \
    -video_mode -1 \
    -project_name Superposition \
    -video_resizable 1 \
    -console_command "config_readonly 1 && world_load superposition/superposition" \
    -mode 2 \
    -preset 0 \
    -video_width 1920 \
    -video_height 1080 \
    -video_fullscreen 1 \
    -shaders_quality 2 \
    -textures_quality 2 \
    -video_app opengl > "$output_dir/run${pass}-engine.log" 2>&1

  cleanup
  telemetry_pid=

  result=$(find "$automation_dir" -maxdepth 1 -type f -name 'log-*.txt' \
    -newer "$marker" -print | sort | tail -1)
  if [[ -z "$result" ]]; then
    echo "No new automation result found for pass $pass" >&2
    exit 1
  fi

  cp "$result" "$output_dir/run${pass}-result.txt"
  printf 'Pass %s: %s\n' "$pass" "$output_dir/run${pass}-result.txt"
done
