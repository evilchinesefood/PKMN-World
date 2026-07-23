#!/usr/bin/env bash
# Regenerate the save-format migration fixtures under Testing/lua/fixtures/.
#
# For each historical SAVE_FORMAT_VERSION, this builds that commit in a throwaway git worktree,
# boots a fresh new-game in BizHawk, saves, and harvests the raw 131072-byte battery save as
# Testing/lua/fixtures/v<N>.srm. Those .srm files are the inputs to Testing/lua/MigrateFixtures.lua
# (which loads each under the CURRENT build so MigrateSaveFormatIfNeeded runs, then asserts a clean
# upgrade). Re-run this whenever the format is bumped, adding the new previous-version fixture.
#
# WSL + Windows BizHawk specific (this is where the project lives): it shells out to EmuHawk via
# cmd.exe. Toolchain: the modern user-space arm-none-eabi at ~/.local (see CLAUDE.md). The old
# commits build with the same toolchain (unchanged since the region-merge lane).
#
# Fixtures come from FRESH new-games only — no personal data, deterministic. Never commit a .srm
# harvested from a real playthrough.
set -euo pipefail

REPO="/mnt/c/Users/evilc/Github/PKMN-World"
REPO_WIN='C:\Users\evilc\Github\PKMN-World'
BIZHAWK="C:/Users/evilc/BizHawk"
BIZHAWK_WIN='C:\Users\evilc\BizHawk'
FIXDIR="$REPO/Testing/lua/fixtures"
HARVEST="$REPO/_pwtest/SaveHarvest.lua"   # gitignored scratch; the USM-wheel harvester (v2+)
export PATH="$HOME/.local/arm-none-eabi/usr/bin:$PATH"

# version -> introducing commit (git log -S 'SAVE_FORMAT_VERSION <n>' -- include/constants/global.h)
declare -A COMMIT=( [1]=37af5518 [2]=12e04c20 [3]=ee80c4d9 [4]=75ec2556 [5]=d949845a )

mkdir -p "$FIXDIR"

for V in "$@"; do
  C="${COMMIT[$V]:?unknown version $V}"
  WT="/tmp/pkmnworld-v$V"
  echo "== v$V ($C) =="
  [ -d "$WT" ] || git -C "$REPO" worktree add -f "$WT" "$C"
  ( cd "$WT" && make -j12 >/dev/null )

  # per-build boot addresses (they move every build) for the harvester's boot loop
  CB2=$(grep -E ' CB2_Overworld$' "$WT/pokemonworld.map" | awk '{print $1}')
  GMAIN=$(grep -E ' gMain$' "$WT/pokemonworld.map" | awk '{print $1}')
  SB1=$(grep -E ' gSaveBlock1Ptr$' "$WT/pokemonworld.map" | awk '{print $1}')
  SB2=$(grep -E ' gSaveBlock2Ptr$' "$WT/pokemonworld.map" | awk '{print $1}')
  GMAIN_CB2=$(printf '0x%08x' $(( GMAIN + 4 )))
  echo "  addrs CB2=$CB2 gMain.cb2=$GMAIN_CB2 SB1=$SB1 SB2=$SB2"

  # patch the harvester's address header for this build, stage an isolated ROM+blank-save pair
  sed -e "s/^local GMAIN_CB2 = .*/local GMAIN_CB2 = $GMAIN_CB2/" \
      -e "s/^local CB2_OW    = .*/local CB2_OW    = $CB2/" \
      -e "s/^local SB1_PTR   = .*/local SB1_PTR   = $SB1/" \
      -e "s/^local SB2_PTR   = .*/local SB2_PTR   = $SB2/" \
      "$HARVEST" > "$REPO/_pwtest/SaveHarvest_v$V.lua"
  cp "$WT/pokemonworld.gba" "$BIZHAWK/FixGen.gba"
  python3 -c "open('$BIZHAWK/GBA/SaveRAM/FixGen.SaveRAM','wb').write(b'\xff'*131072)"

  cmd.exe /c "$BIZHAWK_WIN\\EmuHawk.exe $BIZHAWK_WIN\\FixGen.gba --lua=$REPO_WIN\\_pwtest\\SaveHarvest_v$V.lua" >/dev/null 2>&1 || true

  # harvest the raw 128KB body (drop BizHawk's 16-byte footer) and sanity-check a save was written
  python3 - "$V" <<'PY'
import sys
v=sys.argv[1]
d=open("/mnt/c/Users/evilc/BizHawk/GBA/SaveRAM/FixGen.SaveRAM","rb").read()
assert d.find((0x08012025).to_bytes(4,"little"))>=0, f"v{v}: NO save written (nav failed)"
open(f"/mnt/c/Users/evilc/Github/PKMN-World/Testing/lua/fixtures/v{v}.srm","wb").write(d[:131072])
print(f"  wrote Testing/lua/fixtures/v{v}.srm")
PY
done

echo "Done. Verify each with: cp <rom> FixChk.gba; cp fixtures/vN.srm FixChk.SaveRAM; EmuHawk --lua=MigrateFixtures.lua"
