#!/usr/bin/env python3
"""Small topology fixtures for the placement validator, not ROM emulation."""
import unittest
from OwMonReachability import flood, approachable

NAMES = {'MB_JUMP_SOUTH': 2}

class Grid:
    def __init__(self, rows):
        self.rows = rows
    def grid(self, _):
        return len(self.rows[0]), len(self.rows), []
    def tile(self, _, x, y):
        elevation, collision, behavior = self.rows[y][x]
        return dict(elevation=elevation, collision=collision, behavior=behavior)

class ReachabilityTests(unittest.TestCase):
    def fill(self, grid):
        return flood(Grid(grid), {'layout':'test', 'warp_events':[{'x':0,'y':0}]}, NAMES, {1}, {}, {})
    def test_roof_is_not_a_walkable_approach(self):
        reached, tiles, _ = self.fill([[(3,0,0),(3,1,0),(5,0,0)],[(3,0,0),(3,1,0),(5,0,0)]])
        self.assertNotIn((2,0), reached)
        self.assertFalse(approachable({'runtime_x':2,'runtime_y':1,'elevation':5},reached,tiles))
    def test_elevation_change_needs_transition(self):
        reached, _, _ = self.fill([[(3,0,0),(5,0,0)]])
        self.assertNotIn((1,0), reached)
        reached, _, _ = self.fill([[(3,0,0),(0,0,0),(5,0,0)]])
        self.assertIn((2,0), reached)
    def test_surf_reaches_water_from_shore(self):
        reached, _, _ = self.fill([[(3,0,0),(1,0,1),(1,0,1)]])
        self.assertIn((2,0), reached)
    def test_surf_cannot_climb_elevated_bank(self):
        reached, _, _ = self.fill([[(1,0,1),(5,0,0)]])
        self.assertNotIn((1,0), reached)
        reached, _, _ = self.fill([[(5,0,0),(1,0,1)]])
        self.assertNotIn((1,0), reached)
    def test_south_ledge_jumps_to_landing(self):
        reached, _, _ = self.fill([[(3,0,0)],[(3,1,2)],[(3,0,0)]])
        self.assertIn((0,2), reached)
        self.assertNotIn((0,1), reached)
    def test_collision_blocks_even_matching_elevation(self):
        reached, _, _ = self.fill([[(3,0,0),(3,1,0),(3,0,0)]])
        self.assertNotIn((2,0), reached)

if __name__ == '__main__':
    unittest.main()
