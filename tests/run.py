#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run the WoW-free behavioral suite in Lua 5.1 (via the local Lupa runtime)."""
from pathlib import Path

from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
runtime = LuaRuntime(unpack_returned_tuples=True)
runtime.globals().ADDON_TEST_ROOT = str(root / "addon" / "ForeverReframed")
runtime.execute((root / "tests" / "addon_spec.lua").read_text(encoding="utf-8"))
