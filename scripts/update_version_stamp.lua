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

local function iswin()
  return package.config:sub(1,1) == '\\'
end

if #arg ~= 2 then
  die(string.format("Expected two args, got %d", #arg))
end

local versiondeffile = arg[1]
local prefix = arg[2]

local dev_null = iswin() and 'NUL' or '/dev/null'
local described = io.popen('git describe --first-parent --dirty 2>'..dev_null):read('*l')
if not described then
  described = io.popen('git describe --first-parent --tags --always --dirty'):read('*l')
end
if not described then
  io.open(versiondeffile, 'w'):write('\n')
  die('git-describe failed, using empty include file.')
end

-- `git describe` annotates the most recent tagged release; for pre-release
-- builds we must replace that with the unreleased version.
local with_prefix = described:gsub("^v%d+%.%d+%.%d+", prefix)
if described == with_prefix then
  -- Prepend the prefix always, e.g. with "nightly-12208-g4041b62b9".
  with_prefix = prefix .. "-" .. described
end

-- Read existing include file.
local current = io.open(versiondeffile, 'r')
if current then
  current = current:read('*l')
end

-- Write new include file, if different.
local new = '#define NVIM_VERSION_MEDIUM "'..with_prefix..'"'
if current ~= new then
  io.open(versiondeffile, 'w'):write(new .. '\n')
end
