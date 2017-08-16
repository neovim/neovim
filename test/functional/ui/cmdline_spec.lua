local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local source = helpers.source

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

  function expect_cmdline(expected)
    local attr_ids = screen._default_attr_ids
    local attr_ignore = screen._default_attr_ignore
    local actual = ''
    for _, chunk in ipairs(content or {}) do
      local attrs, text = chunk[1], chunk[2]
      if screen:_equal_attrs(attrs, {}) then
        actual = actual..text
      else
        local attr_id = screen:_get_attr_id(attr_ids, attr_ignore, attrs)
        actual =  actual..'{' .. attr_id .. ':' .. text .. '}'
      end
    end
    eq(expected, actual)
  end

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
        eq({{{}, 'sign'}}, content)
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
        eq({{{}, 'sign'}}, content)
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
        eq({{{}, 'sin'}}, content)
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
        eq({{{}, 'default'}}, content)
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
        eq({{{}, '1+2'}}, content)
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
        eq({{{}, '3'}}, content)
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
        eq(2, indent)
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
        eq(2, indent)
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

  it('works with highlighted cmdline', function()
      source([[
        highlight RBP1 guibg=Red
        highlight RBP2 guibg=Yellow
        highlight RBP3 guibg=Green
        highlight RBP4 guibg=Blue
        let g:NUM_LVLS = 4
        function RainBowParens(cmdline)
          let ret = []
          let i = 0
          let lvl = 0
          while i < len(a:cmdline)
            if a:cmdline[i] is# '('
              call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
              let lvl += 1
            elseif a:cmdline[i] is# ')'
              let lvl -= 1
              call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
            endif
            let i += 1
          endwhile
          return ret
        endfunction
        map <f5>  :let x = input({'prompt':'>','highlight':'RainBowParens'})<cr>
        "map <f5>  :let x = input({'prompt':'>'})<cr>
      ]])
      screen:set_default_attr_ids({
        RBP1={background = Screen.colors.Red},
        RBP2={background = Screen.colors.Yellow},
        RBP3={background = Screen.colors.Green},
        RBP4={background = Screen.colors.Blue},
        EOB={bold = true, foreground = Screen.colors.Blue1},
        ERR={foreground = Screen.colors.Grey100, background = Screen.colors.Red},
        SK={foreground = Screen.colors.Blue},
        PE={bold = true, foreground = Screen.colors.SeaGreen4}
      })
      feed('<f5>(a(b)a)')
      screen:expect([[
        ^                         |
        {EOB:~                        }|
        {EOB:~                        }|
        {EOB:~                        }|
                                 |
      ]], nil, nil, function()
        expect_cmdline('{RBP1:(}a{RBP2:(}b{RBP2:)}a{RBP1:)}')
      end)
  end)
end)
