-- Wraps a PKMN-World suite and saves every Nth frame as a PNG for review videos.
-- Env: REC_SUITE (suite path), REC_DIR (frame dir), REC_EVERY (default 2).
local suite = assert(os.getenv("REC_SUITE"), "REC_SUITE unset")
local dir = assert(os.getenv("REC_DIR"), "REC_DIR unset")
local every = tonumber(os.getenv("REC_EVERY") or "2")
local n, k = 0, 0
local advance = emu.frameadvance
REC = { on = true }
emu.frameadvance = function()
  advance()
  n = n + 1
  if REC.on and n % every == 0 then
    k = k + 1
    client.screenshot(string.format("%s/f%06d.png", dir, k))
  end
end
REC.frame = function() return k end
REC.mark = function(label)
  local f = io.open(dir .. "/marks.txt", "a"); f:write(string.format("%d\t%s\n", k, label)); f:close()
end
dofile(suite)
