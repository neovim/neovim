local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed
local api = n.api

before_each(clear)

describe('Vim script', function()
  -- oldtest: Test_deep_nest()
  it('Error when if/for/while/try/function is nested too deep', function()
    local screen = Screen.new(80, 24)
    screen:attach()
    api.nvim_set_option_value('laststatus', 2, {})
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
    screen:expect({ any = '%[No Name%]' })
    feed(':call Test1()<CR>')
    screen:expect({ any = 'E579: ' })
    feed('<C-C>')
    screen:expect({ any = '%[No Name%]' })
    feed(':call Test2()<CR>')
    screen:expect({ any = 'E585: ' })
    feed('<C-C>')
    screen:expect({ any = '%[No Name%]' })
    feed(':call Test3()<CR>')
    screen:expect({ any = 'E585: ' })
    feed('<C-C>')
    screen:expect({ any = '%[No Name%]' })
    feed(':call Test4()<CR>')
    screen:expect({ any = 'E601: ' })
    feed('<C-C>')
    screen:expect({ any = '%[No Name%]' })
    feed(':call Test5()<CR>')
    screen:expect({ any = 'E1058: ' })
  end)

  -- oldtest: Test_typed_script_var()
  it('using s: with a typed command', function()
    local screen = Screen.new(80, 24)
    screen:attach()
    feed(":echo get(s:, 'foo', 'x')\n")
    screen:expect({ any = 'E116: ' })
  end)
end)
