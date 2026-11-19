#!/usr/bin/env python3
"""Every message line fits the window it prints in, with its placeholders at their longest.

A line is measured the way RenderText draws it: charmap bytes, the advance table in src/fonts.c,
and the ink of the last glyph read from the font PNG. CopyGlyphToVRAM cuts any glyph past the
window's right edge, so a line wider than its window loses its last letters.

SWSH_MESSAGE_BOX narrowed every 27-tile message window to 26 tiles (216 to 208 px) and moved the
"more text" arrow to the window's bottom-right corner. TextPrinterDrawDownArrow fills that 8x16
corner with the background before it draws the arrow, so a line that waits on \\p or \\l from
the bottom row loses whatever it drew past width - 8. A line printed below the last row is not
drawn at all. The main menu's save-error window is two rows deep, so a third row there is lost.

Placeholders take their widest value at each call site. {PLAYER} is PLAYER_NAME_LENGTH of the
widest glyphs the naming screen offers, {RIVAL} the widest name ExpandPlaceholder_RivalName can
return, and {STR_VAR_n} whatever the script last buffered into it: the species, item or move it
names (or every one a setvar in the same script gives that variable), a nickname of
POKEMON_NAME_LENGTH glyphs, a number's digits, or another text. A buffer the script does not
fill is a nickname.

Lines written upstream (the initial commit, which is pokeemerald-expansion with its FRLG maps,
or pokemonHnS) were laid out for 216 px and no corner arrow. One that was already cut upstream
is out of scope and sits in the baseline; everything else must fit.

  python3 test/overworld/ValidateTextWidth.py                  check against the baseline
  python3 test/overworld/ValidateTextWidth.py --report         every line that does not fit
  python3 test/overworld/ValidateTextWidth.py --fix --hns DIR  reflow new overflows in their page
  python3 test/overworld/ValidateTextWidth.py --write-baseline --hns DIR

--hns names a pokemonHnS checkout (its data/ is enough). --report, --fix and --write-baseline
take the initial commit from git, so they need full history.
"""
from pathlib import Path
import argparse
import io
import re
import subprocess
import sys
import tarfile
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ValidateBattleScenes import png_pixels  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "test/overworld/reference/text_width_baseline.tsv"
INITIAL_COMMIT = "ac9e6927bc"

EOS, NEWLINE, SCROLL, PARAGRAPH = 0xFF, 0xFE, 0xFA, 0xFB
DYNAMIC, KEYPAD_ICON, EXTRA_SYMBOL, EXT_CTRL, PLACEHOLDER = 0xF7, 0xF8, 0xF9, 0xFC, 0xFD
ZERO_WIDTH_SPACE = 0x3A
BREAKS = {NEWLINE: "\\n", SCROLL: "\\l", PARAGRAPH: "\\p", EOS: "$"}
EXT_FONT, EXT_ESCAPE, EXT_SHIFT_RIGHT, EXT_CLEAR, EXT_SKIP, EXT_CLEAR_TO = 0x06, 0x0C, 0x0D, 0x11, 0x12, 0x13
EXT_MIN_LETTER_SPACING, EXT_SPEAKER = 0x14, 0x19


def read(rel, root=ROOT):
    return (root / rel).read_text(encoding="utf-8", errors="replace")


def c_literal(chunks):
    return "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', chunks))


class Charmap:
    def __init__(self):
        self.chars, self.escapes, self.consts = {}, {}, {}
        for line in read("charmap.txt").splitlines():
            line = line.split("@", 1)[0].strip()
            m = re.match(r"^'(\\?.)'\s*=\s*([0-9A-Fa-f ]+)$", line)
            if m:
                key, value = m.group(1), bytes(int(b, 16) for b in m.group(2).split())
                if len(key) == 2 and key[1] not in "'\"\\":
                    self.escapes[key[1]] = value
                else:
                    self.chars[key[-1]] = value
                continue
            m = re.match(r"^(\w+)\s*=\s*([0-9A-Fa-f ]+)$", line)
            if m:
                self.consts[m.group(1)] = bytes(int(b, 16) for b in m.group(2).split())

    def tokens(self, text):
        """(source, bytes) for each unit tools/preproc maps: a character, an escape or a {...}."""
        i = 0
        while i < len(text):
            if text[i] == "{":
                j = text.index("}", i)
                out = b""
                for part in text[i + 1:j].split():
                    out += bytes([int(part, 0) & 0xFF]) if part[0].isdigit() else self.consts[part]
                yield text[i:j + 1], out
                i = j + 1
            elif text[i] == "\\":
                yield text[i:i + 2], self.escapes.get(text[i + 1]) or self.chars[text[i + 1]]
                i += 2
            else:
                yield text[i], self.chars[text[i]]
                i += 1

    def encode(self, text):
        return b"".join(b for _, b in self.tokens(text))


FONT_FILES = {
    "FONT_SMALL": ("gFontSmallLatinGlyphWidths", "latin_small"),
    "FONT_NORMAL": ("gFontNormalLatinGlyphWidths", "latin_normal"),
    "FONT_SHORT": ("gFontShortLatinGlyphWidths", "latin_short"),
    "FONT_NARROW": ("gFontNarrowLatinGlyphWidths", "latin_narrow"),
    "FONT_SMALL_NARROW": ("gFontSmallNarrowLatinGlyphWidths", "latin_small_narrow"),
    "FONT_NARROWER": ("gFontNarrowerLatinGlyphWidths", "latin_narrower"),
    "FONT_SMALL_NARROWER": ("gFontSmallNarrowerLatinGlyphWidths", "latin_small_narrower"),
    "FONT_SHORT_NARROW": ("gFontShortNarrowLatinGlyphWidths", "latin_short_narrow"),
    "FONT_SHORT_NARROWER": ("gFontShortNarrowerLatinGlyphWidths", "latin_short_narrower"),
}


class Font:
    """Advance per glyph from src/fonts.c; ink ends at the last drawn column (text or shadow)."""

    def __init__(self, table, png):
        body = read("src/fonts.c")
        start = body.index(f"{table}[] = {{")
        self.advance = [int(n) for n in re.findall(r"\d+", body[body.index("{", start) + 1:body.index("};", start)])]
        rows = png_pixels(ROOT / f"graphics/fonts/{png}.png")
        self.ink = []
        for glyph in range(len(self.advance)):
            x0, y0 = glyph % 16 * 16, glyph // 16 * 16
            cols = [x for x in range(16) for y in range(16) if rows[y0 + y][x0 + x] in (1, 2)]
            self.ink.append(max(cols) + 1 if cols else 0)


class Line:
    __slots__ = ("text", "width", "row", "end", "lineno")

    def __init__(self, text, width, row, end, lineno):
        self.text, self.width, self.row, self.end, self.lineno = text, width, row, end, lineno


class Renderer:
    """Walks charmap bytes the way RenderText does and reports each visual line."""

    def __init__(self):
        enum = read("include/text.h")
        enum = enum[enum.index("enum {\n    FONT_SMALL"):]
        self.font_ids = {n: i for i, n in enumerate(re.findall(r"^\s+(FONT_\w+),", enum[:enum.index("};")], re.M))}
        self.font_names = {i: n for n, i in self.font_ids.items()}
        self.fonts = {}
        chars = dict(re.findall(r"#define (\w+)\s+(0x[0-9A-Fa-f]+|\d+)", read("include/constants/characters.h")))
        table = read("src/string_util.c")
        table = table[table.index("u8 GetExtCtrlCodeLength"):]
        self.ext = {int(chars[n], 0): int(k) for n, k in re.findall(r"\[(EXT_CTRL_CODE_\w+)\]\s*=\s*(\d+)", table[:table.index("};")])}
        self.ext[0] = 1
        self.ext[EXT_SPEAKER] = 2  # RenderText reads the speaker id after the code
        icons = read("src/text.c")
        icons = icons[icons.index("static const sKeypadIcons[]"):]
        self.keypad = {int(chars[n], 0): int(w) for n, w in re.findall(r"\[(CHAR_\w+)\]\s*=\s*\{\s*\w+,\s*(\d+)", icons[:icons.index("};")])}
        self.widest_cache = {}

    def font(self, font_id):
        name = self.font_names[font_id]
        name = "FONT_SHORT" if name.startswith("FONT_SHORT_COPY") else name
        if name not in self.fonts:
            self.fonts[name] = Font(*FONT_FILES[name])
        return self.fonts[name]

    def glyph(self, g, font_id, x, ink, spacing):
        if g == ZERO_WIDTH_SPACE:
            return x, ink
        font = self.font(font_id)
        if font.ink[g]:
            ink = max(ink, x + font.ink[g])
        return x + max(font.advance[g], spacing), ink

    def width(self, data, font_id):
        x = ink = 0
        for g in data:
            x, ink = self.glyph(g, font_id, x, ink, 0)
        return ink

    def widest(self, candidates, font_id):
        key = (id(candidates), font_id)
        if key not in self.widest_cache:
            self.widest_cache[key] = (candidates, max(candidates, key=lambda b: self.width(b, font_id)) if candidates else b"")
        return self.widest_cache[key][1]

    def lines(self, tokens, font_name, expand):
        """tokens: [(source, bytes, lineno)]; expand(kind, id) -> candidate glyph strings."""
        data, owner = bytearray(), []
        for k, (_, chunk, _) in enumerate(tokens):
            data += chunk
            owner += [k] * len(chunk)
        out, x, ink, row, first, spacing = [], 0, 0, 0, 0, 0
        font_id = self.font_ids[font_name]
        i = 0

        def close(end, last):
            src = "".join(t[0] for t in tokens[first:last])
            out.append(Line(src, ink, row, end, tokens[min(first, len(tokens) - 1)][2] if tokens else 0))

        while i < len(data):
            b = data[i]
            if b in BREAKS:
                close(BREAKS[b], owner[i])
                if b == EOS:
                    return out
                row = 0 if b == PARAGRAPH else row + (b == NEWLINE)
                x = ink = 0
                first = owner[i] + 1
                i += 1
            elif b == EXT_CTRL:
                code = data[i + 1]
                size = self.ext.get(code, 1)
                args = data[i + 2:i + 1 + size]
                i += 1 + size
                if code == EXT_FONT:
                    font_id = args[0]
                elif code == EXT_ESCAPE:
                    x, ink = self.glyph(args[0] | 0x100, font_id, x, ink, spacing)
                elif code in (EXT_SHIFT_RIGHT, EXT_SKIP):
                    x = args[0]
                elif code == EXT_CLEAR:
                    x += args[0]
                elif code == EXT_CLEAR_TO:
                    x = max(x, args[0])
                elif code == EXT_MIN_LETTER_SPACING:
                    spacing = args[0]
            elif b in (PLACEHOLDER, DYNAMIC):
                for g in self.widest(expand(b, data[i + 1]), font_id):
                    x, ink = self.glyph(g, font_id, x, ink, spacing)
                i += 2
            elif b == KEYPAD_ICON:
                w = self.keypad.get(data[i + 1], 8)
                x, ink = x + w, max(ink, x + w)
                i += 2
            elif b == EXTRA_SYMBOL:
                x, ink = self.glyph(data[i + 1] | 0x100, font_id, x, ink, spacing)
                i += 2
            else:
                x, ink = self.glyph(b, font_id, x, ink, spacing)
                i += 1
        close("$", len(tokens))
        return out


class Window:
    def __init__(self, key, width, rows, upstream_width, origin=0, font="FONT_NORMAL", arrow=0):
        self.key, self.width, self.rows, self.upstream_width = key, width, rows, upstream_width
        self.origin, self.font, self.arrow = origin, font, arrow

    def limit(self, end, row):
        """Pixels a line may ink here, and whether the corner arrow is what sets that limit."""
        waits = self.arrow > 0 and end in ("\\p", "\\l") and row == self.rows - 1
        return self.width - self.origin - (self.arrow if waits else 0), waits


def windows():
    swsh = re.search(r"#define SWSH_MESSAGE_BOX\s+TRUE", read("include/config/name_box.h")) is not None
    box = read("src/menu.c")
    box = box[box.index("sStandardTextBox_WindowTemplates[]"):]
    now, old = (int(w) for w in re.search(r"#if SWSH_MESSAGE_BOX\s*\.width = (\d+),\s*#else\s*\.width = (\d+)", box).groups())
    rows = int(re.search(r"\.height = (\d+)", box).group(1)) // 2
    arrow = int(re.search(r"arrowX = .*? - (\d+);", read("src/text.c")).group(1)) if swsh else 0
    battle = int(re.search(r"\[B_WIN_MSG\] = \{[^}]*?\.width = (\d+)", read("src/battle_bg.c")).group(1)) * 8
    call = read("src/match_call.c")
    call_w = int(re.search(r"sMatchCallTextWindow =\s*\{[^}]*?\.width = (\d+)", call).group(1)) * 8
    call_x = int(re.search(r"printerTemplate\.x = (\d+);", call).group(1))
    store = int(re.search(r"\[WIN_MESSAGE\] = \{[^}]*?\.width = (\d+)", read("src/data/swsh_storage_system.h")).group(1)) * 8
    story = re.search(r"sStoryWindows\[\] = \{\s*\{[^}]*\},\s*\{\s*\d+,\s*\d+,\s*\d+,\s*(\d+)", read("src/story_progress_menu.c"))
    story = int(story.group(1)) * 8
    intro = re.search(r"Dedicated textbox for the Pikachu.*?\.width = (\d+),\s*\.height = (\d+)", read("src/oak_speech.c"), re.S)
    message = (now if swsh else old) * 8
    main = read("src/main_menu.c")
    error_w, error_h = (int(re.search(rf"#define MENU_{k}_ERROR (\d+)", main).group(1)) for k in ("WIDTH", "HEIGHT"))
    return {
        "message": Window("message", message, rows, old * 8, arrow=arrow),
        "battle": Window("battle", battle, rows, battle, arrow=arrow),
        "match_call": Window("match_call", call_w, rows, call_w, origin=call_x, arrow=arrow),
        "storage": Window("storage", store, 1, store),
        "story": Window("story", story, 3, story, origin=8, font="FONT_SMALL"),
        "intro": Window("intro", int(intro.group(1)) * 8, int(intro.group(2)) // 2, int(intro.group(1)) * 8, origin=3),
        "main_menu": Window("main_menu", error_w * 8, error_h // 2, error_w * 8, arrow=arrow),
    }


def keyed_names(text, key, field):
    out, current = {}, None
    for line in text.splitlines():
        m = re.match(rf"^\s*\[({key}_\w+)\]\s*=", line)
        if m:
            current = m.group(1)
            continue
        m = re.search(rf'\.{field} = \w+\("((?:[^"\\]|\\.)*)"\)', line)
        if m and current and current not in out:
            out[current] = m.group(1)
    return out


def c_strings():
    pattern = re.compile(r'u8\s+(\w+)\[\]\s*=\s*_\(\s*((?:"(?:[^"\\]|\\.)*"\s*)+)\)\s*;')
    out = {}
    for path in sorted((ROOT / "src").glob("*.c")):
        for name, chunks in pattern.findall(path.read_text(encoding="utf-8", errors="replace")):
            out.setdefault(name, c_literal(chunks))
    return out


NUMBER = re.compile(r"^(0x[0-9A-Fa-f]+|\d+)$")


class Values:
    """Candidate glyph strings for every placeholder; the renderer takes the widest per font."""

    def __init__(self, charmap, messages, cstrings):
        enc = charmap.encode
        self.charmap, self.messages, self.cstrings = charmap, messages, cstrings
        keyboard = read("src/naming_screen.c")
        keyboard = keyboard[keyboard.index("sKeyboardChars[KBPAGE_COUNT]"):]
        typed = sorted({c for row in re.findall(r'__\("([^"]*)"\)', keyboard[:keyboard.index("};\n")]) for c in row} - {" "})
        typed = [enc(c) for c in typed]
        consts = read("include/constants/global.h")
        player = int(re.search(r"#define PLAYER_NAME_LENGTH (\d+)", consts).group(1))
        mon = int(re.search(r"#define POKEMON_NAME_LENGTH (\d+)", consts).group(1))
        move_len = int(re.search(r"#define MOVE_NAME_LENGTH (\d+)", consts).group(1))
        box = int(re.search(r"#define BOX_NAME_LENGTH\s+(\d+)", read("include/pokemon_storage_system.h")).group(1))
        self.names = {"species": {}}
        for path in sorted((ROOT / "src/data/pokemon/species_info").glob("*.h")):
            self.names["species"].update(keyed_names(path.read_text(encoding="utf-8"), "SPECIES", "speciesName"))
        items = read("src/data/items.h")
        self.names["item"] = keyed_names(items, "ITEM", "name")
        tmhm = read("include/constants/tms_hms.h")
        for kind in ("TM", "HM"):
            block = tmhm[tmhm.index(f"#define FOREACH_{kind}(F)"):]
            for n, move in enumerate(re.findall(r"F\((\w+)\)", block[:block.index("\n\n")]), 1):
                if f"ITEM_{kind}_{move}" in self.names["item"]:
                    self.names["item"][f"ITEM_{kind}{n:02d}"] = self.names["item"][f"ITEM_{kind}_{move}"]
        plurals = keyed_names(items, "ITEM", "pluralName")
        self.names["item_plural"] = {k: plurals.get(k, v + "s") for k, v in self.names["item"].items()}
        self.names["move"] = {k: v for k, v in keyed_names(read("src/data/moves_info.h"), "MOVE", "name").items()
                              if len(v) <= move_len}
        decor = re.findall(r'\.name = _\("((?:[^"\\]|\\.)*)"\)', read("src/data/decoration/header.h"))
        self.kinds = {kind: [enc(s) for s in table.values()] for kind, table in self.names.items()}
        self.kinds.update({
            "decoration": [enc(s) for s in decor],
            "box": [g * box for g in typed],
            "nickname": self.kinds["species"] + [g * mon for g in typed],
            "number": [enc("65535")],
        })
        c = lambda n: enc(cstrings[f"gText_ExpandedPlaceholder_{n}"])
        fixed = {
            "PLAYER": [g * player for g in typed],
            "RIVAL": [c("Gary"), c("May"), c("Brendan")],
            "KUN": [c("Kun"), c("Chan")],
            "VERSION": [c("Emerald")], "AQUA": [c("Aqua")], "MAGMA": [c("Magma")], "ARCHIE": [c("Archie")],
            "MAXIE": [c("Maxie")], "KYOGRE": [c("Kyogre")], "GROUDON": [c("Groudon")],
            "REGION": [enc(cstrings[f"gText_{r}"]) for r in ("Kanto", "Johto", "Hoenn")],
        }
        self.fixed = {charmap.consts[n][1]: v for n, v in fixed.items()}
        self.strvar = {charmap.consts[f"STR_VAR_{n}"][1]: f"STR_VAR_{n}" for n in (1, 2, 3)}

    def named(self, kind, arg, setvars):
        """A buffer command's argument: a constant, or every constant a setvar gave that variable."""
        table = self.names.get(kind, {})
        names = [n for n in ([arg] if arg in table else sorted(setvars.get(arg, ()))) if n in table]
        return [self.charmap.encode(table[n]) for n in names] or self.kinds[kind]

    def number(self, arg, setvars):
        values = [v for v in ([arg] if NUMBER.match(arg) else sorted(setvars.get(arg, ()))) if NUMBER.match(v)]
        return [self.charmap.encode(str(int(v, 0))) for v in values] or self.kinds["number"]

    def text_of(self, label):
        if label in self.messages:
            return [b"".join(b for _, b, _ in self.messages[label].tokens).split(bytes([EOS]))[0]]
        if label in self.cstrings:
            return [self.charmap.encode(self.cstrings[label]).split(bytes([EOS]))[0]]
        return None

    def expander(self, strvars, dynamic=None, unknown=None):
        """unknown, when given, replaces every buffer not narrowed to the values its call site names."""
        def expand(kind, pid):
            if kind == DYNAMIC:
                return dynamic or self.kinds["nickname"]
            if pid in self.fixed:
                return self.fixed[pid]
            value = strvars.get(self.strvar.get(pid))
            if unknown is not None and (value is None or any(value is k for k in self.kinds.values())):
                return unknown
            return value if value is not None else self.kinds["nickname"]
        return expand


class Message:
    __slots__ = ("path", "label", "tokens", "uses")

    def __init__(self, path, label, tokens):
        self.path, self.label, self.tokens, self.uses = path, label, tokens, []


STRING = re.compile(r'^\s*\.string\s+"((?:[^"\\]|\\.)*)"')
LABEL = re.compile(r"^(\w+)::?")


def script_files(root):
    return sorted(root.glob("data/**/*.inc")) + [root / "data/event_scripts.s"]


def script_messages(root, charmap):
    """label -> Message for every .string block under data/."""
    messages = {}
    for path in script_files(root):
        if not path.exists():
            continue
        label, msg = None, None
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            m = LABEL.match(line)
            if m:
                label, msg = m.group(1), None
                continue
            m = STRING.match(line)
            if not m or label is None:
                continue
            if msg is None:
                msg = Message(str(path.relative_to(root)), label, [])
                messages.setdefault(label, msg)
            msg.tokens.extend((src, b, n) for src, b in charmap.tokens(m.group(1)))
    return messages


def source_lines(tokens):
    """Source text of each visual line, split where the source writes \\n, \\l or \\p."""
    out, cur = [], []
    for src, _, _ in tokens:
        if src in ("\\n", "\\l", "\\p"):
            out.append("".join(cur))
            cur = []
        elif src == "$":
            break
        else:
            cur.append(src)
    out.append("".join(cur))
    return out


BUFFERS = {
    "bufferspeciesname": "species", "bufferleadmonspeciesname": "species", "bufferpartymonnick": "nickname",
    "bufferlivemonnickname": "nickname", "bufferitemname": "item", "bufferitemnameplural": "item_plural",
    "bufferdecorationname": "decoration", "buffermovename": "move", "bufferboxname": "box",
}
# Argument positions of text labels, by the window the text prints in.
TEXT_ARGS = {
    "message": {"msgbox": (0,), "message": (0,), "messageautoscroll": (0,), "vmessage": (0,),
                "messageinstant": (0,), "giveitem_msg": (0,), "msgreceiveditem": (0,), "ingame_trade": (1, 4),
                "move_tutor": (1, 2), "trainerbattle_single": (1,), "trainerbattle_double": (1, 3),
                "trainerbattle_rematch": (1,), "trainerbattle_rematch_double": (1, 3), "trainerbattle": (3, 8, 11)},
    "battle": {"trainerbattle_single": (2,), "trainerbattle_double": (2,), "trainerbattle_rematch": (2,),
               "trainerbattle_rematch_double": (2,), "trainerbattle_no_intro": (1,),
               "trainerbattle_no_intro_no_reveal": (1,), "trainerbattle_two_trainers": (1, 3),
               "trainerbattle_earlyrival": (2, 3), "multi_2_vs_2": (1, 3), "multi_2_vs_1": (1,),
               "setmultitrainerbattle": (1, 3), "trainerbattle": (4, 9, 10)},
    "match_call": {"pokenavcall": (0,)},
}
UNSCRIPTED = (("data/text/match_call.inc", "match_call"), ("data/text/braille.inc", None),
              ("gPikachuIntro_Text_", "intro"))


def macro_args(macro, k):
    out = set()
    for path in script_files(ROOT):
        for m in re.finditer(rf"^\s*{macro}\s+([^@\n]+)", path.read_text(encoding="utf-8", errors="replace"), re.M):
            args = [a.strip() for a in m.group(1).split(",")]
            if k < len(args):
                out.add(args[k])
    return out


def c_array_constants(rel, arrays):
    body = read(rel)
    return {c for name in arrays for c in re.findall(r"\b[A-Z]+_\w+", re.search(rf"{name}\[\]\s*=\s*\{{([^}}]*)\}}", body).group(1))}


# Buffers filled where the script cannot see: by a macro's caller or by C. Each names its source.
HINTS = {
    "gText_GiverSeesKeyItem": {"STR_VAR_2": ("item", lambda: macro_args("givekeyitem", 0))},
    "BugContest_Text_PrizeSentToPC": {"STR_VAR_2": ("item", lambda: c_array_constants(
        "src/bug_contest.c", ("sFirstPlaceRewards", "sSecondPlaceRewards", "sThirdPlaceRewards")))},
}


def file_setvars(lines):
    """Every constant a setvar in this file gives each variable, followed through copyvar."""
    setvars, copies = {}, []
    for line in lines:
        parts = line.split("@", 1)[0].strip().split(None, 1)
        if len(parts) < 2:
            continue
        args = [a.strip() for a in parts[1].split(",")]
        if parts[0] in ("setvar", "setorcopyvar") and len(args) > 1:
            setvars.setdefault(args[0], set()).add(args[1])
        elif parts[0] == "copyvar" and len(args) > 1:
            copies.append((args[0], args[1]))
    for _ in copies:
        for dst, src in copies:
            setvars.setdefault(dst, set()).update(setvars.get(src, ()))
    return setvars


def add_script_uses(messages, values):
    """What each script buffered before printing a text, and which window it printed in."""
    for path in script_files(ROOT):
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        setvars = file_setvars(lines)
        strvars = {}
        for line in lines:
            if re.match(r"^\w+::", line):
                strvars = {}
            s = line.split("@", 1)[0].strip()
            if not s or s.startswith(".") or LABEL.match(line):
                continue
            parts = s.split(None, 1)
            cmd, args = parts[0], [a.strip() for a in parts[1].split(",")] if len(parts) > 1 else []
            if cmd in BUFFERS and args:
                strvars[args[0]] = values.named(BUFFERS[cmd], args[1] if len(args) > 1 else "", setvars)
            elif cmd == "buffernumberstring" and len(args) > 1:
                strvars[args[0]] = values.number(args[1], setvars)
            elif cmd == "bufferstring" and len(args) > 1:
                strvars[args[0]] = values.text_of(args[1]) or values.kinds["nickname"]
            elif cmd.startswith("buffer") and args and args[0].startswith("STR_VAR_"):
                strvars.pop(args[0], None)
            for window, table in TEXT_ARGS.items():
                for k in table.get(cmd, ()):
                    if k < len(args) and args[k] in messages:
                        messages[args[k]].uses.append((window, dict(strvars), None))
    for label, hints in HINTS.items():
        resolved = {var: values.named(kind, "", {"": source()}) for var, (kind, source) in hints.items()}
        messages[label].uses = [(w, {**sv, **resolved}, d) for w, sv, d in messages[label].uses]
    for msg in messages.values():
        if msg.uses:
            continue
        window = "message"
        for prefix, override in UNSCRIPTED:
            if msg.path.startswith(prefix) or msg.label.startswith(prefix):
                window = override
        if window:
            msg.uses.append((window, {}, None))


def c_messages(charmap, values):
    """Story pages, storage messages and the main menu's save errors: project text printed from C."""
    out = []
    rel = "src/main_menu.c"
    body = read(rel)
    for name in sorted(set(re.findall(r"CreateMainMenuErrorWindow\((gText_\w+)\)", body))):
        lineno = body[:body.index(name + "[]")].count("\n") + 1
        msg = Message(rel, name, [(s, b, lineno) for s, b in charmap.tokens(values.cstrings[name] + "$")])
        msg.uses.append(("main_menu", {}, None))
        out.append(msg)
    literal = r'"((?:[^"\\]|\\.)*)"'
    for rel in ["src/story_progress.c"] + sorted(str(p.relative_to(ROOT)) for p in (ROOT / "src/data/story_progress").glob("*.inc")):
        body = read(rel)
        for m in re.finditer(r"STORY_OBJECTIVE\((\w+),\s*" + literal + r",\s*STORY_\w+\(\w+\),((?:\s*" + literal + r",?){5})\s*\);", body):
            lineno = body[:m.start()].count("\n") + 1
            for field, text in zip(("chapter", "recap", "action", "where", "why"), re.findall(literal, m.group(3))):
                msg = Message(rel, f"{m.group(1)}.{field}", [(s, b, lineno) for s, b in charmap.tokens(text + "$")])
                msg.uses.append(("story", {}, None))
                out.append(msg)
    rel = "src/data/swsh_storage_system.h"
    body = read(rel)
    body_start = body.index("sMessages[] =")
    for m in re.finditer(r"\[(MSG_\w+)\]\s*=\s*\{(?:COMPOUND_STRING\(" + literal + r"\)|(gText_\w+)),\s*(MSG_VAR_\w+)\}", body[body_start:]):
        lineno = body[:body_start + m.start()].count("\n") + 1
        text = m.group(2) if m.group(3) is None else values.cstrings[m.group(3)]
        msg = Message(rel, f"sMessages.{m.group(1)}", [(s, b, lineno) for s, b in charmap.tokens(text + "$")])
        msg.uses.append(("storage", {}, values.kinds["item"] if m.group(4) == "MSG_VAR_ITEM_NAME" else values.kinds["nickname"]))
        out.append(msg)
    return out


class Finding:
    __slots__ = ("msg", "line", "window", "width", "limit", "kind", "unresolved", "upstream")

    def __init__(self, msg, line, window, width, limit, kind, unresolved):
        self.msg, self.line, self.window, self.width, self.limit, self.kind = msg, line, window, width, limit, kind
        self.unresolved, self.upstream = unresolved, None

    @property
    def key(self):
        return (self.msg.label, self.line.text)

    def where(self):
        return f"{self.msg.path}:{self.line.lineno}"


class Checker:
    def __init__(self):
        self.charmap = Charmap()
        self.renderer = Renderer()
        self.windows = windows()
        self.script = script_messages(ROOT, self.charmap)
        self.values = Values(self.charmap, self.script, c_strings())
        add_script_uses(self.script, self.values)
        self.messages = list(self.script.values()) + c_messages(self.charmap, self.values)

    def render(self, msg, use, unknown=None):
        window, strvars, dynamic = use
        win = self.windows[window]
        return win, self.renderer.lines(msg.tokens, win.font, self.values.expander(strvars, dynamic, unknown))

    def findings(self):
        worst = {}
        for msg in self.messages:
            for use in msg.uses:
                win, lines = self.render(msg, use)
                bare = None
                for i, line in enumerate(lines):
                    limit, arrow = win.limit(line.end, line.row)
                    if line.row >= win.rows:
                        kind = "below"
                    elif line.width > limit:
                        kind = "arrow" if arrow and line.width <= win.width - win.origin else "wide"
                    else:
                        continue
                    if bare is None:
                        bare = self.render(msg, use, unknown=[b""])[1]
                    unresolved = kind != "below" and bare[i].width <= limit
                    f = Finding(msg, line, win, line.width, limit, kind, unresolved)
                    old = worst.get(f.key)
                    if old is None or f.width - f.limit > old.width - old.limit:
                        worst[f.key] = f
        return sorted(worst.values(), key=lambda f: (f.msg.path, f.line.lineno))


def upstream_corpus(charmap, hns):
    corpus = set()
    with tempfile.TemporaryDirectory() as tmp:
        tar = subprocess.run(["git", "archive", INITIAL_COMMIT, "data"], cwd=ROOT, capture_output=True, check=True).stdout
        tarfile.open(fileobj=io.BytesIO(tar)).extractall(tmp, filter="data")
        for root in (Path(tmp), Path(hns)):
            for msg in script_messages(root, charmap).values():
                corpus.update(source_lines(msg.tokens))
    return corpus


def classify(findings, corpus):
    """A line written upstream is out of scope when it was already cut there, or when it only
    overflows by a buffer that C fills and this check cannot resolve."""
    for f in findings:
        if f.line.text not in corpus or not f.msg.path.startswith("data/"):
            continue
        if f.kind == "below" or f.width > f.window.upstream_width - f.window.origin:
            f.upstream = "upstream-cut"
        elif f.unresolved:
            f.upstream = "upstream-unresolved"


def reflow(checker, msg, bad_lines):
    """Move words between the lines of each page that holds a bad line, keeping every break.

    Returns {source lineno: new string content} or None when some page cannot fit."""
    rows = {}
    for src, _, n in msg.tokens:
        rows.setdefault(n, []).append(src)
    order = sorted(rows)
    for n in order:
        ends = [i for i, s in enumerate(rows[n]) if s in ("\\n", "\\l", "\\p", "$")]
        if ends != [len(rows[n]) - 1]:
            return None
    texts = ["".join(rows[n][:-1]) for n in order]
    breaks = [rows[n][-1] for n in order]
    uses = msg.uses
    changes = {}
    page = []
    for i, n in enumerate(order):
        page.append(i)
        if breaks[i] not in ("\\p", "$"):
            continue
        if any(order[j] in bad_lines for j in page):
            new = reflow_page(checker, uses, [texts[j] for j in page], [breaks[j] for j in page])
            if new is None:
                return None
            for j, text in zip(page, new):
                if text != texts[j]:
                    changes[order[j]] = text + breaks[j]
        page = []
    return changes


SENTENCE_END = re.compile(r"([.!?…:]['\"”’)]*|-)$")


def reflow_page(checker, uses, texts, breaks):
    if any(t != t.strip(" ") or "  " in t or not t for t in texts):
        return None
    words = " ".join(texts).split(" ")
    starts, k = [], 0
    for t in texts:
        starts.append(k)
        k += len(t.split(" "))
    # A line that ends a sentence or a hyphenated half keeps ending it, so a reflow never runs one
    # sentence into the next or leaves "life- forms" mid-line.
    fixed = {i for i in range(1, len(texts)) if SENTENCE_END.search(words[starts[i] - 1])}
    rows, row = [], 0
    for i, b in enumerate(breaks):
        rows.append(row)
        row = 0 if b == "\\p" else row + (b == "\\n")
    cache = {}

    def fits(i, a, b):
        key = (i, a, b)
        if key not in cache:
            text = " ".join(words[a:b])
            toks = [(s, x, 0) for s, x in checker.charmap.tokens(text + "$")]
            ok = True
            for use in uses:
                win, lines = checker.render(Message("", "", toks), use)
                limit, _ = win.limit(breaks[i], rows[i])
                ok = ok and lines[0].width <= limit and rows[i] < win.rows
            cache[key] = ok
        return cache[key]

    n, m = len(texts), len(words)
    best = {(0, 0): (0, [])}
    for i in range(n):
        nxt = {}
        for (_, a), (cost, cuts) in best.items():
            if i in fixed and a != starts[i]:
                continue
            for b in range(a + 1, m + 1 - (n - 1 - i)):
                if i == n - 1 and b != m:
                    continue
                if not fits(i, a, b):
                    continue
                c = cost + abs(a - starts[i])
                if (i + 1, b) not in nxt or c < nxt[(i + 1, b)][0]:
                    nxt[(i + 1, b)] = (c, cuts + [(a, b)])
        best = nxt
    if (n, m) not in best:
        return None
    return [" ".join(words[a:b]) for a, b in best[(n, m)][1]]


def apply_changes(path, changes):
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines(keepends=True)
    for n, text in changes.items():
        m = re.match(r'^(\s*\.string\s+")((?:[^"\\]|\\.)*)("\s*)$', lines[n - 1].rstrip("\n"))
        lines[n - 1] = m.group(1) + text + m.group(3) + "\n"
    (ROOT / path).write_text("".join(lines), encoding="utf-8")


def load_baseline():
    if not BASELINE.exists():
        return {}
    out = {}
    for row in BASELINE.read_text(encoding="utf-8").splitlines()[1:]:
        label, text, reason = row.split("\t")
        out[(label, text)] = reason
    return out


def write_baseline(findings):
    rows = sorted({(f.msg.label, f.line.text, f.upstream) for f in findings if f.upstream})
    BASELINE.write_text("label\ttext\treason\n" + "".join(f"{a}\t{b}\t{c}\n" for a, b, c in rows), encoding="utf-8")
    return len(rows)


def describe(f):
    why = {"arrow": "under the corner arrow", "wide": "past the window edge", "below": "below the last row"}[f.kind]
    return (f"{f.where()}: {f.msg.label} [{f.window.key}] {f.width}px > {f.limit}px {why}"
            f"{' (' + f.upstream + ')' if f.upstream else ''}: {f.line.text}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--fix", action="store_true")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--hns")
    opts = ap.parse_args()
    checker = Checker()
    findings = checker.findings()
    if opts.report or opts.fix or opts.write_baseline:
        if not opts.hns:
            ap.error("--report, --fix and --write-baseline need --hns")
        classify(findings, upstream_corpus(checker.charmap, opts.hns))
    if opts.fix:
        bad = {}
        for f in findings:
            if not f.upstream:
                bad.setdefault(f.msg.label, (f.msg, set()))[1].add(f.line.lineno)
        fixed, manual = 0, []
        for label, (msg, linenos) in sorted(bad.items()):
            changes = reflow(checker, msg, linenos) if msg.path.startswith("data/") else None
            if changes is None:
                manual.append(label)
                continue
            apply_changes(msg.path, changes)
            fixed += 1
        print(f"Reflowed {fixed} messages; {len(manual)} need rewording: {', '.join(manual)}")
        return 0
    if opts.report:
        for f in findings:
            print(describe(f))
        print(f"{len(findings)} lines do not fit; {sum(1 for f in findings if f.upstream)} were cut upstream")
        return 0
    if opts.write_baseline:
        n = write_baseline(findings)
        new = [f for f in findings if not f.upstream]
        for f in new:
            print(describe(f))
        print(f"Baseline: {n} upstream lines. {len(new)} new lines still do not fit.")
        return 1 if new else 0
    baseline = load_baseline()
    keys = {f.key for f in findings}
    new = [f for f in findings if f.key not in baseline]
    stale = sorted(k for k in baseline if k not in keys)
    for f in new:
        print(describe(f))
    for label, text in stale:
        print(f"stale baseline entry, the line fits now or is gone: {label}: {text}")
    measured = sum(len(m.uses) for m in checker.messages)
    if new or stale:
        print(f"FAIL: {len(new)} lines do not fit their window; {len(stale)} stale baseline entries. "
              "Reword or reflow the line (--fix), or rerun --write-baseline after an upstream-only change.")
        return 1
    print(f"PASS: {len(checker.messages)} messages in {measured} print sites fit; {len(baseline)} upstream lines baselined")
    return 0


if __name__ == "__main__":
    sys.exit(main())
