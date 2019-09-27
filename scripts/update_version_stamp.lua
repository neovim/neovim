#!/usr/bin/env lua
--
-- Script to update the Git version stamp during build.
-- This is called via the custom update_version_stamp target in
-- src/nvim/CMakeLists.txt.
--
-- arg[1]: file containing the last git-describe output
-- arg[2]: file in which to update the version string

local function die(msg)
  print(string.format('%s: %s', arg[0], msg))
  -- No error, fall back to using generated "-dev" version.
  os.exit(0)
end

if #arg ~= 2 then
  die(string.format("Expected two args, got %d", #arg))
end

local stampfile = arg[1]
local stamp = io.open(stampfile, 'r')
if stamp then
  stamp = stamp:read('*l')
end

local current = io.popen('git describe --dirty'):read('*l')
if not current then
  die('git-describe failed')
end

if stamp ~= current then
  if stamp then
    print(string.format('git version changed: %s -> %s', stamp, current))
  end
  local new_lines = {}
  local versiondeffile = arg[2]
  for line in io.lines(versiondeffile) do
    if line:match("NVIM_VERSION_MEDIUM") then
      line = '#define NVIM_VERSION_MEDIUM "'..current..'"'
    end
    new_lines[#new_lines + 1] = line
  end
  io.open(versiondeffile, 'w'):write(table.concat(new_lines, '\n') .. '\n')
  io.open(stampfile, 'w'):write(current)
end
