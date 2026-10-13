# Windows vs macOS

This table compares the Windows build studied here (2.0.89.141, Geronimo `gs_04_92`) with the macOS study in PR #1161 (`docs/gfn-macos-re/`, macOS 2.0.87.131). The builds are two releases apart, so some differences may be version drift rather than platform design (**I**).

The macOS upload included `libBifrost2.dylib`; the Windows upload does not include `Bifrost2.dll`. So the macOS study has decompiled NVST wire formats and the Windows study has runtime logs. The two are complementary: where both exist they agree.

## Same on both platforms

| Area | Shared behavior | Windows evidence | macOS evidence |
| --- | --- | --- | --- |
| App-to-native boundary | `GFNQueryHandler` reads `deviceId`, `serverAddress`, `clientHeaders`, `keyboardLayout`, `metaData`, `supportedControls`, `spanData`, `streamingProfile`, `partnerCustomData` and calls `GridApp::prepare`, `setAuthInfo`, `start`, `resume` | **D** `GeForceNOW.exe` `0x1401a69c0` ([architecture.md](architecture.md)) | `GFNQueryHandler::OnQueryNative` `0x1000c3660` |
| Engine split | Geronimo is the client facade over Bifrost through the `nvb*` C API | **S** 31 `nvb*` imports | symbols in `libGeronimo.dylib` |
| Codec selection | Same selector, same branch order: 4:4:4 forces HEVC, explicit-codec failure has no fallback, Auto prefers AV1 > HEVC > H.264, H.264 + HDR is an error | **D** `FUN_180157f20` ([video.md](video.md)) | `chooseMaxSupportedVideoSettings` `0xb1de0` |
| Socket arrangements | RTC media on the bundle, optional unified Mjolnir video, legacy dedicated video socket | **L** legacy path taken on an NVIDIA seat ([handshake.md](handshake.md)) | **D** `setupSessionStreams` `0x1145c0` |
| NACK v2 | `RtpSourceQueueExtV2`, 64-record limit, 3 retries | **L** class name and constants | **D** serializer `0x256310`, command `0x317` |
| Mjolnir receive deadline | 8 ms queue-insert deadline | **L** `general.mjolnirVideoReceiverDequeueTimeoutMs 8` | **D** `CNvQueue::Add` `0x25da10` |
| Signaling header version | `14.2` | **L** `X-GS-Version: 14.2` | **D** `connectWithRtspHandshake` `0x1197a0` |
| Mic processing | WebRTC APM with a reverse (render) stream feeding the echo canceller | **D/L** `GsAudioWebRTC.dll`, `processReverseStream` `0x1802c2710` | **D** `libGsAudioWebRTC.dylib` |
| Server types | `NVB_SERVER_NIMBUS`, `GAMESTREAM`, `ROAMING_PROXY`, `CLOUD_STATION`, `QUADRO_STATION`, `PASSTHRU` | **D** numbers recovered at `0x1401a2c00` ([providers.md](providers.md)) | names only |

## Different on Windows

| Area | Windows | macOS | Evidence |
| --- | --- | --- | --- |
| Process model | Geronimo, Bifrost and SDL2 load in-process in the CEF shell. `GeForceNOWStreamer.exe` only relaunches `GeForceNOW.exe` | streamer stub inferred to be a launcher | **D** `GeForceNOWStreamer.exe` `0x140009eb0` |
| Background services | NvContainer host with `GameStreamClientAgent`, `GeForceNOWReliabilityMonitor` and `NvMessageBusBroadcast` over named pipes | `libGameStreamClientAgent.dylib` in an `nvc` folder | **L** NvContainer logs |
| Hardware decode | D3D11VA with Geronimo's own SPS/PPS parser and DXVA picture parameters; MFT, DXVA2/DX9 and FFmpeg (`avcodec-59`, software H.264) as alternates | VideoToolbox | **D** `platformCreateVideoDecoder` `0x18015bc10` |
| Capability probe | Creates real `ID3D11VideoDecoder` objects per candidate resolution; per-GPU disabled-config list; long/short slice | VideoToolbox support masks; `hevc120`; AV1-broken OS check | **D** `0x1801f9e90` |
| 4:4:4 decode | `HEVC_VLD_Main_444` / `HEVC_VLD_Main10_444` into AYUV/Y410; optional second D3D11 device on NVIDIA and Intel | `444v`/`x444` pixel buffers | **D** `0x180201e50` |
| Presentation | DXGI flip-sequential, 2 buffers, RGBA8 or RGB10A2, tearing, waitable object, `SetMaximumFrameLatency(1)`; render thread at time-critical priority | CAMetalLayer | **D** `0x18026cc80`, `0x18027b4b0` |
| HDR output | `SetColorSpace1(RGB_FULL_G2084_NONE_P2020)`; no `SetHDRMetaData` call | EDR layer with `CAEDRMetadata` from stream SEI | **D** ([color.md](color.md)) |
| Display HDR test | `DisplayConfigGetDeviceInfo` advanced-color supported/enabled bits plus BT.2020 or >400 nits; SDR white level from display config | EDR headroom | **D** ([color.md](color.md)) |
| Upscaling | Lanczos, NvScaler, NvSharp, Shepherd3/6 and DeepISP (CUDA in `NvPixels.dll`, NV12 8-bit only, falls back to Lanczos) | not compared (**U**) | **D/S** ([video.md](video.md)) |
| VRR | `NvAPI_D3D_SetVRRState`, cloud G-Sync, VVSync | display-sync flag in the Metal path | **D** |
| Audio playback | WASAPI shared, event-driven, `RATEADJUST` drift correction, ducking off, 2/6/8 channels | Audio Units renderer symbols | **D/L** ([audio.md](audio.md)) |
| Raw input | One Raw Input thread (`RIDEV_INPUTSINK`) for keyboard and mouse; GFN key-code space from SDL scancodes | not compared in detail (**U**) | **D** ([input.md](input.md)) |
| HID passthrough | `GSHID` raw HID forwarding for listed wheels and flight sticks, from remote config plus `RIDevices.json` | not studied (**U**) | **S/L** |
| Telemetry export | OpenTelemetry over gRPC, statically linked from a vcpkg tree named "Mjolnir" | not studied (**U**) | **S** |

## What the Windows logs add to the macOS findings

- The CloudMatch usage numbers seen at runtime on an NVIDIA seat: only 14 (`NVB_PU_RTSPS`) for streams and 10 for the session-control resource. The macOS map (2 VIDEO, 17 BUNDLE, 14/16 RTSPS) is not contradicted but is only partly exercised.
- The media peer for a non-unified session comes from the SETUP `Transport` header (`X-GS-ServerPort`), not from SDP ports.
- Six named SCTP data channels and the `udp_ag` control protocol choice.
- The NACK timing constants as configured in production, including the 1 ms initial delay.
- The idle-timeout timer notifications and the termination codes for idle and resumable drops.
- The frame-state values Geronimo reports to Bifrost (`nvbUpdateVideoFrameState`), which are the client half of frame acknowledgement.
