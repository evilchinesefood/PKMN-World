#!/usr/bin/env python3
"""Execute the lobby's reward scripts with host substitutes for bag and UI commands."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "data/maps/BattleFrontier_BattleDomeLobby/scripts.inc"
PREFIX = "BattleFrontier_BattleDomeLobby_EventScript_"
PENDING = "VAR_WORLD_CHAMPIONSHIP_PRIZES"
MODE = "VAR_WORLD_CHAMPIONSHIP_MODE"
TITLE = "FLAG_WORLD_CHAMPION"


class Lobby:
    def __init__(self, room=10, pending=0, champion=False):
        self.vars = {PENDING: pending, MODE: 0}
        self.flags = {TITLE} if champion else set()
        self.room = room
        self.caps = 0
        self.eligible = True
        self.streak_updates = 0
        self.labels = {}
        self.code = []
        for line in SCRIPT.read_text().splitlines():
            line = line.split("@", 1)[0].strip()
            if not line:
                continue
            if re.fullmatch(r"\w+::?", line):
                self.labels[line.rstrip(":")] = len(self.code)
            else:
                command, _, arguments = line.partition(" ")
                self.code.append((command, [arg.strip() for arg in arguments.split(",")]))

    def value(self, token):
        if token.startswith("VAR_"):
            return self.vars.get(token, 0)
        if token in ("TRUE", "FALSE", "YES", "NO"):
            return int(token in ("TRUE", "YES"))
        if token.startswith("FRONTIER_"):
            return token
        return int(token, 0)

    def run(self, entry):
        pc = self.labels[PREFIX + entry]
        stack = []
        stops = {self.labels[PREFIX + name]: name for name in
                 ("GiveBattlePoints", "AttendantWelcome", "AskRecordBattle")}
        for _ in range(1000):
            if pc in stops:
                return stops[pc]
            command, args = self.code[pc]
            pc += 1
            if command in ("lock", "lockall", "release", "releaseall", "faceplayer",
                           "msgbox", "message", "waitmessage", "special",
                           "frontier_setpartyorder", "frontier_checkairshow", "dome_set"):
                if command == "msgbox" and args[-1] == "MSGBOX_YESNO":
                    self.vars["VAR_RESULT"] = 1
            elif command in ("setvar", "addvar", "subvar"):
                previous = self.vars.get(args[0], 0)
                value = self.value(args[1])
                if command == "addvar":
                    value = (previous + value) & 65535
                elif command == "subvar":
                    value = (previous - value) & 65535
                self.vars[args[0]] = value
            elif command == "setflag":
                self.flags.add(args[0])
            elif command == "goto":
                pc = self.labels[args[0]]
            elif command == "goto_if_eq":
                if self.value(args[0]) == self.value(args[1]):
                    pc = self.labels[args[2]]
            elif command == "goto_if_set":
                if args[0] in self.flags:
                    pc = self.labels[args[1]]
            elif command == "call":
                if args[0] == "BattleFrontier_EventScript_IncrementWinStreak":
                    self.streak_updates += 1
                else:
                    stack.append(pc)
                    pc = self.labels[args[0]]
            elif command == "return":
                if not stack:
                    return None
                pc = stack.pop()
            elif command == "end":
                return None
            elif command == "giveitem":
                assert args == ["ITEM_GOLD_BOTTLE_CAP"], "Delivery must use one cap at a time"
                self.vars["VAR_RESULT"] = int(self.room > 0)
                if self.room:
                    self.caps += 1
                    self.room -= 1
            elif command == "frontier_isbrain":
                self.vars["VAR_RESULT"] = 0
            elif command == "callnative":
                if args[0] == "RegionHub_ScrIsThreeRegionChampion":
                    self.vars["VAR_RESULT"] = int(self.eligible)
                else:
                    assert args == ["UpdateFollowingPokemon"]
            else:
                raise AssertionError(f"Unmodeled command {command} {args}")
        raise AssertionError("Reward script did not terminate")

    def win(self):
        self.vars[MODE] = 1
        return self.run("WonChallenge")


class ChampionshipPrizes(unittest.TestCase):
    def test_first_and_repeat_win_keep_normal_reward_route(self):
        lobby = Lobby()
        self.assertEqual(lobby.win(), "GiveBattlePoints")
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.streak_updates), (1, 0, 1))
        self.assertIn(TITLE, lobby.flags)
        self.assertEqual(lobby.win(), "GiveBattlePoints")
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.streak_updates), (2, 0, 2))

    def test_existing_champion_gets_only_future_prizes(self):
        lobby = Lobby(champion=True)
        lobby.run("ClaimChampionshipPrizes")
        self.assertEqual(lobby.caps, 0)
        lobby.win()
        self.assertEqual(lobby.caps, 1)

    def test_full_bag_keeps_title_and_all_wins(self):
        lobby = Lobby(room=0)
        for _ in range(3):
            self.assertEqual(lobby.win(), "GiveBattlePoints")
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.streak_updates), (0, 3, 3))
        self.assertIn(TITLE, lobby.flags)

    def test_failed_claims_do_not_consume_prizes(self):
        lobby = Lobby(room=0, pending=3)
        for _ in range(3):
            lobby.run("ClaimChampionshipPrizes")
        self.assertEqual((lobby.caps, lobby.vars[PENDING]), (0, 3))

    def test_partial_collection_and_retry_deliver_each_prize_once(self):
        lobby = Lobby(room=1, pending=3)
        lobby.run("ClaimChampionshipPrizes")
        self.assertEqual((lobby.caps, lobby.vars[PENDING]), (1, 2))
        lobby.room = 10
        lobby.run("ClaimChampionshipPrizes")
        lobby.run("ClaimChampionshipPrizes")
        self.assertEqual((lobby.caps, lobby.vars[PENDING]), (3, 0))

    def test_registrar_collects_without_another_win_or_eligibility(self):
        lobby = Lobby(pending=2)
        lobby.eligible = False
        self.assertIsNone(lobby.run("Maniac"))
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.streak_updates), (2, 0, 0))

    def test_full_bag_still_allows_another_championship(self):
        lobby = Lobby(room=0, pending=3)
        self.assertEqual(lobby.run("Maniac"), "AttendantWelcome")
        self.assertEqual((lobby.vars[PENDING], lobby.vars[MODE]), (3, 1))

    def test_counter_capacity_prevents_overflow_and_collection_reopens_entry(self):
        lobby = Lobby(room=0, pending=65535)
        self.assertIsNone(lobby.run("Maniac"))
        self.assertEqual((lobby.vars[PENDING], lobby.vars[MODE]), (65535, 0))
        lobby.room = 1
        self.assertEqual(lobby.run("Maniac"), "AttendantWelcome")
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.vars[MODE]), (1, 65534, 1))
        lobby.win()
        self.assertEqual(lobby.vars[PENDING], 65535)

    def test_ordinary_dome_win_does_not_award_championship_prize(self):
        lobby = Lobby(pending=2)
        self.assertEqual(lobby.run("WonChallenge"), "GiveBattlePoints")
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.streak_updates), (0, 2, 1))
        self.assertNotIn(TITLE, lobby.flags)

    def test_loss_does_not_award_championship_prize(self):
        lobby = Lobby(pending=2)
        lobby.vars[MODE] = 1
        self.assertEqual(lobby.run("LostChallenge"), "AskRecordBattle")
        self.assertEqual((lobby.caps, lobby.vars[PENDING], lobby.streak_updates), (0, 2, 0))
        self.assertNotIn(TITLE, lobby.flags)

    def test_mode_is_cleared_before_existing_result_save(self):
        lobby = Lobby()
        start = lobby.labels[PREFIX + "AskRecordBattle"]
        self.assertEqual(lobby.code[start:start + 2], [
            ("setvar", [MODE, "0"]), ("dome_save", ["0"])])

    def test_counter_uses_existing_saved_slot(self):
        definitions = (ROOT / "include/constants/vars.h").read_text()
        self.assertRegex(definitions, rf"#define {PENDING}\s+0x40E5\b")
        self.assertRegex(definitions, r"#define VARS_END\s+0x40FF\b")


if __name__ == "__main__":
    unittest.main()
