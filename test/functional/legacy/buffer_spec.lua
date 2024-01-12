local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local call, eq, api = helpers.call, helpers.eq, helpers.api

local function expected_empty()
  eq({}, api.nvim_get_vvar('errors'))
end

describe('buffer', function()
  before_each(function()
    clear()
    api.nvim_ui_attach(80, 24, {})
    api.nvim_set_option_value('hidden', false, {})
  end)

  it('deleting a modified buffer with :confirm', function()
    source([[
      func Test_bdel_with_confirm()
        new
        call setline(1, 'test')
        call assert_fails('bdel', 'E89:')
        call nvim_input('c')
        confirm bdel
        call assert_equal(2, winnr('$'))
        call assert_equal(1, &modified)
        call nvim_input('n')
        confirm bdel
        call assert_equal(1, winnr('$'))
      endfunc
    ]])
    call('Test_bdel_with_confirm')
    expected_empty()
  end)

  it('editing another buffer from a modified buffer with :confirm', function()
    source([[
      func Test_goto_buf_with_confirm()
        new Xfile
        enew
        call setline(1, 'test')
        call assert_fails('b Xfile', 'E37:')
        call nvim_input('c')
        call assert_fails('confirm b Xfile', 'E37:')
        call assert_equal(1, &modified)
        call assert_equal('', @%)
        call nvim_input('y')
        call assert_fails('confirm b Xfile', 'E37:')
        call assert_equal(1, &modified)
        call assert_equal('', @%)
        call nvim_input('n')
        confirm b Xfile
        call assert_equal('Xfile', @%)
        close!
      endfunc
    ]])
    call('Test_goto_buf_with_confirm')
    expected_empty()
  end)
end)
