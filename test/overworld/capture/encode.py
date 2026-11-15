#!/usr/bin/env python3
"""encode.py <run> <out-stem> <start:end> [<start:end> ...] [--gif] [--hold N]
Joins frame ranges of runs/<run>/frames into out/<out-stem>.mp4 (3x, 30 fps) and optionally a
2x 15 fps GIF. --hold N repeats the final frame N times so the last screen can be read."""
import os, sys, subprocess, tempfile, shutil
R = os.environ.get("CAPTURE_OUT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../build/capture")
args = sys.argv[1:]
gif = "--gif" in args
hold = int(args[args.index("--hold") + 1]) if "--hold" in args else 30
args = [a for i, a in enumerate(args) if a != "--gif" and a != "--hold" and (i == 0 or args[i - 1] != "--hold")]
run, stem, ranges = args[0], args[1], args[2:]
src = f"{R}/runs/{run}/frames"
tmp = tempfile.mkdtemp()
k = 0
last = None
for r in ranges:
    a, b = (int(x) for x in r.split(":"))
    for f in range(a, b + 1):
        p = f"{src}/f{f:06d}.png"
        if not os.path.exists(p): continue
        k += 1; os.symlink(p, f"{tmp}/{k:06d}.png"); last = p
for _ in range(hold):
    k += 1; os.symlink(last, f"{tmp}/{k:06d}.png")
os.makedirs(f"{R}/out", exist_ok=True)
secs = k / 30
assert secs <= 60, f"{stem}: {secs:.1f}s exceeds a minute"
mp4 = f"{R}/out/{stem}.mp4"
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "30", "-i", f"{tmp}/%06d.png",
                "-vf", "scale=720:480:flags=neighbor", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                "-crf", "16", "-movflags", "+faststart", mp4], check=True)
out = [mp4]
if gif:
    g = f"{R}/out/{stem}.gif"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "30", "-i", f"{tmp}/%06d.png",
                    "-vf", "fps=15,scale=480:320:flags=neighbor,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=none",
                    "-loop", "0", g], check=True)
    out.append(g)
shutil.rmtree(tmp)
for o in out: print(f"{o}\t{secs:.1f}s\t{os.path.getsize(o)//1024} KB")
