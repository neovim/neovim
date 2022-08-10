-- Tests for core Vimscript "eval" behavior.
--
-- See also:
--    let_spec.lua
--    null_spec.lua
--    operators_spec.lua
--
-- Tests for the Vimscript |builtin-functions| library should live in:
--    test/functional/vimscript/<funcname>_spec.lua
--    test/functional/vimscript/functions_spec.lua

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local lfs = require('lfs')
local clear = helpers.clear
local eq = helpers.eq
local exc_exec = helpers.exc_exec
local exec = helpers.exec
local eval = helpers.eval
local command = helpers.command
local write_file = helpers.write_file
local meths = helpers.meths
local sleep = helpers.sleep
local poke_eventloop = helpers.poke_eventloop
local feed = helpers.feed

describe('Up to MAX_FUNC_ARGS arguments are handled by', function()
  local max_func_args = 20  -- from eval.h
  local range = helpers.funcs.range

  before_each(clear)

  it('printf()', function()
    local printf = helpers.funcs.printf
    local rep = helpers.funcs['repeat']
    local expected = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,'
    eq(expected, printf(rep('%d,', max_func_args-1), unpack(range(2, max_func_args))))
    local ret = exc_exec('call printf("", 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)')
    eq('Vim(call):E740: Too many arguments for function printf', ret)
  end)

  it('rpcnotify()', function()
    local rpcnotify = helpers.funcs.rpcnotify
    local ret = rpcnotify(0, 'foo', unpack(range(3, max_func_args)))
    eq(1, ret)
    ret = exc_exec('call rpcnotify(0, "foo", 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)')
    eq('Vim(call):E740: Too many arguments for function rpcnotify', ret)
  end)
end)

describe("backtick expansion", function()
  setup(function()
    clear()
    lfs.mkdir("test-backticks")
    write_file("test-backticks/file1", "test file 1")
    write_file("test-backticks/file2", "test file 2")
    write_file("test-backticks/file3", "test file 3")
    lfs.mkdir("test-backticks/subdir")
    write_file("test-backticks/subdir/file4", "test file 4")
    -- Long path might cause "Press ENTER" prompt; use :silent to avoid it.
    command('silent cd test-backticks')
  end)

  teardown(function()
    helpers.rmdir('test-backticks')
  end)

  it("with default 'shell'", function()
    if helpers.iswin() then
      command(":silent args `dir /b *2`")
    else
      command(":silent args `echo ***2`")
    end
    eq({ "file2", }, eval("argv()"))
    if helpers.iswin() then
      command(":silent args `dir /s/b *4`")
      eq({ "subdir\\file4", }, eval("map(argv(), 'fnamemodify(v:val, \":.\")')"))
    else
      command(":silent args `echo */*4`")
      eq({ "subdir/file4", }, eval("argv()"))
    end
  end)

  it("with shell=fish", function()
    if eval("executable('fish')") == 0 then
      pending('missing "fish" command')
      return
    end
    command("set shell=fish")
    command(":silent args `echo ***2`")
    eq({ "file2", }, eval("argv()"))
    command(":silent args `echo */*4`")
    eq({ "subdir/file4", }, eval("argv()"))
  end)
end)

describe('List support code', function()
  local dur
  local min_dur = 8
  local len = 131072

  if not pending('does not actually allows interrupting with just got_int', function() end) then return end
  -- The following tests are confirmed to work with os_breakcheck() just before
  -- `if (got_int) {break;}` in tv_list_copy and list_join_inner() and not to
  -- work without.
  setup(function()
    clear()
    dur = 0
    while true do
      command(([[
        let rt = reltime()
        let bl = range(%u)
        let dur = reltimestr(reltime(rt))
      ]]):format(len))
      dur = tonumber(meths.get_var('dur'))
      if dur >= min_dur then
        -- print(('Using len %u, dur %g'):format(len, dur))
        break
      else
        len = len * 2
      end
    end
  end)
  it('allows interrupting copy', function()
    feed(':let t_rt = reltime()<CR>:let t_bl = copy(bl)<CR>')
    sleep(min_dur / 16 * 1000)
    feed('<C-c>')
    poke_eventloop()
    command('let t_dur = reltimestr(reltime(t_rt))')
    local t_dur = tonumber(meths.get_var('t_dur'))
    if t_dur >= dur / 8 then
      eq(nil, ('Took too long to cancel: %g >= %g'):format(t_dur, dur / 8))
    end
  end)
  it('allows interrupting join', function()
    feed(':let t_rt = reltime()<CR>:let t_j = join(bl)<CR>')
    sleep(min_dur / 16 * 1000)
    feed('<C-c>')
    poke_eventloop()
    command('let t_dur = reltimestr(reltime(t_rt))')
    local t_dur = tonumber(meths.get_var('t_dur'))
    print(('t_dur: %g'):format(t_dur))
    if t_dur >= dur / 8 then
      eq(nil, ('Took too long to cancel: %g >= %g'):format(t_dur, dur / 8))
    end
  end)
end)

-- oldtest: Test_deep_nest()
it('Error when if/for/while/try/function is nested too deep',function()
  clear()
  local screen = Screen.new(80, 24)
  screen:attach()
  meths.set_option('laststatus', 2)
  exec([[
    " Deep nesting of if ... endif
    func Test1()
      let @a = join(repeat(['if v:true'], 51), "\n")
      let @a ..= "\n"
      let @a ..= join(repeat(['endif'], 51), "\n")
      @a
      let @a = ''
    endfunc

    " Deep nesting of for ... endfor
    func Test2()
      let @a = join(repeat(['for i in [1]'], 51), "\n")
      let @a ..= "\n"
      let @a ..= join(repeat(['endfor'], 51), "\n")
      @a
      let @a = ''
    endfunc

    " Deep nesting of while ... endwhile
    func Test3()
      let @a = join(repeat(['while v:true'], 51), "\n")
      let @a ..= "\n"
      let @a ..= join(repeat(['endwhile'], 51), "\n")
      @a
      let @a = ''
    endfunc

    " Deep nesting of try ... endtry
    func Test4()
      let @a = join(repeat(['try'], 51), "\n")
      let @a ..= "\necho v:true\n"
      let @a ..= join(repeat(['endtry'], 51), "\n")
      @a
      let @a = ''
    endfunc

    " Deep nesting of function ... endfunction
    func Test5()
      let @a = join(repeat(['function X()'], 51), "\n")
      let @a ..= "\necho v:true\n"
      let @a ..= join(repeat(['endfunction'], 51), "\n")
      @a
      let @a = ''
    endfunc
  ]])
  screen:expect({any = '%[No Name%]'})
  feed(':call Test1()<CR>')
  screen:expect({any = 'E579: '})
  feed('<C-C>')
  screen:expect({any = '%[No Name%]'})
  feed(':call Test2()<CR>')
  screen:expect({any = 'E585: '})
  feed('<C-C>')
  screen:expect({any = '%[No Name%]'})
  feed(':call Test3()<CR>')
  screen:expect({any = 'E585: '})
  feed('<C-C>')
  screen:expect({any = '%[No Name%]'})
  feed(':call Test4()<CR>')
  screen:expect({any = 'E601: '})
  feed('<C-C>')
  screen:expect({any = '%[No Name%]'})
  feed(':call Test5()<CR>')
  screen:expect({any = 'E1058: '})
end)

describe("uncaught exception", function()
  before_each(clear)
  after_each(function()
    os.remove('throw1.vim')
    os.remove('throw2.vim')
    os.remove('throw3.vim')
  end)

  it('is not forgotten #13490', function()
    command('autocmd BufWinEnter * throw "i am error"')
    eq('i am error', exc_exec('try | new | endtry'))

    -- Like Vim, throwing here aborts the processing of the script, but does not stop :runtime!
    -- from processing the others.
    -- Only the first thrown exception should be rethrown from the :try below, though.
    for i = 1, 3 do
      write_file('throw' .. i .. '.vim', ([[
        let result ..= '%d'
        throw 'throw%d'
        let result ..= 'X'
      ]]):format(i, i))
    end
    command('set runtimepath+=. | let result = ""')
    eq('throw1', exc_exec('try | runtime! throw*.vim | endtry'))
    eq('123', eval('result'))
  end)
end)
