-- Test argument list commands

local helpers = require('test.functional.helpers')(after_each)
local clear, command, eq = helpers.clear, helpers.command, helpers.eq
local eval, exc_exec, neq = helpers.eval, helpers.exc_exec, helpers.neq

if helpers.pending_win32(pending) then return end

describe('argument list commands', function()
  before_each(clear)

  local function init_abc()
    command('args a b c')
    command('next')
  end

  local function reset_arglist()
    command('arga a | %argd')
  end

  local function assert_fails(cmd, err)
    neq(exc_exec(cmd):find(err), nil)
  end

  it('test that argidx() works', function()
    command('args a b c')
    command('last')
    eq(2, eval('argidx()'))
    command('%argdelete')
    eq(0, eval('argidx()'))

    command('args a b c')
    eq(0, eval('argidx()'))
    command('next')
    eq(1, eval('argidx()'))
    command('next')
    eq(2, eval('argidx()'))
    command('1argdelete')
    eq(1, eval('argidx()'))
    command('1argdelete')
    eq(0, eval('argidx()'))
    command('1argdelete')
    eq(0, eval('argidx()'))
  end)

  it('test that argadd() works', function()
    -- Fails with “E474: Invalid argument”. Not sure whether it is how it is
    -- supposed to behave.
    -- command('%argdelete')
    command('argadd a b c')
    eq(0, eval('argidx()'))

    command('%argdelete')
    command('argadd a')
    eq(0, eval('argidx()'))
    command('argadd b c d')
    eq(0, eval('argidx()'))

    init_abc()
    command('argadd x')
    eq({'a', 'b', 'x', 'c'}, eval('argv()'))
    eq(1, eval('argidx()'))

    init_abc()
    command('0argadd x')
    eq({'x', 'a', 'b', 'c'}, eval('argv()'))
    eq(2, eval('argidx()'))

    init_abc()
    command('1argadd x')
    eq({'a', 'x', 'b', 'c'}, eval('argv()'))
    eq(2, eval('argidx()'))

    init_abc()
    command('$argadd x')
    eq({'a', 'b', 'c', 'x'}, eval('argv()'))
    eq(1, eval('argidx()'))

    init_abc()
    command('$argadd x')
    command('+2argadd y')
    eq({'a', 'b', 'c', 'x', 'y'}, eval('argv()'))
    eq(1, eval('argidx()'))

    command('%argd')
    command('edit d')
    command('arga')
    eq(1, eval('len(argv())'))
    eq('d', eval('get(argv(), 0, "")'))

    command('%argd')
    command('new')
    command('arga')
    eq(0, eval('len(argv())'))
  end)

  it('test for [count]argument and [count]argdelete commands', function()
    reset_arglist()
    command('let save_hidden = &hidden')
    command('set hidden')
    command('let g:buffers = []')
    command('augroup TEST')
    command([[au BufEnter * call add(buffers, expand('%:t'))]])
    command('augroup END')

    command('argadd a b c d')
    command('$argu')
    command('$-argu')
    command('-argu')
    command('1argu')
    command('+2argu')

    command('augroup TEST')
    command('au!')
    command('augroup END')

    eq({'d', 'c', 'b', 'a', 'c'}, eval('g:buffers'))

    command('redir => result')
    command('ar')
    command('redir END')
    eq(1, eval([[result =~# 'a b \[c] d']]))

    command('.argd')
    eq({'a', 'b', 'd'}, eval('argv()'))

    command('-argd')
    eq({'a', 'd'}, eval('argv()'))

    command('$argd')
    eq({'a'}, eval('argv()'))

    command('1arga c')
    command('1arga b')
    command('$argu')
    command('$arga x')
    eq({'a', 'b', 'c', 'x'}, eval('argv()'))

    command('0arga Y')
    eq({'Y', 'a', 'b', 'c', 'x'}, eval('argv()'))

    command('%argd')
    eq({}, eval('argv()'))

    command('arga a b c d e f')
    command('2,$-argd')
    eq({'a', 'f'}, eval('argv()'))

    command('let &hidden = save_hidden')

    -- Setting the argument list should fail when the current buffer has
    -- unsaved changes
    command('%argd')
    command('enew!')
    command('set modified')
    assert_fails('args x y z', 'E37:')
    command('args! x y z')
    eq({'x', 'y', 'z'}, eval('argv()'))
    eq('x', eval('expand("%:t")'))

    command('%argdelete')
    assert_fails('argument', 'E163:')
  end)

  it('test for 0argadd and 0argedit', function()
    reset_arglist()

    command('arga a b c d')
    command('2argu')
    command('0arga added')
    eq({'added', 'a', 'b', 'c', 'd'}, eval('argv()'))

    command('%argd')
    command('arga a b c d')
    command('2argu')
    command('0arge edited')
    eq({'edited', 'a', 'b', 'c', 'd'}, eval('argv()'))

    command('2argu')
    command('arga third')
    eq({'edited', 'a', 'third', 'b', 'c', 'd'}, eval('argv()'))
  end)

  it('test for argc()', function()
    reset_arglist()
    eq(0, eval('argc()'))
    command('argadd a b')
    eq(2, eval('argc()'))
  end)

  it('test for arglistid()', function()
    reset_arglist()
    command('arga a b')
    eq(0, eval('arglistid()'))
    command('split')
    command('arglocal')
    eq(1, eval('arglistid()'))
    command('tabnew | tabfirst')
    eq(0, eval('arglistid(2)'))
    eq(1, eval('arglistid(1, 1)'))
    eq(0, eval('arglistid(2, 1)'))
    eq(1, eval('arglistid(1, 2)'))
    command('tabonly | only | enew!')
    command('argglobal')
    eq(0, eval('arglistid()'))
  end)

  it('test for argv()', function()
    reset_arglist()
    eq({}, eval('argv()'))
    eq('', eval('argv(2)'))
    command('argadd a b c d')
    eq('c', eval('argv(2)'))
  end)

  it('test for :argedit command', function()
    reset_arglist()
    command('argedit a')
    eq({'a'}, eval('argv()'))
    eq('a', eval('expand("%:t")'))
    command('argedit b')
    eq({'a', 'b'}, eval('argv()'))
    eq('b', eval('expand("%:t")'))
    command('argedit a')
    eq({'a', 'b'}, eval('argv()'))
    eq('a', eval('expand("%:t")'))
    command('argedit c')
    eq({'a', 'c', 'b'}, eval('argv()'))
    command('0argedit x')
    eq({'x', 'a', 'c', 'b'}, eval('argv()'))
    command('enew! | set modified')
    assert_fails('argedit y', 'E37:')
    command('argedit! y')
    eq({'x', 'y', 'a', 'c', 'b'}, eval('argv()'))
    command('%argd')
    -- Nvim allows unescaped spaces in filename on all platforms. #6010
    command('argedit a b')
    eq({'a b'}, eval('argv()'))
  end)

  it('test for :argdelete command', function()
    reset_arglist()
    command('args aa a aaa b bb')
    command('argdelete a*')
    eq({'b', 'bb'}, eval('argv()'))
    eq('aa', eval('expand("%:t")'))
    command('last')
    command('argdelete %')
    eq({'b'}, eval('argv()'))
    assert_fails('argdelete', 'E471:')
    assert_fails('1,100argdelete', 'E16:')
    command('%argd')
  end)

  it('test for the :next, :prev, :first, :last, :rewind commands', function()
    reset_arglist()
    command('args a b c d')
    command('last')
    eq(3, eval('argidx()'))
    assert_fails('next', 'E165:')
    command('prev')
    eq(2, eval('argidx()'))
    command('Next')
    eq(1, eval('argidx()'))
    command('first')
    eq(0, eval('argidx()'))
    assert_fails('prev', 'E164:')
    command('3next')
    eq(3, eval('argidx()'))
    command('rewind')
    eq(0, eval('argidx()'))
    command('%argd')
  end)


  it('test for autocommand that redefines the argument list, when doing ":all"', function()
    command('autocmd BufReadPost Xxx2 next Xxx2 Xxx1')
    command("call writefile(['test file Xxx1'], 'Xxx1')")
    command("call writefile(['test file Xxx2'], 'Xxx2')")
    command("call writefile(['test file Xxx3'], 'Xxx3')")

    command('new')
    -- redefine arglist; go to Xxx1
    command('next! Xxx1 Xxx2 Xxx3')
    -- open window for all args
    command('all')
    eq('test file Xxx1', eval('getline(1)'))
    command('wincmd w')
    command('wincmd w')
    eq('test file Xxx1', eval('getline(1)'))
    -- should now be in Xxx2
    command('rewind')
    eq('test file Xxx2', eval('getline(1)'))

    command('autocmd! BufReadPost Xxx2')
    command('enew! | only')
    command("call delete('Xxx1')")
    command("call delete('Xxx2')")
    command("call delete('Xxx3')")
    command('argdelete Xxx*')
    command('bwipe! Xxx1 Xxx2 Xxx3')
  end)
end)
