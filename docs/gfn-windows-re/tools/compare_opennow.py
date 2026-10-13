#!/usr/bin/env python3
"""Compare the x-nv key sets seen in the Windows logs with OpenNOW's RTSP builders.

Usage: compare_opennow.py [--opennow /workspace/opennow] [--extracted DIR]
Reads extracted/sdp_server_xnv.tsv and extracted/nvsc_config.tsv (written by extract.py) and greps
OpenNOW's native/opennow-streamer sources for a=x-nv-* literals. Writes extracted/xnv_compare.tsv.
"""
import argparse
import os
import re

ap = argparse.ArgumentParser()
ap.add_argument("--opennow", default="/workspace/opennow")
ap.add_argument("--extracted", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "extracted"))
a = ap.parse_args()

server = {}
for ln in open(os.path.join(a.extracted, "sdp_server_xnv.tsv"), encoding="utf-8").read().splitlines()[1:]:
    parts = ln.split("\t")
    if len(parts) == 4 and parts[2].startswith("x-nv-"):
        server[parts[2][5:]] = parts[3]

config = {}
for ln in open(os.path.join(a.extracted, "nvsc_config.tsv"), encoding="utf-8").read().splitlines()[1:]:
    k, _, v = ln.partition("\t")
    config[k] = " | ".join(x.split("=", 1)[1] for x in v.split(" | ") if "=" in x)

opennow = {}
root = os.path.join(a.opennow, "native/opennow-streamer/crates/opennow-streamer-core/src")
rx = re.compile(r"a=x-nv-([A-Za-z0-9_\[\]\.]+):([^\"{}]*)")
for dirpath, _, files in os.walk(root):
    for f in files:
        if not f.endswith(".rs") or f.endswith("_tests.rs") or f == "tests.rs":
            continue
        rel = os.path.relpath(os.path.join(dirpath, f), a.opennow)
        for n, line in enumerate(open(os.path.join(dirpath, f), encoding="utf-8"), 1):
            if "\\r\\n" in line:
                continue
            for m in rx.finditer(line):
                opennow.setdefault(m.group(1), (m.group(2).strip() or "{fmt}", f"{rel}:{n}"))

keys = sorted(set(server) | set(opennow) | {k for k in config if k in server or k in opennow})
out = ["key\twin_server_DESCRIBE\twin_final_NvscClientConfig\topennow_literal\topennow_source"]
for k in sorted(set(server) | set(opennow)):
    ov = opennow.get(k, ("", ""))
    out.append(f"{k}\t{server.get(k, '')}\t{config.get(k, '(not dumped)')}\t{ov[0]}\t{ov[1]}")
open(os.path.join(a.extracted, "xnv_compare.tsv"), "w", encoding="utf-8").write("\n".join(out) + "\n")
only_server = sorted(set(server) - set(opennow))
only_opennow = sorted(set(opennow) - set(server))
print(f"server DESCRIBE keys {len(server)}, OpenNOW literal keys {len(opennow)}, NvscClientConfig keys {len(config)}")
print(f"server-only (OpenNOW never writes): {len(only_server)}; OpenNOW-only (not in logged server section): {len(only_opennow)}")
print(f"OpenNOW keys absent from the Windows final config dump: {sorted(k for k in opennow if k not in config)}")
