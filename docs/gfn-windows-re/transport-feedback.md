# Transport and feedback on Windows (GFN 2.0.89.141)

Bifrost2.dll was not supplied, so no wire byte layout below is Windows-derived. Windows evidence is (a) Bifrost log lines in `geronimo.log(.bak)`, (b) the 973-row effective `NvscClientConfig` dump in the same log (`nvsc_client_config.tsv`), and (c) Geronimo's calls into the `nvb*` API. Byte layouts are quoted from macOS Bifrost (PR #1161) and marked so.

Tags: **S** static, **D** decompiled (Geronimo.dll base 0x180000000), **L** log (file, local UTC+2 time), **I** inferred, **U** unknown. Log times are from `geronimo.log.bak` unless stated: S5 ended 2026-10-12 19:33:41 by idle timeout, S6 started 19:45:11.

## 1. What "Mjolnir" means in Geronimo.dll

All 21 `Mjolnir` strings in Geronimo.dll are vcpkg build paths (a vcpkg tree named Mjolnir that built gRPC and OpenSSL). Geronimo has no Mjolnir packetizer, FEC or frame-header code (**S**). The only Mjolnir behaviour visible on Windows is Bifrost's log line `Bypassing 'Mjolnir' SETUP for the Audio stream. Deferring to WebRtcTransport setup` (and the same for Mic, 19:45:30.654, **L**) and the config key `general.mjolnirVideoReceiverDequeueTimeoutMs` = 8 (**L**). That 8 ms value matches the 8 ms queue-insert deadline that macOS Bifrost (PR #1161) recovered in `MjolnirVideoReceiver`.

Geronimo uses gRPC only to export OpenTelemetry data. The method paths in Geronimo.dll are `/opentelemetry.proto.collector.logs.v1.LogsService/Export`, `/opentelemetry.proto.collector.trace.v1.TraceService/Export` and `/opentelemetry.proto.collector.metrics.v1.MetricsService/Export`. The other paths (`/grpc.gcp.HandshakerService/DoHandshake`, `/grpc.health.v1.Health/Watch`, `/grpc.lb.v1.LoadBalancer/BalanceLoad`, `/grpc.lookup.v1.RouteLookupService/RouteLookup`) are gRPC-core internals (**S**). A `TracingDispatcher` class and `registerTracingCallbacks` (0x18036ad00) feed that exporter (**S/D**). No streaming data goes over gRPC.

## 2. Socket layout seen in S6

| Purpose | Client side | Server side | Evidence |
|---|---|---|---|
| RTSPS/WSS signaling | ephemeral | 322, later 48322 | `WSS Options ... :322`; `Signaling Server Ip ... :48322` (**L**) |
| Video RTP (dedicated, legacy) | 49005 | 5004 (`X-GS-ServerPort=5004-5005`) | `UDP RTP Source: bound to <redacted-ip>:49005` (**L**) |
| Native bundle (ICE/DTLS/SCTP, audio, mic) | 49006 (`clientBundlePort`) | `serverBundlePort` 47999 in config; NAT pings go to :5004 | `Client early ICE socket bound to port 49006`; NattHolePunch lines (**L**) |
| DESCRIBE `general.serverEndpoints` | — | RTSP 322, control 47995, UDP control 47999, audio 48000, input 47995, bundle 48001, video 47998/48005/... | 19:45:31.258 (**L**) |

Config (**L**): `enableUnifiedSocket` 0, `clientPorts.bundle` 0, `clientBundlePortUsage` 0, `nativeRtcOnBundlePort` 1, `rtcDataChannelOnNativeBundle` 1, `rtcAudioOnNativeBundle` 1, `rtcMicOnNativeBundle` 1, `rtcVideoOnNativeBundle` 0, `rtcpOnSctp` 1. The client logs `Unified socket mode disabled (enableUnifiedSocket=0, using legacy dedicated sockets)` (19:45:31.364). It also prints `Unified socket RiverMax: PIPELINE_RTC_TRANSPORT_READY published; ClientControl may start (deferred offload allowed)` (19:45:31.337) even with unified mode off, so that line is a pipeline-ready event rather than proof of unified mode (**I**).

So on an NVIDIA (NIMBUS) seat, Windows ran two sockets: a dedicated video socket and a bundle socket that carries audio, mic, data channels and RTCP over SCTP.

## 3. NAT hole punch and pings

- `Set ping-version: 6`, matching SETUP response `x-nv-ping: 6` and config `general.pingVersion` 6 (**L**).
- `Send src ping version 6 on port 49006 to dest <redacted-ip>:5004: Success` (30×) and from port 49005 (10×); then `Setting <redacted-ip>:5004 as valid destination` (19:45:31.323) (**L**).
- Ping cadence config: `pingIntervalBeforeConnectionMs` 20, `pingIntervalAfterConnectionMs` 100, `candidateAttemptTimeoutMs` 0, `webSocketPingThrottleEnabled` 0 (**L**). The ping payload format is **U** on Windows (the SETUP response carries an opaque `X-Nv-Ping-Payload`, value redacted).

## 4. Control channel, data channels, input

- Control protocol: offered udp, udp_ag, tcp, udp_enc, udp_ag_enc, tcp_enc, channel_encrypt; picked `udp_ag (2) - not encrypted`, control id `streamid=control/10` (19:45:30.643, **L**). `Instanstiated ServerControlReliableUdpAggregated` (`ServerControlRUA`, 19:45:31.337). `general.useReliableUdp` 10 (**L**). "Not encrypted" refers to the control framing; the transport underneath is the DTLS bundle (**I**).
- SCTP data channels: Bifrost logs `Channel <label> is created with stream-id: <n>` for six channels, and each gets `Received explicit creation acknowledgment` (19:45:31.360-.362, **L**): 0 `control_channel_reliable`, 2 `custom_message_on_sctp_private_reliable`, 4 `custom_message_on_sctp_private_partially_reliable`, 6 `control_channel_partially_reliable`, 8 `control_channel_unreliable`, 10 `input_channel_partially_reliable`. The input channel is created with `config.maxRetransmitTime = 300` (**L**).
- SCTP stats at teardown, e.g. `totalReliableTxAttempts 99 totalPartialReliableTxAttempts 1798 totalReliableTxTimedOut 0 ... roundTripTimeMs 10` (**L**).
- Teardown always logs `ServerControlReliableUdp Unable to send command packet` (10× per session, within ~0.2 s after termination) and `killConnection() last sent: 0.04, last recved: 0.86` (**L**). These are post-termination sends, not mid-session loss (**I**).
- Input: Geronimo `sendNvstInputEvent` 0x1800d2eb0 → `nvbSendInputEvent` (**D**). `sendHeartbeatEvent` 0x1800d0470 builds an input event of type 0xa (**D**). Partially reliable input config: `ri.partialReliableThresholdMs`, `ri.hidDeviceMask` (value redacted) (**L**).
- Custom messages: `sendCustomMessage` 0x1800e62f0 drops messages before `onStreamingReady` and queues them before `onUpstreamReady` (**D**); `BifrostSDKExecutor::sendCustomMessage` 0x1800d25d0 → `nvbSendMessage`. Logged targets: `NvExtendedCommandMessage` → Serenity (9668×), `PASTE` and `SESSION_LENGTH_TIMER` → `GFN_CLIENT_UI` (**L**). Server SDP enables `general.customMessageOnCC` 1 (**L**).
- Server-to-client control notices (`[NVST:ServerControl]`, 348 lines): system cursor info (`Server sent system cursor info with ID: N (x,y)`), `Gamepad handling notification (RS = 0/1)`, timer and termination notices (section 8) (**L**).

## 5. NACK (retransmission)

Windows evidence that the v2 NACK path is active:

- Config: `video[0].enableRtpNack` 1, `rtpNackVersion` 2, `rtpNackMaxPacketCount` 64, `rtpNackMaxRetries` 3, `rtpNackBackoffTimeMs` 4, `rtpNackInitialWaitTimeMs` 1, `rtpNackQueueLength` 2048, `rtpNackQueueMaxPackets` 1024, `useRtdForRtpNackToggle` 1, `nackHysteresisLengthUs` 4000, `nackDjbLengthMultiplyFactorx100` 100, `rtpNackDjbInteractionMode` 0 (**L**).
- `[NVST:RtpSourceQueueExtV2] NACK waiting queue limit time: 52 ms, waiting queue packets limit count: 1024, NACK request backoff time: 4 ms, NACK request initial send delay: 1 ms, max allowed NACK retries: 3` and `[NVST:NackTracker] Max allowed pending NACKS: 2048 ... max packet wait time: 52.0, extra wait time before sending NACK retry: 4.0` (19:45:31.363, **L**). `RtpSourceQueueExtV2` is the class that macOS Bifrost (PR #1161) shows building the version-2 payload.
- Results: `RTP NACK Stats: numNackRequest=16, numNackedPacketsRequested=46, numNackedPacketsReceived=46, numNackedPacketsUtilized=14, numNackedPacketsRetried=6` (19:33:41) and `numNackRequest=3 ... Requested=8, Received=8, Utilized=4, Retried=0` (**L**). `Deactivating Rtp Nack frameNumber:125259` also appears (**L**).

Command `0x317` and the 3 + 10·n payload come from macOS Bifrost (PR #1161) only; no Windows log prints a command code. The video stream here uses the dedicated socket, so on Windows the NACK travels on the control path selected in §4, not as RTCP Generic NACK (**I**, consistent with OpenNOW `docs/mjolnir-nack-v2.md`).

## 6. Reference-frame invalidation (0x301), IDR (0x302), recovery mode

- Config: `video[0].refPicInvalidation` 1, `framesWithInvalidRefThreshold` 4, `streamRecoveryType` 2, `general.enableRecoveryMode` 1, `recoveryModeTriggerThresholdMs` 6000, `enableIntraRefreshInRecoveryMode` 1, `triggerIdrOnAllStreams` 0, `forcedPeriodicSettings.frameInvalidationInterval` 0, `invalidationFrameRange` 0, `dumpDroppedFramesDueToInvalidation` 1 (**L**).
- `[NVST:NvscClientConfigDefaults] Client requests display freeze on Invalidated Reference Frames` (19:45:30.643, **L**). The Windows client withholds frames that may reference lost data instead of showing them.
- No log line shows an invalidation or IDR request being sent, and no `IDR`/`RFI` string appears in either log. Command values 0x301 (24-byte payload) and 0x302 (2-byte payload) are macOS Bifrost (PR #1161) only.
- Geronimo's own last resort: `GeronimoIOInterface::updateVideoFrameState` 0x1800e92a0 counts frames reported with state 4 (decode failure). When the count reaches the threshold at object offset +0x6ac it raises `0xc0f11002 GERONIMO_VIDEODECODER_UNRECOVERABLE_BITSTREAM` ("VideoDecoder repeatedly received undecodable video data.") once. State 2 resets the counter. Every state-4 report also calls the decode-queue flush at vtable slot +0xb0 (0x1800e1260) with its flag argument set to 1; that flag sets a per-stream byte at +0xe0 (meaning **U**). The flush logs `Stream[%u]: Performing a %s flush of %u frames.`: "complete" (code 5) when the queued count is at most the threshold at +0xf4 plus one, otherwise "partial" (code 6) (**D**).

## 7. What Geronimo reports back to Bifrost (frame acks and loss feedback, Windows-visible side)

All of these go through `BifrostSDKExecutor` (vtable 0x18141c1c0). Each wrapper passes the client handle (`this+0x50`), a session string (`this+0x10`), then the arguments, and logs `Error %s (%d)` through `nvbEnumToString` on failure (**D**).

| Executor method (slot) | Import | Arguments | Caller chain (D) |
|---|---|---|---|
| `updateVideoFrameState` 0x1800d42e0 (+0x60) | `nvbUpdateVideoFrameState` | stream id (u16), frame number (u32), `NvstVideoFrameState_t`, two u32 values, steady-clock time point | decoders → `GeronimoIOInterface` slot +0xb8 (0x1800e92a0) → executor +0x60 |
| `updateVideoDecoderState` 0x1800d4240 (+0x78) | `nvbUpdateVideoDecoderState` | stream id, u32, `NvstVideoDecoderState_t` | `IOInterface::updateVideoDecoderState` 0x1800d0f90 forwards to executor +0x78 |
| `setCurrentDJBConfig` 0x1800d3b40 (+0x80) | `nvbUpdateDJBState` | stream id, frame number, `NvstClientDJBConfig_t` | `VideoDecoderThread` 0x1801969c0 → `IOInterface::setCurrentDJBConfig` 0x1800d0840 → executor +0x80 |
| `configureStatistics` 0x1800d1c20 (+0xa8) | `nvbCollectStatistics` | `NVbStatisticsOption_t`, bool | stats options 1 and 2 appear in logs (**L**) |
| `sendBlobStats` 0x1800d2220 (+0xb0), `sendExtendedStats` 0x1800d2810 (+0xb8), `sendStreamDebugEvent` 0x1800d3050, `sendClientRoiDebuggingMarker` 0x1800d2450 | `nvbSendStreamStats` | typed stats blobs | `GeronimoStatsHandler` 0x1800eb840 (`No active session. Cannot send extended stats`) |

`NvstVideoFrameState_t` values that Geronimo sends (**D**; names are not in the binary, the meanings are **I** from the code path):

| Value | Sent from | Meaning (I) |
|---|---|---|
| 1 | `VideoDecoderThread` 0x1801969c0 when a decode unit for the expected stream is taken | frame received / handed to decoder |
| 2 | `DXVADecoder::decode` 0x1801f9320 after `setVideoDecodeUnit` succeeds, and for HEADER frames; MFT decoder 0x18021aad0 | decoded OK |
| 4 | DXVA parse failure (`0xc0f11034 GERONIMO_DXVADECODER_EXEC_PARSER`), `getDecodedFrame` failure (`0xc0f1103c`), `setVideoDecodeUnit` failure; MFT failure; wrong stream id (`Expecting decode unit for stream %u, received %u`) | decode failed |
| 7 | render path; with a non-zero 5th argument it feeds the render benchmark 0x1800e8570 (`Render benchmark completed. p95 GPU time %uus ...`) | rendered/presented, with GPU time |
| 8 | DXVA decode when the decoded frame is freed without rendering; `VideoDecoder::getNextFrame` 0x180194170 when dropping queued frames | dropped |
| 9 | updates a per-frame timestamp at +0x760 when the frame number changes | U |
| 13 (0xd) | MFT decoder 0x18021aad0 early path | U |

This is the Windows-visible half of frame acknowledgement: Geronimo reports per-frame decode/render outcomes with the sender's frame number and stream id. Bifrost turns them into wire feedback; that conversion is in Bifrost2.dll (**U**).

DJB (de-jitter buffer) config: `Sending DJB Config at frame %u. Mode: %s, reason: %s, minDepthUs: %u, maxDepthUs: %u`, modes 1 VVSYNC, 2 TIMESTAMP, 3 FIXED, reasons MODE/QOS; the server can request a change (`Received DJB Config request at frame %u. Force: %d, minDepthUs: %u`), delivered by `NskStreamClient` 0x180138d40 through `IOInterface::handleDJBConfigRequest` (+0x158) and read back by the decoder thread through `getCurrentDJBConfigRequest` (+0x150) (**D/S**).

Feature and client-info messages that also travel upstream (tags recovered from the r9 struct, **D**): `nvbFeatureControl` tags 10 (mouse settings), 0xc (vsync interval), 0xf (dynamic streaming mode), 0x16 (prefilter params, 0x1800d2f30), 0x17 (HUD streaming params); `nvbSendClientInfo` tags 0 window states, 1 system states, 2/3 G-SYNC info, 4 client OS, 5 network interface info. Full table: configuration-fields.md §6.

## 8. QoS, keepalive, idle timeout, termination, resume

- QoS versions from the server SDP: `QosFeedback version ... [7]`, `QosTimings version ... [5]`, `Blob stats version server: [9], client: [9], final: [9]`; client default `QOS_RL_FEEDBACK version to default [3]` (19:45:30.643, **L**). `ServerQosSessionComm QoS comm thread started`; `[BifrostClient: Streamer] Cancelling the QOS_POLLING_TASK task...` at teardown (**L**). `vqos[0].statsProcessorThread.flags` 1023 (server SDP) (**L**).
- Telemetry `Nvst_RealTimeMetrics` events carry `minNetworkLossScore`, `minLatencyScore`, `frameDropPercent`, `maxRoundTripDelayMs`, `avgNumTxPerReliableMsg`, ... (**L**). These go to telemetry, not to the server's rate control (**I**).
- L4S: request `enabledL4S` false; `video[0].l4sHandling.*` defaults present (version 1, `enableEcnFeedback` 0, `ecnFeedbackFrequencyMs` 25, ...) (**L**). Geronimo has `setL4sState` 0x1800d3d10 → `nvbFeatureControl` (**D**).
- Keepalive: no "keepalive" string in the logs. Related timers: `video[0].pingBackIntervalMs` 3000, `pingBackTimeoutMs` 10000, `timeoutLengthMs` 8000, `sendFrameTimeoutMs` 7000, `sendFirstFrameTimeoutMs` 50000 (**L**); Geronimo heartbeat input event type 0xa (§4).
- Idle timeout (S5): `Server sent a timer notification of type 4 with 60 seconds left for termination.` (19:32:41.257) → `NVB_SN_APPROACHING_IDLE_TIMEOUT`; `type 5 with 0 seconds left` (19:33:41.253); `Server sent termination notification NVST_DISCONN_SERVER_TERMINATED_CLOSED (0x80030023)` (19:33:41.365); `NVB_SN_EXITED_DUE_TO_USER_IDLE_TIMEOUT` (**L**). The CloudMatch response field `userIdleWarningTimeoutInMs` was 0 in S6 (**L**).
- Termination: `ExtendedTermination code:: SessionTerminationReason: 0x104, NvbSessionTerminationType: 56, ExitCode: 0x80030007` and `Resumable: 0, SessionAlive: 0 is sent for terminationReason:0x00000038 extendedCode:0x80030007` (19:33:41.380, **L**). debug.log also has a resumable case: reason 55 (0x37), code 0x80040010, alive 1, resumable 1 (**L**).
- Resumable rule, Geronimo 0x180142a70 (**D**): reason 0x37 is resumable unless the code is 0x80040003, 0x8004000b–0x8004000f or 0x80040011–0x80040016; reason 0x3b is resumable only for 0x80040004, 0x80040007, 0x80040010; every other reason is not resumable. `GridApp::handleNVbCallback` 0x1800c8180 routes event types 50–200 to termination handling and drops repeats (`Skipping duplicate streaming termination notification`); type 7 goes to router ping stats 0x1800e4ae0 (**D**).

## 9. Comparison with OpenNOW and PRs #1162 / #1164

| Topic | Windows evidence | OpenNOW (origin/dev 7ce3cd54) | Verdict |
|---|---|---|---|
| NACK timing | 52 ms wait, 4 ms backoff, 3 retries, 64 packets, RTT used (`useRtdForRtpNackToggle` 1), 1 ms initial delay | `nvst.rs`: `NACK_TRACKING_TIMEOUT` 52 ms, `NACK_RETRY_INTERVAL` 4 ms, `MAX_NACK_ATTEMPTS` 3; `nvst_control.rs` `MAX_NACK_PACKET_COUNT` 64; `docs/mjolnir-nack-v2.md` says retries use RTT + 4 ms and the official 1 ms initial delay is not implemented | Supports the constants. The 1 ms initial delay is the one Windows-visible difference. |
| PR #1162 unified socket / bundle | NIMBUS seat: `enableUnifiedSocket` 0, legacy dedicated video socket, audio/mic/data on bundle; connectionInfo had only usage 14 (no 2 or 17) | `nvst_rtsp.rs` reads `general.enableUnifiedSocket` from DESCRIBE; `cloudmatch.rs` picks media from usage 2/17 | Consistent with the non-alliance path. **Cannot test** the alliance branch: no partner session in the Windows logs. |
| PR #1164 RFI 0x301 | `refPicInvalidation` 1, "display freeze on Invalidated Reference Frames", recovery mode and intra-refresh enabled, IDR on all streams off | `nvst_invalidation.rs` sends 0x301, withholds dependent frames, resumes on I/intra-refresh/RefPicI, IDR backstop | Policy matches. Wire format **cannot be tested** on Windows (no Bifrost2.dll, no 0x301 log). OpenNOW does not put `video[0].refPicInvalidation` in its ANNOUNCE keys; whether the server needs it to emit RefPic-I frames is **U**. |
| Idle timeout | timer types 4 (60 s left) and 5 (0 s) on ServerControl, then 0x80030023 | no handler for server timer notifications found (`rg -i 'timer notification|idle'` in streamer crates) | Gap. |
| Resumable termination | Geronimo computes Resumable/SessionAlive from reason + code (0x180142a70) | `opennow-streamer-core/src/lib.rs` ~2359 sets `"resumable": null` | Gap. |
