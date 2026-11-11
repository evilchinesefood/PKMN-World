#!/usr/bin/env python3
"""Exercise native-runner failure and isolation behavior with an emulator double."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
INHERITED = ("PW_SAVE", "PW_LOSE", "PW_TO", "PW_FROM", "PW_NATURAL",
             "PW_CAMPAIGN", "PW_NO_RETRY")
EMULATOR = '''#!/usr/bin/env python3
import os
from pathlib import Path
import signal
import sys
import time

if "--version" in sys.argv:
    print("native-runner emulator double")
    sys.exit(0)
mode = os.environ.get("FAKE_MODE", "good")
if mode == "timeout":
    time.sleep(30)
if mode == "none":
    sys.exit(0)
if mode == "crash":
    os.kill(os.getpid(), signal.SIGTERM)
if mode == "env":
    for key in ("PW_SAVE", "PW_LOSE", "PW_TO", "PW_FROM", "PW_NATURAL",
                "PW_CAMPAIGN", "PW_NO_RETRY"):
        if key in os.environ:
            sys.exit("inherited selector: " + key)
out = Path(os.environ["PW_OUT"])
name = "Wrong" if mode == "wrongname" else "SmokeBoot"
rom = "0" * 32 if mode == "wronghash" else os.environ["PW_ROM_HASH"]
count = "0/0" if mode == "zero" else "1/2" if mode == "partial" else "2/2"
(out / (name + ".PASS")).write_text(
    f"PASS {count} rom={rom} at=2020-01-01T00:00:00Z suite={name}\\n")
if mode == "fail":
    (out / "SmokeBoot.FAIL").write_text("FAIL")
if mode == "nonzero":
    sys.exit(7)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "pokemonworld.gba")
    parser.add_argument("--elf", type=Path)
    parser.add_argument("--out", type=Path, default=ROOT / "_pwtest")
    args = parser.parse_args()
    rom = args.rom.resolve()
    elf = (args.elf or rom.with_suffix(".elf")).resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    out = Path(tempfile.mkdtemp(prefix="runner-contract-", dir=args.out.resolve()))
    print(f"Boundary test evidence: {out}", flush=True)
    fake = out / "fake-mgba"
    fake.write_text(EMULATOR)
    fake.chmod(0o755)
    bundle = out / "bundle"
    subprocess.run([sys.executable, str(HERE / "NativeRunner.py"), "bundle",
                    "--rom", str(rom), "--elf", str(elf), "--out", str(bundle)],
                   check=True)
    shared = out / "shared"
    records = []

    def run(label, mode, expected, *, extra=(), bundled=True, selected_rom=rom,
            reason=None):
        env = os.environ.copy()
        env.update(MGBA_HEADLESS=str(fake), FAKE_MODE=mode)
        env.update({key: "INHERITED_BAD_VALUE" for key in INHERITED})
        command = [str(HERE / "mgba-run.sh"), str(HERE / "lua/SmokeBoot.lua"),
                   str(selected_rom), *extra, "--out", str(shared), "--timeout",
                   "1" if mode == "timeout" else "10"]
        command += (["--bundle", str(bundle)] if bundled else ["--elf", str(elf)])
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                text=True)
        output = result.stdout + result.stderr
        ok = (result.returncode == 0) == expected
        if reason:
            ok = ok and reason in output
        record = {"case": label, "expected_pass": expected,
                  "returncode": result.returncode, "ok": ok, "output": output}
        print(f"{'PASS' if ok else 'FAIL'} {label} rc={result.returncode}", flush=True)
        return record

    for mode in ("none", "wrongname", "wronghash", "zero", "partial", "fail",
                 "nonzero", "timeout", "crash"):
        records.append(run(mode, mode, False))
    records.append(run("inherited-selectors", "env", True))
    stale = shared / "SmokeBoot.PASS"
    stale.write_text("STALE SENTINEL MUST SURVIVE")
    record = run("stale-sibling", "none", False)
    record["ok"] = record["ok"] and stale.read_text() == "STALE SENTINEL MUST SURVIVE"
    records.append(record)
    with ThreadPoolExecutor(max_workers=2) as pool:
        records.extend(pool.map(lambda n: run(f"concurrent-{n}", "good", True),
                                range(2)))
    records.append(run("missing-fixture", "good", False,
                       extra=(str(out / "missing.srm"),)))
    corrupt = out / "corrupt.srm"
    corrupt.write_bytes(bytes(131072))
    records.append(run("corrupt-fixture", "good", False, extra=(str(corrupt),)))
    wrong_rom = out / "wrong.gba"
    data = bytearray(rom.read_bytes())
    data[1024] ^= 1
    wrong_rom.write_bytes(data)
    records.append(run("wrong-rom-elf-pair", "good", False, bundled=False,
                       selected_rom=wrong_rom, reason="ROM/ELF mismatch"))
    wrong_symbols = out / "wrong-symbols.lua"
    text, count = re.subn(r"(gMain\s*=\s*)0x[0-9a-fA-F]+", r"\g<1>0x00000000",
                         (bundle / "symbols.lua").read_text(), count=1)
    if count != 1:
        raise ValueError("generated symbols did not contain gMain")
    wrong_symbols.write_text(text)
    records.append(run("wrong-symbols", "good", False, bundled=False,
                       extra=("--symbols", str(wrong_symbols)),
                       reason="symbols do not match"))
    records.append(run("wrong-rom-with-bundle", "good", False,
                       selected_rom=wrong_rom, reason="ROM does not match"))
    records.append(run("wrong-elf-with-bundle", "good", False,
                       extra=("--elf", str(wrong_rom)), reason="ELF does not match"))
    records.append(run("wrong-symbols-with-bundle", "good", False,
                       extra=("--symbols", str(wrong_symbols)), reason="symbols do not match"))
    trailer = out / "trailer.srm"
    trailer.write_bytes((HERE / "lua/fixtures/v3.srm").read_bytes() + b"trailer")
    records.append(run("unsupported-fixture-trailer", "good", False,
                       extra=(str(trailer),), reason="raw"))
    legacy = HERE / "lua/fixtures/v3.srm"
    records.append(run("historical-refusal-fixture", "good", True, extra=(str(legacy),)))
    bad_legacy = out / "changed-v3.srm"
    historical = bytearray(legacy.read_bytes()); historical[100] ^= 1
    bad_legacy.write_bytes(historical)
    records.append(run("corrupt-historical-fixture", "good", False, extra=(str(bad_legacy),)))
    directories = [re.search(r"^case-dir: (.+)$", r["output"], re.MULTILINE)
                   for r in records]
    unique = all(directories) and len({m[1] for m in directories}) == len(records)
    records.append({"case": "exclusive-case-directories", "ok": unique})
    (out / "results.json").write_text(json.dumps(records, indent=2) + "\n")
    failures = [r["case"] for r in records if not r["ok"]]
    print(f"Boundary checks: {len(records) - len(failures)}/{len(records)} passed")
    print("These checks use an emulator double. They are not gameplay evidence.")
    if failures:
        print("Failed: " + ", ".join(failures), file=sys.stderr)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
