-- Message lines must fit the SwSh message box with a seven-letter player name.
--
-- SWSH_MESSAGE_BOX narrowed the field box to 26 tiles (208 px) and draws the "more text" arrow in
-- its bottom-right 8x16 corner, clearing that corner first. A line that waits on \p or \l from the
-- bottom row therefore loses anything it printed past x = 200. ValidateTextWidth.py measures every
-- line on the host; this suite plays four of the lines it caught, with a 42 px player name and
-- Instant text, and reads the field text printer at every prompt: currentX is where the waiting
-- line ended, currentY its row. Oracle: no prompt on the bottom row ends past 200 px and none
-- anywhere past 208 px. Every prompt is screenshotted for a reviewer.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MessageBoxFit")

local CONTEXT_SHUTDOWN = 2
local BOX_WIDTH, ARROW_WIDTH, BOTTOM_ROW_Y = 208, 8, 17
-- Measured on this build: the field printer keeps fontId, x, y, currentX, currentY at +12..+16.
local P_FONT, P_X, P_Y, P_CURX, P_CURY = 12, 13, 14, 15, 16
local FONT_NORMAL = 1
-- Glyphs whose last column is blank in latin_normal.png (ink one pixel short of the advance).
local SHORT_INK = { [0xDD] = 1, [0xE0] = 1, [0xA2] = 1 }

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function setup()
  local sb2 = F.sb2()
  for i = 0, 6 do F.w8(sb2 + i, 0xC7) end            -- "MMMMMMM": every naming-screen glyph is 6 px
  F.w8(sb2 + 7, 0xFF)
  local a = sb2 + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)                     -- Instant text
end

local function prompt()
  local p = F.r32(S.sFirstTextPrinter)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  local cur = F.r32(p)
  local x, ink = F.r8(p + P_CURX), F.r8(p + P_CURX)
  local k = 2
  while F.r8(cur - k) == 0x00 and ink > 0 do ink = ink - 3; k = k + 1 end
  ink = ink - (SHORT_INK[F.r8(cur - k)] or 0)
  return { font = F.r8(p + P_FONT), x0 = F.r8(p + P_X), y0 = F.r8(p + P_Y), x = x, ink = ink, y = F.r8(p + P_CURY) }
end

local layoutChecked = false
local function talk(tag, dir)
  F.face(dir)
  F.press("A", 2)
  local worst, prompts = nil, 0
  for i = 1, 1500 do
    if F.reportCrash(tag) then break end
    if i > 30 and hasControl() then break end
    if i % 45 == 0 then
      local p = prompt()
      if p then
        if not layoutChecked then
          layoutChecked = true
          F.check("field text printer layout is the one measured (font 1, x 0, y 1)",
            p.font == FONT_NORMAL and p.x0 == 0 and p.y0 == 1, string.format("font=%d x=%d y=%d", p.font, p.x0, p.y0))
        end
        prompts = prompts + 1
        local limit = BOX_WIDTH - ((p.y == BOTTOM_ROW_Y) and ARROW_WIDTH or 0)
        F.L(string.format("  %s prompt %d: line ends at %d px (ink %d) on y=%d, limit %d", tag, prompts, p.x, p.ink, p.y, limit))
        F.shot(string.format("%s_%02d", tag, prompts))
        if p.ink > limit and (not worst or p.ink - limit > worst.over) then
          worst = { over = p.ink - limit, ink = p.ink, limit = limit, n = prompts }
        end
      end
      F.press("A", 2)
    else F.idle(1) end
  end
  for _ = 1, 300 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  F.check(tag .. ": the talk printed prompts", prompts > 0, string.format("%d prompts", prompts))
  F.check(tag .. ": no prompt line runs under the arrow or past the box",
    worst == nil, worst and string.format("prompt %d inks %d px, limit %d", worst.n, worst.ink, worst.limit) or "")
  F.check(tag .. ": control returns", hasControl(), where())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setup()
  F.check("walk to the Frontier attendant", F.route({ { 16, 4 }, { 4, 4 }, { 4, 3 } }, "frontier"), where())
  talk("hub_frontier", "Up")

  F.check("warp to the Tunnelers' Rest House", F.warpTo(0, 2, 1, 0, 0, 0, 0, 0, 0, 21, 0, "tunnel"))
  setup()
  F.check("walk to the tunneler", F.route({ { 6, 7 }, { 6, 6 } }, "tunneler"), where())
  talk("tunneler", "Up")

  F.check("warp to the Rustboro Gym", F.warpTo(0, 1, 1, 0, 0, 3, 0, 0, 0, 11, 3, "rustgym"))
  setup()
  F.check("walk to the Gym guide", F.route({ { 5, 18 }, { 4, 18 } }, "guide"), where())
  talk("rustboro_guide", "Left")

  F.check("warp to the Safari Zone gate Pokemon Center", F.warpTo(0, 9, 6, 0, 0, 1, 0, 0, 0, 96, 1, "safaripc"))
  setup()
  F.check("walk to the caretaker", F.route({ { 13, 8 }, { 13, 6 } }, "caretaker"), where())
  talk("safari_pc", "Right")
  F.finish()
end)
