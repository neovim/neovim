local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local feed, eq, eval, ok = helpers.feed, helpers.eq, helpers.eval, helpers.ok
local source, nvim_async, run = helpers.source, helpers.nvim_async, helpers.run
local clear, command, funcs = helpers.clear, helpers.command, helpers.funcs
local curbufmeths = helpers.curbufmeths
local load_adjust = helpers.load_adjust
local retry = helpers.retry

describe('timers', function()
  before_each(function()
    clear()
    source([[
      let g:val = 0
      func MyHandler(timer)
        let g:val += 1
      endfunc
    ]])
  end)

  it('works one-shot', function()
    eq(0, eval("[timer_start(10, 'MyHandler'), g:val][1]"))
    run(nil, nil, nil, load_adjust(100))
    eq(1,eval("g:val"))
  end)

  it('works one-shot when repeat=0', function()
    eq(0, eval("[timer_start(10, 'MyHandler', {'repeat': 0}), g:val][1]"))
    run(nil, nil, nil, load_adjust(100))
    eq(1, eval("g:val"))
  end)

  it('works with repeat two', function()
    eq(0, eval("[timer_start(10, 'MyHandler', {'repeat': 2}), g:val][1]"))
    run(nil, nil, nil, load_adjust(20))
    retry(nil, load_adjust(300), function()
      eq(2, eval("g:val"))
    end)
  end)

  it('are triggered during sleep', function()
    source([[
      let g:val = -1
      func! MyHandler(timer)
        if g:val >= 0
          let g:val += 1
          if g:val == 2
            call timer_stop(a:timer)
          endif
        endif
      endfunc
    ]])
    eval("timer_start(10, 'MyHandler', {'repeat': -1})")
    nvim_async("command", "sleep 10")
    eq(-1, eval("g:val"))  -- timer did nothing yet.
    nvim_async("command", "let g:val = 0")
    run(nil, nil, nil, load_adjust(20))
    retry(nil, nil, function()
      eq(2, eval("g:val"))
    end)
  end)

  it('works with zero timeout', function()
    -- timer_start does still not invoke the callback immediately
    eq(0, eval("[timer_start(0, 'MyHandler', {'repeat': 1000}), g:val][1]"))
    retry(nil, nil, function()
      eq(1000, eval("g:val"))
    end)
  end)

  it('can be started during sleep', function()
    nvim_async("command", "sleep 10")
    -- this also tests that remote requests works during sleep
    eq(0, eval("[timer_start(10, 'MyHandler', {'repeat': 2}), g:val][1]"))
    run(nil, nil, nil, load_adjust(20))
    retry(nil, load_adjust(300), function() eq(2,eval("g:val")) end)
  end)

  it('are paused when event processing is disabled', function()
    command("call timer_start(5, 'MyHandler', {'repeat': -1})")
    run(nil, nil, nil, load_adjust(10))
    local count = eval("g:val")
    -- shows two line error message and thus invokes the return prompt.
    -- if we start to allow event processing here, we need to change this test.
    feed(':throw "fatal error"<CR>')
    run(nil, nil, nil, load_adjust(30))
    feed("<cr>")
    local diff = eval("g:val") - count
    assert(0 <= diff and diff <= 4,
           'expected (0 <= diff <= 4), got: '..tostring(diff))
  end)

  it('are triggered in blocking getchar() call', function()
    command("call timer_start(5, 'MyHandler', {'repeat': -1})")
    nvim_async("command", "let g:val = 0 | let g:c = getchar()")
    retry(nil, nil, function()
      local val = eval("g:val")
      ok(val >= 2, "expected >= 2, got: "..tostring(val))
      eq(0, eval("getchar(1)"))
    end)
    feed("c")
    eq(99, eval("g:c"))
  end)

  it('can invoke redraw in blocking getchar() call', function()
    local screen = Screen.new(40, 6)
    screen:attach()
    screen:set_default_attr_ids({
        [1] = {bold=true, foreground=Screen.colors.Blue},
    })

    curbufmeths.set_lines(0, -1, true, {"ITEM 1", "ITEM 2"})
    source([[
      func! AddItem(timer)
        call nvim_buf_set_lines(0, 2, 2, v:true, ['ITEM 3'])

        " Meant to test for what Vim tests in Test_peek_and_get_char.
        call getchar(1)

        redraw
      endfunc
    ]])
    nvim_async("command", "let g:c2 = getchar()")
    nvim_async("command", "call timer_start("..load_adjust(100)..", 'AddItem')")

    screen:expect([[
      ITEM 1                                  |
      ITEM 2                                  |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      ^                                        |
    ]])

    screen:expect([[
      ITEM 1                                  |
      ITEM 2                                  |
      ITEM 3                                  |
      {1:~                                       }|
      {1:~                                       }|
      ^                                        |
    ]])

    feed("3")
    eq(51, eval("g:c2"))
    screen:expect([[
      ^ITEM 1                                  |
      ITEM 2                                  |
      ITEM 3                                  |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
  end)

  it('can be stopped', function()
    local t_init_val = eval("[timer_start(5, 'MyHandler', {'repeat': -1}), g:val]")
    eq(0, t_init_val[2])
    run(nil, nil, nil, load_adjust(30))
    funcs.timer_stop(t_init_val[1])
    local count = eval("g:val")
    run(nil, load_adjust(300), nil, load_adjust(30))
    local count2 = eval("g:val")
    -- when count is eval:ed after timer_stop this should be non-racy
    eq(count, count2)
  end)

  it('can be stopped from the handler', function()
    source([[
      func! MyHandler(timer)
        let g:val += 1
        if g:val == 3
          call timer_stop(a:timer)
          " check double stop is ignored
          call timer_stop(a:timer)
        endif
      endfunc
    ]])
    eq(0, eval("g:val"))
    command("call timer_start(10, 'MyHandler', {'repeat': -1})")
    retry(nil, nil, function()
      eq(3, eval("g:val"))
    end)
  end)

  it('can have two timers', function()
    source([[
      let g:val2 = 0
      func! MyHandler2(timer)
        let g:val2 += 1
      endfunc
    ]])
    command("call timer_start(2, 'MyHandler',  {'repeat': 3})")
    command("call timer_start(4, 'MyHandler2', {'repeat': 2})")
    retry(nil, nil, function()
      eq(3, eval("g:val"))
      eq(2, eval("g:val2"))
    end)
  end)

  it('do not crash when processing events in the handler', function()
    source([[
      let g:val = 0
      func! MyHandler(timer)
        call timer_stop(a:timer)
        sleep 10m
        let g:val += 1
      endfunc
    ]])
    command("call timer_start(5, 'MyHandler', {'repeat': 1})")
    run(nil, nil, nil, load_adjust(10))
    retry(nil, load_adjust(100), function()
      eq(1, eval("g:val"))
    end)
  end)


  it("doesn't mess up the cmdline", function()
    local screen = Screen.new(40, 6)
    screen:attach()
    screen:set_default_attr_ids( {[0] = {bold=true, foreground=255}} )
    source([[
      let g:val = 0
      func! MyHandler(timer)
        echo "evil"
        redraw
        let g:val = 1
      endfunc
    ]])
    command("call timer_start(100,  'MyHandler', {'repeat': 1})")
    feed(":good")
    screen:expect([[
                                              |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      :good^                                   |
    ]])

    screen:expect{grid=[[
                                              |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      :good^                                   |
    ]], intermediate=true, timeout=load_adjust(200)}

    eq(1, eval('g:val'))
  end)
end)
