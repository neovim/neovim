-- vim: ft=lua tw=80

-- Don't report globals from luajit or busted (e.g. jit.os or describe).
std = '+luajit +busted'

-- One can't test these files properly; assume correctness.
exclude_files = { '*/preload.lua' }

-- Don't report unused self arguments of methods.
self = false

-- Rerun tests only if their modification time changed.
cache = true

-- Ignore whitespace issues in converted Vim legacy tests.
files["functional/legacy"] = {ignore = { "611", "612", "613", "621" }}
