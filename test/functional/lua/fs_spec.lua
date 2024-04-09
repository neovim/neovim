local t = require('test.functional.testutil')()

local clear = t.clear
local exec_lua = t.exec_lua
local eq = t.eq
local mkdir_p = t.mkdir_p
local rmdir = t.rmdir
local nvim_dir = t.nvim_dir
local test_build_dir = t.paths.test_build_dir
local test_source_path = t.paths.test_source_path
local nvim_prog = t.nvim_prog
local is_os = t.is_os
local mkdir = t.mkdir

local nvim_prog_basename = is_os('win') and 'nvim.exe' or 'nvim'

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

before_each(clear)

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
        exec_lua(
          [[
        local dir, nvim = ...
        for name, type in vim.fs.dir(dir) do
          if name == nvim and type == 'file' then
            return true
          end
        end
        return false
      ]],
          nvim_dir,
          nvim_prog_basename
        )
      )
    end)

    it('works with opts.depth and opts.skip', function()
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

      local function run(dir, depth, skip)
        local r = exec_lua(
          [[
          local dir, depth, skip = ...
          local r = {}
          local skip_f
          if skip then
            skip_f = function(n)
              if vim.tbl_contains(skip or {}, n) then
                return false
              end
            end
          end
          for name, type_ in vim.fs.dir(dir, { depth = depth, skip = skip_f }) do
            r[name] = type_
          end
          return r
        ]],
          dir,
          depth,
          skip
        )
        return r
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
    end)
  end)

  describe('find()', function()
    it('works', function()
      eq(
        { test_build_dir .. '/build' },
        vim.fs.find('build', { path = nvim_dir, upward = true, type = 'directory' })
      )
      eq({ nvim_prog }, vim.fs.find(nvim_prog_basename, { path = test_build_dir, type = 'file' }))

      local parent, name = nvim_dir:match('^(.*/)([^/]+)$')
      eq({ nvim_dir }, vim.fs.find(name, { path = parent, upward = true, type = 'directory' }))
    end)

    it('accepts predicate as names', function()
      local opts = { path = nvim_dir, upward = true, type = 'directory' }
      eq(
        { test_build_dir .. '/build' },
        vim.fs.find(function(x)
          return x == 'build'
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
        exec_lua(
          [[
          local dir = ...
          return vim.tbl_map(vim.fs.basename, vim.fn.glob(dir..'/contrib/*', false, true))
        ]],
          test_source_path
        ),
        vim.tbl_map(
          vim.fs.basename,
          vim.fs.find(function(_, d)
            return d:match('[\\/]contrib$')
          end, opts)
        )
      )
    end)
  end)

  describe('joinpath()', function()
    it('works', function()
      eq('foo/bar/baz', vim.fs.joinpath('foo', 'bar', 'baz'))
      eq('foo/bar/baz', vim.fs.joinpath('foo', '/bar/', '/baz'))
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
        exec_lua(
          [[
        vim.env.XDG_CONFIG_HOME = ...
        return vim.fs.normalize('$XDG_CONFIG_HOME/nvim')
      ]],
          xdg_config_home
        )
      )
    end)

    it('works with UNC paths', function()
      eq('//foo', vim.fs.normalize('//foo')) -- UNC path
      eq('//foo/bar', vim.fs.normalize('//foo//bar////')) -- UNC path
      eq('/foo', vim.fs.normalize('///foo')) -- Not a UNC path
      eq('/', vim.fs.normalize('//')) -- Not a UNC path
      eq('/', vim.fs.normalize('///')) -- Not a UNC path
      eq('/foo/bar', vim.fs.normalize('/foo//bar////')) -- Not a UNC path
    end)

    if is_os('win') then
      it('Last slash is not truncated from root drive', function()
        eq('C:/', vim.fs.normalize('C:/'))
      end)
      it('converts backward slashes', function()
        eq('C:/Users/jdoe', vim.fs.normalize('C:\\Users\\jdoe'))
      end)
    else
      it('allows backslashes on unix-based os', function()
        eq('/home/user/hello\\world', vim.fs.normalize('/home/user/hello\\world'))
      end)
    end
  end)
end)
