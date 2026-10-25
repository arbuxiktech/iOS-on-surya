# freedreno on Sweet Adreno devices (libdrm stand-in for the Sweet kernel ABI)

The stand-in is integrated with the Poco F1's Adreno 630 user client and Mesa path (the phone results are in `docs/GPU_EAGL.md`). It now discovers either `SweetAdreno630` or the planned `SweetAdreno618` service and accepts only a ready ABI-1 device reporting GPU ID 618 or 630. `SWEET_GPU_SERVICE=NAME` pins discovery to one service. Mesa falls back to softpipe when no matching ready service exists.

Surya's current XNU patches do not publish an Adreno 618 user client or implement command submission, so the new discovery path is preparation only: on the current Surya kernel the expected userland result is the softpipe fallback. The staged GMU/GX/ZAP bring-up is not a rendering interface. Kernel requirements are tracked in `docs/SURYA_PORT.md`; the existing A630 interface is documented in `docs/GPU_KERNEL.md`.

## Approach: a libdrm stand-in, no Mesa source change

Mesa's freedreno `msm` backend (Mesa 25.0.x: `src/freedreno/drm/msm/*.c`, 34 call sites) only needs `drmCommandWriteRead/Write`, `drmIoctl(GEM_CLOSE)`,
`drmGetVersion`, `drmOpenWithType`, `drmGetCap` and `mmap(fd, bo offset)`. The kernel interface was made of exactly those requests
(selector = `0x40 + DRM_MSM_*`, Linux structure layouts), so `sweet_drm.c` implements them over `IOConnectCallStructMethod` and interposes `mmap`/`munmap` for
its fds (dups of `/dev/null`) with `IOConnectMapMemory64(memoryType = BO handle, kIOMapWriteCombineCache)`.
It reports DRM version msm 1.3 on purpose (no softpin: Mesa would pick its own GPU addresses; the kernel assigns them and the backend reads them with `GEM_INFO(GET_IOVA)`
and patches relocations, which the kernel also supports). Absolute `CLOCK_MONOTONIC` timeouts are converted to the kernel's relative ones. `SWEET_DRM_TRACE=1` logs failing requests.

## Build

`ARCH` and `IOS_MIN_VERSION` are configurable. Defaults preserve the existing iOS 18 arm64e build. For the Surya arm64 userspace target, use a separate scratch directory so Meson does not reuse an arm64e build tree:

```sh
ARCH=arm64 IOS_MIN_VERSION=18.0 GPU_EAGL_WORK=/path/to/surya-eagl gpu/eagl/mesa/build-mesa.sh
ARCH=arm64 IOS_MIN_VERSION=18.0 GPU_EAGL_WORK=/path/to/surya-eagl MESA_BLD=/path/to/surya-eagl/build-hw gpu/eagl/make-payload.sh research/surya-gles
```

The result is an arm64 payload for the same iOS 18 userland with a software fallback. If a future kernel publishes the A618 user client with the `SweetAdreno618` service name and the documented MSM ABI, the stand-in will select it; `SWEET_GPU_SERVICE` can override automatic discovery. The process sandbox must permit the service open.

## Interface limits

* The EAGL Mesa integration supplies an OSMesa GLES frontend and IOSurface BO hooks; the hardware path still requires a kernel user client that supports BO allocation/mapping, command submission, fences, IOSurface import and cache synchronization.
* `drmSyncobj*` and PRIME are stubs (`-ENOSYS`, `drmGetCap` reports no syncobj); freedreno gallium falls back to its own fence handling.
* If dyld interposing is not honoured on the PAC-less runtime, patch `fd_bo_map_os_mmap` (`freedreno_bo.c`) to call `IOConnectMapMemory64` directly.
