local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local clear = helpers.clear

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
      vim.api.nvim_buf_set_name(0, '/home/user/src/main.rs')
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
      vim.api.nvim_buf_set_name(0, '/home/usr/src/main.rs')
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
      vim.api.nvim_buf_set_name(0, '/home/user/src/s_O_m_e_F_i_l_e')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]])

    eq('dosini', exec_lua [[
      vim.filetype.add({
        filename = {
          ['config'] = 'toml',
          ['~/.config/fun/config'] = 'dosini',
        },
      })
      vim.api.nvim_buf_set_name(0, '~/.config/fun/config')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]])
  end)

  it('works with patterns', function()
    eq('markdown', exec_lua [[
      vim.filetype.add({
        pattern = {
          ['~/blog/.*%.txt'] = 'markdown',
        }
      })
      vim.api.nvim_buf_set_name(0, '~/blog/why_neovim_is_awesome.txt')
      vim.filetype.match(0)
      return vim.bo.filetype
    ]])
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
