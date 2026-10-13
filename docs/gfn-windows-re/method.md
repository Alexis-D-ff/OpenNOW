# Method and reproduction

## Scope and constraints

- **Inputs.** One Windows install subset and its logs, uploaded as `GFN.zip` (SHA-256 `73d96b78930a8b88eb18580c11bd1fbcbd5ab323b0ec56b35002ad861a10dc95`). [artifacts.md](artifacts.md) lists every file and hash.
- **No execution.** No GFN binary was run. Linux cannot run them, and running them was out of scope.
- **No network contact.** No NVIDIA or GFN server was contacted and no login was attempted. Every runtime fact comes from logs the user produced on their own machine.
- **No secrets.** Quoted log lines are short and have IPs, session and request IDs, device hashes, keys, ICE and DTLS material, account data, the Windows user name and the user's age replaced with `<redacted>`. Seat hostnames that embed an IP are written `<redacted-ip>.cloudmatchbeta.nvidiagrid.net`. Zone names such as `eu-netherlands-north` and `np-ams-08` are kept because they identify a public region, not a person.

## Tools

| Tool | Use |
| --- | --- |
| Ghidra 12.1.4 headless (`analyzeHeadless`) | Full auto-analysis of `Geronimo.dll` (about 11 minutes, 10 GB heap). Smaller binaries (`GeForceNOW.exe`, `GeForceNOWStreamer.exe`, `GsAudioWebRTC.dll`, `NvPixels.dll`, the NvContainer plugins) were analyzed in separate projects. Decompilation used small Java GhidraScripts that select functions by string reference or address and write pseudocode to scratch files. |
| `pefile`, `capstone` (Python, via `uv`) | Version resources, imports, exports, PDB paths, string-to-code cross-references (RIP-relative `lea`), jump tables and vtable slots. |
| `strings`, `objdump` | Quick string and section census. |
| `tools/*.py` in this folder | Log extraction, redaction, catalogs and the OpenNOW key comparison. See below. |

No REA MCP was available for this study, unlike the macOS study. Evidence therefore cites function VAs from the Ghidra project instead of REA evidence IDs.

## How claims were established

1. **Inventory.** Hash every file, read its version resource, imports and exports. This established that `Bifrost2.dll` is missing and that Geronimo calls it through 31 `nvb*` imports.
2. **Static anchors.** For each topic, find the log or format strings in the binary, follow references to the functions that use them, and decompile those functions. Function names come from exports, RTTI and log strings. Unnamed functions keep Ghidra's `FUN_<VA>` name.
3. **Log confirmation.** Parse the logs into sessions and events, then check each static path against what a real session did. Bifrost's own log lines in `geronimo.log` (`[NVST:*]`, `[BifrostClient: *]`) stand in for the missing DLL.
4. **macOS cross-check.** Compare each finding with `docs/gfn-macos-re/` from PR #1161. Facts that exist only on macOS are labelled "macOS Bifrost (PR #1161)".
5. **OpenNOW comparison.** Read the corresponding OpenNOW code on `dev` at `7ce3cd54` and record differences in [opennow-gaps.md](opennow-gaps.md).

The work ran as four parallel investigations (logs; video and color; architecture, audio and input; protocol, providers and configuration), each with its own decision log. One reviewer reconciled them. Reconciliation re-decompiled the codec selector to confirm both PR #1165 contradictions, corrected the SCTP channel labels against the log, normalized all times to local time, and rechecked the OpenNOW file pointers after #1162, #1164 and #1165 merged. [decisions.tsv](decisions.tsv) records each judgment call (`REC-*` rows for reconciliation).

## Reproducing the generated files

The scripts in [tools/](tools/) need Python 3 and, for `config_catalog.py`, `pefile` and `capstone`. They read the unzipped upload and never contact the network.

```sh
cd docs/gfn-windows-re/tools
python3 extract.py --src /path/to/unzipped/GFN      # writes redacted intermediates to tools/extracted/ (do not commit)
python3 compare_opennow.py --opennow /path/to/opennow
python3 render.py                                    # fills the generated tables in ../cloudmatch-fields.md and ../sdp-attributes.md
GFN_DIR=/path/to/unzipped/GFN python3 config_catalog.py   # rewrites ../configuration-fields.md and ../nvsc-client-config.tsv
```

On this upload the four generated files come out identical to the committed versions. The OpenNOW line numbers in `sdp-attributes.md` follow the checkout passed to `compare_opennow.py`.

`tools/extracted/` holds redacted log excerpts. It is excluded from the repository because the study commits no raw logs.

To repeat a decompilation, import the binary into Ghidra 12.1.4, run auto-analysis, and open the function at the cited VA. Keep the Ghidra project outside any directory whose name starts with a dot; Ghidra rejects such project paths.

## Leak scan

Before committing, the folder was scanned for IPv4 addresses, UUIDs, `eyJ` (JWT), `HMAC:` followed by key material, email addresses, the Windows user name, `C:\Users\` paths, MAC addresses and long base64 runs. The only matches are documented placeholders such as `<redacted>`, `<redacted-ip>` and public constants (DXVA GUID prefixes, version numbers).

## Limits

- Pseudocode is not source. Struct offsets and enum meanings are recovered layout, not a public ABI.
- A static path proves that the client can take a branch, not that a session did. A log line proves what one session did, not the default for every session.
- Findings are specific to 2.0.89.141 on one machine (NVIDIA RTX GPU, 165 Hz SDR display, wired Ethernet, NVIDIA seats in one zone).
