# OpenNOW gaps against the Windows client

This list compares OpenNOW `dev` at `7ce3cd54` (after PRs #1162, #1164 and #1165 merged) with the Windows GFN client 2.0.89.141. Each item names the GFN evidence, the OpenNOW location, and what would close the gap. "Not found" means a repository search found no handling; read the code before acting on it.

Priority: **P1** affects what users see, hear or whether a session survives. **P2** is correctness or robustness. **P3** is parity or diagnostics.

## Contradictions with merged PRs

| # | Gap | GFN Windows evidence | OpenNOW location | Suggested change |
| --- | --- | --- | --- | --- |
| C1 | **P2.** Auto codec order under HDR is HEVC then AV1. | Auto picks AV1, then HEVC, then H.264 in both the SDR and the HDR branch (**D** `FUN_180157f20`). The macOS study (`docs/gfn-macos-re/video.md`) records the same order. | `native/opennow-core/src/streamer.rs`, `resolve_embedded_session`, HDR branch `["h265", "av1"]` | Try AV1 first when `auto_av1_eligible` and AV1 10-bit decode pass, or keep HEVC first on purpose and stop calling it the GFN order in `docs/hdr.md`. |
| C2 | **P2.** H.264 cap applies only to Auto+HDR above 120 fps. | H.264 is capped at 120 fps and below 4,953,600 px whenever H.264 is explicit or the only decodable codec (**D/L**). | Same function, `cap_fps` | Apply the 120 fps and pixel cap to explicit H.264 and to Auto-only-H.264, and record a `stream_profile_fallback` event. |
| C3 | **P3.** Explicit H.264 + HDR downgrades to SDR. | GFN returns `0xc0f11042` (**D**). | Same function | None. PR #1165 documents this choice. |

## Transport and session lifecycle

| # | Gap | GFN Windows evidence | OpenNOW location | Suggested change |
| --- | --- | --- | --- | --- |
| T1 | **P1.** Any input forward error ends the session. | 42 `Sending Input event failed: NVST_R_GENERIC_ERROR` lines while streaming continues (**L**). | `native/opennow-streamer/crates/opennow-streamer-core/src/lib.rs` ~1906-1917 (`native-input-capture-failed`) | Count and drop transient send errors; end the session only on a dead transport. |
| T2 | **P1.** No idle-timeout warning. | Server timer notifications type 4 (60 s left) and type 5 (0 s), then `NVST_DISCONN_SERVER_TERMINATED_CLOSED (0x80030023)`; Geronimo raises `NVB_SN_APPROACHING_IDLE_TIMEOUT` (**L**). | Not found in `opennow-streamer-transport/src/nvst.rs`, `nvst_control.rs` | Parse the ServerControl timer notification, surface a warning to Qt, and classify the end as idle timeout. |
| T3 | **P2.** Termination has no resumable flag. | Geronimo `0x180142a70`: reason 0x37 is resumable except codes 0x80040003, 0x8004000b-f, 0x80040011-16; reason 0x3b only for 0x80040004/7/10 (**D**). The JS app auto-resumes once, bounded at about 10 s (**L**). | `opennow-streamer-core/src/lib.rs` ~2359 (`"resumable": null`); resume body in `native/opennow-core/src/cloudmatch.rs` | Carry reason and extended code, apply the same rule, and drive one bounded auto-resume. |
| T4 | **P3.** NACK has no initial send delay. | `NACK request initial send delay: 1 ms`; all other constants match (**L**). | `opennow-streamer-transport/src/nvst.rs`; `docs/mjolnir-nack-v2.md` | Add the 1 ms delay, or note the measured effect. |
| T6 | **P3.** Some ANNOUNCE values differ from the Windows merged config: `mic.micSsrcConfig.senderSsrc` 5 vs 1, `packetPacing.minNumPacketsPerGroup` 0 vs 15, `vqos[0].bllFec.enable` 1 vs 0, `fec.repairMinPercent` 5 vs 20, `fec.repairMaxPercent` 40 vs 35. | Merged config dump, not the wire body (**L**; wire **U**). | `nvst_rtsp.rs`, `build_announce` | Confirm against `Bifrost2.dll` or the macOS ANNOUNCE builder before changing. |
| T7 | **P3.** `video[0].refPicInvalidation` and recovery keys are not in ANNOUNCE. | Windows config has `refPicInvalidation 1`, `framesWithInvalidRefThreshold 4`, `streamRecoveryType 2`, `enableRecoveryMode 1`, `enableIntraRefreshInRecoveryMode 1` (**L**). Whether Windows sends them is **U**. | `nvst_rtsp.rs`; PR #1164's `nvst_invalidation.rs` | If RFI counters stay at zero in real sessions, test advertising these keys. |
| T8 | **P2.** Peer selection on NVIDIA seats must stay on the SETUP `Transport` port. | Video and bundle sockets both sent to `X-GS-ServerPort` 5004; `serverBundlePort 47999` and `serverEndpoints` were never peers (**L**). | `nvst_rtsp.rs` (video setup sweep, bundle peer, `bundle-route` line) | Add a regression test with the S6 shape: two usage-14 entries, `X-GS-ServerPort=5004-5005`, `serverBundlePort 47999`, `enableUnifiedSocket 0`. |
| T9 | **P3.** QoS report version. | Server SDP announces QoS feedback v7, timings v5, blob stats v9 (**L**). | `opennow-streamer-transport/src/nvst.rs`, `nvst_qos_tests.rs` | Check that the report follows the announced version. |

## CloudMatch request

| # | Gap | GFN Windows evidence | OpenNOW location | Suggested change |
| --- | --- | --- | --- | --- |
| R1 | **P3.** `requestedStreamingFeatures.qosPolicy`, `touchSupport` and `dlssOverrides` are omitted, and a code comment says GFN does not send them. | Windows sends `qosPolicy 0`, `touchSupport false`, `dlssOverrides` with 7 keys (**L**). | `native/opennow-core/src/cloudmatch.rs` (comment above `build_create_body`'s feature list; test asserting `qosPolicy` absent) | Send them with the logged defaults, or fix the comment. |
| R2 | **P3.** `metaData` lacks `ClientImeSupport`, `clientPhysicalResolution`, `networkType`. | Sent by Windows (**L**). | `cloudmatch.rs` (test `session_metadata_contains_only_owned_values`) | Decide deliberately; server effect is **U**. |
| R3 | **P3.** `remoteControllersBitmap` 0 and `dpi` 96 on NVIDIA seats; constant `userAge`. | Windows sends 1, 100, and the account age (**L**). | `cloudmatch.rs` | Low risk; `userAge` may matter for age-gated titles (**U**). |

## Video, color and presentation

| # | Gap | GFN Windows evidence | OpenNOW location | Suggested change |
| --- | --- | --- | --- | --- |
| V1 | **P2.** Display HDR detection uses only `IDXGIOutput6::GetDesc1`. | GFN reads `DisplayConfigGetDeviceInfo` advanced-color supported/enabled bits plus BT.2020 or >400 nits, and the SDR white level (default 200 nits) (**D**). | `opennow-qt/src/streaming/rendering/WindowsHdrDisplay.cpp` | Add the advanced-color bits so "supported but off" and wide-gamut SDR desktops are told apart. |
| V2 | **P3.** No max-decodable-resolution probe. | GFN creates real `ID3D11VideoDecoder` objects per candidate resolution and caps the request (`Maximum decoder supported resolution`) (**D/L**). | `native/opennow-streamer/crates/opennow-streamer-platform-windows/src/windows/decoder.rs` | Expose a per-codec max resolution from the capability probe. |
| V3 | **P3.** No client render benchmark before high fps. | `Render benchmark completed. p95 GPU time ... MaxFPS ... Affordable` (**L**). | Not found | Optional: gate fps on measured render cost. |
| V4 | **P3.** Upscaling choices. | GFN offers Lanczos, NvScaler/NvSharp (NVIDIA), Shepherd3/6 and DeepISP (CUDA) and negotiates a server prefilter (**D/L**). | `native/opennow-core/src/settings.rs` (`upscaling`: off/metalfx/fsr1) | Make sure the server's finalized prefilter mode is honored. |
| V5 | **P3.** No NvAPI VRR toggle and no time-critical render thread. | `NvAPI_D3D_SetVRRState`; render thread priority 15 (**D**). | `opennow-qt/src/streaming/rendering/` | Optional for G-Sync users. |
| V6 | **P3.** Diagnostics do not print format transitions the way GFN does. | `Stream bit depth/chroma/colorspace changed to ...`, swap-chain `Old/New Format` lines (**L**). | streamer diagnostics | Log decoder output format, swap-chain format and color space changes. |

## Audio and microphone

| # | Gap | GFN Windows evidence | OpenNOW location | Suggested change |
| --- | --- | --- | --- | --- |
| A1 | **P1.** No echo cancellation on the microphone. | WebRTC AEC with decoded game audio as the reverse stream; NS and AGC off (**D/L**). | `native/opennow-streamer/crates/opennow-streamer-platform/src/microphone.rs` | Add AEC with the decoded game audio as the reference. |
| A2 | **P2.** Mic packets have no RED. | `Mic redundancy enabled using RFC2198 (RED), redundancy level is 3`; Opus 20 ms (**L**). | `opennow-streamer-transport/src/nvst_microphone.rs`; `microphone.rs` (Opus VoIP, 10 ms, mono, 32 kbps) | Add RED level 3 encoding, as `aqos.redundancyLevelForMic` asks. |
| A3 | **P1.** No adaptive jitter buffer. | Bifrost adapts between 45 and 200 ms, starting at 80 ms (**L**). | `opennow-streamer-platform/src/audio_playout.rs`, `media.rs` (fixed 120 ms playout) | Adaptive depth driven by measured jitter. |
| A4 | **P2.** Playback is SDL2 without drift correction or device-change rebuild on the Qt path. | WASAPI shared, event-driven, `RATEADJUST` drift correction, rebuild on default-device change (**D**). | `opennow-streamer-platform/src/output.rs`; `opennow-streamer-platform-windows/src/windows/audio.rs` | Use the WASAPI path in the embedded flow, or add drift correction and device-change handling. |
| A5 | **P3.** Stereo only. | 2/6/8 channels negotiated from the device (`nvbConfigureAudioChannelCount`) (**D**). | `nvst_rtsp.rs` (`channels: 2`); `media.rs` | Multichannel Opus when the device supports it. |

## Input, cursor, clipboard

| # | Gap | GFN Windows evidence | OpenNOW location | Suggested change |
| --- | --- | --- | --- | --- |
| I1 | **P2.** Lock-key state is never sent. | `Updated lock keys with cached values` at upstream-ready (**L**). | `opennow-streamer-transport/src/nvst_input.rs` (type-19 encoder, no producer); `opennow-qt/src/streaming/StreamVideoItemInput.cpp` | Send Caps/Num/Scroll on capture start and on change. |
| I2 | **P2.** Key auto-repeat is dropped. | GFN forwards repeats with a repeat flag (**D**). | `StreamVideoItemInput.cpp` ~557-560 | Forward repeats. |
| I3 | **P2.** Bitmap cursors are detected but not drawn. | GFN draws server bitmap cursors locally and caches them by ID (**D/L**). | `nvst_input.rs` ~499-516 | Render them on the stream item. |
| I4 | **P2.** No clipboard protocol. | `PASTE` custom messages to `UIPlugin` and `GFN_CLIENT_UI`, `CLIENT_DATA_RESPONSE` up to 64 KB (**L/D**). | `nvst_input.rs`; custom-message channels opened but unused | Implement the custom-message clipboard after confirming the JSON schema. |
| I5 | **P2.** No DS5 synthesis or raw HID passthrough. | DS4/DS5 synthesis with cross-synthesis flags; `GSHID` passthrough for listed wheels and flight sticks (**D/L**). | `native/opennow-streamer/crates/opennow-streamer-hid/` | DS5 when `ri.hidDeviceMask` allows; GSHID later. |
| I6 | **P3.** No mouse-settings feature control. | `nvbFeatureControl` type 10 (accel 0, speed 10) on capture changes (**L**). | `cloudmatch.rs` (`mouseMovementFlags 0` only) | Confirm the wire format (macOS Bifrost) first. |
| I7 | **P3.** Keyboard layout is static. | GFN derives it from the OS layout and re-checks at upstream-ready (**L**). | `native/opennow-core/src/language.rs`, `cloudmatch.rs` | Follow the OS layout. |

## Not gaps

Windows evidence agrees with OpenNOW on: ping version 6 and ping intervals (20/100 ms); RTSP over WSS with `wssignaling=1`; the partially reliable input channel with a 300 ms lifetime; NACK wait, backoff, retry and record limits; the legacy dedicated video socket with audio, mic and data on the bundle when `enableUnifiedSocket=0`; leaving the V1 ICE/DTLS keys out of ANNOUNCE (`nvst_rtsp.rs:1580-1586` sends only the `*V2` keys and the standard ICE lines); the color wire mapping `10bit_444` → `bitDepth 1, chromaFormat 1`; the 4:4:4-forces-HEVC rule; and the RFI policy of withholding frames that may reference lost data.
