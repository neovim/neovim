local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local clear = helpers.clear
local feed = helpers.feed
local eval = helpers.eval
local poke_eventloop = helpers.poke_eventloop

local source = helpers.source
local Screen = require('test.functional.ui.screen')
local meths = helpers.meths

describe('vim.ui', function()
  before_each(function()
    clear()
  end)


  describe('select', function()
    it('can select an item', function()
      local result = exec_lua[[
        local items = {
          { name = 'Item 1' },
          { name = 'Item 2' },
        }
        local opts = {
          format_item = function(entry)
            return entry.name
          end
        }
        local selected
        local cb = function(item)
          selected = item
        end
        -- inputlist would require input and block the test;
        local choices
        vim.fn.inputlist = function(x)
          choices = x
          return 1
        end
        vim.ui.select(items, opts, cb)
        vim.wait(100, function() return selected ~= nil end)
        return {selected, choices}
      ]]
      eq({ name = 'Item 1' }, result[1])
      eq({
        'Select one of:',
        '1: Item 1',
        '2: Item 2',
      }, result[2])
    end)
  end)

  describe('input', function()
    it('can input text', function()
      local result = exec_lua[[
        local opts = {
            prompt = 'Input: ',
        }
        local input
        local cb = function(item)
          input = item
        end
        -- input would require input and block the test;
        local prompt
        vim.fn.input = function(opts)
          prompt = opts.prompt
          return "Inputted text"
        end
        vim.ui.input(opts, cb)
        vim.wait(100, function() return input ~= nil end)
        return {input, prompt}
      ]]
      eq('Inputted text', result[1])
      eq('Input: ', result[2])
    end)

    it('can input text on nil opt', function()
      feed(':lua vim.ui.input(nil, function(input) result = input end)<cr>')
      eq('', eval('v:errmsg'))
      feed('Inputted text<cr>')
      eq('Inputted text', exec_lua('return result'))
    end)

    it('can input text on {} opt', function()
      feed(':lua vim.ui.input({}, function(input) result = input end)<cr>')
      eq('', eval('v:errmsg'))
      feed('abcdefg<cr>')
      eq('abcdefg', exec_lua('return result'))
    end)

    it('can input empty text #18144', function()
      feed(':lua vim.ui.input({}, function(input) result = input end)<cr>')
      feed('<cr>')
      eq('', exec_lua('return result'))
    end)

    it('can input empty text with cancelreturn opt #18144', function()
      feed(':lua vim.ui.input({ cancelreturn = "CANCEL" }, function(input) result = input end)<cr>')
      feed('<cr>')
      eq('', exec_lua('return result'))
    end)

    it('can return nil when aborted with ESC #18144', function()
      feed(':lua result = "on_confirm not called"<cr>')
      feed(':lua vim.ui.input({}, function(input) result = input end)<cr>')
      feed('Inputted Text<esc>')
      -- Note: When `result == nil`, exec_lua('returns result') returns vim.NIL
      eq(true, exec_lua('return (nil == result)'))
    end)

    it('can return opts.cacelreturn when aborted with ESC with cancelreturn opt #18144', function()
      feed(':lua result = "on_confirm not called"<cr>')
      feed(':lua vim.ui.input({ cancelreturn = "CANCEL" }, function(input) result = input end)<cr>')
      feed('Inputted Text<esc>')
      eq('CANCEL', exec_lua('return result'))
    end)

    it('can return nil when interrupted with Ctrl-C #18144', function()
      feed(':lua result = "on_confirm not called"<cr>')
      feed(':lua vim.ui.input({}, function(input) result = input end)<cr>')
      poke_eventloop()  -- This is needed because Ctrl-C flushes input
      feed('Inputted Text<c-c>')
      eq(true, exec_lua('return (nil == result)'))
    end)

    it('can return the identical object when an arbitrary opts.cancelreturn object is given', function()
      feed(':lua fn = function() return 42 end<CR>')
      eq(42, exec_lua('return fn()'))
      feed(':lua vim.ui.input({ cancelreturn = fn }, function(input) result = input end)<cr>')
      feed('cancel<esc>')
      eq(true, exec_lua('return (result == fn)'))
      eq(42, exec_lua('return result()'))
    end)

  end)

  describe('confirm', function()
    local screen
    before_each(function()
      clear()
      screen = Screen.new(25, 5)
      screen:attach()
      source([[
      hi Test ctermfg=Red guifg=Red term=bold
      function CustomCompl(...)
        return 'TEST'
      endfunction
      function CustomListCompl(...)
        return ['FOO']
      endfunction

      let g:NUM_LVLS = 4
      function Redraw()
        redraw!
        return ''
      endfunction
      cnoremap <expr> {REDRAW} Redraw()
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
      ]])
    screen:set_default_attr_ids({
      CONFIRM={bold = true, foreground = Screen.colors.SeaGreen4},
    })
    end)
    it('can choose an item', function()
      local result = exec_lua[[
        local msg = "Can you choose a fruit?"
        local opts = {
          choices = {"Apple", "Banana"},
          default = 1
        }
        local selected
        local cb = function(idx, item)
          selected = item
        end
        local choice
        vim.fn.confirm = function(x)
          choice = x
          return 2
        end
        vim.ui.confirm(msg, opts, cb)
        vim.wait(100, function() return selected ~= nil end)
        return {choice, selected}
      ]]
      eq("Can you choose a fruit?", result[1])
      eq("Banana", result[2])
    end)

    it('can choose default item with <cr>', function()
      meths.set_option('more', false)
      meths.set_option('laststatus', 2)
      screen:expect({any = '%[No Name%]'})

      feed(':lua vim.ui.confirm("choice", { choices = {"Apple", "Banana"}, default = 2 }, function(idx, item) result = {idx, item} end)<cr>')
      screen:expect({any = '{CONFIRM:.+: }'})
      feed('<cr>')
      eq('', eval('v:errmsg'))
      eq({2, 'Banana'}, exec_lua('return result'))
    end)

    it('can choose non default item', function()
      meths.set_option('more', false)
      meths.set_option('laststatus', 2)
      screen:expect({any = '%[No Name%]'})

      feed(':lua vim.ui.confirm("choice", { choices = {"Apple", "Banana"}, default = 2 }, function(idx, item) result = {idx, item} end)<cr>')
      screen:expect({any = '{CONFIRM:.+: }'})
      feed('a<cr>')
      eq('', eval('v:errmsg'))
      eq({1, 'Apple'}, exec_lua('return result'))
    end)

    it('can choose item based on designated shortcut key', function()
      meths.set_option('more', false)
      meths.set_option('laststatus', 2)
      screen:expect({any = '%[No Name%]'})

      feed(':lua vim.ui.confirm("choice", { choices = {"App&le", "Banana"}}, function(idx, item) result = {idx, item} end)<cr>')
      screen:expect({any = '{CONFIRM:.+: }'})
      feed('l<cr>')
      eq('', eval('v:errmsg'))
      eq({1, 'Apple'}, exec_lua('return result'))
    end)

    it('can return 1 when choices is nil and default choice is chosen', function()
      meths.set_option('more', false)
      meths.set_option('laststatus', 2)
      screen:expect({any = '%[No Name%]'})

      feed(':lua vim.ui.confirm("choice", { choices = {}}, function(idx, item) result = {idx, item} end)<cr>')
      screen:expect({any = '{CONFIRM:.+: }'})
      feed('o<cr>')
      eq('', eval('v:errmsg'))
      eq({1, nil}, exec_lua('return result'))
    end)

    it('can return nil when choices is nil and <cr> is hit', function()
      meths.set_option('more', false)
      meths.set_option('laststatus', 2)
      screen:expect({any = '%[No Name%]'})

      feed(':lua vim.ui.confirm("choice", { choices = {}}, function(idx, item) result = {idx, item} end)<cr>')
      screen:expect({any = '{CONFIRM:.+: }'})
      feed('<cr>')
      eq('', eval('v:errmsg'))
      eq({nil, nil}, exec_lua('return result'))
    end)

    it('can return nil when aborted with ESC', function()
      feed(':lua vim.ui.confirm("choice", { choices = {"Apple", "Banana"}, function(idx, item) result = {idx, input} end)<cr>')
      feed('<esc>')
      eq(true, exec_lua('return (nil == result)'))
    end)

    it('can return nil when aborted with <c-c>', function()
      feed(':lua vim.ui.confirm("choice", { choices = {"Apple", "Banana"}, function(idx, item) result = {idx, input} end)<cr>')
      feed('<c-c>')
      eq(true, exec_lua('return (nil == result)'))
    end)

  end)
end)
