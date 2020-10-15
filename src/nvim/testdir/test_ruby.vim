" Tests for ruby interface

if !has('ruby')
  finish
end

" Helper function as there is no builtin rubyeval() function similar
" to perleval, luaevel() or pyeval().
func RubyEval(ruby_expr)
  let s = split(execute('ruby print ' . a:ruby_expr), "\n")
  return (len(s) == 0) ? '' : s[-1]
endfunc

func Test_ruby_change_buffer()
  call setline(line('$'), ['1 line 1'])
  ruby Vim.command("normal /^1\n")
  ruby $curbuf.line = "1 changed line 1"
  call assert_equal('1 changed line 1', getline('$'))
endfunc

func Test_rubydo()
  throw 'skipped: TODO: '
  " Check deleting lines does not trigger ml_get error.
  new
  call setline(1, ['one', 'two', 'three'])
  rubydo Vim.command("%d_")
  bwipe!

  " Check switching to another buffer does not trigger ml_get error.
  new
  let wincount = winnr('$')
  call setline(1, ['one', 'two', 'three'])
  rubydo Vim.command("new")
  call assert_equal(wincount + 1, winnr('$'))
  %bwipe!
endfunc

func Test_rubyfile()
  " Check :rubyfile does not SEGV with Ruby level exception but just fails
  let tempfile = tempname() . '.rb'
  call writefile(['raise "vim!"'], tempfile)
  call assert_fails('rubyfile ' . tempfile)
  call delete(tempfile)
endfunc

func Test_set_cursor()
  " Check that setting the cursor position works.
  new
  call setline(1, ['first line', 'second line'])
  normal gg
  rubydo $curwin.cursor = [1, 5]
  call assert_equal([1, 6], [line('.'), col('.')])
  call assert_equal('[1, 5]', RubyEval('$curwin.cursor'))

  " Check that movement after setting cursor position keeps current column.
  normal j
  call assert_equal([2, 6], [line('.'), col('.')])
  call assert_equal('[2, 5]', RubyEval('$curwin.cursor'))

  " call assert_fails('ruby $curwin.cursor = [1]',
  "      \           'ArgumentError: array length must be 2')
  bwipe!
endfunc

" Test buffer.count and buffer.length (number of lines in buffer)
func Test_buffer_count()
  new
  call setline(1, ['one', 'two', 'three'])
  call assert_equal('3', RubyEval('$curbuf.count'))
  call assert_equal('3', RubyEval('$curbuf.length'))
  bwipe!
endfunc

" Test buffer.name (buffer name)
func Test_buffer_name()
  new Xfoo
  call assert_equal(expand('%:p'), RubyEval('$curbuf.name'))
  bwipe
  call assert_equal('', RubyEval('$curbuf.name'))
endfunc

" Test buffer.number (number of the buffer).
func Test_buffer_number()
  new
  call assert_equal(string(bufnr('%')), RubyEval('$curbuf.number'))
  new
  call assert_equal(string(bufnr('%')), RubyEval('$curbuf.number'))

  %bwipe
endfunc

" Test buffer.delete({n}) (delete line {n})
func Test_buffer_delete()
  new
  call setline(1, ['one', 'two', 'three'])
  ruby $curbuf.delete(2)
  call assert_equal(['one', 'three'], getline(1, '$'))

  " call assert_fails('ruby $curbuf.delete(0)', 'IndexError: line number 0 out of range')
  " call assert_fails('ruby $curbuf.delete(3)', 'IndexError: line number 3 out of range')
  call assert_fails('ruby $curbuf.delete(3)', 'RuntimeError: Index out of bounds')

  bwipe!
endfunc

" Test buffer.append({str}, str) (append line {str} after line {n})
func Test_buffer_append()
  new
  ruby $curbuf.append(0, 'one')
  ruby $curbuf.append(1, 'three')
  ruby $curbuf.append(1, 'two')
  ruby $curbuf.append(4, 'four')

  call assert_equal(['one', 'two', 'three', '', 'four'], getline(1, '$'))

  " call assert_fails('ruby $curbuf.append(-1, "x")',
  "    \           'IndexError: line number -1 out of range')
  call assert_fails('ruby $curbuf.append(-1, "x")',
       \           'ArgumentError: Index out of bounds')
  call assert_fails('ruby $curbuf.append(6, "x")',
       \           'RuntimeError: Index out of bounds')

  bwipe!
endfunc

" Test buffer.line (get or set the current line)
func Test_buffer_line()
  new
  call setline(1, ['one', 'two', 'three'])
  2
  call assert_equal('two', RubyEval('$curbuf.line'))

  ruby $curbuf.line = 'TWO'
  call assert_equal(['one', 'TWO', 'three'], getline(1, '$'))

  bwipe!
endfunc

" Test buffer.line_number (get current line number)
func Test_buffer_line_number()
  new
  call setline(1, ['one', 'two', 'three'])
  2
  call assert_equal('2', RubyEval('$curbuf.line_number'))

  bwipe!
endfunc

func Test_buffer_get()
  new
  call setline(1, ['one', 'two'])
  call assert_equal('one', RubyEval('$curbuf[1]'))
  call assert_equal('two', RubyEval('$curbuf[2]'))

  " call assert_fails('ruby $curbuf[0]',
  "     \           'IndexError: line number 0 out of range')
  call assert_fails('ruby $curbuf[3]',
       \           'RuntimeError: Index out of bounds')

  bwipe!
endfunc

func Test_buffer_set()
  new
  call setline(1, ['one', 'two'])
  ruby $curbuf[2] = 'TWO'
  ruby $curbuf[1] = 'ONE'

  " call assert_fails('ruby $curbuf[0] = "ZERO"',
  "      \           'IndexError: line number 0 out of range')
  " call assert_fails('ruby $curbuf[3] = "THREE"',
  "      \           'IndexError: line number 3 out of range')
  call assert_fails('ruby $curbuf[3] = "THREE"',
        \           'RuntimeError: Index out of bounds')
  bwipe!
endfunc

" Test window.width (get or set window height).
func Test_window_height()
  new

  " Test setting window height
  ruby $curwin.height = 2
  call assert_equal(2, winheight(0))

  " Test getting window height
  call assert_equal('2', RubyEval('$curwin.height'))

  bwipe
endfunc

" Test window.width (get or set window width).
func Test_window_width()
  vnew

  " Test setting window width
  ruby $curwin.width = 2
  call assert_equal(2, winwidth(0))

  " Test getting window width
  call assert_equal('2', RubyEval('$curwin.width'))

  bwipe
endfunc

" Test window.buffer (get buffer object of a window object).
func Test_window_buffer()
  new Xfoo1
  new Xfoo2
  ruby $b2 = $curwin.buffer
  ruby $w2 = $curwin
  wincmd j
  ruby $b1 = $curwin.buffer
  ruby $w1 = $curwin

  " call assert_equal(RubyEval('$b1'), RubyEval('$w1.buffer'))
  " call assert_equal(RubyEval('$b2'), RubyEval('$w2.buffer'))
  call assert_equal(string(bufnr('Xfoo1')), RubyEval('$w1.buffer.number'))
  call assert_equal(string(bufnr('Xfoo2')), RubyEval('$w2.buffer.number'))

  ruby $b1, $w1, $b2, $w2 = nil
  %bwipe
endfunc

" Test Vim::Window.current (get current window object)
func Test_Vim_window_current()
  let cw = RubyEval('$curwin')
  " call assert_equal(cw, RubyEval('Vim::Window.current'))
  call assert_match('^#<Neovim::Window:0x\x\+>$', cw)
endfunc

" Test Vim::Window.count (number of windows)
func Test_Vim_window_count()
  new Xfoo1
  new Xfoo2
  split
  call assert_equal('4', RubyEval('Vim::Window.count'))
  %bwipe
  call assert_equal('1', RubyEval('Vim::Window.count'))
endfunc

" Test Vim::Window[n] (get window object of window n)
func Test_Vim_window_get()
  new Xfoo1
  new Xfoo2
  call assert_match('Xfoo2$', RubyEval('Vim::Window[0].buffer.name'))
  wincmd j
  call assert_match('Xfoo1$', RubyEval('Vim::Window[1].buffer.name'))
  wincmd j
  call assert_equal('',       RubyEval('Vim::Window[2].buffer.name'))
  %bwipe
endfunc

" Test Vim::Buffer.current (return the buffer object of current buffer)
func Test_Vim_buffer_current()
  let cb = RubyEval('$curbuf')
  " call assert_equal(cb, RubyEval('Vim::Buffer.current'))
  call assert_match('^#<Neovim::Buffer:0x\x\+>$', cb)
endfunc

" Test Vim::Buffer:.count (return the number of buffers)
func Test_Vim_buffer_count()
  new Xfoo1
  new Xfoo2
  call assert_equal('3', RubyEval('Vim::Buffer.count'))
  %bwipe
  call assert_equal('1', RubyEval('Vim::Buffer.count'))
endfunc

" Test Vim::buffer[n] (return the buffer object of buffer number n)
func Test_Vim_buffer_get()
  new Xfoo1
  new Xfoo2

  " Index of Vim::Buffer[n] goes from 0 to the number of buffers.
  call assert_equal('',       RubyEval('Vim::Buffer[0].name'))
  call assert_match('Xfoo1$', RubyEval('Vim::Buffer[1].name'))
  call assert_match('Xfoo2$', RubyEval('Vim::Buffer[2].name'))
  call assert_fails('ruby print Vim::Buffer[3].name',
        \           "NoMethodError: undefined method `name' for nil:NilClass")
  %bwipe
endfunc

" Test Vim::command({cmd}) (execute a Ex command))
" Test Vim::command({cmd})
func Test_Vim_command()
  new
  call setline(1, ['one', 'two', 'three', 'four'])
  ruby Vim::command('2,3d')
  call assert_equal(['one', 'four'], getline(1, '$'))
  bwipe!
endfunc

" Test Vim::set_option (set a vim option)
func Test_Vim_set_option()
  call assert_equal(0, &number)
  ruby Vim::set_option('number')
  call assert_equal(1, &number)
  ruby Vim::set_option('nonumber')
  call assert_equal(0, &number)
endfunc

func Test_Vim_evaluate()
  call assert_equal('123',      RubyEval('Vim::evaluate("123")'))
  " Vim::evaluate("123").class gives Integer or Fixnum depending
  " on versions of Ruby.
  call assert_match('^Integer\|Fixnum$', RubyEval('Vim::evaluate("123").class'))

  call assert_equal('1.23',     RubyEval('Vim::evaluate("1.23")'))
  call assert_equal('Float',    RubyEval('Vim::evaluate("1.23").class'))

  call assert_equal('foo',      RubyEval('Vim::evaluate("\"foo\"")'))
  call assert_equal('String',   RubyEval('Vim::evaluate("\"foo\"").class'))

  call assert_equal('[1, 2]',   RubyEval('Vim::evaluate("[1, 2]")'))
  call assert_equal('Array',    RubyEval('Vim::evaluate("[1, 2]").class'))

  call assert_equal('{"1"=>2}', RubyEval('Vim::evaluate("{1:2}")'))
  call assert_equal('Hash',     RubyEval('Vim::evaluate("{1:2}").class'))

  call assert_equal('',         RubyEval('Vim::evaluate("v:null")'))
  call assert_equal('NilClass', RubyEval('Vim::evaluate("v:null").class'))

  " call assert_equal('',         RubyEval('Vim::evaluate("v:none")'))
  " call assert_equal('NilClass', RubyEval('Vim::evaluate("v:none").class'))

  call assert_equal('true',      RubyEval('Vim::evaluate("v:true")'))
  call assert_equal('TrueClass', RubyEval('Vim::evaluate("v:true").class'))
  call assert_equal('false',     RubyEval('Vim::evaluate("v:false")'))
  call assert_equal('FalseClass',RubyEval('Vim::evaluate("v:false").class'))
endfunc

func Test_Vim_evaluate_list()
  call setline(line('$'), ['2 line 2'])
  ruby Vim.command("normal /^2\n")
  let l = ["abc", "def"]
  ruby << EOF
  curline = $curbuf.line_number
  l = Vim.evaluate("l");
  $curbuf.append(curline, l.join("|"))
EOF
  normal j
  .rubydo $_ = $_.gsub(/\|/, '/')
  call assert_equal('abc/def', getline('$'))
endfunc

func Test_Vim_evaluate_dict()
  let d = {'a': 'foo', 'b': 123}
  redir => l:out
  ruby d = Vim.evaluate("d"); print d
  redir END
  call assert_equal(['{"a"=>"foo", "b"=>123}'], split(l:out, "\n"))
endfunc

" Test Vim::message({msg}) (display message {msg})
func Test_Vim_message()
  throw 'skipped: TODO: '
  ruby Vim::message('A message')
  let messages = split(execute('message'), "\n")
  call assert_equal('A message', messages[-1])
endfunc

func Test_print()
  ruby print "Hello World!"
  let messages = split(execute('message'), "\n")
  call assert_equal('Hello World!', messages[-1])
endfunc

func Test_p()
  ruby p 'Just a test'
  let messages = split(execute('message'), "\n")
  call assert_equal('"Just a test"', messages[-1])

  " Check return values of p method

  call assert_equal('123', RubyEval('p(123)'))
  call assert_equal('[1, 2, 3]', RubyEval('p(1, 2, 3)'))

  " Avoid the "message maintainer" line.
  let $LANG = ''
  messages clear
  call assert_equal('true', RubyEval('p() == nil'))

  let messages = split(execute('message'), "\n")
  call assert_equal(0, len(messages))
endfunc
