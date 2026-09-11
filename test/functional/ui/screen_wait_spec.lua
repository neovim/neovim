local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each

-- Exercise notification ordering independently of OS pipe buffering. Each batch
-- represents notifications delivered together before the event loop returns.
describe('Screen wait', function()
  before_each(n.clear)

  local function wait_for_batches(batches)
    local screen = Screen.new(20, 5)
    local state = 'not ready'
    local timeouts = {}
    local now = 0
    local session = {
      -- Like uv.stop(), this does not interrupt the current notification batch.
      stop = function() end,
    }
    function session:run(_, notify, _, timeout)
      timeouts[#timeouts + 1] = timeout
      local batch = batches[#timeouts]
      if batch then
        now = now + 1e6
        for _, update in ipairs(batch) do
          if update == 'eof' then
            self.eof_err = { 1, 'test EOF' }
          else
            state = update[1]
            notify('redraw', { { update[2] and 'flush' or 'busy_start', {} } })
          end
        end
      else
        -- No more notifications: emulate the session reaching its timeout.
        now = now + timeout * 1e6
      end
    end
    screen._session = session
    local hrtime = vim.uv.hrtime
    vim.uv.hrtime = function()
      return now
    end
    local ok, err = pcall(screen._wait, screen, function()
      if state ~= 'ready' then
        return state
      end
    end, { timeout = 200 })
    vim.uv.hrtime = hrtime
    return ok, err, timeouts
  end

  it('waits for a partial redraw following a successful flush #40979', function()
    local ok, err, timeouts = wait_for_batches({
      {},
      { { 'ready', true }, { 'ready', false } },
      { { 'ready', true } },
    })
    assert(ok, err)
    t.eq(3, #timeouts)
  end)

  it('finishes a partial redraw after a match in the minimal wait', function()
    local ok, err, timeouts = wait_for_batches({
      { { 'ready', true }, { 'ready', false } },
      { { 'ready', true } },
    })
    assert(ok, err)
    t.eq(2, #timeouts)
  end)

  it('checks the completed redraw instead of accepting an earlier match', function()
    local ok, err = wait_for_batches({
      {},
      { { 'ready', true }, { 'wrong screen', false } },
      { { 'wrong screen', true } },
    })
    t.eq(false, ok)
    t.matches('wrong screen', err)
  end)

  it('does not reset the timeout for successive partial redraws', function()
    local ok, err, timeouts = wait_for_batches({
      {},
      { { 'ready', true }, { 'ready', false } },
      { { 'ready', true }, { 'ready', false } },
    })
    t.eq(false, ok)
    t.matches('no flush received', err)
    t.eq(4, #timeouts)
    assert(timeouts[3] < timeouts[2])
    assert(timeouts[4] < timeouts[3])
  end)

  it('reports EOF while waiting for the pending flush', function()
    local ok, err = wait_for_batches({
      {},
      { { 'ready', true }, { 'ready', false } },
      { 'eof' },
    })
    t.eq(false, ok)
    t.matches('no flush received', err)
    t.matches('test EOF', err)
  end)
end)
