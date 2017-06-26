local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq

if helpers.pending_win32(pending) then return end

describe('External command line completion', function()
  local screen
  local shown = false
  local firstc, prompt, content, pos, char, shift, indent, level, current_hide_level, in_function

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_cmdline=true})
    screen:set_on_event_handler(function(name, data)
      if name == "cmdline_hide" then
        shown = false
        current_hide_level = data[1]
      elseif name == "cmdline_show" then
        shown = true
        content, pos, firstc, prompt, indent, level = unpack(data)
      elseif name == "cmdline_char" then
        char, shift = unpack(data)
      elseif name == "cmdline_pos" then
        pos = data[1]
      elseif name == "cmdline_function_show" then
        in_function = true
      elseif name == "cmdline_function_hide" then
        in_function = false
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  describe("'cmdline'", function()
    it(':sign', function()
      feed(':')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(true, shown)
        eq(':', firstc)
      end)

      feed('sign')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq({{'Normal', 'sign'}}, content)
        eq(4, pos)
      end)

      feed('<Left>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq({{'Normal', 'sign'}}, content)
        eq(true, shown)
        eq(3, pos)
      end)

      feed('<bs>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq({{'Normal', 'sin'}}, content)
        eq(true, shown)
        eq(2, pos)
      end)

      feed('<Esc>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(false, shown)
      end)

      feed(':call input("input", "default")<cr>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(true, shown)
        eq("input", prompt)
        eq({{'Normal', 'default'}}, content)
      end)
      feed('<cr>')

      feed(':')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(1, level)
      end)

      feed('<C-R>=1+2')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq({{'Normal', '1+2'}}, content)
        eq("\"", char)
        eq(1, shift)
        eq(2, level)
      end)

      feed('<cr>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq({{'Normal', '3'}}, content)
        eq(2, current_hide_level)
        eq(1, level)
      end)

      feed('<esc>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(1, current_hide_level)
      end)

      feed(':function Foo()<cr>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(true, in_function)
      end)

      feed('line1<cr>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(true, in_function)
      end)

      feed('endfunction<cr>')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(false, in_function)
      end)

      feed(':sign<c-f>')
      screen:expect([[
                                 |
        [No Name]                |
        :sign^                    |
        [Command Line]           |
                                 |
      ]], nil, nil, function()
        eq(false, in_function)
      end)

    end)
  end)
end)
