local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local meths = helpers.meths
local clear = helpers.clear
local pathroot = helpers.pathroot
local command = helpers.command

local root = pathroot()

describe('vim.filetype', function()
  before_each(function()
    clear()

    exec_lua [[
      local bufnr = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(bufnr)
    ]]
  end)

  it('works with extensions', function()
    eq('radicalscript', exec_lua [[
      vim.filetype.add({
        extension = {
          rs = 'radicalscript',
        },
      })
      return vim.filetype.match({ filename = 'main.rs' })
    ]])
  end)

  it('prioritizes filenames over extensions', function()
    eq('somethingelse', exec_lua [[
      vim.filetype.add({
        extension = {
          rs = 'radicalscript',
        },
        filename = {
          ['main.rs'] = 'somethingelse',
        },
      })
      return vim.filetype.match({ filename = 'main.rs' })
    ]])
  end)

  it('works with filenames', function()
    eq('nim', exec_lua [[
      vim.filetype.add({
        filename = {
          ['s_O_m_e_F_i_l_e'] = 'nim',
        },
      })
      return vim.filetype.match({ filename = 's_O_m_e_F_i_l_e' })
    ]])

    eq('dosini', exec_lua([[
      local root = ...
      vim.filetype.add({
        filename = {
          ['config'] = 'toml',
          [root .. '/.config/fun/config'] = 'dosini',
        },
      })
      return vim.filetype.match({ filename = root .. '/.config/fun/config' })
    ]], root))
  end)

  it('works with patterns', function()
    eq('markdown', exec_lua([[
      local root = ...
      vim.env.HOME = '/a-funky+home%dir'
      vim.filetype.add({
        pattern = {
          ['~/blog/.*%.txt'] = 'markdown',
        }
      })
      return vim.filetype.match({ filename = '~/blog/why_neovim_is_awesome.txt' })
    ]], root))
  end)

  it('works with functions', function()
    command('new')
    command('file relevant_to_me')
    eq('foss', exec_lua [[
      vim.filetype.add({
        pattern = {
          ["relevant_to_(%a+)"] = function(path, bufnr, capture)
            if capture == "me" then
              return "foss"
            end
          end,
        }
      })
      return vim.filetype.match({ buf = 0 })
    ]])
  end)

  it('works with contents #22180', function()
    eq('sh', exec_lua [[
      -- Needs to be set so detect#sh doesn't fail
      vim.g.ft_ignore_pat = '\\.\\(Z\\|gz\\|bz2\\|zip\\|tgz\\)$'
      return vim.filetype.match({ contents = { '#!/usr/bin/env bash' } })
    ]])
  end)

  it('considers extension mappings when matching from hashbang', function()
    eq('fooscript', exec_lua [[
      vim.filetype.add({
        extension = {
          foo = 'fooscript',
        }
      })
      return vim.filetype.match({ contents = { '#!/usr/bin/env foo' } })
    ]])
  end)

  it('can get default option values for filetypes via vim.filetype.get_option()', function()
    command('filetype plugin on')

    for ft, opts in pairs {
      lua = { commentstring = '-- %s' },
      vim = { commentstring = '"%s' },
      man = { tagfunc = 'v:lua.require\'man\'.goto_tag' },
      xml = { formatexpr = 'xmlformat#Format()' }
    } do
      for option, value in pairs(opts) do
        eq(value, exec_lua([[ return vim.filetype.get_option(...) ]], ft, option))
      end
    end

  end)
end)

describe('filetype.lua', function()
  it('does not override user autocommands that set filetype #20333', function()
    clear({args={'--clean', '--cmd', 'autocmd BufRead *.md set filetype=notmarkdown', 'README.md'}})
    eq('notmarkdown', meths.get_option_value('filetype', {}))
  end)
end)
