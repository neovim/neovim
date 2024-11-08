local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local exec_lua = n.exec_lua
local clear = n.clear
local is_ci = t.is_ci
local is_os = t.is_os
local skip = t.skip

-- Create a file via a rename to avoid multiple
-- events which can happen with some backends on some platforms
local function touch(path)
  local tmp = t.tmpname()
  assert(vim.uv.fs_rename(tmp, path))
end

describe('vim._watch', function()
  before_each(function()
    clear()
  end)

  local function run(watchfunc)
    -- Monkey-patches vim.notify_once so we can "spy" on it.
    local function spy_notify_once()
      exec_lua [[
        _G.__notify_once_msgs = {}
        vim.notify_once = (function(overridden)
          return function(msg, level, opts)
            table.insert(_G.__notify_once_msgs, msg)
            return overridden(msg, level, opts)
          end
        end)(vim.notify_once)
      ]]
    end

    local function last_notify_once_msg()
      return exec_lua 'return _G.__notify_once_msgs[#_G.__notify_once_msgs]'
    end

    local function do_watch(root_dir, watchfunc_)
      exec_lua(
        [[
          local root_dir, watchfunc = ...

          _G.events = {}

          _G.stop_watch = vim._watch[watchfunc](root_dir, {
            debounce = 100,
            include_pattern = vim.lpeg.P(root_dir) * vim.lpeg.P("/file") ^ -1,
            exclude_pattern = vim.lpeg.P(root_dir .. '/file.unwatched'),
          }, function(path, change_type)
            table.insert(_G.events, { path = path, change_type = change_type })
          end)
      ]],
        root_dir,
        watchfunc_
      )
    end

    it(watchfunc .. '() ignores nonexistent paths', function()
      if watchfunc == 'inotify' then
        skip(n.fn.executable('inotifywait') == 0, 'inotifywait not found')
        skip(is_os('bsd'), 'inotifywait on bsd CI seems to expect path to exist?')
      end

      local msg = ('watch.%s: ENOENT: no such file or directory'):format(watchfunc)

      spy_notify_once()
      do_watch('/i am /very/funny.go', watchfunc)

      if watchfunc ~= 'inotify' then -- watch.inotify() doesn't (currently) call vim.notify_once.
        t.retry(nil, 2000, function()
          t.eq(msg, last_notify_once_msg())
        end)
      end
      eq(0, exec_lua [[return #_G.events]])

      exec_lua [[_G.stop_watch()]]
    end)

    it(watchfunc .. '() detects file changes', function()
      if watchfunc == 'inotify' then
        skip(is_os('win'), 'not supported on windows')
        skip(is_os('mac'), 'flaky test on mac')
        skip(not is_ci() and n.fn.executable('inotifywait') == 0, 'inotifywait not found')
      end

      -- Note: because this is not `elseif`, BSD is skipped for *all* cases...?
      if watchfunc == 'watch' then
        skip(is_os('mac'), 'flaky test on mac')
        skip(is_os('bsd'), 'Stopped working on bsd after 3ca967387c49c754561c3b11a574797504d40f38')
      elseif watchfunc == 'watchdirs' and is_os('mac') then
        -- Bump this (or fix the bug) if CI continues to fail in future versions of macos CI.
        skip(is_ci() and vim.uv.os_uname().release == '24.0.0', 'weird failure for macOS arm 15 CI')
      else
        skip(
          is_os('bsd'),
          'kqueue only reports events on watched folder itself, not contained files #26110'
        )
      end

      local expected_events = 0
      --- Waits for a new event, or fails if no events are triggered.
      local function wait_for_event()
        expected_events = expected_events + 1
        exec_lua(
          [[
            local expected_events = ...
            assert(
              vim.wait(3000, function()
                return #_G.events == expected_events
              end),
              string.format(
                'Timed out waiting for expected event no. %d. Current events seen so far: %s',
                expected_events,
                vim.inspect(events)
              )
            )
        ]],
          expected_events
        )
      end

      local root_dir = vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/nvim_XXXXXXXXXX')
      local unwatched_path = root_dir .. '/file.unwatched'
      local watched_path = root_dir .. '/file'

      do_watch(root_dir, watchfunc)

      if watchfunc ~= 'watch' then
        vim.uv.sleep(200)
      end

      touch(watched_path)
      touch(unwatched_path)
      wait_for_event()

      os.remove(watched_path)
      os.remove(unwatched_path)
      wait_for_event()

      exec_lua [[_G.stop_watch()]]
      -- No events should come through anymore

      vim.uv.sleep(100)
      touch(watched_path)
      vim.uv.sleep(100)
      os.remove(watched_path)
      vim.uv.sleep(100)

      eq({
        {
          change_type = exec_lua([[return vim._watch.FileChangeType.Created]]),
          path = root_dir .. '/file',
        },
        {
          change_type = exec_lua([[return vim._watch.FileChangeType.Deleted]]),
          path = root_dir .. '/file',
        },
      }, exec_lua [[return _G.events]])
    end)
  end

  run('watch')
  run('watchdirs')
  run('inotify')
end)
