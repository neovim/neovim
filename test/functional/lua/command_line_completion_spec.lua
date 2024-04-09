local t = require('test.functional.testutil')()

local clear = t.clear
local eq = t.eq
local exec_lua = t.exec_lua

local get_completions = function(input, env)
  return exec_lua('return {vim._expand_pat(...)}', input, env)
end

local get_compl_parts = function(parts)
  return exec_lua('return {vim._expand_pat_get_parts(...)}', parts)
end

before_each(clear)

describe('nlua_expand_pat', function()
  it('should complete exact matches', function()
    eq({ { 'exact' }, 0 }, get_completions('exact', { exact = true }))
  end)

  it('should return empty table when nothing matches', function()
    eq({ {}, 0 }, get_completions('foo', { bar = true }))
  end)

  it('should return nice completions with function call prefix', function()
    eq({ { 'FOO' }, 6 }, get_completions('print(F', { FOO = true, bawr = true }))
  end)

  it('should return keys for nested dictionaries', function()
    eq(
      { {
        'nvim_buf_set_lines',
      }, 8 },
      get_completions('vim.api.nvim_buf_', {
        vim = {
          api = {
            nvim_buf_set_lines = true,
            nvim_win_doesnt_match = true,
          },
          other_key = true,
        },
      })
    )
  end)

  it('it should work with colons', function()
    eq(
      { {
        'bawr',
        'baz',
      }, 8 },
      get_completions('MyClass:b', {
        MyClass = {
          baz = true,
          bawr = true,
          foo = false,
        },
      })
    )
  end)

  it('should return keys for string reffed dictionaries', function()
    eq(
      { {
        'nvim_buf_set_lines',
      }, 11 },
      get_completions('vim["api"].nvim_buf_', {
        vim = {
          api = {
            nvim_buf_set_lines = true,
            nvim_win_doesnt_match = true,
          },
          other_key = true,
        },
      })
    )
  end)

  it('should return keys for string reffed dictionaries', function()
    eq(
      { {
        'nvim_buf_set_lines',
      }, 21 },
      get_completions('vim["nested"]["api"].nvim_buf_', {
        vim = {
          nested = {
            api = {
              nvim_buf_set_lines = true,
              nvim_win_doesnt_match = true,
            },
          },
          other_key = true,
        },
      })
    )
  end)

  it('should work with lazy submodules of "vim" global', function()
    eq({ { 'inspect', 'inspect_pos' }, 4 }, get_completions('vim.inspec'))

    eq({ { 'treesitter' }, 4 }, get_completions('vim.treesi'))

    eq({ { 'set' }, 11 }, get_completions('vim.keymap.se'))
  end)

  it('should be able to interpolate globals', function()
    eq(
      { {
        'nvim_buf_set_lines',
      }, 12 },
      get_completions('vim[MY_VAR].nvim_buf_', {
        MY_VAR = 'api',
        vim = {
          api = {
            nvim_buf_set_lines = true,
            nvim_win_doesnt_match = true,
          },
          other_key = true,
        },
      })
    )
  end)

  it('should return everything if the input is of length 0', function()
    eq({ { 'other', 'vim' }, 0 }, get_completions('', { vim = true, other = true }))
  end)

  describe('get_parts', function()
    it('should return an empty list for no separators', function()
      eq({ {}, 1 }, get_compl_parts('vim'))
    end)

    it('just the first item before a period', function()
      eq({ { 'vim' }, 5 }, get_compl_parts('vim.ap'))
    end)

    it('should return multiple parts just for period', function()
      eq({ { 'vim', 'api' }, 9 }, get_compl_parts('vim.api.nvim_buf'))
    end)

    it('should be OK with colons', function()
      eq({ { 'vim', 'api' }, 9 }, get_compl_parts('vim:api.nvim_buf'))
    end)

    it('should work for just one string ref', function()
      eq({ { 'vim', 'api' }, 12 }, get_compl_parts("vim['api'].nvim_buf"))
    end)

    it('should work for just one string ref, with double quote', function()
      eq({ { 'vim', 'api' }, 12 }, get_compl_parts('vim["api"].nvim_buf'))
    end)

    it('should allows back-to-back string ref', function()
      eq({ { 'vim', 'nested', 'api' }, 22 }, get_compl_parts('vim["nested"]["api"].nvim_buf'))
    end)

    it('should allows back-to-back string ref with spaces before and after', function()
      eq({ { 'vim', 'nested', 'api' }, 25 }, get_compl_parts('vim[ "nested"  ]["api"].nvim_buf'))
    end)

    it('should allow VAR style loolup', function()
      eq({ { 'vim', { 'NESTED' }, 'api' }, 20 }, get_compl_parts('vim[NESTED]["api"].nvim_buf'))
    end)
  end)
end)
