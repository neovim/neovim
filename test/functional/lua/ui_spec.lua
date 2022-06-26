local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local clear = helpers.clear
local feed = helpers.feed
local eval = helpers.eval

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
  end)
end)
