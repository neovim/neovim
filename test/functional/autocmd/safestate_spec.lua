local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local exec = helpers.exec
local feed = helpers.feed
local api = helpers.api

before_each(clear)

describe('SafeState autocommand', function()
  local function create_autocmd()
    exec([[
      let g:safe = 0
      autocmd SafeState * ++once let g:safe += 1
    ]])
  end

  it('with pending operator', function()
    feed('d')
    create_autocmd()
    eq(0, api.nvim_get_var('safe'))
    feed('d')
    eq(1, api.nvim_get_var('safe'))
  end)

  it('with specified register', function()
    feed('"r')
    create_autocmd()
    eq(0, api.nvim_get_var('safe'))
    feed('x')
    eq(1, api.nvim_get_var('safe'))
  end)

  it('with i_CTRL-O', function()
    feed('i<C-O>')
    create_autocmd()
    eq(0, api.nvim_get_var('safe'))
    feed('x')
    eq(1, api.nvim_get_var('safe'))
  end)

  it('with Insert mode completion', function()
    feed('i<C-X><C-V>')
    create_autocmd()
    eq(0, api.nvim_get_var('safe'))
    feed('<C-X><C-Z>')
    eq(1, api.nvim_get_var('safe'))
  end)

  it('with Cmdline completion', function()
    feed(':<Tab>')
    create_autocmd()
    eq(0, api.nvim_get_var('safe'))
    feed('<C-E>')
    eq(1, api.nvim_get_var('safe'))
  end)
end)
