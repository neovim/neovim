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
      assert(vim._watch.active().inotify == 0)
      cancel()
      assert(#errors == 1, vim.inspect(errors))
      assert(errors[1]:find('ENOENT', 1, true), errors[1])
    end)
  end)

  it('releases earlier subscriptions when setup raises', function()
    exec_lua(function()
      local starts, stops = 0, 0
      vim.system = function()
        starts = starts + 1
        if starts == 2 then
          error('cannot start watcher')
        end
        return {
          kill = function()
            stops = stops + 1
          end,
        }
      end

      local ok, err = pcall(vim._watch.inotify, {
        { path = '/one' },
        { path = '/two' },
      }, { on_error = error }, function() end)

      assert(not ok and err:find('cannot start watcher', 1, true))
      assert(starts == 2 and stops == 1, 'started watchers must be stopped on error')
      assert(vim._watch.active().inotify == 0)
    end)
  end)

  it('inotify() groups rules by root and filters file events', function()
    local events = exec_lua(function()
      local outputs = {}
      vim.system = function(cmd, opts)
        local root = cmd[#cmd]
        assert(not outputs[root], 'rules for one root must share a watcher')
        outputs[root] = opts.stdout
        return {
          kill = function()
            outputs[root] = nil
          end,
        }
      end

      local watch = vim._watch
      local T = watch.FileChangeType
      local python = '/one/*.py'
      local events = {}
      local cancel = watch.inotify({
        { path = '/one', pattern = python, events = { T.Changed } },
        { path = '/one', pattern = python, events = { T.Created, T.Changed } },
        { path = '/one', pattern = '**/*.txt' },
        { path = '/two' },
      }, {
        include_pattern = '**/*.py',
        exclude_pattern = '**/ignored.py',
        on_error = error,
      }, function(path, change_type)
        events[#events + 1] = { path, change_type }
      end)
      assert(watch.active().inotify == 2)

      outputs['/one'](nil, '/one/ MODIFY file.py\n') -- Matches two rules, reported once.
      outputs['/one'](nil, '/one/ CREATE file.py\n')
      outputs['/one'](nil, '/one/ DELETE file.py\n') -- Wrong event type.
      outputs['/one'](nil, '/one/ MODIFY file.txt\n') -- Global include still applies.
      outputs['/one'](nil, '/one/ MODIFY ignored.py\n')
      outputs['/two'](nil, '/two/ DELETE file.py\n') -- No per-rule filters.
      cancel()
      cancel()
      assert(not next(outputs))
      assert(watch.active().inotify == 0)
      return events
    end)
    eq({ { '/one/file.py', 2 }, { '/one/file.py', 1 }, { '/two/file.py', 3 } }, events)
  end)

  it('inotify() shares glob watches and releases subscriptions independently', function()
    exec_lua(function()
      local root = vim.fs.normalize(assert(vim.uv.cwd()))
      local prefix = vim.fn.escape(root, '\\/*?[]{}#') .. '/'
      local processes = {}
      vim.system = function(_, opts)
        processes[#processes + 1] = opts
        return {
          kill = function()
            assert(not opts.stopped, 'process stopped twice')
            opts.stopped = true
          end,
        }
      end
      local changes, errors = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
      local function subscribe(id, pattern)
        local path = id == 1 and root or { { path = root .. '/' } }
        return vim._watch.inotify(path, {
          include_pattern = { prefix .. (pattern or '*.{py,lua}') },
          exclude_pattern = { '**/ignored.py' },
          on_error = function()
            errors[id] = errors[id] + 1
          end,
        }, function()
          changes[id] = changes[id] + 1
        end)
      end
      local cancel_a = subscribe(1)
      local cancel_b = subscribe(2)
      assert(#processes == 1, 'equivalent globs must share a backend')
      assert(vim._watch.active().inotify == 1)
      processes[1].stdout(nil, root .. '/ CREATE file.py')
      assert(vim.deep_equal(changes, { 1, 1, 0, 0 }))
      cancel_a()
      cancel_a()
      assert(not processes[1].stopped)
      processes[1].stdout(nil, root .. '/ MODIFY file.py')
      assert(vim.deep_equal(changes, { 1, 2, 0, 0 }))

      processes[1].stderr(nil, 'watcher failed')
      assert(vim.deep_equal(errors, { 0, 1, 0, 0 }))
      assert(vim._watch.active().inotify == 1, 'backend remains owned after an error')
      local cancel_c = subscribe(3)
      assert(#processes == 2, 'failed backend must not be reused')
      local cancel_d = subscribe(4, '*.txt')
      assert(#processes == 3, 'different filters must not share a backend')
      processes[2].stdout(nil, root .. '/ CREATE file.py')
      processes[3].stdout(nil, root .. '/ CREATE file.py')
      processes[3].stdout(nil, root .. '/ CREATE file.txt')
      assert(vim.deep_equal(changes, { 1, 2, 1, 1 }))
      cancel_b()
      assert(processes[1].stopped and not processes[2].stopped)
      cancel_c()
      cancel_d()
      assert(processes[2].stopped and processes[3].stopped)
      assert(vim._watch.active().inotify == 0)
    end)
  end)

  it('inotify() skips invalid globs without disabling sharing', function()
    exec_lua(function()
      local root = assert(vim.uv.cwd())
      local outputs = {}
      vim.system = function(_, opts)
        outputs[#outputs + 1] = opts.stdout
        return { kill = function() end }
      end

      local changes, errors, cancels = 0, {}, {}
      for i = 1, 2 do
        errors[i] = {}
        cancels[i] = vim._watch.inotify({
          { path = root, pattern = 'a/**b' },
          { path = root, pattern = { '{foo}', '**/*.lua' } },
        }, {
          on_error = function(err)
            errors[i][#errors[i] + 1] = err
          end,
        }, function()
          changes = changes + 1
        end)
      end

      assert(#errors[1] == 2 and #errors[2] == 2, 'each subscriber receives its own glob errors')
      assert(#outputs == 1, 'valid rules still share a backend')
      outputs[1](nil, root .. '/ MODIFY file.lua\n')
      assert(changes == 2)
      cancels[1]()
      cancels[2]()
      assert(vim._watch.active().inotify == 0)
    end)
  end)

  it('watchdirs() keeps directories watched when only their files match a glob', function()
    local root_dir = t.tmpname(false)
    n.mkdir_p(root_dir .. '/src')
    t.finally(function()
      n.rmdir(root_dir)
    end)
    exec_lua(function(root)
      root = vim.fs.normalize(root)
      local callbacks = {}
      vim.uv.new_fs_event = function()
        return {
          start = function(_, path, _, callback)
            callbacks[path] = callback
          end,
          is_closing = function()
            return false
          end,
          close = function() end,
        }
      end
      local events = {}
      local cancel = vim._watch.watchdirs(root, {
        include_pattern = '**/*.py',
        debounce = 1,
      }, function(path)
        events[#events + 1] = path
      end)
      assert(callbacks[root .. '/src'], 'existing parent directory must be watched')
      vim.fn.mkdir(root .. '/new')
      callbacks[root](nil, 'new', { rename = true })
      assert(
        vim.wait(1000, function()
          return callbacks[root .. '/new'] ~= nil
        end),
        'new parent directory must be watched'
      )
      vim.fn.writefile({}, root .. '/new/file.py')
      callbacks[root .. '/new'](nil, 'file.py', { rename = true })
      assert(vim.wait(1000, function()
        return #events == 1
      end))
      assert(events[1] == root .. '/new/file.py')
      cancel()
    end, root_dir)
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
        assert(errors[1]:find('(watching /i am /very/funny.go)', 1, true), errors[1])
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
          assert(vim._watch.active()[backend] == 0)
          cancel()
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
  run('watchdirs')
  run('inotify')
end)
