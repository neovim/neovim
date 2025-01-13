local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua

--- @return { [1]: string[], [2]: integer }
local get_completions = function(input, env)
  return exec_lua('return { vim._expand_pat(...) }', input, env)
end

--- @return { [1]: string[], [2]: integer }
local get_compl_parts = function(parts)
  return exec_lua('return { vim._expand_pat_get_parts(...) }', parts)
end

before_each(clear)

describe('nlua_expand_pat', function()
  it('completes exact matches', function()
    eq({ { 'exact' }, 0 }, get_completions('exact', { exact = true }))
  end)

  it('returns empty table when nothing matches', function()
    eq({ {}, 0 }, get_completions('foo', { bar = true }))
  end)

  it('returns nice completions with function call prefix', function()
    eq({ { 'FOO' }, 6 }, get_completions('print(F', { FOO = true, bawr = true }))
  end)

  it('returns keys for nested dicts', function()
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

  it('with colons', function()
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

  it('returns keys after string key', function()
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

  it('with lazy submodules of "vim" global', function()
    eq({ { 'inspect', 'inspect_pos' }, 4 }, get_completions('vim.inspec'))

    eq({ { 'treesitter' }, 4 }, get_completions('vim.treesi'))

    eq({ { 'set' }, 11 }, get_completions('vim.keymap.se'))
  end)

  it('excludes private fields after "."', function()
    eq(
      { { 'bar' }, 4 },
      get_completions('foo.', {
        foo = {
          _bar = true,
          bar = true,
        },
      })
    )
  end)

  it('includes private fields after "._"', function()
    eq(
      { { '_bar' }, 4 },
      get_completions('foo._', {
        foo = {
          _bar = true,
          bar = true,
        },
      })
    )
  end)

  it('can interpolate globals', function()
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

  describe('vim.fn', function()
    it('simple completion', function()
      local actual = get_completions('vim.fn.did')
      local expected = {
        { 'did_filetype' },
        #'vim.fn.',
      }
      eq(expected, actual)
    end)
    it('does not suggest "#" items', function()
      exec_lua [[
        -- ensure remote#host#... functions exist
        vim.cmd [=[
          runtime! autoload/remote/host.vim
        ]=]
        -- make a dummy call to ensure vim.fn contains an entry: remote#host#...
        vim.fn['remote#host#IsRunning']('python3')
      ]]
      local actual = get_completions('vim.fn.remo')
      local expected = {
        { 'remove' }, -- there should be no completion "remote#host#..."
        #'vim.fn.',
      }
      eq(expected, actual)
    end)
  end)

  describe('completes', function()
    it('vim.v', function()
      local actual = get_completions('vim.v.t_')
      local expected = {
        { 't_blob', 't_bool', 't_dict', 't_float', 't_func', 't_list', 't_number', 't_string' },
        #'vim.v.',
      }
      eq(expected, actual)
    end)

    it('vim.g', function()
      exec_lua [[
        vim.cmd [=[
          let g:nlua_foo = 'completion'
          let g:nlua_foo_bar = 'completion'
          let g:nlua_foo#bar = 'nocompletion'  " should be excluded from lua completion
        ]=]
      ]]
      local actual = get_completions('vim.g.nlua')
      local expected = {
        { 'nlua_foo', 'nlua_foo_bar' },
        #'vim.g.',
      }
      eq(expected, actual)
    end)

    it('vim.b', function()
      exec_lua [[
        vim.b.nlua_foo_buf = 'bar'
        vim.b.some_other_vars = 'bar'
      ]]
      local actual = get_completions('vim.b.nlua')
      local expected = {
        { 'nlua_foo_buf' },
        #'vim.b.',
      }
      eq(expected, actual)
    end)

    it('vim.w', function()
      exec_lua [[
        vim.w.nlua_win_var = 42
      ]]
      local actual = get_completions('vim.w.nlua')
      local expected = {
        { 'nlua_win_var' },
        #'vim.w.',
      }
      eq(expected, actual)
    end)

    it('vim.t', function()
      exec_lua [[
        vim.t.nlua_tab_var = 42
      ]]
      local actual = get_completions('vim.t.')
      local expected = {
        { 'nlua_tab_var' },
        #'vim.t.',
      }
      eq(expected, actual)
    end)
  end)

  describe('completes', function()
    -- for { vim.o, vim.go, vim.opt, vim.opt_local, vim.opt_global }
    local test_opt = function(accessor)
      do
        local actual = get_completions(accessor .. '.file')
        local expected = {
          'fileencoding',
          'fileencodings',
          'fileformat',
          'fileformats',
          'fileignorecase',
          'filetype',
        }
        eq({ expected, #accessor + 1 }, actual, accessor .. '.file')
      end
      do
        local actual = get_completions(accessor .. '.winh')
        local expected = {
          'winheight',
          'winhighlight',
        }
        eq({ expected, #accessor + 1 }, actual, accessor .. '.winh')
      end
    end

    test_opt('vim.o')
    test_opt('vim.go')
    test_opt('vim.opt')
    test_opt('vim.opt_local')
    test_opt('vim.opt_global')

    it('vim.o, suggesting all known options', function()
      local completions = get_completions('vim.o.')[1] ---@type string[]
      eq(
        exec_lua [[
        return vim.tbl_count(vim.api.nvim_get_all_options_info())
      ]],
        #completions
      )
    end)

    it('vim.bo', function()
      do
        local actual = get_completions('vim.bo.file')
        local compls = {
          -- should contain buffer options only
          'fileencoding',
          'fileformat',
          'filetype',
        }
        eq({ compls, #'vim.bo.' }, actual)
      end
      do
        local actual = get_completions('vim.bo.winh')
        local compls = {}
        eq({ compls, #'vim.bo.' }, actual)
      end
    end)

    it('vim.wo', function()
      do
        local actual = get_completions('vim.wo.file')
        local compls = {}
        eq({ compls, #'vim.wo.' }, actual)
      end
      do
        local actual = get_completions('vim.wo.winh')
        -- should contain window options only
        local compls = { 'winhighlight' }
        eq({ compls, #'vim.wo.' }, actual)
      end
    end)
  end)

  it('returns everything if input is empty', function()
    eq({ { 'other', 'vim' }, 0 }, get_completions('', { vim = true, other = true }))
  end)

  it('get_parts', function()
    eq({ {}, 1 }, get_compl_parts('vim'))
    eq({ { 'vim' }, 5 }, get_compl_parts('vim.ap'))
    eq({ { 'vim', 'api' }, 9 }, get_compl_parts('vim.api.nvim_buf'))
    eq({ { 'vim', 'api' }, 9 }, get_compl_parts('vim:api.nvim_buf'))
    eq({ { 'vim', 'api' }, 12 }, get_compl_parts("vim['api'].nvim_buf"))
    eq({ { 'vim', 'api' }, 12 }, get_compl_parts('vim["api"].nvim_buf'))
    eq({ { 'vim', 'nested', 'api' }, 22 }, get_compl_parts('vim["nested"]["api"].nvim_buf'))
    eq({ { 'vim', 'nested', 'api' }, 25 }, get_compl_parts('vim[ "nested"  ]["api"].nvim_buf'))
    eq({ { 'vim', { 'NESTED' }, 'api' }, 20 }, get_compl_parts('vim[NESTED]["api"].nvim_buf'))
  end)
end)
