# Investigation report

## Hardware and tested software

- Dell Precision 7740, board identifier `0DJVM3`, system identifier `0927`
- Intel Core i5-9400H and Intel UHD Graphics 630
- NVIDIA Quadro RTX 3000 Mobile / Max-Q, PCI ID `10de:1f36`
- NVIDIA VBIOS `90.06.39.00.70`
- Dell BIOS 1.42.1
- 240 W Dell power adapter recognized by the platform
- Omarchy 4.0.4 / kernel `7.2.5-3-omarchy`
- Proprietary NVIDIA 580.178.04 with GSP disabled
- Platform profile `performance`

Dell officially offered the Precision 7740 with Quadro RTX 3000, RTX 4000, and
RTX 5000 options. NVIDIA lists the mobile RTX 3000 in a 60-80 W power range.

## Initial telemetry

The NVIDIA driver repeatedly reported:

- current power limit: 20.00 W
- requested power limit: 20.00 W
- default/max power limit: 80.00 W
- performance cap reason: `SW Power Cap`
- hardware thermal slowdown: inactive
- hardware power-brake slowdown: inactive
- idle graphics/SM clock: 300 MHz

The driver refused an attempted `nvidia-smi -pl 80` operation as unsupported.
AC power, battery state, Dell platform profile, latest published BIOS, GSP
enabled/disabled, and proprietary/open driver variants did not explain or
remove the idle policy observation.

An Ubuntu 26.04.1 persistent installation, using its own kernel and packaged
proprietary NVIDIA 580.178.04 driver, reproduced the 20 W current/requested
limit and active software power cap at idle. No 3D benchmark was run in Ubuntu,
so this cross-distribution result must not be overstated as a performance A/B.

## The interpretation error

An early NVENC load showed 100% encoder utilization, about 20 W board power,
and a 300 MHz graphics clock. Treating that as proof of a globally broken GPU
was incorrect for two reasons:

1. NVENC is a fixed-function engine independent of the graphics/CUDA cores.
2. An 80 W whole-board maximum is not a required draw for video encoding.

The corrected test recorded graphics, SM, memory, and video clocks separately,
along with workload-specific utilization and throughput.

## Video-domain results

### GStreamer NVENC

A bounded GStreamer pipeline encoded 1,800 generated 3840x2160 frames with
H.264 NVENC, P1/high-quality, 50 Mbit/s, to a null sink.

- elapsed time: 25.027 seconds
- throughput: approximately 71.9 FPS
- encoder utilization: 100%
- graphics utilization: approximately 24%
- graphics/SM clock: 300 MHz
- memory clock: 810 MHz
- video clock: 540 MHz
- power: approximately 18.97-19.65 W
- temperature: 50-51 C

This proved that encoding worked, but did not prove whether the fixed 540 MHz
video clock was the highest appropriate clock for the board.

### NVIDIA AppEncPerf

NVIDIA's historical `video-sdk-samples` repository was checked out at commit
`aa3544dcea2fe63122e4feb83bf805ea40e58dbe`. Its AppEncPerf sample describes
itself as measuring encoding performance in FPS. A minimal CUDA 13 source
compatibility patch is included in this repository.

The sample encoded 10,000 1920x1080 IYUV frames as H.264 High Profile, legacy
`hp` preset, VBR-HQ, 50 Mbit/s, GOP 250, no B-frames, and one encoding thread.

- elapsed time: 68.3832 seconds
- throughput: 146.235 FPS
- encoder utilization: 95%
- general GPU utilization: 12-14%
- graphics/SM clock: 300 MHz
- memory clock: 810 MHz
- video clock: 540 MHz
- maximum power: 23.33 W
- maximum temperature: 60 C

The legacy `hp` preset does not map numerically one-for-one to NVIDIA's current
P1-P7 reference table. The valid conclusion is that NVENC is functional and
sustains well above real-time 1080p60 throughput—not that the video domain is
necessarily operating at its maximum possible clock.

## Graphics-domain results

Official UNIGINE Superposition 1.1 for Linux was downloaded from UNIGINE. The
installer SHA-256 was:

```text
7494e1c73bf59ef2161513d5d5cb9d9bffbd8479929d4976ac53b6955de580f8
```

It was run three times at 1920x1080 fullscreen, High shaders/textures, OpenGL,
with NVIDIA PRIME render offload explicitly selected. Each saved automation
report was identical:

| Pass | Score | Average FPS | Minimum FPS | Maximum FPS |
|---:|---:|---:|---:|---:|
| 1 | 953 | 7.1 | 6.1 | 8.4 |
| 2 | 953 | 7.1 | 6.1 | 8.4 |
| 3 | 953 | 7.1 | 6.1 | 8.4 |

The old UNIGINE UI displayed `Unknown GPU (256MB)`, but the engine log proved
that it rendered on `Quadro RTX 3000/PCIe/SSE2` through NVIDIA 580.178.04.

Telemetry across the three passes showed:

| Pass | Samples at >=90% GPU | Samples at 300 MHz | Max power | Max temp |
|---:|---:|---:|---:|---:|
| 1 | 363 | 363 | 25.73 W | 61 C |
| 2 | 372 | 372 | 25.85 W | 63 C |
| 3 | 371 | 371 | 25.88 W | 63 C |

All runs reached 100% GPU utilization and 0% encoder utilization. Every loaded
sample had graphics/SM clocks fixed at 300 MHz. Memory reached 810 MHz; video
remained at 540 MHz. Low temperature excludes thermal saturation as the cause.

This is direct evidence of a severe graphics/SM-domain performance clamp in
the tested state.

## Related failure during live reset testing

A guarded NVIDIA PCI unbind was attempted only after visible NVIDIA display
connectors and ordinary compute processes were absent. Hidden DRM clients from
the compositor/session still retained device references. The NVIDIA removal
path entered an internal non-zero-usage-count deadlock, and later bind/reset
attempts could not recover the device in that boot.

This was a separate driver teardown failure, not the original 300 MHz fault.
It is documented here so others do not use live unbind/rebind as a casual
workaround on a hybrid Wayland system.

## Current diagnosis

The RTX 3000 is not globally nonfunctional: PCI/VBIOS enumeration is normal,
NVENC works, and there are no relevant Xid, hardware thermal, or hardware
power-brake errors. It is nevertheless not performing normally for graphics.

The leading category is a Dell platform/EC plus NVIDIA initialization or power
policy problem. A card-specific power-management/VBIOS fault and a system-board
fault remain possible. The available evidence does not justify naming one of
those as proven.

Changing distributions is not a demonstrated fix. Omarchy should not be blamed
from this evidence, and the same NVIDIA 580 branch under Ubuntu reproduced the
idle power-policy state. A controlled Windows reinitialization test or a known-
good supported GPU A/B would be needed to separate card-specific from platform-
specific causes.
