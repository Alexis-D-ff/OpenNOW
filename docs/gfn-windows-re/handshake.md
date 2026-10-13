# NVST handshake on Windows (GFN 2.0.89.141, Geronimo gs_04_92 38967594)

Bifrost2.dll was not supplied. Every RTSP, ICE, DTLS and socket detail below therefore comes from Bifrost log lines that Bifrost prints into `geronimo.log(.bak)`, from Geronimo's side of the `nvb*` API, and from GeForceNOW.exe. No Windows Bifrost function address is claimed. macOS facts are labelled "macOS Bifrost (PR #1161)".

Evidence tags: **S** static, **D** decompiled/disassembled (Geronimo.dll base 0x180000000, GeForceNOW.exe base 0x140000000), **L** log line (file, local UTC+2 time), **I** inferred, **U** unknown. Unless noted, log lines are from `geronimo.log.bak`, session started 2026-10-12 19:45 local (S6) (the second session in that file; the first ended at 19:33:41).

## 1. Layers and who owns what

| Layer | Binary | Evidence |
|---|---|---|
| UI, CloudMatch query bridge (`QUERY_GFN_PREPARE`, `QUERY_GFN_START`, `QUERY_GFN_RESUME`) | GeForceNOW.exe | **S** command list from 0x14028d820; **D** handler 0x1401a69c0 reads `address`, `serverType`, `partnerCustomData`, `deviceId`, `token`, `tokenType`, `clientHeaders` |
| Session orchestration, decode, render, input; caller of 31 `nvb*` imports | Geronimo.dll | **S** IAT; **D** `BifrostSDKExecutor` vtable 0x18141c1c0 |
| CloudMatch HTTP, RTSPS/WSS, ICE/DTLS/SRTP, SCTP, Mjolnir, NACK, QoS | Bifrost2.dll (absent) | **L** only: tags `[BifrostClient: GridServer]`, `[BifrostClient: Streamer]`, `[NVST:*]` |

`nvbCreateClient` callers: 0x1800c8e20, 0x18012e310, 0x180139ac0. `nvbStartSession`: 0x180130170, 0x180130250. `nvbStartStreaming`: 0x1800cdcc0, 0x1800ce3e0, 0x18013bf50. `nvbPauseSession` 0x18012e680, `nvbResumeSession` 0x18012f740/0x18012faf0, `nvbSetAuthInfo` 0x18012fce0, `nvbStopSession` 0x1801303a0 (**S/D**, IAT caller scan).

## 2. Server type conversion

GeForceNOW.exe 0x1401a2c00 converts the JS `serverType` into a Bifrost server type (**D**, log literals at 0x1402a12c8..0x1402a1490):

| JS value | Returned | Name |
|---|---|---|
| 1 | 0 | `NVB_SERVER_NIMBUS` |
| 2 | 1 | `NVB_SERVER_GAMESTREAM` |
| 3 | 2 | `NVB_SERVER_ROAMING_PROXY` |
| 4 | 3 | `NVB_SERVER_CLOUD_STATION` |
| 5 | 4 | `NVB_SERVER_QUADRO_STATION` |
| 1001 (0x3e9) | 0x33 (51) | `NVB_SERVER_PASSTHRU` (branch 0x1401a2ddf, `mov eax,0x33` at 0x1401a2e24) |
| 0, 6, other | -1 | `NVB_SERVER_UNKNOWN` |

Logs: console.log `streamingService prepare params` has `"serverType": 1` (**L**); debug.log has `Pre-NVb-conversion ServerType : 1` (**L**); Bifrost then logs `Converted Nvb server type 0 to nvsc Server type 2` (19:45:11, **L**). So NIMBUS (Bifrost 0) maps to NVSC server type 2. The NVSC numbering for other types is **U**.

## 3. CloudMatch session request and response

Bifrost logs the serialized request (`Serialized session request. Size: 1957`, 19:45:11, **L**). Field names (values redacted where identifying):

- Identity of client: `clientIdentification` "GFN-PC", `clientVersion` "30.0", `sdkVersion` "2.0", `streamerVersion` "14", `clientPlatformName` "Windows", `deviceHashId` <redacted>.
- Session: `appId`, `externalAppId`, `internalTitle`, `appLaunchMode` 1, `parentSessionId`, `networkTestSessionId`, `useOps` true, `accountLinked` false, `userAge`, `enablePersistingInGameSettings`, `clientTimezoneOffset`.
- Transport hints: `secureRTSPSupported` true, `transport` null, `partnerCustomData` null.
- Display/audio: `clientRequestMonitorSettings[]` (monitorId, position, size, dpi, framesPerSecond, sdrHdrMode, displayData, hdr10PlusGamingData), `sdrHdrMode`, `clientDisplayHdrCapabilities`, `audioMode` 2, `surroundAudioInfo`, `requestedAudioFormat`.
- `requestedStreamingFeatures`: reflex, bitDepth, cloudGsync, enabledL4S, mouseMovementFlags, trueHdr, supportedHidDevices, profile, fallbackToLogicalResolution, hidDevices, chromaFormat, prefilterMode/Sharpness/NoiseReduction, hudStreamingMode, qosPolicy, touchSupport, dlssOverrides{srMode,srModel,srScale,rrModel,fgMode,fgModel,fgMultiplier}.
- `metaData[]` keys: `ClientImeSupport`, `SubSessionId`, `clientPhysicalResolution`, `networkType`, `wssignaling` (value 1), `surroundAudioInfo`.

The response (`Client Request: 11, server response:`, 19 polls, **L**) carries `session.status` 1 for 18 polls and 2 once, `seatSetupInfo{queuePosition,seatSetupStep,seatSetupEta}`, `finalizedStreamingFeatures`, `userIdleWarningTimeoutInMs` (0 here), `gpuType`, `clientIp` <redacted>, `requestStatus{statusCode,unifiedErrorCode,serverId,...}`.

### Connection info and port usage

In this NVIDIA (NIMBUS) session the response had exactly these endpoints (all 19 polls, **L**):

| Object | usage | protocol | appLevelProtocol | port | resourcePath |
|---|---|---|---|---|---|
| `sessionControlInfo` | 10 | 0 | 5 | 443 | `/v2/session/<redacted>` |
| `connectionInfo[0]` | 14 | 1 | 6 | 322 | `rtsps://<redacted-ip>.cloudmatchbeta.nvidiagrid.net:322` |
| `connectionInfo[1]` | 14 | 1 | 6 | 48322 | `rtsps://<redacted-ip>.cloudmatchbeta.nvidiagrid.net:48322` |

Bifrost names usage 14 `NVB_PU_RTSPS` (`ConnectionInfo[0]: ... usage: NVB_PU_RTSPS`, 19:45:29, **L**). The `NVB_PU_*` names are not present as strings in Geronimo.dll or GeForceNOW.exe (**S**, negative search), so the full enum stays in Bifrost2.dll. **No usage 2 (VIDEO) or 17 (BUNDLE) entry appeared in any Windows log.** Usage 10 appears only on `sessionControlInfo` (the CloudMatch session resource), not as a stream endpoint.

Geronimo has its own usage map in `Nsk::getStreamStartParameters` 0x18012af30 (jump table at RVA 0x12bbf4, **D**): 1→1, 2→2, 3→3, 4→4, 5→2, 7→5, 12→5, 13→6, 14→5, 16→7, 17→8; 6, 8–11 and 15 log `Unknown port usage detected in the SessionObject`. This path belongs to the Nsk/SessionObject API (no direct callers found; its log line `Populating connection info: ... Port Usage: %d` at 0x18013f040 never appears in the logs), so it is **not** the path the PC client used here (**I**). The meaning of the internal values 1–8 is **U**. It agrees with macOS and PR #1162 in treating 14 and 16 as one class (both → 5) and 2/17 as distinct media classes.

## 4. Signaling: RTSP over secure WebSocket

1. `Using Secure WebSockets for Signaling` (`[BifrostClient: Streamer]`, 19:45:11, **L**), consistent with request `metaData` `wssignaling`=1 and `general.rtspWebSocketPerConnection`=1 (NvscClientConfig, **L**).
2. `WSS Options: rtsps://<redacted-ip>.cloudmatchbeta.nvidiagrid.net:322` (19:45:30.560). The server answers `X-GS-Version: 14.2` and `Public: OPTIONS,DESCRIBE,ANNOUNCE,SETUP,TEARDOWN,PLAY,PAUSE,X_NV_COMMAND,X_NV_EVENT` (**L**).
3. DESCRIBE: `application/sdp`, `Content-Length: 219292`, `WSS Describe: latency is: 69.9 ms` (**L**). Bifrost prints only the server's "new features" SDP subset (`SignalingHandler new features:`; 62 `a=x-nv-*` keys such as `general.customMessageOnCC`, `vqos[0].qec.featureSetting`, `packetPacing.enableAccurateSleep`). The SDP origin line carries `k=HMAC:<redacted>`. Then `SDP: Received QosFeedback version from server: [7]`, `QosTimings version ... [5]`, `Blob stats version server: [9], client: [9]` (19:45:30.643, **L**).
4. Control protocol negotiation: `Adding support for protocol` udp, udp_ag, tcp, udp_enc, udp_ag_enc, tcp_enc, channel_encrypt; `updateControlProtocol has picked udp_ag (2) - not encrypted`; `Final Selected ControlProtocol: udp_ag, controlControlId: streamid=control/10` (19:45:30.643, **L**). `ServerControlRUA` later logs `Instanstiated ServerControlReliableUdpAggregated` (19:45:31.337).
5. SETUP for video only: `WSS Setup: streamid=video/0/0`; response `Transport: unicast;X-GS-ServerPort=5004-5005;source=<redacted-ip>`, `X-Nv-Ping-Payload: <redacted>`, `x-nv-ping: 6`, latency 173 ms (19:45:30.827, **L**). The video RTP source is bound to local port 49005 (`UDP RTP Source: bound to <redacted-ip>:49005`).
6. Audio and mic skip RTSP SETUP: `Bypassing 'Mjolnir' SETUP for the Audio stream. Deferring to WebRtcTransport setup` (same for Mic, 19:45:30.654, **L**). This matches NvscClientConfig `rtcAudioOnNativeBundle`=1, `rtcMicOnNativeBundle`=1, `rtcVideoOnNativeBundle`=0.
7. `Encryption key in RTSPS`; `setEncryptionKey` for audio and video with a single key ID (value <redacted>) (19:45:30.828, **L**). The media key travels inside the RTSPS exchange.
8. ANNOUNCE body: `AppendNvscConfigToSdp` → `Successfully appended 163 NvscClientConfig attributes to SDP`. Bifrost skips `x-nv-general.iceUsernameFragment`, `x-nv-general.iceUsernamePwd` and `x-nv-general.dtlsFingerprint` (`addSdpAttribute: Skipping field`, **L**). The 163 client attributes themselves are not logged; the effective config is the 973-row `NvscClientConfig` dump (see configuration-fields.md §11).
9. `WSS Announce: rtsps://...:322` (19:45:30.876), `RtspAnnounce duration greater than 300 ms` (19:45:31.258, ~382 ms). ICE/DTLS runs during ANNOUNCE (section 5).
10. After ANNOUNCE, `Signaling Server Ip: rtsps://<redacted-ip>.cloudmatchbeta.nvidiagrid.net:48322` and `general.serverEndpoints: RTSP hanshake 322 control 47995 UDP control 47999 audio 48000 input 47995 bundle 48001 ...` (19:45:31.258, **L**).
11. `WSS Play : sessionId : <redacted>`, `WSS Play: latency is: 113.7 ms with code 200:200` (19:45:31.480, **L**).

## 5. NAT punch, ICE, DTLS, SRTP

- `Set ping-version: 6` and `Client early ICE socket bound to port 49006` (19:45:30.828, **L**). `NattHolePunch` sends `Send src ping version 6 on port 49006 to dest <redacted-ip>:5004: Success` (30 lines) and the same from port 49005 (10 lines), then `Setting <redacted-ip>:5004 as valid destination` (19:45:31.323). Port 49006 is `general.clientBundlePort`; 49005 is the video socket.
- `No need to capture candidates for cloud server` (**L**): no host-candidate gathering for NIMBUS.
- `DTLS handshake done.` (19:45:31.337) followed by one `Retrying DTLS handshake after timeout, retry count 1` from a second `DtlsTransport` thread (19:45:31.354), and a telemetry event `NvstDebug_Event DTLSHandshake Succeed` (**L**).
- `OpenSSLCertUtils` logs 37 `Certificate bag` lines, `PKCS7 Encrypted data`, and root subjects (GlobalSign, VeriSign Universal Root) (**L**). This is the RTSPS/HTTPS trust store load; the DTLS peer verification policy is **U** on Windows (macOS Bifrost (PR #1161) describes fingerprint checking).
- SRTP: `runtime.srtpReplayWindowSize: 1024`; at session end `SRTP encrypt failures: total=0 replay=0 cipher=0 other=0` and `RtpStats percPacketsDroppedByReplayProtectionx1e6 0.000000, percPacketsDroppedByAuthFailx1e6 0.000000` (19:33:41, **L**).

## 6. Pause, resume and session reuse

Geronimo calls `nvbPauseSession` from 0x18012e680 and `nvbResumeSession` from 0x18012f740 and 0x18012faf0 (**D**). `QUERY_GFN_RESUME` is one of the commands handled by GeForceNOW.exe 0x1401a69c0 (**S/D**). Neither call appears in the supplied logs, so the wire effect of pause/resume is **U**. Resumability after termination is decided by Geronimo helper 0x180142a70; see transport-feedback.md §8.

## 7. Comparison with macOS Bifrost and OpenNOW

- macOS Bifrost (PR #1161) describes three socket arrangements: RTC-compliant, unified Mjolnir, and legacy dedicated sockets. The Windows NIMBUS session used the legacy dedicated video socket: `Unified socket mode disabled (enableUnifiedSocket=0, using legacy dedicated sockets)` (19:45:31.364, **L**), with audio/mic/data channels on the native bundle. This is consistent with macOS.
- OpenNOW `native/opennow-core/src/cloudmatch.rs` picks a media endpoint from usage 2 or 17 when present. In this Windows NVIDIA session no such entry exists, so OpenNOW (`nvst_rtsp.rs`, `parse_video_peer` and the bundle-peer fallback after `setup_video`) takes the video peer from the SETUP `Transport` `source`/`X-GS-ServerPort` and reuses it as the bundle peer. That is the same peer both Windows sockets used (server port 5004). OpenNOW does not use `general.serverBundlePort` as a peer; it uses it only to build the NAT ping username (`bundle_natt_username`) (read from code on dev `7ce3cd54`). The two clients therefore agree on NVIDIA seats; the ping-username rule has no Windows evidence either way (**U**).
- OpenNOW `nvst_rtsp.rs` emits `general.iceUsernameFragment`, `general.iceUsernamePwd` and `general.dtlsFingerprint` in ANNOUNCE, plus the `*V2` variants. Windows Bifrost explicitly skips the three V1 fields (**L**). Whether the server ignores or uses the V1 fields is **U**.
- OpenNOW's request builder (`cloudmatch.rs` ~1656) sends `metaData` `wssignaling`, `SubSessionId` and `surroundAudioInfo`, like Windows. Windows also sends `ClientImeSupport`, `clientPhysicalResolution` and `networkType`; OpenNOW deliberately omits all three (test `session_metadata_contains_only_owned_values` in `cloudmatch.rs`). Their server-side effect is **U**.
