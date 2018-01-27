local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local eval = helpers.eval
local meths = helpers.meths
local redir_exec = helpers.redir_exec
local source = helpers.source

before_each(clear)

describe(':let', function()
  it('correctly lists variables with curly-braces', function()
    meths.set_var('v', {0})
    eq('\nv                     [0]', redir_exec('let {"v"}'))
  end)

  it('correctly lists variables with subscript', function()
    meths.set_var('v', {0})
    eq('\nv[0]                  #0', redir_exec('let v[0]'))
    eq('\ng:["v"][0]            #0', redir_exec('let g:["v"][0]'))
    eq('\n{"g:"}["v"][0]        #0', redir_exec('let {"g:"}["v"][0]'))
  end)

  it(":unlet self-referencing node in a List graph #6070", function()
    -- :unlet-ing a self-referencing List must not allow GC on indirectly
    -- referenced in-scope Lists. Before #6070 this caused use-after-free.
    source([=[
      let [l1, l2] = [[], []]
      echo 'l1:' . id(l1)
      echo 'l2:' . id(l2)
      echo ''
      let [l3, l4] = [[], []]
      call add(l4, l4)
      call add(l4, l3)
      call add(l3, 1)
      call add(l2, l2)
      call add(l2, l1)
      call add(l1, 1)
      unlet l2
      unlet l4
      call garbagecollect(1)
      call feedkeys(":\e:echo l1 l3\n:echo 42\n:cq\n", "t")
    ]=])
  end)

  it("sets environment variables", function()
    local multibyte_multiline = [[\p* .ม .ม .ม .ม่ .ม่ .ม่ ֹ ֹ ֹ .ֹ .ֹ .ֹ ֹֻ ֹֻ ֹֻ
                                  .ֹֻ .ֹֻ .ֹֻ ֹֻ ֹֻ ֹֻ .ֹֻ .ֹֻ .ֹֻ ֹ ֹ ֹ .ֹ .ֹ .ֹ ֹ ֹ ֹ .ֹ .ֹ .ֹ ֹֻ ֹֻ
                                  .ֹֻ .ֹֻ .ֹֻ a a a ca ca ca à à à]]
    command("let $NVIM_TEST1 = 'AìaB'")
    command("let $NVIM_TEST2 = 'AaあB'")
    command("let $NVIM_TEST3 = '"..multibyte_multiline.."'")
    eq('AìaB', eval('$NVIM_TEST1'))
    eq('AaあB', eval('$NVIM_TEST2'))
    eq(multibyte_multiline, eval('$NVIM_TEST3'))
  end)
end)
