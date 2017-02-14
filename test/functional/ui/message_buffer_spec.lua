local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local execute, command = helpers.execute, helpers.command

before_each(function()
  local file = io.open('Xtest_msgbuf_script', 'w')
  file:write([[
function! s:throw_func() abort
  throw 'Error'
endfunction

function! Throw() abort
  call s:throw_func()
endfunction
]])
  file:close()
end)

after_each(function()
  os.remove('Xtest_msgbuf_script')
end)

describe(':messages', function()
  local screen

  local function echo_messages(times, final_message)
    if times == nil then
      times = 1
    end

    for _=1,times do
      command('echomsg "message 1"')

      command('echohl Green')
      command('echomsg "message 2"')
      command('echohl None')

      command('echo "not logged"')

      command('echohl Yellow')
      command('echomsg "message 3"')

      command('echohl Magenta')
      command('echomsg "message 4"')
      command('echohl None')
    end

    if final_message ~= nil then
      command('echomsg "' .. final_message .. '"')
    end
  end

  local function echo_long_messages(times, final_message)
    if times == nil then
      times = 1
    end

    for _=1,times do
      command('echomsg "message 1 xxxx xxxx xxxx xxxx xxxx xxxx xxxx end 1"')

      command('echohl Green')
      command('echomsg "message 2 xxxx xxxx xxxx xxxx xxxx xxxx xxxx end 2"')
      command('echohl None')

      command('echo "not logged"')

      command('echohl Yellow')
      command('echomsg "message 3 xxxx xxxx xxxx xxxx xxxx xxxx xxxx end 3"')

      command('echohl Magenta')
      command('echomsg "message 4 xxxx xxxx xxxx xxxx xxxx xxxx xxxx end 4"')
      command('echohl None')
    end

    if final_message ~= nil then
      command('echomsg "' .. final_message .. '"')
    end
  end

  before_each(function()
    clear({env={
      VIMRUNTIME='runtime',
      XDG_CONFIG_HOME='tmp/Xconfig',
    }})

    screen = Screen.new(40, 10)
    screen:attach()

    screen:set_default_attr_ids({
      [1]  = { bold = true, foreground = Screen.colors.Blue },
      [2]  = { reverse = true },
      [3]  = { bold = true, reverse = true },
      [4]  = { background = Screen.colors.Red },
      [5]  = { foreground = Screen.colors.Green },
      [6]  = { foreground = Screen.colors.Yellow },
      [7]  = { foreground = Screen.colors.Fuchsia },
      [8]  = { background = Screen.colors.Orange },
      [9]  = { bold = true, foreground = Screen.colors.SeaGreen },
      -- CursorLine
      [10] = { background = Screen.colors.Maroon },
      [11] = { background = Screen.colors.Maroon, foreground = Screen.colors.Green },
      [12] = { background = Screen.colors.Maroon, foreground = Screen.colors.Yellow },
      [13] = { background = Screen.colors.Maroon, foreground = Screen.colors.Fuchsia },
      -- Visual
      [14] = { background = Screen.colors.Coral },
      [15] = { background = Screen.colors.Coral, foreground = Screen.colors.Green },
      [16] = { background = Screen.colors.Coral, foreground = Screen.colors.Yellow },
      [17] = { background = Screen.colors.Coral, foreground = Screen.colors.Fuchsia },
      -- Search
      [18] = { background = Screen.colors.PeachPuff },
      [19] = { background = Screen.colors.PeachPuff, foreground = Screen.colors.Green },
      [20] = { background = Screen.colors.PeachPuff, foreground = Screen.colors.Yellow },
      [21] = { background = Screen.colors.PeachPuff, foreground = Screen.colors.Fuchsia },
      -- tabline
      [22] = { background = Screen.colors.LightGrey, underline = true },
      [23] = { background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Fuchsia },
      [24] = { bold = true },
      [25] = { bold = true, foreground = Screen.colors.Fuchsia },
    })

    -- Needs to be sourced before 'syntax on' and 'filetype plugin on' so that
    -- it's <SNR>1
    command('source Xtest_msgbuf_script')

    command('syntax on')
    command('filetype plugin on')

    command('highlight ErrorMsg guifg=none guibg=Red')
    command('highlight LineNr guifg=none guibg=Orange')
    command('highlight Green guifg=Green guibg=none')
    command('highlight Yellow guifg=Yellow guibg=none')
    command('highlight Magenta guifg=Magenta guibg=none')
    command('highlight CursorLine guibg=Maroon')
    command('highlight Visual guibg=Coral')
    command('highlight Search guibg=PeachPuff')
  end)

  describe('default', function()
    it('displays messages', function()
      echo_messages()
      execute('messages')

      screen:expect([[
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        message 1                               |
        {5:message 2}                               |
        {6:message 3}                               |
        {7:message 4}                               |
        {9:Press ENTER or type command to continue}^ |
      ]])
    end)

    it('displays exception', function()
      echo_messages()
      execute('call Throw()')

      screen:expect([[
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {4:Error detected while processing function}|
        {4: Throw[1]..<SNR>1_throw_func:}           |
        {8:line    1:}                              |
        {4:E605: Exception not caught: Error}       |
        {9:Press ENTER or type command to continue}^ |
      ]])
    end)
  end)

  describe('in a buffer', function()
    it('displays messages', function()
      echo_messages()
      command('set messagebuf')
      execute('messages')

      screen:expect([[
                                                |
        {2:[No Name]                               }|
        message 1                               |
        {5:message 2}                               |
        {6:message 3}                               |
        {7:^message 4}                               |
        {1:~                                       }|
        {1:~                                       }|
        {3:nvim://messages                         }|
        :messages                               |
      ]])
    end)

    it('displays an exception', function()
      echo_messages()
      command('set messagebuf')
      execute('messages')
      execute('call Throw()')

      screen:expect([[
                                                |
        {2:[No Name]                               }|
        {6:message 3}                               |
        {7:message 4}                               |
        {4:Error detected while processing function}|
        {4: Throw[1]..<SNR>1_throw_func:}           |
        {8:line    1:}                              |
        {4:^E605: Exception not caught: Error}       |
        {3:nvim://messages                         }|
        {4:E605: Exception not caught: Error}       |
      ]])
    end)

    it('displays the last message without prompting', function()
      command('set messagebuf')
      execute('call Throw()')

      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {4:E605: Exception not caught: Error}       |
      ]])

      echo_messages()

      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {7:message 4}                               |
      ]])

      echo_messages()
      execute('call Throw()')

      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {4:E605: Exception not caught: Error}       |
      ]])
    end)

    it('displays history before messagebuf enabled', function()
      echo_messages()
      command('set messagebuf')
      command('messages')

      screen:expect([[
                                                |
        {2:[No Name]                               }|
        message 1                               |
        {5:message 2}                               |
        {6:message 3}                               |
        {7:^message 4}                               |
        {1:~                                       }|
        {1:~                                       }|
        {3:nvim://messages                         }|
        {7:message 4}                               |
      ]])
    end)

    describe('auto scrolling', function()
      before_each(function()
        command('set messagebuf')
        command('messages')
      end)

      it('in an empty buffer', function()
        echo_messages(5, 'test')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          {7:message 4}                               |
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          ^test                                    |
          {3:nvim://messages                         }|
          test                                    |
        ]])
      end)

      it('disabled because cursor is not on last line', function()
        echo_messages(1, 'test')
        feed('k')
        echo_messages(5, 'end')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:^message 4}                               |
          test                                    |
          message 1                               |
          {3:nvim://messages                         }|
          end                                     |
        ]])
      end)

      it('continues after moving cursor back to last line', function()
        echo_messages(1, 'test')
        feed('k')
        echo_messages(5, 'mid')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:^message 4}                               |
          test                                    |
          message 1                               |
          {3:nvim://messages                         }|
          mid                                     |
        ]])

        feed('G')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          {7:message 4}                               |
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          ^mid                                     |
          {3:nvim://messages                         }|
          mid                                     |
        ]])

        echo_messages(5, 'end')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          {7:message 4}                               |
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          ^end                                     |
          {3:nvim://messages                         }|
          end                                     |
        ]])
      end)

      it("with 'wrap' enabled", function()
        command('set wrap')
        echo_long_messages(5, 'end')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          {6:message 3 xxxx xxxx xxxx xxxx xxxx xxxx }|
          {6:xxxx end 3}                              |
          {7:message 4 xxxx xxxx xxxx xxxx xxxx xxxx }|
          {7:xxxx end 4}                              |
          ^end                                     |
          {1:~                                       }|
          {3:nvim://messages                         }|
          end                                     |
        ]])
      end)
    end)

    describe('displays error functions', function()

      before_each(function()
        screen:try_resize(40, 20)

        command('set messagebuf')
        execute('messages')
        execute('call Throw()')

        screen:expect([[
                                                  |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {2:[No Name]                               }|
          {4:Error detected while processing function}|
          {4: Throw[1]..<SNR>1_throw_func:}           |
          {8:line    1:}                              |
          {4:^E605: Exception not caught: Error}       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          {4:E605: Exception not caught: Error}       |
        ]])
      end)

      it('selection', function()
        feed('2kgf')

        screen:expect([[
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {2:[No Name]                               }|
          {4:Error detected while processing function}|
          {4: Throw[1]..<SNR>1_throw_func:}           |
          {8:line    1:}                              |
          {4:E605: Exception not caught: Error}       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          Jump to function:                       |
          1. Throw()                              |
          2. s:throw_func()                       |
          Type number and <Enter> or click with mo|
          use (empty cancels): ^                   |
        ]])
      end)

      it('and selection jumps to split', function()
        feed('2kgf1<cr>')

        -- Remove the filename's text from the screen
        command('setlocal statusline=%t')
        command('echo')

        screen:expect([[
                                                  |
          function! Throw() abort                 |
            ^call s:throw_func()                   |
          endfunction                             |
          {1:~                                       }|
          {3:Xtest_msgbuf_script                     }|
                                                  |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {2:[No Name]                               }|
          {4:Error detected while processing function}|
          {4: Throw[1]..<SNR>1_throw_func:}           |
          {8:line    1:}                              |
          {4:E605: Exception not caught: Error}       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {2:nvim://messages                         }|
                                                  |
        ]])
      end)

      it('and selection jumps to existing buffer', function()
        command('wincmd k')
        command('setlocal statusline=%t')
        command('edit Xtest_msgbuf_script')
        command('wincmd j')
        feed('G2kgf1<cr>')

        screen:expect([[
            throw 'Error'                         |
          endfunction                             |
                                                  |
          function! Throw() abort                 |
            ^call s:throw_func()                   |
          endfunction                             |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {3:Xtest_msgbuf_script                     }|
          {4:Error detected while processing function}|
          {4: Throw[1]..<SNR>1_throw_func:}           |
          {8:line    1:}                              |
          {4:E605: Exception not caught: Error}       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {2:nvim://messages                         }|
                                                  |
        ]])
      end)
    end)

    describe('highlight', function()
      before_each(function()
        echo_messages()
        command('set messagebuf noshowmode')
        command('messages')
      end)

      it('combines with CursorLine', function()
        command('set cursorline')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {13:^message 4                               }|
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          {7:message 4}                               |
        ]])

        feed('k')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {5:message 2}                               |
          {12:^message 3                               }|
          {7:message 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          {7:message 4}                               |
        ]])

        feed('k')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {11:^message 2                               }|
          {6:message 3}                               |
          {7:message 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          {7:message 4}                               |
        ]])

        feed('k')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          {10:^message 1                               }|
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          {7:message 4}                               |
        ]])
      end)

      it('combines with Visual', function()
        feed('v3k')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          ^m{14:essage 1}                               |
          {15:message 2}                               |
          {16:message 3}                               |
          {17:m}{7:essage 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          {7:message 4}                               |
        ]])
      end)

      it('combines with Search', function()
        feed('gg/e\\|a<cr>')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          m{18:^e}ss{18:a}g{18:e} 1                               |
          {5:m}{19:e}{5:ss}{19:a}{5:g}{19:e}{5: 2}                               |
          {6:m}{20:e}{6:ss}{20:a}{6:g}{20:e}{6: 3}                               |
          {7:m}{21:e}{7:ss}{21:a}{7:g}{21:e}{7: 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          /e\|a                                   |
        ]])
      end)

      it('combines with Search + CursorLine', function()
        command('set cursorline')
        feed('gg/e\\|a<cr>')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          {10:m}{18:^e}{10:ss}{18:a}{10:g}{18:e}{10: 1                               }|
          {5:m}{19:e}{5:ss}{19:a}{5:g}{19:e}{5: 2}                               |
          {6:m}{20:e}{6:ss}{20:a}{6:g}{20:e}{6: 3}                               |
          {7:m}{21:e}{7:ss}{21:a}{7:g}{21:e}{7: 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          /e\|a                                   |
        ]])

        feed('j')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          m{18:e}ss{18:a}g{18:e} 1                               |
          {11:m}{19:^e}{11:ss}{19:a}{11:g}{19:e}{11: 2                               }|
          {6:m}{20:e}{6:ss}{20:a}{6:g}{20:e}{6: 3}                               |
          {7:m}{21:e}{7:ss}{21:a}{7:g}{21:e}{7: 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          /e\|a                                   |
        ]])

        feed('j')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          m{18:e}ss{18:a}g{18:e} 1                               |
          {5:m}{19:e}{5:ss}{19:a}{5:g}{19:e}{5: 2}                               |
          {12:m}{20:^e}{12:ss}{20:a}{12:g}{20:e}{12: 3                               }|
          {7:m}{21:e}{7:ss}{21:a}{7:g}{21:e}{7: 4}                               |
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
          /e\|a                                   |
        ]])

      end)
    end)

    describe('without a window', function()
      before_each(function()
        command('set messagebuf')
        command('messages')
        echo_messages(1, 'before')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          ^before                                  |
          {1:~                                       }|
          {3:nvim://messages                         }|
          before                                  |
        ]])
      end)

      it('and still writes to buffer', function()
        command('quit')
        echo_messages(1, 'after')

        screen:expect([[
          ^                                        |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          after                                   |
        ]])

        command('messages')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          before                                  |
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          ^after                                   |
          {3:nvim://messages                         }|
          after                                   |
        ]])
      end)

      it('in current tab and still writes to buffer', function()
        command('tabnew')

        screen:expect([[
          {22: }{23:2}{22: n//messages }{24: [No Name] }{2:             }{22:X}|
          ^                                        |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
                                                  |
        ]])

        echo_messages(1, 'after tab')

        screen:expect([[
          {22: }{23:2}{22: n//messages }{24: [No Name] }{2:             }{22:X}|
          ^                                        |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          after tab                               |
        ]])

        command('tabp')

        screen:expect([[
          {24: }{25:2}{24: n//messages }{22: [No Name] }{2:             }{22:X}|
                                                  |
          {2:[No Name]                               }|
          message 1                               |
          {5:message 2}                               |
          {6:message 3}                               |
          {7:message 4}                               |
          ^after tab                               |
          {3:nvim://messages                         }|
                                                  |
        ]])
      end)
    end)

    describe('using vimscript', function()
      before_each(function()
        command('set messagebuf')
      end)

      it('msgbuf_open()', function()
        command('call msgbuf_open()')

        screen:expect([[
                                                  |
          {2:[No Name]                               }|
          ^                                        |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {3:nvim://messages                         }|
                                                  |
        ]])
      end)

      describe('msgbuf()', function()
        it('does not display message in command line', function()
          command('call msgbuf("test")')
          command('call msgbuf("test", "Green")')

          screen:expect([[
            ^                                        |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]])
        end)

        it('opens message pane when not open', function()
          command('call msgbuf("test", "Green", 1)')

          screen:expect([[
                                                    |
            {2:[No Name]                               }|
            {5:^test}                                    |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {3:nvim://messages                         }|
                                                    |
          ]])

          -- One more call to make sure the window doesn't change
          command('call msgbuf("test 2", "Green", 1)')

          screen:expect([[
                                                    |
            {2:[No Name]                               }|
            {5:test}                                    |
            {5:^test 2}                                  |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {3:nvim://messages                         }|
                                                    |
          ]])
        end)

        it('opens message pane when not open using truthy argument', function()
          command('call msgbuf("test", "Green", "open")')

          screen:expect([[
                                                    |
            {2:[No Name]                               }|
            {5:^test}                                    |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {3:nvim://messages                         }|
                                                    |
          ]])

          -- One more call to make sure the window doesn't change
          command('call msgbuf("test 2", "Green", "open")')

          screen:expect([[
                                                    |
            {2:[No Name]                               }|
            {5:test}                                    |
            {5:^test 2}                                  |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {3:nvim://messages                         }|
                                                    |
          ]])
        end)

        describe('with unexpected', function()
          it('highlight group', function()
            command('messages')
            command('call msgbuf("test", "NotAHighlight")')

            screen:expect([[
                                                      |
              {2:[No Name]                               }|
              ^test                                    |
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {3:nvim://messages                         }|
                                                      |
            ]])
          end)

          it('number as a highlight group', function()
            command('messages')
            command('call msgbuf("test", 0)')

            screen:expect([[
                                                      |
              {2:[No Name]                               }|
              ^test                                    |
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {3:nvim://messages                         }|
                                                      |
            ]])

            command('call msgbuf("test 2", -1)')

            screen:expect([[
                                                      |
              {2:[No Name]                               }|
              test                                    |
              ^test 2                                  |
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {1:~                                       }|
              {3:nvim://messages                         }|
                                                      |
            ]])
          end)
        end)
      end)
    end)
  end)
end)
