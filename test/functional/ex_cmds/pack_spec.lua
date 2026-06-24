local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local matches = t.matches
local ok = t.ok
local pcall_err = t.pcall_err

local foo = {
  active = true,
  path = '/dev/null',
  rev = '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33',
  spec = {
    name = 'foo',
    src = 'https://foo.example/foo/foo',
  },
}
local bar = {
  active = false,
  path = '/var/empty',
  rev = '62cdb7020ff920e5aa642c3d4066950dd1f01f4d',
  spec = {
    name = 'bar',
    src = 'https://foo.example/bar/bar',
    version = vim.version.range('0.42.42rc1'),
  },
}

local function assert_success(fn)
  exec_lua(fn)
  ok(exec_lua('return _G.success'), 'true', '_G.success')
end

local function assert_completion(pat, expected)
  local completions = exec_lua(function()
    return vim.fn.getcompletion(pat, 'cmdline')
  end)
  eq(expected, completions)
end

describe(':packupdate', function()
  before_each(function()
    clear()
    exec_lua(function()
      vim.pack.get = function(names, opts)
        assert(opts.info == false)
        return { foo, bar }
      end
    end)
  end)

  it('works', function()
    assert_success(function()
      vim.pack.update = function(names, opts)
        success = names == nil and opts.force ~= true and opts._ex == true
      end
      vim.cmd.packupdate()

      vim.pack.update = function(names, opts)
        success = success
          and names[1] == 'foo'
          and names[2] == nil
          and opts.force ~= true
          and opts._ex == true
      end
      vim.cmd.packupdate { 'foo' }
    end)
  end)

  it('handles !', function()
    assert_success(function()
      vim.pack.update = function(names, opts)
        success = opts.force == true
      end
      vim.cmd.packupdate { bang = true }
    end)
  end)

  it('handles args', function()
    assert_success(function()
      vim.pack.update = function(names, opts)
        success = opts.offline == true
      end
      vim.cmd.packupdate { '++offline' }

      vim.pack.update = function(names, opts)
        success = success and opts.target == 'lockfile'
      end
      vim.cmd.packupdate { '++lockfile' }
    end)
  end)

  it('shows E5807', function()
    eq('Vim(packupdate):E5807: Plugin not installed: baz', pcall_err(command, 'packupdate baz'))
  end)

  it('shows E5808', function()
    exec_lua(function()
      vim.pack.get = function(names, opts)
        return {}
      end
    end)
    eq('Vim(packupdate):E5808: Nothing to update', pcall_err(command, 'packupdate'))
  end)

  it('has completion', function()
    assert_completion('packupdate ', { 'bar', 'foo' })
    assert_completion('packupdate b', { 'bar' })
    assert_completion('packupdate ++', { '++lockfile', '++offline' })
  end)

  it('fails if runtime is missing/broken', function()
    clear {
      args_rm = { '-u' },
      args = { '-u', 'NONE' },
      env = { VIMRUNTIME = 'non-existent' },
    }
    matches(
      [[.*module 'vim%.pack' not found:]],
      vim.split(t.pcall_err(n.command, 'packupdate foo'), '\n')[1]
    )
  end)
end)

describe(':packdel', function()
  before_each(function()
    clear()
    exec_lua(function()
      vim.pack.get = function(names, opts)
        assert(opts.info == false)
        return { foo, bar }
      end
    end)
  end)

  it('works', function()
    assert_success(function()
      vim.pack.del = function(names, opts)
        success = names[1] == 'bar' and names[2] == nil and opts.force ~= true and opts._ex == true
      end
      vim.cmd.packdel { 'bar' }
    end)
  end)

  it('handles !', function()
    assert_success(function()
      vim.pack.del = function(names, opts)
        success = opts.force == true
      end
      vim.cmd.packdel { 'bar', bang = true }
    end)
  end)

  it('handles ++all', function()
    assert_success(function()
      vim.pack.del = function(names, opts)
        success = vim.list_contains(names, 'bar') and not vim.list_contains(names, 'foo')
      end
      vim.cmd.packdel { '++all' }

      vim.pack.del = function(names, opts)
        success = success and vim.list_contains(names, 'foo') and vim.list_contains(names, 'bar')
      end
      vim.cmd.packdel { '++all', bang = true }
    end)
  end)

  it('shows E5807', function()
    eq('Vim(packdel):E5807: Plugin not installed: baz', pcall_err(command, 'packdel baz'))
  end)

  it('shows E5809', function()
    exec_lua(function()
      vim.pack.get = function(names, opts)
        return {}
      end
    end)
    eq('Vim(packdel):E5809: Nothing to remove', pcall_err(command, 'packdel ++all'))
  end)

  it('shows E5811', function()
    eq(
      'Vim(packdel):E5811: Cannot specify plugin names when using ++all',
      pcall_err(command, 'packdel bar ++all')
    )
  end)

  it('has completion', function()
    assert_completion('packdel ', { 'bar' })
    assert_completion('packdel! ', { 'bar', 'foo' })
    assert_completion('packdel! b', { 'bar' })
    assert_completion('packdel ++', { '++all' })
    assert_completion('packdel! ++', { '++all' })
  end)

  it('fails if runtime is missing/broken', function()
    clear {
      args_rm = { '-u' },
      args = { '-u', 'NONE' },
      env = { VIMRUNTIME = 'non-existent' },
    }
    matches(
      [[.*module 'vim%.pack' not found:]],
      vim.split(t.pcall_err(n.command, 'packdel foo'), '\n')[1]
    )
  end)
end)
