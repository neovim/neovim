-- See test/functional/legacy/mapping_spec.lua for other tests

local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local execute = helpers.execute
local eq = helpers.eq
local eval = helpers.eval
local source = helpers.source
local sleep = helpers.sleep

describe('mapping edge cases', function()
  if helpers.pending_win32(pending) then return end  -- Need `mkfifo`
  local fifo_name = 'Xtest-map'

  before_each(function()
    clear()
    local script = [[
      set timeout
      set timeoutlen=1
      let a_map_called=0
      let b_map_called=0
      function ExprMap(retstring)
        " Wake up the test thread
        call system('echo Hello > ]] .. fifo_name .. [[')
        " Don't worry about time limits on completing mappings.
        set notimeout
        return a:retstring
      endfunction
    ]]
    source(script)
    os.execute('mkfifo ' .. fifo_name)
  end)
  after_each(function() os.remove(fifo_name) end)

  -- Requires a timeout of a string suitable to give to the unix `timeout`
  -- command.
  local function wait_for(timeout)
    io.input(fifo_name)
  end

  it('does not wait for timeout a second time', function()
    execute("nnoremap aaaa :let a_map_called=1<CR>")
    execute("nnoremap bb :let b_map_called=1<CR>")
    execute("nmap <expr> b ExprMap('aaa')")
    feed('b')
    -- Wait until the expression times out.
    wait_for(nil)
    -- feed 'a' so that the mapping would complete if keys are waited for.
    -- This won't trigger the map, because vgetorpeek() doesn't attempt to read
    -- anything due to the 'timedout' setting.
    -- We don't have to wait because there is no call to os_inchar() between
    -- the exit of the ExprMap() and finishing the call to eval_map_expr().
    feed('a')
    eq(0, eval('a_map_called'))
  end)
  it('does not carry over a timeout between user inputs', function()
    execute("nnoremap <expr> a ExprMap('')",
            "nnoremap aa :let a_map_called=1<CR>",
            "nnoremap bb :let b_map_called=1<CR>")
    feed('a')
    -- Wait until vim has timed out and called the ExprMap() function
    wait_for(nil)
    feed('b')
    -- Wait enough time that the vgetorpeek() function has had a chance to read
    -- in the previous input. nvim won't time out on this because notimeout has
    -- been set in the `a` <expr> map.
    -- It is possible that we send this input too early so that vgetorpeek()
    -- reads in the entire 'bb' at once, but not likely.
    -- This would cause a test pass without actually testing the behaviour we
    -- want.
    sleep(100)
    feed('bl')
    eq(1, eval('b_map_called'))
  end)
end)
