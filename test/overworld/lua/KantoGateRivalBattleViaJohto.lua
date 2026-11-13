-- The Kanto rival-battle return, but through Johto first. See KantoGateRivalBattle.lua.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
KANTO_RIVAL_VIA = "johto"
dofile(here .. "KantoGateRivalBattle.lua")
