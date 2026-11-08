#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.11"
# ///
"""The gate must close on pressure, reopen only after load settles, and never flap between."""
from importlib.machinery import SourceFileLoader
from pathlib import Path
import unittest

fleet = SourceFileLoader("fleet", str(Path(__file__).resolve().parents[1] / "fleet/fleet")).load_module()
GATE = {"close_load": 1.5, "open_load": 0.9, "min_disk_gb": 30, "min_mem_free_pct": 15}


def snap(load1=0.5, load5=0.5, disk_gb=100, mem=50, drained=0):
    return {"ncpu": 10, "load1": load1 * 10, "load5": load5 * 10,
            "disk_kb": disk_gb * 1048576, "mem_free": mem, "drained": drained}


class GateTests(unittest.TestCase):
    def test_open_host_stays_open_between_thresholds(self):
        self.assertTrue(fleet.decide(True, snap(load1=1.2, load5=1.2), GATE)[0])

    def test_closed_host_stays_closed_between_thresholds(self):
        self.assertFalse(fleet.decide(False, snap(load1=0.5, load5=1.2), GATE)[0])

    def test_spike_closes_and_settled_load_reopens(self):
        self.assertFalse(fleet.decide(True, snap(load1=2.0), GATE)[0])
        self.assertTrue(fleet.decide(False, snap(load5=0.5), GATE)[0])

    def test_disk_memory_and_drain_close_even_when_idle(self):
        for s in (snap(disk_gb=10), snap(mem=5), snap(drained=1)):
            self.assertFalse(fleet.decide(True, s, GATE)[0])


if __name__ == "__main__":
    unittest.main()
