-- Per-region data for natural.lua: gym beats with the plan's ace levels and grind allowances,
-- catch beats for the team of three, and done-predicate replacements for beats written around
-- the debug pair.
return {
  johto = {
    gyms = {
      { beat = 'falkner', ace = 11, limit = 1000 }, { beat = 'bugsy', ace = 16, limit = 1000 },
      { beat = 'whitney', ace = 21, limit = 1000 }, { beat = 'morty', ace = 25, limit = 1000 },
      { beat = 'chuck', ace = 31, limit = 1000 }, { beat = 'jasmine', ace = 36, limit = 1000 },
      { beat = 'pryce', ace = 38, limit = 1000 }, { beat = 'clair', ace = 45, limit = 1000 },
      { beat = 'league_entry', ace = 56, limit = 2000 },
    },
    exclude = { 'SPECIES_TOGEPI', 'SPECIES_TOGETIC', 'SPECIES_TOGEKISS' },
    catches = {
      { after = 'mom_farewell', map = 'Route31', species = 'SPECIES_MAREEP', budget = 500 },
      { after = 'route32_gate', map = 'Route32', species = 'SPECIES_WOOPER', budget = 400 },
    },
    done = {
      starter = function(F, N, C) return function() return N.flag(C.FLAG_JOHTO_STARTER_CHOSEN) and N.partyCount() == 1 end end,
    },
  },
  -- Run with PW_STARTER=1 (Squirtle, the Surf carrier); catch_cut_user adds the Cut carrier.
  kanto = {
    gyms = {
      { beat = 'brock', ace = 14, limit = 1000 }, { beat = 'misty', ace = 21, limit = 1000 },
      { beat = 'surge', ace = 24, limit = 1000 }, { beat = 'erika', ace = 29, limit = 1000 },
      { beat = 'koga', ace = 43, limit = 2000 }, { beat = 'sabrina', ace = 43, limit = 1000 },
      { beat = 'blaine', ace = 47, limit = 1000 }, { beat = 'giovanni', ace = 50, limit = 1000 },
      { beat = 'to_league', ace = 63, limit = 2000 },
    },
    catches = {
      { after = 'brock', map = 'MtMoon_1F_Frlg', species = 'SPECIES_GEODUDE', budget = 600, cave = true },
    },
    done = {
      catch_cut_user = function(F, N, C) return function() return N.partyCount() == 2 end end,
    },
  },
  hoenn = {
    gyms = {
      { beat = 'roxanne', ace = 15, limit = 1000 }, { beat = 'brawly', ace = 19, limit = 1000 },
      { beat = 'wattson', ace = 24, limit = 1000 }, { beat = 'flannery', ace = 29, limit = 1000 },
      { beat = 'norman', ace = 31, limit = 1000 }, { beat = 'winona', ace = 33, limit = 1000 },
      { beat = 'tate_liza', ace = 42, limit = 2000 }, { beat = 'juan', ace = 46, limit = 1000 },
      { beat = 'league_gate', ace = 58, limit = 2000 },
    },
    catches = {
      { after = 'pokedex', map = 'Route101', species = 'SPECIES_MUDKIP', budget = 500 },
      { after = 'route110', map = 'Route110', species = 'SPECIES_ELECTRIKE', budget = 400 },
    },
    done = {},
  },
}
