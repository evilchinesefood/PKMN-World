#!/usr/bin/env bash
# Battle weather indicator suite (issue #661). Usage: run.sh <fresh-empty-output-dir>
set -euo pipefail
repo="$(cd "$(dirname "$0")/../../.." && pwd)"
out="${1:?usage: run.sh <fresh-empty-output-dir>}"
nm="${DEVKITARM:-/opt/devkitpro/devkitARM}/bin/arm-none-eabi-nm"
cd "$repo"
addr() {
    local value
    value="$("$nm" pokemonworld.elf | awk -v s="$1" '$3==s{print $1; exit}')"
    [ -n "$value" ] || { echo "symbol not found: $1" >&2; exit 1; }
    echo "$value"
}
envs=(
    --env "PW_A_WEATHER=$(addr gBattleWeather)"
    --env "PW_A_CURSOR=$(addr gMoveSelectionCursor)"
    --env "PW_A_TASK=$(addr Task_WeatherIndicatorHandler)"
    --env "PW_A_MONS=$(addr gBattleMons)"
    --env "PW_A_SPRITES=$(addr gSprites)"
    --env "PW_A_V5=$(addr gSpecialVar_0x8005)"
    --env "PW_A_V6=$(addr gSpecialVar_0x8006)"
    --env "PW_A_V7=$(addr gSpecialVar_0x8007)"
)
mkdir -p "$out"
python3 test/overworld/visual-features/build_fixture.py --repo . --rom pokemonworld.gba --elf pokemonworld.elf \
    --source test/overworld/world-menu-theme/fixture.c --out "$out/fixture" >/dev/null
python3 test/overworld/swsh-refresh/export_symbols.py pokemonworld.elf "$out/fixture"
status=0
for mode in 0 1; do
    python3 test/overworld/visual-features/run_fixture.py --repo . --fixture "$out/fixture" \
        --suite test/overworld/weather-indicator/capture.lua --out "$out/mode$mode" \
        --env "PW_BATTLE_MODE=$mode" "${envs[@]}" || status=1
done
exit $status
