local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local api = n.api
local feed = n.feed
local poke_eventloop = n.poke_eventloop
local eq = t.eq
local retry = t.retry

describe("'belloff'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(42, 5)
    screen:attach()
    screen:expect([[
      ^                                          |
      {1:~                                         }|*3
                                                |
    ]])
  end)

  it('various flags work properly', function()
    command('set cpoptions+=E')

    local map = {
      backspace = 'i<BS><Esc>',
      cursor = 'i<Up><Esc>',
      copy = 'i<C-Y><Esc>',
      ctrlg = 'i<C-G><C-G><Esc>',
      error = 'J',
      esc = '<Esc>',
      operator = 'y0',
      register = 'i<C-R>@<Esc>',
    }

    local items = {} ---@type string[]
    local inputs = {} ---@type string[]
    for item, input in pairs(map) do
      table.insert(items, item)
      table.insert(inputs, input)
    end

    local values = {} ---@type string[]
    for i, _ in ipairs(items) do
      -- each tested 'belloff' value enables at most one item
      local parts = vim.deepcopy(items)
      table.remove(parts, i)
      local value = table.concat(parts, ',')
      table.insert(values, value)
    end
    table.insert(values, 'all')

    for i, value in ipairs(values) do
      api.nvim_set_option_value('belloff', value, {})

      for j, input in ipairs(inputs) do
        screen.bell = false
        local beep = value ~= 'all' and i == j
        -- Nvim avoids beeping more than 3 times in half a second,
        -- so retry if beeping is expected but not received.
        retry(not beep and 1 or nil, 1000, function()
          feed(input)
          poke_eventloop()
          screen:expect({
            condition = function()
              eq(beep, screen.bell, ('%s with belloff=%s'):format(items[j], value))
            end,
            unchanged = not beep,
          })
        end)
      end
    end
  end)
end)
