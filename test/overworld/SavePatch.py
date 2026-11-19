#!/usr/bin/env python3
"""Inspect battery saves and verify the game's sector geometry and current save ABI.

With a save argument, report slot health and version. Decode gameplay fields only
for the supported layout. Use --check for source pins and --probe to verify the
field offsets with the game's ARM compiler.
"""
import argparse
import os
import re
import struct
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# --- sector geometry (include/save.h) -----------------------------------------
SECTOR_DATA_SIZE = 3968
SB3_CHUNK = 116
FOOTER = 12
SECTOR_SIZE = SECTOR_DATA_SIZE + SB3_CHUNK + FOOTER      # 4096
SECTORS_PER_SLOT = 14
NUM_SLOTS = 2
SIGNATURE = 0x8012025
FLASH_SIZE = SECTOR_SIZE * 32                            # 131072

ID_SB2, ID_SB1_START, ID_SB1_END = 0, 1, 4
ID_PK_START, ID_PK_END = 5, 13

SAVE_FORMAT_VERSION = 14
SAVE_FORMAT_LAYOUT_MIN = 14

# --- probed values ------------------------------------------------------------
# name -> (C expression, value). --probe compiles the expressions and diffs the values, so
# this table is both the source of truth used below AND the probe's own script. Do not add a
# value here without its expression; an unprobeable entry is an unverifiable one.
PROBED = {
    'SB1_SIZE':            ('sizeof(struct SaveBlock1)', 14752),
    'SB2_SIZE':            ('sizeof(struct SaveBlock2)', 3884),
    'SB3_SIZE':            ('sizeof(struct SaveBlock3)', 1408),
    'PK_SIZE':             ('sizeof(struct PokemonStorage)', 34144),

    'SB1.playerPartyCount': ('offsetof(struct SaveBlock1, playerPartyCount)', 564),
    'SB1.playerParty':     ('offsetof(struct SaveBlock1, playerParty)', 568),
    'PARTY_SIZE':          ('PARTY_SIZE', 6),
    'DAYCARE_MON_COUNT':   ('DAYCARE_MON_COUNT', 2),
    'MAX_FUSION_STORAGE':  ('MAX_FUSION_STORAGE', 4),
    'SB1.money':           ('offsetof(struct SaveBlock1, money)', 1168),
    'PC_ITEMS_COUNT':      ('PC_ITEMS_COUNT', 150),
    'BAG_KEYITEMS_COUNT':  ('BAG_KEYITEMS_COUNT', 99),
    'SB1.flags':           ('offsetof(struct SaveBlock1, flags)', 5524),
    'SB1.gameStats':       ('offsetof(struct SaveBlock1, gameStats)', 6556),
    'SB1.dexSeen':         ('offsetof(struct SaveBlock1, dexSeen)', 13900),
    'SB1.dexCaught':       ('offsetof(struct SaveBlock1, dexCaught)', 14029),
    'NUM_DEX_FLAG_BYTES':  ('NUM_DEX_FLAG_BYTES', 129),


    'SB2.playerGender':    ('offsetof(struct SaveBlock2, playerGender)', 8),
    'SB2.playerTrainerId': ('offsetof(struct SaveBlock2, playerTrainerId)', 10),
    'SB2.playTimeHours':   ('offsetof(struct SaveBlock2, playTimeHours)', 14),
    'SB2.playTimeMinutes': ('offsetof(struct SaveBlock2, playTimeMinutes)', 16),
    'SB2.playTimeSeconds': ('offsetof(struct SaveBlock2, playTimeSeconds)', 17),
    'SB2.encryptionKey':   ('offsetof(struct SaveBlock2, encryptionKey)', 172),
    'SB2.currentRegion':   ('offsetof(struct SaveBlock2, currentRegion)', 144),
    'SB2.saveVersion':     ('offsetof(struct SaveBlock2, saveVersion)', 145),
    'SB2.regionChecksum':  ('offsetof(struct SaveBlock2, regionChecksum)', 148),

    'SB3.region':          ('offsetof(struct SaveBlock3, region)', 8),
    'RS.size':             ('sizeof(struct RegionSave)', 1400),
    'RS.johtoFlags':       ('offsetof(struct RegionSave, johtoFlags)', 768),
    'RS.obstacleTableHash': ('offsetof(struct RegionSave, obstacleTableHash)', 1132),
    'RS.clearedObstacleBits': ('offsetof(struct RegionSave, clearedObstacleBits)', 1136),
    'RS.johtoTrainerFlags': ('offsetof(struct RegionSave, johtoTrainerFlags)', 1200),
    'RS.regionalTravel':   ('offsetof(struct RegionSave, regionalTravel)', 1232),
    'RegionalTravel.size': ('sizeof(struct RegionalTravelSave)', 168),
    'NUM_JOHTO_TRAINER_FLAG_BYTES': ('NUM_JOHTO_TRAINER_FLAG_BYTES', 32),
    'CLEARED_OBSTACLE_TABLE_HASH': ('CLEARED_OBSTACLE_TABLE_HASH', 0xCF719B0B),

    'FLAG_BADGE01_GET':    ('FLAG_BADGE01_GET', 2383),
    'FLAG_KANTO_BADGE_1':  ('FLAG_KANTO_BADGE_1', 2635),
    'FLAG_JOHTO_BADGE_1':  ('FLAG_JOHTO_BADGE_1', 25592),
    'FLAG_JOHTO_BASE':     ('FLAG_JOHTO_BASE', 0x6000),
    'FLAG_KANTO_CHAMPION': ('FLAG_KANTO_CHAMPION', 2632),
    'FLAG_JOHTO_CHAMPION': ('FLAG_JOHTO_CHAMPION', 2633),
    'FLAG_HOENN_CHAMPION': ('FLAG_HOENN_CHAMPION', 2634),
}
V = {k: v for k, (_, v) in PROBED.items()}

SB1_SIZE, SB2_SIZE = V['SB1_SIZE'], V['SB2_SIZE']
SB3_SIZE, PK_SIZE = V['SB3_SIZE'], V['PK_SIZE']
SB3_REGION_OFF = V['SB3.region']
REGION_SIZE = V['RS.size']
JOHTO_TRAINER_BYTES = V['NUM_JOHTO_TRAINER_FLAG_BYTES']

WARPS = ('location', 'continueGameWarp', 'dynamicWarp', 'lastHealLocation', 'escapeWarp')

CHARMAP = {0x00: ' ', 0xFF: ''}
for _i in range(10):
    CHARMAP[0xA1 + _i] = chr(ord('0') + _i)
for _i in range(26):
    CHARMAP[0xBB + _i] = chr(ord('A') + _i)
for _i in range(26):
    CHARMAP[0xD5 + _i] = chr(ord('a') + _i)


# --- constant pinning ---------------------------------------------------------
# (label, path, regex capturing one integer, expected). Only values the tree actually pins;
# everything else is --probe's job. A miss here means the format moved under the tool.
PINS = [
    ('SAVE_FORMAT_VERSION', 'include/constants/global.h',
     r'^#define SAVE_FORMAT_VERSION\s+(\d+)', SAVE_FORMAT_VERSION),
    ('SAVE_FORMAT_LAYOUT_MIN', 'include/constants/global.h',
     r'^#define SAVE_FORMAT_LAYOUT_MIN\s+(\d+)', SAVE_FORMAT_LAYOUT_MIN),
    ('SECTOR_DATA_SIZE', 'include/save.h',
     r'^#define SECTOR_DATA_SIZE\s+(\d+)', SECTOR_DATA_SIZE),
    ('SAVE_BLOCK_3_CHUNK_SIZE', 'include/save.h',
     r'^#define SAVE_BLOCK_3_CHUNK_SIZE\s+(\d+)', SB3_CHUNK),
    ('SECTOR_FOOTER_SIZE', 'include/save.h', r'^#define SECTOR_FOOTER_SIZE\s+(\d+)', FOOTER),
    ('NUM_SECTORS_PER_SLOT', 'include/save.h',
     r'^#define NUM_SECTORS_PER_SLOT\s+(\d+)', SECTORS_PER_SLOT),
    ('NUM_SAVE_SLOTS', 'include/save.h', r'^#define NUM_SAVE_SLOTS\s+(\d+)', NUM_SLOTS),
    ('SECTOR_SIGNATURE', 'include/save.h', r'^#define SECTOR_SIGNATURE\s+(0x[0-9A-Fa-f]+)', SIGNATURE),
    ('SECTOR_ID_SAVEBLOCK1_END', 'include/save.h',
     r'^#define SECTOR_ID_SAVEBLOCK1_END\s+(\d+)', ID_SB1_END),
    ('SECTOR_ID_PKMN_STORAGE_END', 'include/save.h',
     r'^#define SECTOR_ID_PKMN_STORAGE_END\s+(\d+)', ID_PK_END),
    ('T_SAVEBLOCK1_SIZE', 'test/save.c', r'^#define T_SAVEBLOCK1_SIZE\s+(\d+)', SB1_SIZE),
    ('T_SAVEBLOCK2_SIZE', 'test/save.c', r'^#define T_SAVEBLOCK2_SIZE\s+(\d+)', SB2_SIZE),
    ('T_SAVEBLOCK3_SIZE', 'test/save.c', r'^#define T_SAVEBLOCK3_SIZE\s+(\d+)', SB3_SIZE),
    ('T_POKEMONSTORAGE_SIZE', 'test/save.c', r'^#define T_POKEMONSTORAGE_SIZE\s+(\d+)', PK_SIZE),
    ('sizeof(struct RegionSave)', 'src/load_save.c',
     r'STATIC_ASSERT\(sizeof\(struct RegionSave\) == (\d+)', REGION_SIZE),
    ('offsetof(SaveBlock3, region)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct SaveBlock3, region\) == (0x[0-9A-Fa-f]+)', SB3_REGION_OFF),
    ('offsetof(RegionSave, johtoFlags)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct RegionSave, johtoFlags\) == (\d+)', V['RS.johtoFlags']),
    ('offsetof(RegionSave, obstacleTableHash)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct RegionSave, obstacleTableHash\) == (\d+)',
     V['RS.obstacleTableHash']),
    ('offsetof(RegionSave, clearedObstacleBits)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct RegionSave, clearedObstacleBits\) == (\d+)',
     V['RS.clearedObstacleBits']),
    ('offsetof(RegionSave, johtoTrainerFlags)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct RegionSave, johtoTrainerFlags\) == (\d+)',
     V['RS.johtoTrainerFlags']),
    ('offsetof(RegionSave, regionalTravel)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct RegionSave, regionalTravel\) == (\d+)',
     V['RS.regionalTravel']),
    ('sizeof(RegionalTravelSave)', 'include/global.h',
     r'STATIC_ASSERT\(sizeof\(struct RegionalTravelSave\) == (\d+)',
     V['RegionalTravel.size']),
    ('offsetof(SaveBlock2, currentRegion)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct SaveBlock2, currentRegion\) == (0x[0-9A-Fa-f]+)',
     V['SB2.currentRegion']),
    ('offsetof(SaveBlock2, regionChecksum)', 'src/load_save.c',
     r'STATIC_ASSERT\(offsetof\(struct SaveBlock2, regionChecksum\) == (0x[0-9A-Fa-f]+)',
     V['SB2.regionChecksum']),
    ('NUM_JOHTO_TRAINER_FLAG_BYTES', 'include/constants/region_flags.h',
     r'^#define NUM_JOHTO_TRAINER_FLAG_BYTES\s+\(JOHTO_TRAINER_FLAG_BANK_SIZE / 8\)\s*//\s*(\d+)',
     JOHTO_TRAINER_BYTES),
    ('CLEARED_OBSTACLE_TABLE_HASH', 'include/constants/cleared_obstacles.h',
     r'^#define CLEARED_OBSTACLE_TABLE_HASH\s+(0x[0-9A-Fa-f]+)', V['CLEARED_OBSTACLE_TABLE_HASH']),
]


def check_pins(verbose=False):
    """Re-read every tree-pinned constant. Returns a list of human-readable problems."""
    bad = []
    for label, rel, pattern, expect in PINS:
        path = os.path.join(REPO, rel)
        try:
            with open(path, encoding='utf-8') as fh:
                text = fh.read()
        except OSError as e:
            bad.append(f'{label}: cannot read {rel} ({e})')
            continue
        m = re.search(pattern, text, re.M)
        if not m:
            bad.append(f'{label}: no longer found in {rel} (pattern moved or was renamed)')
            continue
        got = int(m.group(1), 0)
        if got != expect:
            bad.append(f'{label}: {rel} says {got} (0x{got:X}), this tool assumes '
                       f'{expect} (0x{expect:X})')
        elif verbose:
            print(f'  ok  {label:42s} = {got} ({rel})')
    return bad


def require_pins():
    bad = check_pins()
    if bad:
        sys.stderr.write('SavePatch.py: the save format moved under this tool.\n')
        for b in bad:
            sys.stderr.write(f'  - {b}\n')
        sys.stderr.write('Re-derive with --probe and update PROBED/PINS before touching a save.\n')
        raise SystemExit(2)


def probe():
    """Recompile every PROBED expression with the repo CFLAGS and diff against the table."""
    cc = None
    candidates = [os.environ['ARM_CC']] if os.environ.get('ARM_CC') else [
        os.path.join(os.environ.get('DEVKITARM', '/opt/devkitpro/devkitARM'),
                     'bin', 'arm-none-eabi-gcc'), 'arm-none-eabi-gcc']
    for cand in candidates:
        if os.path.isfile(cand) or subprocess.run(['which', cand], capture_output=True).returncode == 0:
            cc = cand
            break
    if cc is None:
        sys.stderr.write('arm-none-eabi-gcc not found (set DEVKITARM); cannot probe.\n')
        return 2

    names = list(PROBED)
    src = ('#include "global.h"\n#include "save.h"\n#include "constants/global.h"\n'
           '#include "pokemon_storage_system.h"\n#include "constants/flags.h"\n'
           '#include "constants/region_flags.h"\n#include "constants/cleared_obstacles.h"\n'
           '#include "constants/items.h"\n#include "constants/vars.h"\n'
           '#include "constants/map_event_ids.h"\n'
           'const unsigned int gProbe[] = {\n'
           + ''.join(f'    (unsigned int)({PROBED[n][0]}),\n' for n in names) + '};\n')
    with tempfile.TemporaryDirectory() as td:
        cpath, spath = os.path.join(td, 'probe.c'), os.path.join(td, 'probe.s')
        with open(cpath, 'w', encoding='utf-8') as fh:
            fh.write(src)
        cmd = [cc, '-S', '-o', spath, cpath, '-iquote', 'include', '-Wno-trigraphs',
               '-DMODERN=1', '-DTESTING=0', '-DEMERALD', '-DALL_REGIONS=1', '-std=gnu17',
               '-mthumb', '-mthumb-interwork', '-O2', '-mabi=apcs-gnu', '-mtune=arm7tdmi',
               '-march=armv4t', '-Wno-pointer-to-int-cast', '-Wno-strict-aliasing']
        r = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
        if r.returncode != 0:
            sys.stderr.write(r.stderr)
            return 2
        with open(spath, encoding='utf-8') as fh:
            words = [int(m.group(1)) & 0xFFFFFFFF
                     for m in re.finditer(r'^\s+\.word\s+(-?\d+)', fh.read(), re.M)]

    if len(words) != len(names):
        sys.stderr.write(f'probe emitted {len(words)} words for {len(names)} expressions\n')
        return 2
    bad = 0
    for name, got in zip(names, words):
        want = PROBED[name][1] & 0xFFFFFFFF
        if got != want:
            print(f'  DRIFT {name:32s} tool={want} (0x{want:X})  build={got} (0x{got:X})')
            bad += 1
    print(f'probe: {len(names) - bad}/{len(names)} match the build')
    return 1 if bad else 0


# --- save file ----------------------------------------------------------------
def calc_checksum(data, size):
    """src/save.c CalculateChecksum — sum size/4 LE u32s, then (sum >> 16) + sum, u16."""
    total = 0
    for i in range(size // 4):
        total = (total + struct.unpack_from('<I', data, i * 4)[0]) & 0xFFFFFFFF
    return ((total >> 16) + total) & 0xFFFF


def _slot_layout():
    """sSaveSlotLayout (src/save.c SAVEBLOCK_CHUNK): (offset, size) per logical sector id."""
    out = []
    for i in range(SECTORS_PER_SLOT):
        if i == ID_SB2:
            total, chunk = SB2_SIZE, 0
        elif ID_SB1_START <= i <= ID_SB1_END:
            total, chunk = SB1_SIZE, i - ID_SB1_START
        else:
            total, chunk = PK_SIZE, i - ID_PK_START
        off = chunk * SECTOR_DATA_SIZE
        out.append((off, max(0, min(total - off, SECTOR_DATA_SIZE))))
    return out


SLOT_LAYOUT = _slot_layout()


def sb3_chunk_size(sector_id):
    begin, end = sector_id * SB3_CHUNK, (sector_id + 1) * SB3_CHUNK
    return max(0, min(end, SB3_SIZE) - begin)


class Sector:
    def __init__(self, flash, phys):
        self.phys = phys
        base = phys * SECTOR_SIZE
        self.raw = flash[base:base + SECTOR_SIZE]
        self.id, self.checksum, self.signature, self.counter = struct.unpack_from(
            '<HHII', self.raw, SECTOR_DATA_SIZE + SB3_CHUNK)

    @property
    def data(self):
        return self.raw[:SECTOR_DATA_SIZE]

    @property
    def sb3(self):
        return self.raw[SECTOR_DATA_SIZE:SECTOR_DATA_SIZE + SB3_CHUNK]

    def valid(self):
        if self.signature != SIGNATURE or self.id >= SECTORS_PER_SLOT:
            return False
        return self.checksum == calc_checksum(self.data, SLOT_LAYOUT[self.id][1])


class Save:
    """One battery file. Anything past FLASH_SIZE is a trailer (mGBA appends 16 bytes of RTC
    state for a cart with a clock) and is carried through untouched — a .srm off a flashcart
    has none, and giving it one is a real difference, not cosmetic."""

    def __init__(self, path, slot=None):
        with open(path, 'rb') as fh:
            blob = fh.read()
        if len(blob) < FLASH_SIZE:
            raise SystemExit(f'{path}: {len(blob)} bytes, need at least {FLASH_SIZE}')
        self.path = path
        self.flash = bytearray(blob[:FLASH_SIZE])
        self.trailer = blob[FLASH_SIZE:]
        self._scan(slot)

    def _scan(self, force_slot=None):
        self.slots = []
        for s in range(NUM_SLOTS):
            secs = [Sector(self.flash, s * SECTORS_PER_SLOT + i) for i in range(SECTORS_PER_SLOT)]
            sig_valid = any(x.signature == SIGNATURE for x in secs)
            flags, counter = 0, 0
            for x in secs:
                if x.signature == SIGNATURE and x.valid():
                    flags |= 1 << x.id
                    counter = x.counter
            if not sig_valid:
                status = 'EMPTY'
            elif flags == (1 << SECTORS_PER_SLOT) - 1 and counter % NUM_SLOTS == s:
                status = 'OK'
            else:
                status = 'ERROR'
            self.slots.append(dict(sectors=secs, status=status, counter=counter, flags=flags))

        # GetSaveValidStatus (src/save.c), including its u32-wrap tie-break.
        a, b = self.slots
        if a['status'] == 'OK' and b['status'] == 'OK':
            ca, cb = a['counter'], b['counter']
            if (ca == 0xFFFFFFFF and cb == 0) or (ca == 0 and cb == 0xFFFFFFFF):
                self.save_counter = cb if ((ca + 1) & 0xFFFFFFFF) < ((cb + 1) & 0xFFFFFFFF) else ca
            else:
                self.save_counter = cb if ca < cb else ca
            self.status = 'OK'
        elif a['status'] == 'OK':
            self.save_counter = a['counter']
            self.status = 'ERROR' if b['status'] == 'ERROR' else 'OK'
        elif b['status'] == 'OK':
            self.save_counter = b['counter']
            self.status = 'ERROR' if a['status'] == 'ERROR' else 'OK'
        else:
            self.save_counter = 0
            self.status = 'EMPTY' if a['status'] == b['status'] == 'EMPTY' else 'CORRUPT'
        self.active = self.save_counter % NUM_SLOTS if force_slot is None else force_slot
        self.gather()

    def gather(self):
        """CopySaveSlotData: only sectors with a good signature AND checksum contribute."""
        self.sb1 = bytearray(SB1_SIZE)
        self.sb2 = bytearray(SB2_SIZE)
        self.sb3 = bytearray(SB3_SIZE)
        self.pk = bytearray(PK_SIZE)
        self.holder = {}
        for sec in self.slots[self.active]['sectors']:
            if not sec.valid():
                continue
            off, size = SLOT_LAYOUT[sec.id]
            dst = self.sb2 if sec.id == ID_SB2 else (self.sb1 if sec.id <= ID_SB1_END else self.pk)
            dst[off:off + size] = sec.data[:size]
            n = sb3_chunk_size(sec.id)
            if n:
                self.sb3[sec.id * SB3_CHUNK: sec.id * SB3_CHUNK + n] = sec.sb3[:n]
            self.holder[sec.id] = sec.phys

    def intact_older_version(self):
        """Identify an old slot whose last chunk no longer has the current size."""
        for slot_index, slot in enumerate(self.slots):
            sectors = slot['sectors']
            if {sec.id for sec in sectors} != set(range(SECTORS_PER_SLOT)):
                continue
            counter = sectors[0].counter
            if counter % NUM_SLOTS != slot_index or any(
                    sec.signature != SIGNATURE or sec.counter != counter
                    or sec.checksum != calc_checksum(sec.data, SECTOR_DATA_SIZE)
                    for sec in sectors):
                continue
            header = next(sec for sec in sectors if sec.id == ID_SB2)
            version = header.data[V['SB2.saveVersion']]
            if version < SAVE_FORMAT_LAYOUT_MIN:
                return version
        return None

    def writeback(self):
        """Push the gathered blocks into the active slot's physical sectors and re-checksum.
        Mirrors HandleWriteSector: the checksum covers data[0:size] only, so a SaveBlock3 edit
        moves no checksum. Sectors that failed validation contributed nothing and are not
        rewritten — reconstructing one from a zeroed block would invent data."""
        for sid, phys in sorted(self.holder.items()):
            base = phys * SECTOR_SIZE
            off, size = SLOT_LAYOUT[sid]
            src = self.sb2 if sid == ID_SB2 else (self.sb1 if sid <= ID_SB1_END else self.pk)
            self.flash[base:base + size] = src[off:off + size]
            n = sb3_chunk_size(sid)
            if n:
                d = base + SECTOR_DATA_SIZE
                self.flash[d:d + n] = self.sb3[sid * SB3_CHUNK: sid * SB3_CHUNK + n]
            cs = calc_checksum(self.flash[base:base + SECTOR_DATA_SIZE], size)
            struct.pack_into('<H', self.flash, base + SECTOR_DATA_SIZE + SB3_CHUNK + 2, cs)

    # -- readers --
    def u8(self, buf, off):
        return buf[off]

    def u16(self, buf, off):
        return struct.unpack_from('<H', buf, off)[0]

    def u32(self, buf, off):
        return struct.unpack_from('<I', buf, off)[0]

    def s16(self, buf, off):
        return struct.unpack_from('<h', buf, off)[0]

    def warp(self, field):
        """WarpData is 8 bytes: 0 group(s8), 1 num, 2 warpId, 3 PAD, 4 x(s16), 6 y(s16).
        Reading x at +3 shifts it a byte and looks exactly like corruption."""
        o = V['SB1.' + field]
        return (struct.unpack_from('<b', self.sb1, o)[0], self.sb1[o + 1], self.sb1[o + 2],
                self.s16(self.sb1, o + 4), self.s16(self.sb1, o + 6))

    def name(self):
        return ''.join(CHARMAP.get(c, '?') for c in self.sb2[0:7]).strip()

    def flag(self, fid):
        """GetFlagPointer's split: the Johto bank lives in SaveBlock3, everything below it
        is inline in SaveBlock1.flags[]."""
        if fid >= V['FLAG_JOHTO_BASE']:
            base = SB3_REGION_OFF + V['RS.johtoFlags']
            idx = fid - V['FLAG_JOHTO_BASE']
            return (self.sb3[base + idx // 8] >> (idx & 7)) & 1
        return (self.sb1[V['SB1.flags'] + fid // 8] >> (fid & 7)) & 1

    def region_checksum(self):
        """Mirror the current RegionSave checksum in src/load_save.c."""
        total = sum(self.sb3[SB3_REGION_OFF:SB3_REGION_OFF + REGION_SIZE])
        return (total + (total >> 16)) & 0xFFFF

    def money(self):
        return self.u32(self.sb1, V['SB1.money']) ^ self.u32(self.sb2, V['SB2.encryptionKey'])

    def game_stat(self, index):
        return (self.u32(self.sb1, V['SB1.gameStats'] + index * 4)
                ^ self.u32(self.sb2, V['SB2.encryptionKey'])) & 0xFFFFFFFF

    def party(self):
        n = self.sb1[V['SB1.playerPartyCount']]
        out = []
        for i in range(min(n, 6)):
            b = V['SB1.playerParty'] + i * 100
            out.append(dict(level=self.sb1[b + 84], hp=self.u16(self.sb1, b + 86),
                            maxhp=self.u16(self.sb1, b + 88)))
        return n, out

    def dex_counts(self):
        n = V['NUM_DEX_FLAG_BYTES']
        seen = sum(bin(b).count('1') for b in self.sb1[V['SB1.dexSeen']:V['SB1.dexSeen'] + n])
        owned = sum(bin(b).count('1') for b in self.sb1[V['SB1.dexCaught']:V['SB1.dexCaught'] + n])
        return owned, seen

    def badges(self, first):
        return sum(self.flag(first + i) for i in range(8))


def self_test(path, slot=None):
    """Guard 2: a no-op round trip must be byte-identical. If it is not, the sector mapping
    or the checksum arithmetic is wrong for THIS file and nothing may be written. See the
    module docstring on what this does NOT catch."""
    sv = Save(path, slot=slot)
    before = bytes(sv.flash)
    sv.writeback()
    if bytes(sv.flash) != before:
        for i, (a, b) in enumerate(zip(before, sv.flash)):
            if a != b:
                raise SystemExit(
                    f'{path}: round-trip self-test FAILED — first difference at 0x{i:05X} '
                    f'(sector {i // SECTOR_SIZE}, offset 0x{i % SECTOR_SIZE:03X}): '
                    f'{a:02X} -> {b:02X}. Refusing to write.')
    return sv


def require_intact_slot(sv):
    """Require every sector of the selected slot to have a valid signature and checksum."""
    slot = sv.slots[sv.active]
    missing = [i for i in range(SECTORS_PER_SLOT) if i not in sv.holder]
    if missing:
        raise SystemExit(
            f'{sv.path}: slot {sv.active} is {slot["status"]} — logical sectors {missing} '
            'failed signature or checksum, so their bytes are absent from the gathered '
            'blocks. Select an intact slot.')


# --- reporting ----------------------------------------------------------------
def describe(sv):
    out = []
    p = out.append
    total = FLASH_SIZE + len(sv.trailer)
    p(f'=== {os.path.basename(sv.path)} ===')
    p(f'  file           {total} bytes'
      + (f' ({len(sv.trailer)}-byte trailer: mGBA RTC state)' if sv.trailer else ' (raw flash)'))
    for i, s in enumerate(sv.slots):
        p(f'  slot {i}         {s["status"]:6s} counter={s["counter"]:<6d} '
          f'sectors ok={bin(s["flags"]).count("1")}/{SECTORS_PER_SLOT}')
    if sv.status == 'CORRUPT':
        version = sv.intact_older_version()
        if version is not None:
            p(f'  saveVersion    {version} (refused: older than supported format {SAVE_FORMAT_VERSION})')
            return '\n'.join(out)
    p(f'  overall        {sv.status}, reading slot {sv.active} (gSaveCounter={sv.save_counter})')
    ver = sv.sb2[V['SB2.saveVersion']]
    if sv.slots[sv.active]['status'] != 'OK':
        return '\n'.join(out)
    if ver < SAVE_FORMAT_LAYOUT_MIN or ver > SAVE_FORMAT_VERSION:
        direction = 'older' if ver < SAVE_FORMAT_LAYOUT_MIN else 'newer'
        p(f'  saveVersion    {ver} (refused: {direction} than supported format {SAVE_FORMAT_VERSION})')
        return '\n'.join(out)
    p(f'  saveVersion    {ver} (current)   currentRegion={sv.sb2[V["SB2.currentRegion"]]}')
    p(f'  trainer        {sv.name()!r} id={sv.u16(sv.sb2, V["SB2.playerTrainerId"]):05d} '
      f'{"F" if sv.sb2[V["SB2.playerGender"]] else "M"}')
    p(f'  play time      {sv.u16(sv.sb2, V["SB2.playTimeHours"])}h '
      f'{sv.sb2[V["SB2.playTimeMinutes"]]}m {sv.sb2[V["SB2.playTimeSeconds"]]}s'
      f'   saves={sv.game_stat(0)}')
    stored, calc = sv.u16(sv.sb2, V['SB2.regionChecksum']), sv.region_checksum()
    p(f'  regionChecksum stored=0x{stored:04X} computed=0x{calc:04X} '
      + ('match' if stored == calc else 'MISMATCH -> main menu warns "region save damaged"'))
    p(f'  money          ${sv.money()}')
    n, party = sv.party()
    p(f'  party          {n}: ' + ', '.join(f'Lv{m["level"]}({m["hp"]}/{m["maxhp"]})'
                                            for m in party))
    owned, seen = sv.dex_counts()
    p(f'  pokedex        owned={owned} seen={seen}')
    p(f'  badges         Hoenn={sv.badges(V["FLAG_BADGE01_GET"])} '
      f'Johto={sv.badges(V["FLAG_JOHTO_BADGE_1"])} Kanto={sv.badges(V["FLAG_KANTO_BADGE_1"])}'
      f'   champion H={sv.flag(V["FLAG_HOENN_CHAMPION"])} J={sv.flag(V["FLAG_JOHTO_CHAMPION"])} '
      f'K={sv.flag(V["FLAG_KANTO_CHAMPION"])}')
    for field in WARPS:
        g, m, wid, x, y = sv.warp(field)
        p(f'  {field:18s} {g}/{m} warpId={wid} ({x},{y})')
    dirty = sum(1 for b in sv.sb3[SB3_REGION_OFF + V['RS.johtoTrainerFlags']:
                                  SB3_REGION_OFF + V['RS.johtoTrainerFlags'] + JOHTO_TRAINER_BYTES]
                if b)
    p(f'  johtoTrainerFlags  {dirty}/{JOHTO_TRAINER_BYTES} non-zero bytes')
    h = sv.u32(sv.sb3, SB3_REGION_OFF + V['RS.obstacleTableHash'])
    p(f'  obstacleTableHash  0x{h:08X} '
      + ('(matches the build)' if h == V['CLEARED_OBSTACLE_TABLE_HASH']
         else f'(build wants 0x{V["CLEARED_OBSTACLE_TABLE_HASH"]:08X}; obstacles regrow once)'))
    return '\n'.join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('saves', nargs='*', help='.sav / .srm files')
    ap.add_argument('--slot', type=int, choices=(0, 1),
                    help='read this slot instead of the one the game would pick')
    ap.add_argument('--check', action='store_true',
                    help='verify this tool\'s constants still match the tree, then exit')
    ap.add_argument('--probe', action='store_true',
                    help='re-derive every offset with arm-none-eabi-gcc and diff')
    ap.add_argument('-v', '--verbose', action='store_true',
                    help='with --check, list every constant rather than only drift')
    args = ap.parse_args()

    # Silent on success, like the other test/overworld/ validators: this runs in the pre-push gate.
    if args.check:
        bad = check_pins(verbose=args.verbose)
        for b in bad:
            sys.stderr.write(f'  DRIFT {b}\n')
        if bad:
            sys.stderr.write(f'{len(bad)}/{len(PINS)} save-format constants have drifted; '
                             'SavePatch.py must be updated (--probe re-derives them) before '
                             'it is used on a real save.\n')
            return 1
        if args.verbose:
            print(f'{len(PINS)}/{len(PINS)} constants match the tree')
        return 0
    if args.probe:
        require_pins()
        return probe()

    require_pins()
    if not args.saves:
        ap.error('nothing to do: pass a save, or --check / --probe')

    for path in args.saves:
        print(describe(Save(path, slot=args.slot)))
        print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
