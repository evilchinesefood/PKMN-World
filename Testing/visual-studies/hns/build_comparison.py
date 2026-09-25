#!/usr/bin/env python3
"""Build the pinned source comparison, without altering either game's files."""
import argparse,pathlib
from render_study import build_deliverables
p=argparse.ArgumentParser();p.add_argument('--world',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[3]);p.add_argument('--donor',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,default=pathlib.Path(__file__).parent);a=p.parse_args();build_deliverables(a.world,a.donor,a.output)
