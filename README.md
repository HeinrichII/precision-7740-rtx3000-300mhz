# Dell Precision 7740 / Quadro RTX 3000 stuck at 300 MHz

This repository documents a reproducible graphics-performance failure on one
Dell Precision 7740 with an NVIDIA Quadro RTX 3000 Mobile (Turing): under a
real 3D workload, GPU utilization reaches 100% while the graphics/SM clock
remains fixed at 300 MHz.

The investigation is published because the most important finding is easy to
miss: **NVIDIA graphics and fixed-function video encoding are separate clock
domains.** A 300 MHz graphics clock during NVENC does not prove that video
encoding is slow. Graphics and video must be benchmarked independently.

## Result at a glance

| Workload | Throughput | Relevant utilization | Relevant clock | Finding |
|---|---:|---:|---:|---|
| UNIGINE Superposition 1.1, 1080p High OpenGL | 953 points / 7.1 FPS | GPU 100% | Graphics/SM 300 MHz | Severe graphics clamp |
| NVIDIA AppEncPerf, H.264 1080p VBR-HQ | 146.235 FPS | Encoder 95% | Video 540 MHz | NVENC functional |
| GStreamer NVENC, H.264 4K P1/HQ | 71.9 FPS | Encoder 100% | Video 540 MHz | NVENC functional |

Superposition was run three times. All three runs produced exactly 953 points,
7.1 average FPS, 6.1 minimum FPS, and 8.4 maximum FPS. Across 1,106 samples
where GPU utilization was at least 90%, every sample reported a 300 MHz
graphics/SM clock. Maximum temperature was only 63 C, and hardware thermal and
power-brake slowdown were not active.

## What this establishes

- The affected machine has a real graphics/SM performance failure in the
  tested proprietary NVIDIA 580.178.04, non-GSP state.
- NVENC is a distinct, working fixed-function path. Its throughput must not be
  judged using the graphics clock.
- The 80 W default/max board limit is not an 80 W target for every workload.
- A 20 W current/requested limit and `SW Power Cap` are meaningful here because
  a real graphics workload saturates the GPU without any graphics-clock boost.

## What this does not establish

- It does not prove whether the root cause is the RTX 3000 board, Dell
  EC/firmware/platform policy, or NVIDIA's platform initialization.
- It does not prove that Omarchy caused the fault.
- It does not benchmark the stock/open 610 driver against proprietary 580.
- It does not prove that 540 MHz is the RTX 3000's correct maximum video clock.
- It is one-machine evidence, not a claim that every Precision 7740 is affected.

The closest public match is an unsolved Dell community report describing the
same model/GPU at approximately 23 W, 300 MHz, and 100% utilization under
Windows. In that case, disabling and re-enabling the GPU temporarily restored
performance. That close match makes a platform/device-initialization problem
plausible, but it is not proof of the cause.

## Repository contents

- [`REPORT.md`](REPORT.md): full findings, eliminated hypotheses, and limits.
- [`REPRODUCE.md`](REPRODUCE.md): exact benchmark methodology.
- [`data/`](data): sanitized raw benchmark reports and telemetry.
- [`scripts/`](scripts): three-pass Superposition runner and telemetry summary.
- [`SOURCES.md`](SOURCES.md): primary documentation and related reports.

## Safety warning

Do not casually use PCI unbind/rebind, module unloading, or GPU reset on a live
hybrid-graphics Wayland session. During this investigation, an NVIDIA DRM
client retained a reference during unbind and the kernel teardown path
deadlocked. A normal reboot recovered the machine, but the reset path did not
repair the performance fault.

No GPU VBIOS, system BIOS, EEPROM, or firmware was flashed during this work.
