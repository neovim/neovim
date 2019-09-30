#!/usr/bin/env lua
--
-- Script to update the Git version stamp during build.
-- This is called via the custom update_version_stamp target in
-- src/nvim/CMakeLists.txt.
--
-- arg[1]: file in which to update the version string
-- arg[2]: prefix to use always ("vX.Y.Z")

local function die(msg)
  print(string.format('%s: %s', arg[0], msg))
  -- No error, fall back to using generated "-dev" version.
  os.exit(0)
end

if #arg ~= 2 then
  die(string.format("Expected two args, got %d", #arg))
end

local versiondeffile = arg[1]
local stamp = io.open(versiondeffile, 'r')
if stamp then
  stamp = stamp:read('*l')
end

local current = io.popen('git describee --dirty'):read('*l')
if not current then
  print('git-describe failed')
  print('debug: --always', io.popen('git describe --always --dirty'):read('*l'))
  print('debug: --tags', io.popen('git describe --tags --dirty'):read('*l'))
  print('debug: --tags --always', io.popen('git describe --tags --always --dirty'):read('*l'))

  current = io.popen('git describe --always --dirty'):read('*l')
  if not current then
    -- TODO: still write/touch an empty file to not fail the build due to missing include?!
    die('git-describe failed')
  end
end

-- `git describe` annotates the most recent tagged release; for pre-release
-- builds we must replace that with the unreleased version.
current = current:gsub("^v%d+%.%d+%.%d+", arg[2])

local new_content = '#define NVIM_VERSION_MEDIUM "'..current..'"'
if stamp ~= new_content then
  io.open(versiondeffile, 'w'):write(new_content .. '\n')
end
