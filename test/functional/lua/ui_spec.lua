local t = require('test.functional.testutil')(after_each)
local eq = t.eq
local matches = t.matches
local exec_lua = t.exec_lua
local clear = t.clear
local feed = t.feed
local eval = t.eval
local is_ci = t.is_ci
local is_os = t.is_os
local poke_eventloop = t.poke_eventloop

describe('vim.ui', function()
  before_each(function()
    clear()
  end)

  describe('select()', function()
    it('can select an item', function()
      local result = exec_lua [[
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

  describe('input()', function()
    it('can input text', function()
      local result = exec_lua [[
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
      poke_eventloop() -- This is needed because Ctrl-C flushes input
      feed('Inputted Text<c-c>')
      eq(true, exec_lua('return (nil == result)'))
    end)

    it(
      'can return the identical object when an arbitrary opts.cancelreturn object is given',
      function()
        feed(':lua fn = function() return 42 end<CR>')
        eq(42, exec_lua('return fn()'))
        feed(':lua vim.ui.input({ cancelreturn = fn }, function(input) result = input end)<cr>')
        feed('cancel<esc>')
        eq(true, exec_lua('return (result == fn)'))
        eq(42, exec_lua('return result()'))
      end
    )
  end)

  describe('open()', function()
    it('validation', function()
      if is_os('win') or not is_ci('github') then
        exec_lua [[vim.system = function() return { wait=function() return { code=3} end } end]]
      end
      if not is_os('bsd') then
        matches(
          'vim.ui.open: command failed %(%d%): { "[^"]+", .*"non%-existent%-file" }',
          exec_lua [[local _, err = vim.ui.open('non-existent-file') ; return err]]
        )
      end

      exec_lua [[
        vim.fn.has = function() return 0 end
        vim.fn.executable = function() return 0 end
      ]]
      eq(
        'vim.ui.open: no handler found (tried: explorer.exe, xdg-open)',
        exec_lua [[local _, err = vim.ui.open('foo') ; return err]]
      )
    end)
  end)
end)
