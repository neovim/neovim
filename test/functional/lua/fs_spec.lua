local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local eq_paths = t.eq_paths
local mkdir_p = n.mkdir_p
local rmdir = n.rmdir
local nvim_dir = n.nvim_dir
local command = n.command
local api = n.api
local fn = n.fn
local test_build_dir = t.paths.test_build_dir
local test_source_path = t.paths.test_source_path
local nvim_prog = n.nvim_prog
local is_os = t.is_os
local mkdir = t.mkdir

local nvim_prog_basename = is_os('win') and 'nvim.exe' or 'nvim'

local link_limit = is_os('win') and 64 or (is_os('mac') or is_os('bsd')) and 33 or 41

local test_basename_dirname_eq = {
  '~/foo/',
  '~/foo',
  '~/foo/bar.lua',
  'foo.lua',
  ' ',
  '',
  '.',
  '..',
  '../',
  '~',
  '/usr/bin',
  '/usr/bin/gcc',
  '/',
  '/usr/',
  '/usr',
  'c:/usr',
  'c:/',
  'c:',
  'c:/users/foo',
  'c:/users/foo/bar.lua',
  'c:/users/foo/bar/../',
  '~/foo/bar\\baz',
}

local tests_windows_paths = {
  'c:\\usr',
  'c:\\',
  'c:',
  'c:\\users\\foo',
  'c:\\users\\foo\\bar.lua',
  'c:\\users\\foo\\bar\\..\\',
}

setup(clear)

describe('vim.fs', function()
  describe('parents()', function()
    it('works', function()
      local test_dir = nvim_dir .. '/test'
      mkdir_p(test_dir)
      local dirs = {} --- @type string[]
      for dir in vim.fs.parents(test_dir .. '/foo.txt') do
        dirs[#dirs + 1] = dir
        if dir == test_build_dir then
          break
        end
      end
      eq({ test_dir, nvim_dir, test_build_dir }, dirs)
      rmdir(test_dir)
    end)
  end)

  describe('dirname()', function()
    it('works', function()
      eq(test_build_dir, vim.fs.dirname(nvim_dir))

      ---@param paths string[]
      ---@param is_win? boolean
      local function test_paths(paths, is_win)
        local gsub = is_win and [[:gsub('\\', '/')]] or ''
        local code = string.format(
          [[
          local path = ...
          return vim.fn.fnamemodify(path,':h')%s
        ]],
          gsub
        )

        for _, path in ipairs(paths) do
          eq(exec_lua(code, path), vim.fs.dirname(path), path)
        end
      end

      test_paths(test_basename_dirname_eq)
      if is_os('win') then
        test_paths(tests_windows_paths, true)
      end
    end)

    it('trims redundant slashes #37698', function()
      eq('/name', vim.fs.dirname('/name//////////'))
    end)
  end)

  describe('basename()', function()
    it('works', function()
      eq(nvim_prog_basename, vim.fs.basename(nvim_prog))

      ---@param paths string[]
      ---@param is_win? boolean
      local function test_paths(paths, is_win)
        local gsub = is_win and [[:gsub('\\', '/')]] or ''
        local code = string.format(
          [[
          local path = ...
          return vim.fn.fnamemodify(path,':t')%s
        ]],
          gsub
        )

        for _, path in ipairs(paths) do
          eq(exec_lua(code, path), vim.fs.basename(path), path)
        end
      end

      test_paths(test_basename_dirname_eq)
      if is_os('win') then
        test_paths(tests_windows_paths, true)
      end
    end)

    it('trims redundant slashes #37698', function()
      -- XXX: for better or worse, this matches python's `os.path.basename`.
      -- https://github.com/neovim/neovim/issues/37698#issuecomment-3847866806
      eq('', vim.fs.basename('/name//////////'))
    end)
  end)

  describe('dir()', function()
    before_each(function()
      mkdir('testd')
      mkdir('testd/a')
      mkdir('testd/a/b')
      mkdir('testd/a/b/c')
    end)

    after_each(function()
      rmdir('testd')
    end)

    it('works', function()
      eq(
        true,
        exec_lua(function()
          for name, type in vim.fs.dir(nvim_dir) do
            if name == nvim_prog_basename and type == 'file' then
              return true
            end
          end
          return false
        end)
      )
    end)

    it('works with opts.depth, opts.skip and opts.follow', function()
      io.open('testd/a1', 'w'):close()
      io.open('testd/b1', 'w'):close()
      io.open('testd/c1', 'w'):close()
      io.open('testd/a/a2', 'w'):close()
      io.open('testd/a/b2', 'w'):close()
      io.open('testd/a/c2', 'w'):close()
      io.open('testd/a/b/a3', 'w'):close()
      io.open('testd/a/b/b3', 'w'):close()
      io.open('testd/a/b/c3', 'w'):close()
      io.open('testd/a/b/c/a4', 'w'):close()
      io.open('testd/a/b/c/b4', 'w'):close()
      io.open('testd/a/b/c/c4', 'w'):close()

      local function run(dir, depth, skip, follow)
        return exec_lua(function(follow_)
          local r = {} --- @type table<string, string>
          local skip_f --- @type function
          if skip then
            skip_f = function(n0)
              if vim.tbl_contains(skip or {}, n0) then
                return false
              end
            end
          end
          for name, type_ in vim.fs.dir(dir, { depth = depth, skip = skip_f, follow = follow_ }) do
            r[name] = type_
          end
          return r
        end, follow)
      end

      local exp = {}

      exp['a1'] = 'file'
      exp['b1'] = 'file'
      exp['c1'] = 'file'
      exp['a'] = 'directory'

      eq(exp, run('testd', 1))

      exp['a/a2'] = 'file'
      exp['a/b2'] = 'file'
      exp['a/c2'] = 'file'
      exp['a/b'] = 'directory'
      local lexp = vim.deepcopy(exp)

      eq(exp, run('testd', 2))

      exp['a/b/a3'] = 'file'
      exp['a/b/b3'] = 'file'
      exp['a/b/c3'] = 'file'
      exp['a/b/c'] = 'directory'

      eq(exp, run('testd', 3))
      eq(exp, run('testd', 999, { 'a/b/c' }))

      exp['a/b/c/a4'] = 'file'
      exp['a/b/c/b4'] = 'file'
      exp['a/b/c/c4'] = 'file'

      eq(exp, run('testd', 999))

      vim.uv.fs_symlink(vim.uv.fs_realpath('testd/a'), 'testd/l', { junction = true, dir = true })
      lexp['l'] = 'link'
      eq(lexp, run('testd', 2, nil, false))

      lexp['l/a2'] = 'file'
      lexp['l/b2'] = 'file'
      lexp['l/c2'] = 'file'
      lexp['l/b'] = 'directory'
      eq(lexp, run('testd', 2, nil, true))
    end)

    it('follow=true handles symlink loop', function()
      local cwd = 'testd/a/b/c'
      local symlink = cwd .. '/link_loop' ---@type string
      vim.uv.fs_symlink(vim.uv.fs_realpath(cwd), symlink, { junction = true, dir = true })

      eq(
        link_limit,
        exec_lua(function()
          return #vim.iter(vim.fs.dir(cwd, { depth = math.huge, follow = true })):totable()
        end)
      )
    end)

    describe('fs_scandir_next fallback', function()
      before_each(function()
        mkdir('testdir')
        t.write_file('testdir/test.txt', 'test file')
      end)

      after_each(function()
        rmdir('testdir')
      end)

      it('falls back to fs_lstat when fs_scandir_next returns nil type', function()
        local result = n.exec_lua([[
          local orig = vim.uv.fs_scandir_next

          vim.uv.fs_scandir_next = function(fs)
            local name = orig(fs)
            if name then
              return name, nil
            end
            return name
          end

          local out = {}
          for name, etype in vim.fs.dir('testdir') do
            out[name] = etype
          end

          vim.uv.fs_scandir_next = orig
          return out
        ]])

        eq('file', result['test.txt'])
      end)
    end)

    it('reports errors', function()
      mkdir('testdir')
      mkdir('testdir/noaccess')
      mkdir('testdir/a')
      mkdir('testdir/a/noaccess')
      finally(function()
        rmdir('testdir')
      end)

      -- With opts.err=false: errors are silent, unreadable root looks empty.
      eq(
        0,
        exec_lua(function()
          local n0 = 0
          for _ in vim.fs.dir('does-not-exist') do
            n0 = n0 + 1
          end
          return n0
        end)
      )

      -- With opts.err=true: unreadable root dir yields a single (name, nil, err).
      eq(
        { name = 'does-not-exist', err = 'ENOENT: no such file or directory: does-not-exist' },
        exec_lua(function()
          for name, type, err in vim.fs.dir('does-not-exist', { err = true }) do
            return { name = name, type = type, err = err }
          end
        end)
      )

      -- With opts.err=true: unreadable child dir.
      local result = exec_lua(function()
        -- Stub fs_scandir since chmod doesn't work reliably on Windows.
        local orig_scandir = vim.uv.fs_scandir
        vim.uv.fs_scandir = function(path, ...)
          if path == 'testdir/noaccess' then
            return nil, 'EACCES: permission denied: testdir/noaccess'
          end
          return orig_scandir(path, ...)
        end

        local errors = {} ---@type table<string, string>
        for f, _, err in vim.fs.dir('testdir', { depth = 2, err = true }) do
          errors[f] = err
        end

        vim.uv.fs_scandir = orig_scandir
        return errors
      end)
      eq('EACCES: permission denied: testdir/noaccess', result['noaccess'])
      -- nil: with depth=2 we don't scan testdir/a/noaccess.
      eq(nil, result['a/noaccess'])
    end)
  end)

  describe('find()', function()
    it('works', function()
      eq(
        { test_build_dir .. '/bin' },
        vim.fs.find('bin', { path = nvim_dir, upward = true, type = 'directory' })
      )
      eq({ nvim_prog }, vim.fs.find(nvim_prog_basename, { path = test_build_dir, type = 'file' }))

      local parent, name = nvim_dir:match('^(.*/)([^/]+)$')
      eq({ nvim_dir }, vim.fs.find(name, { path = parent, upward = true, type = 'directory' }))
    end)

    local function filter_zig_cache(list)
      return vim.tbl_filter(function(val)
        return not vim.startswith(val, test_source_path .. '/.zig-cache/')
      end, list)
    end

    it('follows symlinks', function()
      local build_dir = test_build_dir ---@type string
      local symlink = test_source_path .. '/build_link' ---@type string
      vim.uv.fs_symlink(build_dir, symlink, { junction = true, dir = true })

      finally(function()
        vim.uv.fs_unlink(symlink)
      end)

      local cases = { nvim_prog, symlink .. '/bin/' .. nvim_prog_basename }
      table.sort(cases)

      eq(
        cases,
        vim.fs.find(nvim_prog_basename, {
          path = test_source_path,
          type = 'file',
          limit = 2,
          follow = true,
        })
      )

      eq(
        { nvim_prog },
        filter_zig_cache(vim.fs.find(nvim_prog_basename, {
          path = test_source_path,
          type = 'file',
          limit = 2,
          follow = false,
        }))
      )
    end)

    it('follow=true handles symlink loop', function()
      if t.is_zig_build() then
        return pending('broken/slow with build.zig')
      end
      local cwd = vim.uv.fs_realpath(test_source_path) ---@type string
      local symlink = cwd .. '/loop_link' ---@type string
      vim.uv.fs_symlink(cwd, symlink, { junction = true, dir = true })

      finally(function()
        vim.uv.fs_unlink(symlink)
      end)

      eq(link_limit, #vim.fs.find(nvim_prog_basename, {
        path = cwd,
        type = 'file',
        limit = math.huge,
        follow = true,
      }))
    end)

    it('accepts predicate as names', function()
      local opts = { path = nvim_dir, upward = true, type = 'directory' }
      eq(
        { test_build_dir .. '/bin' },
        vim.fs.find(function(x)
          return x == 'bin'
        end, opts)
      )
      eq(
        { nvim_prog },
        vim.fs.find(function(x)
          return x == nvim_prog_basename
        end, { path = test_build_dir, type = 'file' })
      )
      eq(
        {},
        vim.fs.find(function(x)
          return x == 'no-match'
        end, opts)
      )

      opts = { path = test_source_path .. '/contrib', limit = math.huge }
      eq(
        exec_lua(function()
          return vim.tbl_map(
            vim.fs.basename,
            vim.fn.glob(test_source_path .. '/contrib/*', false, true)
          )
        end),
        vim.tbl_map(
          vim.fs.basename,
          vim.fs.find(function(_, d)
            return d:match('[\\/]contrib$')
          end, opts)
        )
      )
    end)

    it('reports errors', function()
      mkdir('testdir')
      mkdir('testdir/noaccess')
      mkdir('testdir/a')
      mkdir('testdir/a/noaccess')
      t.write_file('testdir/a/match.lua', '')
      finally(function()
        rmdir('testdir')
      end)

      -- Scenarios run in a shared setup(clear) so the fs_scandir/fs_access stubs (chmod is unreliable on
      -- Windows) are installed and restored.
      local res = exec_lua(function()
        local orig_scandir = vim.uv.fs_scandir
        local orig_access = vim.uv.fs_access
        local function is_blocked(path)
          for _, prefix in ipairs({ 'testdir/noaccess', 'testdir/a/noaccess' }) do
            if path == prefix or vim.startswith(path, prefix .. '/') then
              return true
            end
          end
          return false
        end
        vim.uv.fs_scandir = function(path, ...)
          if is_blocked(path) then
            return nil, 'EACCES: permission denied: ' .. path
          end
          return orig_scandir(path, ...)
        end
        vim.uv.fs_access = function(path, ...)
          if is_blocked(path) then
            return nil, 'EACCES: permission denied: ' .. path
          end
          return orig_access(path, ...)
        end

        local r = {}
        r.nonexistent = { vim.fs.find('foo', { path = 'does-not-exist' }) }
        r.unreadable_root = { vim.fs.find('foo', { path = 'testdir/noaccess' }) }
        local dmatches, derrors =
          vim.fs.find('match.lua', { path = 'testdir', limit = math.huge, type = 'file' })
        table.sort(derrors) -- readdir order is not deterministic
        r.downward = { dmatches, derrors }
        r.upward = select(
          2,
          vim.fs.find('match.lua', {
            path = 'testdir/noaccess/x',
            upward = true,
            stop = 'testdir',
          })
        )

        vim.uv.fs_scandir = orig_scandir
        vim.uv.fs_access = orig_access
        return r
      end)

      -- Nonexistent / unreadable root path: no matches, one error.
      eq({ {}, { 'ENOENT: no such file or directory: does-not-exist' } }, res.nonexistent)
      eq({ {}, { 'EACCES: permission denied: testdir/noaccess' } }, res.unreadable_root)

      -- Downward search collects child errors, yet still returns the match found elsewhere.
      eq({
        { 'testdir/a/match.lua' },
        {
          'EACCES: permission denied: testdir/a/noaccess',
          'EACCES: permission denied: testdir/noaccess',
        },
      }, res.downward)

      -- Upward search reports an error for each unreadable ancestor, in traversal order.
      eq({
        'EACCES: permission denied: testdir/noaccess/x',
        'EACCES: permission denied: testdir/noaccess',
      }, res.upward)
    end)
  end)

  describe('root()', function()
    before_each(function()
      command('edit test/functional/fixtures/tty-test.c')
    end)

    after_each(function()
      command('bwipe!')
    end)

    it('works with a single marker', function()
      eq_paths(test_source_path, exec_lua([[return vim.fs.root(0, 'CMakePresets.json')]]))
    end)

    it('works with multiple markers', function()
      local bufnr = api.nvim_get_current_buf()
      eq_paths(
        vim.fs.joinpath(test_source_path, 'test/functional/fixtures'),
        exec_lua([[return vim.fs.root(..., {'CMakeLists.txt', 'CMakePresets.json'})]], bufnr)
      )
    end)

    it('nested markers have equal priority', function()
      local bufnr = api.nvim_get_current_buf()
      eq_paths(
        vim.fs.joinpath(test_source_path, 'test/functional'),
        exec_lua(
          [[return vim.fs.root(..., { 'example_spec.lua', {'CMakeLists.txt', 'CMakePresets.json'}, '.luarc.json'})]],
          bufnr
        )
      )
      eq_paths(
        vim.fs.joinpath(test_source_path, 'test/functional/fixtures'),
        exec_lua(
          [[return vim.fs.root(..., { {'CMakeLists.txt', 'CMakePresets.json'}, 'example_spec.lua', '.luarc.json'})]],
          bufnr
        )
      )
      eq_paths(
        vim.fs.joinpath(test_source_path, 'test/functional/fixtures'),
        exec_lua(
          [[return vim.fs.root(..., {
              function(name, _)
                return name:match('%.txt$')
              end,
              'example_spec.lua',
              '.luarc.json' })]],
          bufnr
        )
      )
    end)

    it('works with a function', function()
      ---@type string
      local result = exec_lua(function()
        return vim.fs.root(0, function(name, _)
          return name:match('%.txt$')
        end)
      end)
      eq_paths(vim.fs.joinpath(test_source_path, 'test/functional/fixtures'), result)
    end)

    it('works with a filename argument', function()
      eq(test_source_path, exec_lua([[return vim.fs.root(..., 'CMakePresets.json')]], nvim_prog))
    end)

    it('works with a relative path', function()
      eq_paths(
        test_source_path,
        exec_lua([[return vim.fs.root(..., 'CMakePresets.json')]], vim.fs.basename(nvim_prog))
      )
    end)

    it('returns CWD (absolute path) for unnamed buffers', function()
      assert(n.fn.isabsolutepath(test_source_path) == 1)
      command('new')
      eq_paths(test_source_path, exec_lua([[return vim.fs.root(0, 'CMakePresets.json')]]))
    end)

    it("returns CWD (absolute path) for buffers with non-empty 'buftype'", function()
      assert(n.fn.isabsolutepath(test_source_path) == 1)
      command('new')
      command('set buftype=nofile')
      command('file lua://')
      eq_paths(test_source_path, exec_lua([[return vim.fs.root(0, 'CMakePresets.json')]]))
    end)

    it('returns CWD (absolute path) if no match is found', function()
      assert(n.fn.isabsolutepath(test_source_path) == 1)
      eq_paths(
        test_source_path,
        exec_lua([[return vim.fs.root('file://bogus', 'CMakePresets.json')]])
      )
    end)
  end)

  describe('joinpath()', function()
    it('works', function()
      eq('foo/bar/baz', vim.fs.joinpath('foo', 'bar', 'baz'))
      eq('foo/bar/baz', vim.fs.joinpath('foo', '/bar/', '/baz'))
    end)
    it('rewrites backslashes on Windows', function()
      if is_os('win') then
        eq('foo/bar/baz/zub/', vim.fs.joinpath([[foo]], [[\\bar\\\\baz]], [[zub\]]))
      else
        eq([[foo/\\bar\\\\baz/zub\]], vim.fs.joinpath([[foo]], [[\\bar\\\\baz]], [[zub\]]))
      end
    end)
    it('strips redundant slashes', function()
      if is_os('win') then
        eq('foo/bar/baz/zub/', vim.fs.joinpath([[foo//]], [[\\bar\\\\baz]], [[zub\]]))
      else
        eq('foo/bar/baz/zub/', vim.fs.joinpath([[foo]], [[//bar////baz]], [[zub/]]))
      end
    end)
    it('handles empty segments', function()
      eq('foo/bar', vim.fs.joinpath('', 'foo', '', 'bar', ''))
      eq('foo/bar', vim.fs.joinpath('', '', 'foo', 'bar', '', ''))
      eq('', vim.fs.joinpath(''))
      eq('', vim.fs.joinpath('', '', '', ''))
    end)
  end)

  describe('normalize()', function()
    it('removes trailing /', function()
      eq('/home/user', vim.fs.normalize('/home/user/'))
    end)
    it('works with /', function()
      eq('/', vim.fs.normalize('/'))
    end)
    it('works with ~', function()
      eq(vim.fs.normalize(assert(vim.uv.os_homedir())) .. '/src/foo', vim.fs.normalize('~/src/foo'))
    end)
    it('works with environment variables', function()
      local xdg_config_home = test_build_dir .. '/.config'
      eq(
        xdg_config_home .. '/nvim',
        exec_lua(function()
          return vim._with({ env = { XDG_CONFIG_HOME = xdg_config_home } }, function()
            return vim.fs.normalize('$XDG_CONFIG_HOME/nvim')
          end)
        end)
      )
    end)

    -- Opts required for testing posix paths and win paths
    local posix_opts = { win = false }
    local win_opts = { win = true }

    it('preserves leading double slashes in POSIX paths', function()
      eq('//foo', vim.fs.normalize('//foo', posix_opts))
      eq('//foo/bar', vim.fs.normalize('//foo//bar////', posix_opts))
      eq('/foo', vim.fs.normalize('///foo', posix_opts))
      eq('//', vim.fs.normalize('//', posix_opts))
      eq('/', vim.fs.normalize('///', posix_opts))
      eq('/foo/bar', vim.fs.normalize('/foo//bar////', posix_opts))
    end)

    it('normalizes drive letter', function()
      eq('C:/', vim.fs.normalize('C:/', win_opts))
      eq('C:/', vim.fs.normalize('c:/', win_opts))
      eq('D:/', vim.fs.normalize('d:/', win_opts))
      eq('C:', vim.fs.normalize('C:', win_opts))
      eq('C:', vim.fs.normalize('c:', win_opts))
      eq('D:', vim.fs.normalize('d:', win_opts))
      eq('C:/foo/test', vim.fs.normalize('C:/foo/test/', win_opts))
      eq('C:/foo/test', vim.fs.normalize('c:/foo/test/', win_opts))
      eq('D:foo/test', vim.fs.normalize('D:foo/test/', win_opts))
      eq('D:foo/test', vim.fs.normalize('d:foo/test/', win_opts))
    end)

    it('always treats paths as case-sensitive #31833', function()
      eq('TEST', vim.fs.normalize('TEST', win_opts))
      eq('test', vim.fs.normalize('test', win_opts))
      eq('C:/FOO/test', vim.fs.normalize('C:/FOO/test', win_opts))
      eq('C:/foo/test', vim.fs.normalize('C:/foo/test', win_opts))
      eq('//SERVER/SHARE/FOO/BAR', vim.fs.normalize('//SERVER/SHARE/FOO/BAR', win_opts))
      eq('//server/share/foo/bar', vim.fs.normalize('//server/share/foo/bar', win_opts))
      eq('C:/FOO/test', vim.fs.normalize('c:/FOO/test', win_opts))
    end)

    it('allows backslashes on unix-based os', function()
      eq('/home/user/hello\\world', vim.fs.normalize('/home/user/hello\\world', posix_opts))
    end)

    it('preserves / after drive letters', function()
      eq('C:/', vim.fs.normalize([[C:\]], win_opts))
    end)

    it('works with UNC and DOS device paths', function()
      eq('//server/share/foo/bar', vim.fs.normalize([[\\server\\share\\\foo\bar\\\]], win_opts))
      eq('//system07/C$/', vim.fs.normalize([[\\system07\C$\\\\]], win_opts))
      eq('//./C:/foo/bar', vim.fs.normalize([[\\.\\C:\foo\\\\bar]], win_opts))
      eq('//?/C:/foo/bar', vim.fs.normalize([[\\?\C:\\\foo\bar\\\\]], win_opts))
      eq(
        '//?/UNC/server/share/foo/bar',
        vim.fs.normalize([[\\?\UNC\server\\\share\\\\foo\\\bar]], win_opts)
      )
      eq('//./BootPartition/foo/bar', vim.fs.normalize([[\\.\BootPartition\\foo\bar]], win_opts))
      eq(
        '//./Volume{12345678-1234-1234-1234-1234567890AB}/foo/bar',
        vim.fs.normalize([[\\.\Volume{12345678-1234-1234-1234-1234567890AB}\\\foo\bar\\]], win_opts)
      )
    end)

    it('handles invalid UNC and DOS device paths', function()
      eq('//server/share', vim.fs.normalize([[\\server\share]], win_opts))
      eq('//server/', vim.fs.normalize([[\\server\]], win_opts))
      eq('//./UNC/server/share', vim.fs.normalize([[\\.\UNC\server\share]], win_opts))
      eq('//?/UNC/server/', vim.fs.normalize([[\\?\UNC\server\]], win_opts))
      eq('//?/UNC/server/..', vim.fs.normalize([[\\?\UNC\server\..]], win_opts))
      eq('//./', vim.fs.normalize([[\\.\]], win_opts))
      eq('//./foo', vim.fs.normalize([[\\.\foo]], win_opts))
      eq('//./BootPartition', vim.fs.normalize([[\\.\BootPartition]], win_opts))
    end)

    it('converts backward slashes', function()
      eq('C:/Users/jdoe', vim.fs.normalize([[C:\Users\jdoe]], win_opts))
    end)

    describe('. and .. component resolving', function()
      it('works', function()
        -- Windows paths
        eq('C:/Users', vim.fs.normalize([[C:\Users\jdoe\Downloads\.\..\..\]], win_opts))
        eq('C:/Users/jdoe', vim.fs.normalize([[C:\Users\jdoe\Downloads\.\..\.\.\]], win_opts))
        eq('C:/', vim.fs.normalize('C:/Users/jdoe/Downloads/./../../../', win_opts))
        eq('C:foo', vim.fs.normalize([[C:foo\bar\.\..\.]], win_opts))
        -- POSIX paths
        eq('/home', vim.fs.normalize('/home/jdoe/Downloads/./../..', posix_opts))
        eq('/home/jdoe', vim.fs.normalize('/home/jdoe/Downloads/./../././', posix_opts))
        eq('/', vim.fs.normalize('/home/jdoe/Downloads/./../../../', posix_opts))
        -- OS-agnostic relative paths
        eq('foo/bar/baz', vim.fs.normalize('foo/bar/foobar/../baz/./'))
        eq('foo/bar', vim.fs.normalize('foo/bar/foobar/../baz/./../../bar/./.'))
      end)

      it('works when relative path reaches current directory', function()
        eq('C:', vim.fs.normalize('C:foo/bar/../../.', win_opts))

        eq('.', vim.fs.normalize('.'))
        eq('.', vim.fs.normalize('././././'))
        eq('.', vim.fs.normalize('foo/bar/../../.'))
      end)

      it('works when relative path goes outside current directory', function()
        eq('../../foo/bar', vim.fs.normalize('../../foo/bar'))
        eq('../foo', vim.fs.normalize('foo/bar/../../../foo'))

        eq('C:../foo', vim.fs.normalize('C:../foo', win_opts))
        eq('C:../../foo/bar', vim.fs.normalize('C:foo/../../../foo/bar', win_opts))
      end)

      it('.. in root directory resolves to itself', function()
        eq('C:/', vim.fs.normalize('C:/../../', win_opts))
        eq('C:/foo', vim.fs.normalize('C:/foo/../../foo', win_opts))

        eq('//server/share/', vim.fs.normalize([[\\server\share\..\..]], win_opts))
        eq('//server/share/foo', vim.fs.normalize([[\\server\\share\foo\..\..\foo]], win_opts))

        eq('//./C:/', vim.fs.normalize([[\\.\C:\..\..]], win_opts))
        eq('//?/C:/foo', vim.fs.normalize([[\\?\C:\..\..\foo]], win_opts))

        eq('//./UNC/server/share/', vim.fs.normalize([[\\.\UNC\\server\share\..\..\]], win_opts))
        eq(
          '//?/UNC/server/share/foo',
          vim.fs.normalize([[\\?\UNC\server\\share\..\..\foo]], win_opts)
        )

        eq('//?/BootPartition/', vim.fs.normalize([[\\?\BootPartition\..\..]], win_opts))
        eq('//./BootPartition/foo', vim.fs.normalize([[\\.\BootPartition\..\..\foo]], win_opts))

        eq('/', vim.fs.normalize('/../../', posix_opts))
        eq('/foo', vim.fs.normalize('/foo/../../foo', posix_opts))
      end)
    end)
  end)

  describe('abspath()', function()
    local cwd = assert(t.fix_slashes(assert(vim.uv.cwd())))
    local home = t.fix_slashes(assert(vim.uv.os_homedir()))

    it('expands relative paths', function()
      assert(n.fn.isabsolutepath(cwd) == 1)
      eq(cwd, vim.fs.abspath('.'))
      eq(cwd .. '/foo', vim.fs.abspath('foo'))
      eq(cwd .. '/././foo', vim.fs.abspath('././foo'))
      eq(cwd .. '/.././../foo', vim.fs.abspath('.././../foo'))
    end)

    it('works with absolute paths', function()
      if is_os('win') then
        eq([[C:/foo]], vim.fs.abspath([[C:\foo]]))
        eq([[C:/foo/../.]], vim.fs.abspath([[C:\foo\..\.]]))
        eq('//foo/bar', vim.fs.abspath('\\\\foo\\bar'))
      else
        eq('/foo/../.', vim.fs.abspath('/foo/../.'))
        eq('/foo/bar', vim.fs.abspath('/foo/bar'))
      end
    end)

    it('expands ~', function()
      eq(home .. '/foo', vim.fs.abspath('~/foo'))
      eq(home .. '/./.././foo', vim.fs.abspath('~/./.././foo'))
    end)

    if is_os('win') then
      it('works with drive-specific cwd on Windows', function()
        local cwd_drive = cwd:match('^%w:')

        eq(cwd .. '/foo', vim.fs.abspath(cwd_drive .. 'foo'))
      end)
    end
  end)

  describe('relpath()', function()
    it('works', function()
      local cwd = assert(t.fix_slashes(assert(vim.uv.cwd())))
      local my_dir = vim.fs.joinpath(cwd, 'foo')

      eq(nil, vim.fs.relpath('/var/lib', '/var'))
      eq(nil, vim.fs.relpath('/var/lib', '/bin'))
      eq(nil, vim.fs.relpath(my_dir, 'bin'))
      eq(nil, vim.fs.relpath(my_dir, './bin'))
      eq(nil, vim.fs.relpath(my_dir, '././'))
      eq(nil, vim.fs.relpath(my_dir, '../'))
      eq(nil, vim.fs.relpath('/var/lib', '/'))
      eq(nil, vim.fs.relpath('/var/lib', '//'))
      eq(nil, vim.fs.relpath(' ', '/var'))
      eq(nil, vim.fs.relpath(' ', '/var'))
      eq('.', vim.fs.relpath('/var/lib', '/var/lib'))
      eq('lib', vim.fs.relpath('/var/', '/var/lib'))
      eq('var/lib', vim.fs.relpath('/', '/var/lib'))
      eq('bar/package.json', vim.fs.relpath('/foo/test', '/foo/test/bar/package.json'))
      eq('foo/bar', vim.fs.relpath(cwd, 'foo/bar'))
      eq('foo/bar', vim.fs.relpath('.', vim.fs.joinpath(cwd, 'foo/bar')))
      eq('bar', vim.fs.relpath('foo', 'foo/bar'))
      eq(nil, vim.fs.relpath('/var/lib', '/var/library/foo'))

      if is_os('win') then
        eq(nil, vim.fs.relpath('/', ' '))
        eq(nil, vim.fs.relpath('/', 'var'))
      else
        local cwd_rel_root = cwd:sub(2)
        eq(cwd_rel_root .. '/ ', vim.fs.relpath('/', ' '))
        eq(cwd_rel_root .. '/var', vim.fs.relpath('/', 'var'))
      end

      if is_os('win') then
        eq(nil, vim.fs.relpath('c:/aaaa/', '/aaaa/cccc'))
        eq(nil, vim.fs.relpath('c:/aaaa/', './aaaa/cccc'))
        eq(nil, vim.fs.relpath('c:/aaaa/', 'aaaa/cccc'))
        eq(nil, vim.fs.relpath('c:/blah\\blah', 'd:/games'))
        eq(nil, vim.fs.relpath('c:/games', 'd:/games'))
        eq(nil, vim.fs.relpath('c:/games', 'd:/games/foo'))
        eq(nil, vim.fs.relpath('c:/aaaa/bbbb', 'c:/aaaa'))
        eq('cccc', vim.fs.relpath('c:/aaaa/', 'c:/aaaa/cccc'))
        eq('aaaa/bbbb', vim.fs.relpath('C:/', 'c:\\aaaa\\bbbb'))
        eq('bar/package.json', vim.fs.relpath('C:\\foo\\test', 'C:\\foo\\test\\bar\\package.json'))
        eq('baz', vim.fs.relpath('\\\\foo\\bar', '\\\\foo\\bar\\baz'))
        eq(nil, vim.fs.relpath('a/b/c', 'a\\b'))
        eq('d', vim.fs.relpath('a/b/c', 'a\\b\\c\\d'))
        eq('.', vim.fs.relpath('\\\\foo\\bar\\baz', '\\\\foo\\bar\\baz'))
        eq(nil, vim.fs.relpath('C:\\foo\\test', 'C:\\foo\\Test\\bar\\package.json'))
      end
    end)
  end)

  describe('rm()', function()
    before_each(function()
      t.mkdir('Xtest_fs-rm')
      t.write_file('Xtest_fs-rm/file-to-link', 'File to link')
      t.mkdir('Xtest_fs-rm/dir-to-link')
      t.write_file('Xtest_fs-rm/dir-to-link/file', 'File in dir to link')
    end)

    after_each(function()
      vim.uv.fs_unlink('Xtest_fs-rm/dir-to-link/file')
      vim.uv.fs_rmdir('Xtest_fs-rm/dir-to-link')
      vim.uv.fs_unlink('Xtest_fs-rm/file-to-link')
      vim.uv.fs_rmdir('Xtest_fs-rm')
    end)

    it('symlink', function()
      -- File
      vim.uv.fs_symlink('Xtest_fs-rm/file-to-link', 'Xtest_fs-rm/file-as-link')
      vim.fs.rm('Xtest_fs-rm/file-as-link')
      eq(vim.uv.fs_stat('Xtest_fs-rm/file-as-link'), nil)
      eq({ 'File to link' }, fn.readfile('Xtest_fs-rm/file-to-link'))

      -- Directory
      local function assert_rm_symlinked_dir(opts)
        vim.uv.fs_symlink('Xtest_fs-rm/dir-to-link', 'Xtest_fs-rm/dir-as-link')
        vim.fs.rm('Xtest_fs-rm/dir-as-link', opts)
        eq(vim.uv.fs_stat('Xtest_fs-rm/dir-as-link'), nil)
        eq({ 'File in dir to link' }, fn.readfile('Xtest_fs-rm/dir-to-link/file'))
      end

      assert_rm_symlinked_dir({})
      assert_rm_symlinked_dir({ force = true })
      assert_rm_symlinked_dir({ recursive = true })
      assert_rm_symlinked_dir({ recursive = true, force = true })
    end)
  end)

  describe('ext()', function()
    it('works', function()
      -- See test/functional/vimscript/fnamemodify_spec.lua
    end)
  end)
end)
