local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local clear = helpers.clear
local is_os = helpers.is_os
local skip = helpers.skip

describe('vim._watch', function()
  before_each(function()
    clear()
  end)

  describe('watch', function()
    it('detects file changes', function()
      skip(is_os('bsd'), 'Stopped working on bsd after 3ca967387c49c754561c3b11a574797504d40f38')
      local root_dir = vim.uv.fs_mkdtemp(vim.fs.dirname(helpers.tmpname()) .. '/nvim_XXXXXXXXXX')

      local result = exec_lua(
        [[
        local root_dir = ...

        local events = {}

        local expected_events = 0
        local function wait_for_events()
          assert(vim.wait(100, function() return #events == expected_events end), 'Timed out waiting for expected number of events. Current events seen so far: ' .. vim.inspect(events))
        end

        local stop = vim._watch.watch(root_dir, {}, function(path, change_type)
          table.insert(events, { path = path, change_type = change_type })
        end)

        -- Only BSD seems to need some extra time for the watch to be ready to respond to events
        if vim.fn.has('bsd') then
          vim.wait(50)
        end

        local watched_path = root_dir .. '/file'
        local watched, err = io.open(watched_path, 'w')
        assert(not err, err)

        expected_events = expected_events + 1
        wait_for_events()

        watched:close()
        os.remove(watched_path)

        expected_events = expected_events + 1
        wait_for_events()

        stop()
        -- No events should come through anymore

        local watched_path = root_dir .. '/file'
        local watched, err = io.open(watched_path, 'w')
        assert(not err, err)

        vim.wait(50)

        watched:close()
        os.remove(watched_path)

        vim.wait(50)

        return events
      ]],
        root_dir
      )

      local expected = {
        {
          change_type = exec_lua([[return vim._watch.FileChangeType.Created]]),
          path = root_dir .. '/file',
        },
        {
          change_type = exec_lua([[return vim._watch.FileChangeType.Deleted]]),
          path = root_dir .. '/file',
        },
      }

      -- kqueue only reports events on the watched path itself, so creating a file within a
      -- watched directory results in a "rename" libuv event on the directory.
      if is_os('bsd') then
        expected = {
          {
            change_type = exec_lua([[return vim._watch.FileChangeType.Created]]),
            path = root_dir,
          },
          {
            change_type = exec_lua([[return vim._watch.FileChangeType.Created]]),
            path = root_dir,
          },
        }
      end

      eq(expected, result)
    end)
  end)

  describe('poll', function()
    it('detects file changes', function()
      skip(
        is_os('bsd'),
        'kqueue only reports events on watched folder itself, not contained files #26110'
      )
      local root_dir = vim.uv.fs_mkdtemp(vim.fs.dirname(helpers.tmpname()) .. '/nvim_XXXXXXXXXX')

      local result = exec_lua(
        [[
        local root_dir = ...
        local lpeg = vim.lpeg

        local events = {}

        local debounce = 100
        local wait_ms = debounce + 200

        local expected_events = 0
        local function wait_for_events()
          assert(vim.wait(wait_ms, function() return #events == expected_events end), 'Timed out waiting for expected number of events. Current events seen so far: ' .. vim.inspect(events))
        end

        local incl = lpeg.P(root_dir) * lpeg.P("/file")^-1
        local excl = lpeg.P(root_dir..'/file.unwatched')
        local stop = vim._watch.poll(root_dir, {
            debounce = debounce,
            include_pattern = incl,
            exclude_pattern = excl,
          }, function(path, change_type)
          table.insert(events, { path = path, change_type = change_type })
        end)

        local watched_path = root_dir .. '/file'
        local watched, err = io.open(watched_path, 'w')
        assert(not err, err)
        local unwatched_path = root_dir .. '/file.unwatched'
        local unwatched, err = io.open(unwatched_path, 'w')
        assert(not err, err)

        expected_events = expected_events + 1
        wait_for_events()

        watched:close()
        os.remove(watched_path)
        unwatched:close()
        os.remove(unwatched_path)

        expected_events = expected_events + 1
        wait_for_events()

        stop()
        -- No events should come through anymore

        local watched_path = root_dir .. '/file'
        local watched, err = io.open(watched_path, 'w')
        assert(not err, err)

        watched:close()
        os.remove(watched_path)

        return events
      ]],
        root_dir
      )

      local created = exec_lua([[return vim._watch.FileChangeType.Created]])
      local deleted = exec_lua([[return vim._watch.FileChangeType.Deleted]])
      local expected = {
        {
          change_type = created,
          path = root_dir .. '/file',
        },
        {
          change_type = deleted,
          path = root_dir .. '/file',
        },
      }
      eq(expected, result)
    end)
  end)
end)
