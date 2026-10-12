# DroidDeck hardware decoding

The experimental `mediacodec` backend uses Android's hardware H.264 decoder through a modified DroidDeck session. It copies decoded NV12 pixels into OpenNOW's existing native Vulkan uploader and Qt stream view. It is not zero-copy. Normal Linux backend selection is unchanged.

## Enable the experiment

Install a DroidDeck build with the MediaCodec bridge, create `/sdcard/droiddeck-enable-mediacodec`, then restart its Linux session. The session publishes `OPENNOW_MEDIACODEC_SOCKET`; do not substitute a guessed socket path.

Launch the matching native ARM64 OpenNOW build from the guest terminal:

```sh
OPENNOW_NATIVE_VIDEO_BACKEND=mediacodec /path/to/OpenNOW.AppImage
```

In Stream settings, keep the video backend on Auto, select H.264 and 8-bit 4:2:0, and turn HDR off. The explicit environment override selects the bridge. Start at 1280x720 at 60 fps. The implementation rejects dimensions above 2560x1440, other codecs, HDR, 10-bit and 4:4:4. This bound is not a throughput guarantee.

The bridge requires Android 10 or later and a codec reported as hardware accelerated, not software-only, with readable flexible-YUV output. A capability probe checks the Android component; opening and decoding validate the actual stream. Missing sockets, unsupported output, protocol errors and failed recovery produce errors rather than selecting a software decoder.

Remove the experiment marker and restart DroidDeck to disable its listener. Launch OpenNOW without the override to return to normal backend selection.

## Verify on the device

From an OpenNOW source checkout inside the Linux guest, with Cargo and FFmpeg installed, run:

```sh
bash scripts/check-mediacodec-bridge.sh "$OPENNOW_MEDIACODEC_SOCKET"
```

The script generates a known black 720p H.264 access unit. The native example opens only MediaCodec, checks the original timestamp and NV12 pixels, closes the decoder, then repeats with a fresh decoder. A successful check proves hardware-component selection, guest socket access, pixel transfer and acknowledged release. It does not prove gameplay, zero-copy or sustained performance. Check the Android codec name in DroidDeck's diagnostics to corroborate the selected hardware component.

Next, test an actual stream for at least 15 minutes at the required resolution and rate. Compare decoder residence, CPU use, thermal behavior, frame drops and memory against the previous software path. At 1440p60, packed NV12 alone carries about 332 MB/s before extra copies and GPU upload.

Keep the same stream running while testing windowed and fullscreen modes, resizing, F3 statistics, Ctrl+G, exit-confirmation open/dismiss, and graphics-surface recreation. Check bridge disconnect/restart and reconnect recovery separately. No hardware, performance or Qt interaction result is implied by compilation or the JVM interoperability fixture.

## Protocol and ownership

DroidDeck owns the Android codec, Image layout normalization and its session-private listener. OpenNOW's native decode worker owns the bounded socket exchanges, pending sender timestamps and keyframe recovery. Qt keeps its existing presenter and stream overlays. No Android handles cross the Qt FFI.

The version-one protocol is documented in the DroidDeck fork's `docs/development/opennow-mediacodec.md`. Requests and replies are bounded and sequential, so compressed input and decoded output cannot deadlock by writing simultaneously. The decoder is released and acknowledged before replacement, including queue discontinuities and stream reconfiguration.

Zero-copy decoding would additionally require verified codec YUV allocation export, Linux-driver import and acquire/release fencing on the physical device. It is not implemented by this compatibility backend.
