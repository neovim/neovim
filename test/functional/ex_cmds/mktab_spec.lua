local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local fn = n.fn
local eq = t.eq
local feed = n.feed

-- local file_prefix = 'Xtest-functional-ex_cmds-mktab_spec'
-- local file_prefix = vim.fn.tempname()

local function _scommand(cmd)
  command(":silent " .. cmd)
end

local function _create_and_feed_session(temp_file)
    feed("ithis is a test<cr>oui, un test<esc>")
    buf_file = fn.tempname()
    temp_file = fn.tempname() .. ".vim"
    _scommand("w " .. buf_file)
    command(":mksession " .. temp_file)
    return temp_file
end

local function _clear_temp_file(temp_file)
  if temp_file ~= nil then
      fn.delete(temp_file)
      temp_file = nil
    end
end



describe(":mktab", function()
  local screen
  local temp_file, buf_file = nil

  before_each(function()
    clear()
    screen = Screen.new(15, 5)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {bold = false, foreground = Screen.colors.Brown}
    })
  end)

  after_each(function()
    _clear_temp_file(temp_file)
    _clear_temp_file(buf_file)
  end)

  it('screen test', function()
    feed('iline1<cr>line2<esc>')
    screen:expect([[
      line1          |
      line^2          |
      {0:~              }|*2
                     |
    ]])
  end)

  it("mksession default write", function()
    temp_file = _create_and_feed_session(temp_file)
    eq(1, fn.filereadable(temp_file))
  end)

  it("mksession default restore", function()
    temp_file = _create_and_feed_session(temp_file)
    -- erasing current buffer
    command(":enew!")
    command(":source " .. temp_file)
    screen:expect([[
      this is a test |
      oui, un tes^t   |
      {0:~              }|*2
                     |
    ]])
  end)
end)
