local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local clear = helpers.clear
local pathroot = helpers.pathroot

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
      vim.api.nvim_buf_set_name(0, 'main.rs')
      vim.filetype.match(0)
      return vim.bo.filetype
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
      vim.api.nvim_buf_set_name(0, 'main.rs')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]])
  end)

  it('works with filenames', function()
    eq('nim', exec_lua [[
      vim.filetype.add({
        filename = {
          ['s_O_m_e_F_i_l_e'] = 'nim',
        },
      })
      vim.api.nvim_buf_set_name(0, 's_O_m_e_F_i_l_e')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]])

    eq('dosini', exec_lua([[
      local root = ...
      vim.filetype.add({
        filename = {
          ['config'] = 'toml',
          [root .. '/.config/fun/config'] = 'dosini',
        },
      })
      vim.api.nvim_buf_set_name(0, root .. '/.config/fun/config')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]], root))
  end)

  it('works with patterns', function()
    eq('markdown', exec_lua([[
      local root = ...
      vim.filetype.add({
        pattern = {
          [root .. '/blog/.*%.txt'] = 'markdown',
        }
      })
      vim.api.nvim_buf_set_name(0, root .. '/blog/why_neovim_is_awesome.txt')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]], root))
  end)

  it('works with functions', function()
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
      vim.api.nvim_buf_set_name(0, 'relevant_to_me')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]])
  end)
end)
