local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, execute, eq = helpers.clear, helpers.feed, helpers.execute, helpers.eq
local funcs = helpers.funcs

if helpers.pending_win32(pending) then return end

describe('External command line completion', function()
  local screen
  local shown = false
  local firstc, prompt, content, pos

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, cmdline_external=true})
    screen:set_on_event_handler(function(name, data)
      if name == "cmdline_enter" then
        shown = true
      elseif name == "cmdline_leave" then
        shown = false
      elseif name == "cmdline_firstc" then
        firstc = data[1]
      elseif name == "cmdline_prompt" then
        prompt = data[1]
      elseif name == "cmdline" then
        content, pos = unpack(data)
      elseif name == "cmdline_pos" then
        pos = data[1]
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
        eq("sign", content)
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
        eq("sign", content)
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
        eq("sin", content)
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

    end)
  end)
end)
