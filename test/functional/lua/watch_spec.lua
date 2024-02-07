local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local clear = helpers.clear
local is_ci = helpers.is_ci
local is_os = helpers.is_os
local skip = helpers.skip

-- Create a file via a rename to avoid multiple
-- events which can happen with some backends on some platforms
local function touch(path)
  local tmp = helpers.tmpname()
  io.open(tmp, 'w'):close()
  assert(vim.uv.fs_rename(tmp, path))
end

describe('vim._watch', function()
  before_each(function()
    clear()
  end)

  local function run(watchfunc)
    it('detects file changes (watchfunc=' .. watchfunc .. '())', function()
      if watchfunc == 'fswatch' then
        skip(is_os('mac'), 'flaky test on mac')
        skip(
          not is_ci() and helpers.fn.executable('fswatch') == 0,
          'fswatch not installed and not on CI'
        )
        skip(is_os('win'), 'not supported on windows')
      end

      if watchfunc == 'watch' then
        skip(is_os('bsd'), 'Stopped working on bsd after 3ca967387c49c754561c3b11a574797504d40f38')
      else
        skip(
          is_os('bsd'),
          'kqueue only reports events on watched folder itself, not contained files #26110'
        )
      end

      local root_dir = vim.uv.fs_mkdtemp(vim.fs.dirname(helpers.tmpname()) .. '/nvim_XXXXXXXXXX')

      local expected_events = 0

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

      local unwatched_path = root_dir .. '/file.unwatched'
      local watched_path = root_dir .. '/file'

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
        watchfunc
      )

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
  run('fswatch')
end)
