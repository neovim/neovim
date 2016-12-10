local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local eval = helpers.eval
local clear = helpers.clear
local source = helpers.source
local redir_exec = helpers.redir_exec
local exc_exec = helpers.exc_exec
local funcs = helpers.funcs
local Screen = require('test.functional.ui.screen')
local feed = helpers.feed

describe('execute()', function()
  before_each(clear)

  it('captures the same result as :redir', function()
    eq(redir_exec('messages'), funcs.execute('messages'))
  end)

  it('captures the concatenated outputs of a List of commands', function()
    eq("foobar", funcs.execute({'echon "foo"', 'echon "bar"'}))
    eq("\nfoo\nbar", funcs.execute({'echo "foo"', 'echo "bar"'}))
  end)

  it('supports nested redirection', function()
    source([[
    function! g:Foo()
      let a = ''
      redir => a
      silent echon "foo"
      redir END
      return a
    endfunction
    function! g:Bar()
      let a = ''
      redir => a
      call g:Foo()
      redir END
      return a
    endfunction
    ]])
    eq('foo', funcs.execute('call g:Bar()'))

    eq('42', funcs.execute([[echon execute("echon execute('echon 42')")]]))
  end)

  it('captures a transformed string', function()
    eq('^A', funcs.execute('echon "\\<C-a>"'))
  end)

  it('returns empty string if the argument list is empty', function()
    eq('', funcs.execute({}))
    eq(0, exc_exec('let g:ret = execute(v:_null_list)'))
    eq('', eval('g:ret'))
  end)

  it('captures errors', function()
    local ret
    ret = exc_exec('call execute(0.0)')
    eq('Vim(call):E806: using Float as a String', ret)
    ret = exc_exec('call execute(v:_null_dict)')
    eq('Vim(call):E731: using Dictionary as a String', ret)
    ret = exc_exec('call execute(function("tr"))')
    eq('Vim(call):E729: using Funcref as a String', ret)
    ret = exc_exec('call execute(["echo 42", 0.0, "echo 44"])')
    eq('Vim(call):E806: using Float as a String', ret)
    ret = exc_exec('call execute(["echo 42", v:_null_dict, "echo 44"])')
    eq('Vim(call):E731: using Dictionary as a String', ret)
    ret = exc_exec('call execute(["echo 42", function("tr"), "echo 44"])')
    eq('Vim(call):E729: using Funcref as a String', ret)
  end)

  -- This matches Vim behavior.
  it('does not capture shell-command output', function()
    eq('\n:!echo "foo"\13\n', funcs.execute('!echo "foo"'))
  end)

  it('silences command run inside', function()
    local screen = Screen.new(40, 5)
    screen:attach()
    screen:set_default_attr_ids( {[0] = {bold=true, foreground=255}} )
    feed(':let g:mes = execute("echon 42")<CR>')
    screen:expect([[
    ^                                        |
    {0:~                                       }|
    {0:~                                       }|
    {0:~                                       }|
    :let g:mes = execute("echon 42")        |
    ]])
    eq('42', eval('g:mes'))
  end)
end)
