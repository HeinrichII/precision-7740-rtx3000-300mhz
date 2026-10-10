# Reproduction methodology

These commands are documentation, not a recommendation to run them blindly.
Review paths and ensure the system is stable before starting a load test.

## Superposition

Download UNIGINE Superposition 1.1 directly from the official page and verify
the installer before use. This investigation used SHA-256:

```text
7494e1c73bf59ef2161513d5d5cb9d9bffbd8479929d4976ac53b6955de580f8
```

The included runner expects an unpacked Superposition directory:

```bash
./scripts/run-superposition.sh /path/to/Unigine_Superposition-1.1 ./results
```

It performs three 1920x1080 fullscreen High/OpenGL runs and records NVIDIA
telemetry twice per second. It does not bind, unbind, reset, or reconfigure the
GPU.

Summarize telemetry afterward:

```bash
./scripts/summarize-telemetry.sh ./results/run*-telemetry.csv
```

The important correlation is workload throughput plus utilization, relevant
clock, power-cap reason, and temperature. An idle clock alone is not evidence
of a performance fault.

## NVIDIA AppEncPerf

The historical NVIDIA sample used for this report can be reproduced without
redistributing NVIDIA's source:

```bash
git clone https://github.com/NVIDIA/video-sdk-samples.git
cd video-sdk-samples
git checkout aa3544dcea2fe63122e4feb83bf805ea40e58dbe
git apply /path/to/patches/appencperf-cuda13-cuCtxCreate-v2.patch
make -C Samples/AppEncode/AppEncPerf -j4 CUDA_PATH=/opt/cuda
```

The patch is only an ABI compatibility adjustment for building this historical
sample with CUDA 13 headers against the tested driver.

Create a small raw input which AppEncPerf will loop:

```bash
ffmpeg -hide_banner -loglevel error \
  -f lavfi -i testsrc2=size=1920x1080:rate=60 \
  -frames:v 8 -pix_fmt yuv420p -f rawvideo input-1080p-8f.yuv
```

Record telemetry in one terminal:

```bash
nvidia-smi \
  --query-gpu=timestamp,pstate,utilization.gpu,utilization.encoder,clocks.current.graphics,clocks.current.sm,clocks.current.memory,clocks.current.video,power.draw,clocks_event_reasons.sw_power_cap,temperature.gpu \
  --format=csv -lms 200 > appencperf-telemetry.csv
```

Run AppEncPerf in another terminal:

```bash
Samples/AppEncode/AppEncPerf/AppEncPerf \
  -i input-1080p-8f.yuv -s 1920x1080 -if iyuv -gpu 0 \
  -frame 10000 -thread 1 -codec h264 -profile high \
  -preset hp -rc vbr_hq -fps 60 -gop 250 -bf 0 \
  -bitrate 50M -maxbitrate 50M
```

Stop the telemetry process after AppEncPerf exits.

## Interpretation rules

- Judge 3D rendering using GPU utilization, graphics/SM clocks, and FPS/score.
- Judge NVENC using encoder utilization, video clock, and encoded FPS.
- Do not treat the whole-board maximum power value as a required workload draw.
- Do not compare legacy AppEncPerf presets directly with current P1-P7 tables.
- Do not use live PCI unbind/rebind as a first-line diagnostic.
