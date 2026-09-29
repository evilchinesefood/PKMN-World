local here = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or ""
package.path = here.."?.lua;"..package.path
local W = require("windows_lib").new("WarmWindowsCapture")
local F = W.F
F.run(function()
  assert(F.boot(100), "boot failed")
  W.invoke(0)
  for i = 1,#W.scenes do
    local scene = W.go(i)
    for _, time in ipairs({{"noon",12,256}, {"dusk",20,128}, {"night",22,0}, {"dawn",8,128}}) do
      W.clock(time[2],0,0)
      local tag = scene.."_"..time[1]
      F.check(tag..": correct blend weight", W.palette(tag)==time[3])
      W.dump(tag)
    end
  end
  F.finish()
end)
