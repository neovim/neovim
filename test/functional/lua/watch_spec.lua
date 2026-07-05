local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
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

  it('watchdirs() does not scan excluded subtrees', function()
    local root_dir = t.tmpname(false)
    t.finally(function()
      n.rmdir(root_dir)
    end)
    n.mkdir_p(root_dir .. '/src/deep')
    n.mkdir_p(root_dir .. '/node_modules/pkg/excluded/deep')

    -- Also cover a pattern that matches the directory but not its descendants.
    for _, pattern in ipairs({ '**/node_modules/*/**', '**/excluded' }) do
      local scanned = exec_lua(function(root, exclude_pattern)
        root = vim.fs.normalize(root)
        local scanned = {}
        local fs_scandir = vim.uv.fs_scandir
        vim.uv.fs_scandir = function(path, ...)
          scanned[#scanned + 1] = path:sub(#root + 1)
          return fs_scandir(path, ...)
        end
        local cancel = vim._watch.watchdirs(root, {
          exclude_pattern = vim.glob.to_lpeg(exclude_pattern),
        }, function() end)
        vim.uv.fs_scandir = fs_scandir
        cancel()
        table.sort(scanned)
        return scanned
      end, root_dir, pattern)

      eq({ '', '/node_modules', '/node_modules/pkg', '/src', '/src/deep' }, scanned, pattern)
    end
  end)

  it('watchdirs() tolerates directories deleted during setup', function()
    local root_dir = t.tmpname(false)
    t.finally(function()
      n.rmdir(root_dir)
    end)
    n.mkdir_p(root_dir .. '/gone')

    exec_lua(function(root)
      local dir = vim.fs.dir
      vim.fs.dir = function(path, opts)
        local iter = dir(path, opts)
        return function()
          local name, kind = iter()
          if name == 'gone' then
            -- Delete after enumeration, before the backend starts watching it.
            assert(vim.uv.fs_rmdir(root .. '/gone'))
          end
          return name, kind
        end
      end
      local cancel = vim._watch.watchdirs(root, { on_error = error }, function() end)
      vim.fs.dir = dir
      cancel()
    end, root_dir)
  end)

  it('inotify() reports failure to start the process', function()
    exec_lua(function()
      vim.env.PATH = ''
      local errors = {}
      local cancel = vim._watch.inotify('.', {
        on_error = function(err)
          errors[#errors + 1] = err
        end,
      }, function() end)
      cancel()
      assert(#errors == 1, vim.inspect(errors))
      assert(errors[1]:find('ENOENT', 1, true), errors[1])
      assert(vim._watch.active.inotify == 0)
    end)
  end)

  local function run(watchfunc)
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

    it(watchfunc .. '() reports nonexistent paths to on_error', function()
      if watchfunc == 'inotify' then
        skip(n.fn.executable('inotifywait') == 0, 'inotifywait not found')
        skip(is_os('bsd'), 'inotifywait on bsd CI seems to expect path to exist?')
        skip(t.is_arch('s390x'), 'inotifywait not available on s390x CI')
      end

      exec_lua(function(backend)
        local errors = {}
        local cancel = vim._watch[backend]('/i am /very/funny.go', {
          on_error = function(err)
            errors[#errors + 1] = err
          end,
        }, function()
          error('Unexpected file change')
        end)
        assert(vim.wait(2000, function()
          return #errors > 0
        end))
        if backend ~= 'inotify' then
          assert(errors[1]:match('^ENOENT:'), errors[1])
        end
        cancel()
      end, watchfunc)
    end)

    if watchfunc ~= 'inotify' then
      it(watchfunc .. '() logs startup failures without on_error', function()
        local logfile = exec_lua(function(backend)
          local logfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'nvim-watch.log')
          vim.fn.writefile({}, logfile)
          local cancel = vim._watch[backend]('/i am /very/funny.go', {}, function()
            error('Unexpected file change')
          end)
          cancel()
          assert(vim._watch.active[backend] == 0)
          return logfile
        end, watchfunc)
        t.assert_log('%[ERROR%].-ENOENT:', logfile)
      end)
    end

    it(watchfunc .. '() detects file changes', function()
      if watchfunc == 'inotify' then
        skip(is_os('win'), 'N/A: inotify not supported on Windows')
        skip(is_os('mac'), 'flaky test on mac')
        skip(not is_ci() and n.fn.executable('inotifywait') == 0, 'inotifywait not found')
        skip(t.is_arch('s390x'), 'inotifywait not available on s390x CI')
      end

      -- Note: because this is not `elseif`, BSD is skipped for *all* cases...?
      if watchfunc == 'watch' then
        skip(is_os('mac'), 'flaky test on mac')
        skip(is_os('bsd'), 'Stopped working on bsd after 3ca967387c49c754561c3b11a574797504d40f38')
      elseif watchfunc == 'watchdirs' and is_os('mac') then
        skip(true, 'weird failure since macOS 14 CI, see bbf208784ca279178ba0075b60d3e9c80f11da7a')
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

  it('watch() reports start errors without counting a failed watcher', function()
    eq(
      { { 'ENOSPC: no space left on device' }, 1, 0 },
      exec_lua(function()
        local watch = vim._watch
        local new_fs_event = vim.uv.new_fs_event
        local before = watch.active.watch
        local closed = 0
        vim.uv.new_fs_event = function()
          return {
            start = function()
              return nil, 'ENOSPC: no space left on device', 'ENOSPC'
            end,
            close = function()
              closed = closed + 1
            end,
          }
        end
        local errors = {}
        local cancel = watch.watch('.', {
          on_error = function(err)
            errors[#errors + 1] = err
          end,
        }, function() end)
        vim.uv.new_fs_event = new_fs_event
        cancel()
        cancel()
        return { errors, closed, watch.active.watch - before }
      end)
    )
  end)

  run('watchdirs')
  run('inotify')
end)
