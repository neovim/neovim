#!/usr/bin/env lua
--
-- Script to update the Git version stamp during build.
-- This is called via the custom update_version_stamp target in
-- src/nvim/CMakeLists.txt.
--
-- arg[1]: file in which to update the version string
-- arg[2]: prefix to use always ("vX.Y.Z")

local function die(msg)
  io.stderr:write(string.format('%s: %s\n', arg[0], msg))
  -- No error, fall back to using generated "-dev" version.
  os.exit(0)
end

if #arg ~= 2 then
  die(string.format("Expected two args, got %d", #arg))
end

local versiondeffile = arg[1]
local prefix = arg[2]

local current = io.popen('git describe --dirty'):read('*l')
if not current then
  current = io.popen('git describe --tags --always --dirty'):read('*l')
end
if not current then
  io.open(versiondeffile, 'w'):write('\n')
  die('git-describe failed, using empty include file.')
end

-- `git describe` annotates the most recent tagged release; for pre-release
-- builds we must replace that with the unreleased version.
local with_prefix = current:gsub("^v%d+%.%d+%.%d+", prefix)
if current == with_prefix then
  -- We might get e.g. "nightly-12208-g4041b62b9" (on Sourcehut also), so
  -- prepend the prefix always.
  with_prefix = prefix .. "-" .. current
end
local new_content = '#define NVIM_VERSION_MEDIUM "'..with_prefix..'"'

local stamp = io.open(versiondeffile, 'r')
if stamp then
  stamp = stamp:read('*l')
end
if stamp ~= new_content then
  io.open(versiondeffile, 'w'):write(new_content .. '\n')
end
