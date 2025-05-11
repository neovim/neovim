-- To run this test:
--    TEST_FILE=test/functional/ui/search_stat_limit_spec.lua make functionaltest

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local clear = n.clear
local command = n.command
local feed = n.feed
local eval = n.eval

describe('search match count display', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 12)
    screen:set_default_attr_ids({
      [10] = { background = Screen.colors.Yellow, foreground = Screen.colors.Black },
    })
    command('set shortmess-=S')
  end)

  local function insert_lines(count)
    command('enew!')
    feed('i')
    for _ = 1, count do
      feed('banana\n')
    end
    feed('<Esc>')
  end

  it('displays match count below 99', function()
    insert_lines(98)

    feed('/banana\n')
    feed('42n')

    screen:expect {
      unchanged = false,
      condition = function()
        for _, row in ipairs(screen._rows or {}) do
          if row[1] and row[1]:find('42/98') then
            return true
          end
        end
        return false
      end,
    }
  end)

  it('displays match count above 99', function()
    insert_lines(200)

    feed('/banana\n')
    feed('150n')

    local found = false
    for _ = 1, 100 do
      local status = eval('v:statusmsg')
      if status:find('151/200') then
        found = true
        break
      end
      command('sleep 10m')
    end

    assert(found, 'Expected match count 151/200 not found in v:statusmsg')
  end)
end)
