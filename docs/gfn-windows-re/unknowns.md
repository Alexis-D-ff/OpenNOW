# Unknowns and follow-up work

**U** means unresolved, not unsupported. Most of these gaps come from one missing file: `Bifrost2.dll` from the same 2.0.89.141 install would settle the majority of the protocol rows by direct decompilation. The rest need a log from a kind of session that is not in the upload. No probe below was performed.

## Missing artifacts and sessions

| Question | Current boundary | What would resolve it |
| --- | --- | --- |
| What are the Windows NVST wire layouts: NACK v2 (0x317), invalidation (0x301), IDR (0x302), GS frame header, Mjolnir FEC, ping payload, input events, haptics, cursor messages? | `Bifrost2.dll` was not supplied. Layouts exist only from macOS Bifrost (PR #1161). | `Bifrost2.dll` from this install, diffed against the macOS functions. |
| Did the Windows client ever send 0x301 or 0x302? | No log line prints a control command code. Losses in the logs were small and all NACK-repaired. | `Bifrost2.dll`, or a log from a session with injected loss. |
| How do alliance-partner sessions differ: endpoints, usage 2/16/17, unified socket, server type, auth, `partnerCustomData`? | Every logged session is an NVIDIA (NIMBUS) seat. PR #1162's alliance branch cannot be tested. | One Windows log from a partner seat. |
| Which server type do partner seats use, and how does Bifrost number non-NIMBUS types? | Only `Converted Nvb server type 0 to nvsc Server type 2` is logged. | A partner-seat log line, or `Bifrost2.dll`. |
| What does an HDR session do end to end: PQ swap chain, HDR metadata upstream, overlay brightness? | No session in the logs used HDR (`pq = 0` everywhere). | A `geronimo.log` from an HDR session (`createDx11SwapChain ... pq = 1`). |
| What happened in sessions S1 to S4? | Geronimo log rotation removed their Bifrost lines. Only IPC and JS events remain. | Logs copied right after each session. |
| What do resumable drops look like inside Bifrost? | Reason 55 / `0x80040010` has no `NVST_DISCONN_*` name; both auto-resumes failed with `0xC2EC1025`. Setup failure `0xC0F52159` has no readable meaning. | A `geronimo.log` covering such a drop, or `Bifrost2.dll` enum tables. |

## Protocol details

- **U.** The ANNOUNCE body. Bifrost logs only `Successfully appended 163 NvscClientConfig attributes to SDP` and the three skipped V1 ICE/DTLS fields. The 975-key config dump is a proxy, not the wire set. So it is unknown whether Windows sends `video[0].refPicInvalidation`, the V2 ICE/DTLS fields, or the five values that differ from OpenNOW.
- **U.** The baseline DESCRIBE. The server SDP was 219,292 bytes with 4,145 attributes, but Bifrost printed only 62 "new features" lines.
- **U.** The full `NVB_PU_*` enum. Only `NVB_PU_RTSPS = 14` is log-confirmed; usage 10 appears only on `sessionControlInfo`. Geronimo's own usage map in `Nsk::getStreamStartParameters` (`0x18012af30`) has no caller on this path, and its internal values 1-8 are unnamed.
- **U.** Why the SETUP response lists `X-GS-ServerPort=5004-5005` when both sockets used 5004, and whether the second RTSPS port (48322) is a fallback.
- **U.** Meanings of `general.featureFlags 183`, `general.useReliableUdp 10`, `general.rtspScheme 3`, and the `Unified socket RiverMax: PIPELINE_RTC_TRANSPORT_READY` line printed while unified mode was off.
- **U.** DTLS peer verification on Windows. macOS checks the expected fingerprint; the Windows logs show only a successful 14 ms handshake.
- **U.** The wire effect of `nvbPauseSession` and `nvbResumeSession`. Neither appears in the logs.
- **I.** NACK deactivation during high RTD (`Deactivating Rtp Nack frameNumber`) is read as RTD-driven policy because `useRtdForRtpNackToggle` is 1. The trigger was not traced.
- **I.** HTTP methods for `/v2/session` (POST to create, GET to poll) are inferred from the REST shape. CloudMatch request header names are not logged.

## Geronimo internals not fully traced

- **U.** Names of `NvstVideoFrameState_t` values 9 and 13, and confirmation of the inferred names for 1, 2, 4, 7 and 8.
- **U.** The undecodable-frame threshold at `GeronimoIOInterface+0x6ac` and the per-stream flag at `+0xe0` set by a flush.
- **U.** The real caller of `IOInterface::updateVideoDecoderState` (`0x1800d0f90`).
- **U.** The three per-codec entries the selector writes at `NVbVideoSettings_t+0x6c/+0xb0/+0xf4` and their per-entry GRC byte. They may be a server-side codec fallback list or recording targets. What "GRC" stands for is also unknown; static evidence ties it to client-side H.264 re-encode.
- **U.** Where Windows gates an HDR request on display capability. The selector `FUN_180157f20` never reads the display's HDR state.
- **U.** How NVST's `video[0].chromaFormat 1` relates to Geronimo's chroma 3 for the same 4:4:4 stream. The two layers use different enums.
- **U.** Which YUV-to-RGB coefficient table the D3D11 shader path selects per frame, whether chroma siting is honored, and whether 8-bit output is dithered.
- **U.** EOS handling and decoder drain (no EOS string in Geronimo), runtime decoder fallback after a creation failure, and GPU device-removed recovery.
- **U.** The definition of `Total missed Vsyncs` and whether `GetFrameStatistics` drives pacing.
- **U.** `FUN_18015ad40` and `FUN_18015afa0` are read as AV1 resolution and AV1 HDR gates from their call sites only.
- **U.** Feature-control type numbers 0, 6, 8 and 13. Type 10 is mouse settings, 0xc vsync interval, 0xf dynamic streaming mode, 0x16 prefilter, 0x17 HUD. Type 0 as "server cursor compositing" is an inference from its timing.
- **U.** The mouse frequency cap value and `InputAggregator` batching; the Unicode/IME input event type; horizontal-wheel handling; touch forwarding.

## Input, audio and app layer

- **U.** The key-code space on the wire. Geronimo maps SDL scancodes to a GFN code space (letters as ASCII, Return 0x104, F1 0x400). OpenNOW sends Windows virtual keys and works. Whether Bifrost translates is unknown.
- **U.** Which input event fails with `NVST_R_GENERIC_ERROR (0x800b0000)`.
- **U.** The JSON schema of the `PASTE` clipboard payload and `CLIENT_DATA_RESPONSE`, and the content of about 9,700 `NvExtendedCommandMessage` messages to recipient `Serenity` (strings tie Serenity to local recording).
- **U.** The full mic-state enum (only 2 and 3 were seen) and multichannel playback (both sessions were stereo).
- **U.** Full message-bus schemas beyond the streaming events, payload events and heartbeat.
- **I.** Why `GeForceNOWStreamer.exe` exists. It never appears in the logs; shortcuts, deep links and the updater are plausible callers.

## Safe follow-up

If runtime evidence is needed, use an authorized account and change one condition per session: HDR display on, an alliance seat, injected packet loss, a resumed session, a multichannel audio device. Copy `geronimo.log` right after each session, because rotation keeps only about two sessions. Redact identifiers before sharing.
