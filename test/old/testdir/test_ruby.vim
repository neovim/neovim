" Tests for ruby interface

source check.vim
CheckFeature ruby

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

func Test_rubydo_dollar_underscore()
  throw 'skipped: TODO: '
  new
  call setline(1, ['one', 'two', 'three', 'four'])
  2,3rubydo $_ = '[' + $_  + ']'
  call assert_equal(['one', '[two]', '[three]', 'four'], getline(1, '$'))
  bwipe!

  call assert_fails('rubydo $_ = 0', 'E265:')
  call assert_fails('rubydo (')
  bwipe!
endfunc

func Test_rubyfile()
  " Check :rubyfile does not SEGV with Ruby level exception but just fails
  let tempfile = tempname() . '.rb'
  call writefile(['raise "vim!"'], tempfile)
  call assert_fails('rubyfile ' . tempfile)
  call delete(tempfile)
endfunc

func Test_ruby_set_cursor()
  " Check that setting the cursor position works.
  new
  call setline(1, ['first line', 'second line'])
  normal gg
  rubydo $curwin.cursor = [1, 5]
  call assert_equal([1, 6], [line('.'), col('.')])
  call assert_equal([1, 5], rubyeval('$curwin.cursor'))

  " Check that movement after setting cursor position keeps current column.
  normal j
  call assert_equal([2, 6], [line('.'), col('.')])
  call assert_equal([2, 5], '$curwin.cursor'->rubyeval())

  " call assert_fails('ruby $curwin.cursor = [1]',
  "      \           'ArgumentError: array length must be 2')
  bwipe!
endfunc

" Test buffer.count and buffer.length (number of lines in buffer)
func Test_ruby_buffer_count()
  new
  call setline(1, ['one', 'two', 'three'])
  call assert_equal(3, rubyeval('$curbuf.count'))
  call assert_equal(3, rubyeval('$curbuf.length'))
  bwipe!
endfunc

" Test buffer.name (buffer name)
func Test_ruby_buffer_name()
  new Xfoo
  call assert_equal(expand('%:p'), rubyeval('$curbuf.name'))
  bwipe
  call assert_equal('',     rubyeval('$curbuf.name'))
endfunc

" Test buffer.number (number of the buffer).
func Test_ruby_buffer_number()
  new
  call assert_equal(bufnr('%'), rubyeval('$curbuf.number'))
  new
  call assert_equal(bufnr('%'), rubyeval('$curbuf.number'))

  %bwipe
endfunc

" Test buffer.delete({n}) (delete line {n})
func Test_ruby_buffer_delete()
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
func Test_ruby_buffer_append()
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
func Test_ruby_buffer_line()
  new
  call setline(1, ['one', 'two', 'three'])
  2
  call assert_equal('two', rubyeval('$curbuf.line'))

  ruby $curbuf.line = 'TWO'
  call assert_equal(['one', 'TWO', 'three'], getline(1, '$'))

  bwipe!
endfunc

" Test buffer.line_number (get current line number)
func Test_ruby_buffer_line_number()
  new
  call setline(1, ['one', 'two', 'three'])
  2
  call assert_equal(2, rubyeval('$curbuf.line_number'))

  bwipe!
endfunc

func Test_ruby_buffer_get()
  new
  call setline(1, ['one', 'two'])
  call assert_equal('one', rubyeval('$curbuf[1]'))
  call assert_equal('two', rubyeval('$curbuf[2]'))

  " call assert_fails('ruby $curbuf[0]',
  "     \           'IndexError: line number 0 out of range')
  call assert_fails('ruby $curbuf[3]',
       \           'RuntimeError: Index out of bounds')

  bwipe!
endfunc

func Test_ruby_buffer_set()
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
func Test_ruby_window_height()
  new

  " Test setting window height
  ruby $curwin.height = 2
  call assert_equal(2, winheight(0))

  " Test getting window height
  call assert_equal(2, rubyeval('$curwin.height'))

  bwipe
endfunc

" Test window.width (get or set window width).
func Test_ruby_window_width()
  vnew

  " Test setting window width
  ruby $curwin.width = 2
  call assert_equal(2, winwidth(0))

  " Test getting window width
  call assert_equal(2, rubyeval('$curwin.width'))

  bwipe
endfunc

" Test window.buffer (get buffer object of a window object).
func Test_ruby_window_buffer()
  new Xfoo1
  new Xfoo2
  ruby $b2 = $curwin.buffer
  ruby $w2 = $curwin
  wincmd j
  ruby $b1 = $curwin.buffer
  ruby $w1 = $curwin

  " call assert_equal(rubyeval('$b1'), rubyeval('$w1.buffer'))
  " call assert_equal(rubyeval('$b2'), rubyeval('$w2.buffer'))
  call assert_equal(bufnr('Xfoo1'), rubyeval('$w1.buffer.number'))
  call assert_equal(bufnr('Xfoo2'), rubyeval('$w2.buffer.number'))

  ruby $b1, $w1, $b2, $w2 = nil
  %bwipe
endfunc

" Test Vim::Window.current (get current window object)
func Test_ruby_Vim_window_current()
  let cw = rubyeval('$curwin.to_s')
  " call assert_equal(cw, rubyeval('Vim::Window.current'))
  call assert_match('^#<Neovim::Window:0x\x\+>$', cw)
endfunc

" Test Vim::Window.count (number of windows)
func Test_ruby_Vim_window_count()
  new Xfoo1
  new Xfoo2
  split
  call assert_equal(4, rubyeval('Vim::Window.count'))
  %bwipe
  call assert_equal(1, rubyeval('Vim::Window.count'))
endfunc

" Test Vim::Window[n] (get window object of window n)
func Test_ruby_Vim_window_get()
  new Xfoo1
  new Xfoo2
  call assert_match('Xfoo2$', rubyeval('Vim::Window[0].buffer.name'))
  wincmd j
  call assert_match('Xfoo1$', rubyeval('Vim::Window[1].buffer.name'))
  wincmd j
  call assert_equal('',       rubyeval('Vim::Window[2].buffer.name'))
  %bwipe
endfunc

" Test Vim::Buffer.current (return the buffer object of current buffer)
func Test_ruby_Vim_buffer_current()
  let cb = rubyeval('$curbuf.to_s')
  " call assert_equal(cb, rubyeval('Vim::Buffer.current'))
  call assert_match('^#<Neovim::Buffer:0x\x\+>$', cb)
endfunc

" Test Vim::Buffer:.count (return the number of buffers)
func Test_ruby_Vim_buffer_count()
  new Xfoo1
  new Xfoo2
  call assert_equal(3, rubyeval('Vim::Buffer.count'))
  %bwipe
  call assert_equal(1, rubyeval('Vim::Buffer.count'))
endfunc

" Test Vim::buffer[n] (return the buffer object of buffer number n)
func Test_ruby_Vim_buffer_get()
  new Xfoo1
  new Xfoo2

  " Index of Vim::Buffer[n] goes from 0 to the number of buffers.
  call assert_equal('',       rubyeval('Vim::Buffer[0].name'))
  call assert_match('Xfoo1$', rubyeval('Vim::Buffer[1].name'))
  call assert_match('Xfoo2$', rubyeval('Vim::Buffer[2].name'))
  call assert_fails('ruby print Vim::Buffer[3].name',
        \           "NoMethodError")
  %bwipe
endfunc

" Test Vim::command({cmd}) (execute a Ex command))
" Test Vim::command({cmd})
func Test_ruby_Vim_command()
  new
  call setline(1, ['one', 'two', 'three', 'four'])
  ruby Vim::command('2,3d')
  call assert_equal(['one', 'four'], getline(1, '$'))
  bwipe!
endfunc

" Test Vim::set_option (set a vim option)
func Test_ruby_Vim_set_option()
  call assert_equal(0, &number)
  ruby Vim::set_option('number')
  call assert_equal(1, &number)
  ruby Vim::set_option('nonumber')
  call assert_equal(0, &number)
endfunc

func Test_ruby_Vim_evaluate()
  call assert_equal(123,        rubyeval('Vim::evaluate("123")'))
  " Vim::evaluate("123").class gives Integer or Fixnum depending
  " on versions of Ruby.
  call assert_match('^Integer\|Fixnum$', rubyeval('Vim::evaluate("123").class'))

  if has('float')
    call assert_equal(1.23,       rubyeval('Vim::evaluate("1.23")'))
    call assert_equal('Float',    rubyeval('Vim::evaluate("1.23").class'))
  endif

  call assert_equal('foo',      rubyeval('Vim::evaluate("\"foo\"")'))
  call assert_equal('String',   rubyeval('Vim::evaluate("\"foo\"").class'))

  call assert_equal([1, 2],     rubyeval('Vim::evaluate("[1, 2]")'))
  call assert_equal('Array',    rubyeval('Vim::evaluate("[1, 2]").class'))

  call assert_equal({'1': 2},   rubyeval('Vim::evaluate("{1:2}")'))
  call assert_equal('Hash',     rubyeval('Vim::evaluate("{1:2}").class'))

  call assert_equal(v:null,     rubyeval('Vim::evaluate("v:null")'))
  call assert_equal('NilClass', rubyeval('Vim::evaluate("v:null").class'))

  " call assert_equal(v:null,     rubyeval('Vim::evaluate("v:none")'))
  " call assert_equal('NilClass', rubyeval('Vim::evaluate("v:none").class'))

  call assert_equal(v:true,      rubyeval('Vim::evaluate("v:true")'))
  call assert_equal('TrueClass', rubyeval('Vim::evaluate("v:true").class'))
  call assert_equal(v:false,     rubyeval('Vim::evaluate("v:false")'))
  call assert_equal('FalseClass',rubyeval('Vim::evaluate("v:false").class'))
endfunc

func Test_ruby_Vim_blob()
  throw 'skipped: TODO: '
  call assert_equal('0z',         rubyeval('Vim::blob("")'))
  call assert_equal('0z31326162', rubyeval('Vim::blob("12ab")'))
  call assert_equal('0z00010203', rubyeval('Vim::blob("\x00\x01\x02\x03")'))
  call assert_equal('0z8081FEFF', rubyeval('Vim::blob("\x80\x81\xfe\xff")'))
endfunc

func Test_ruby_Vim_evaluate_list()
  call setline(line('$'), ['2 line 2'])
  ruby Vim.command("normal /^2\n")
  let l = ["abc", "def"]
  ruby << trim EOF
    curline = $curbuf.line_number
    l = Vim.evaluate("l");
    $curbuf.append(curline, l.join("|"))
  EOF
  normal j
  .rubydo $_ = $_.gsub(/\|/, '/')
  call assert_equal('abc/def', getline('$'))
endfunc

func Test_ruby_Vim_evaluate_dict()
  let d = {'a': 'foo', 'b': 123}
  redir => l:out
  ruby d = Vim.evaluate("d"); print d
  redir END
  call assert_equal(['{"a"=>"foo","b"=>123}'], split(substitute(l:out, '\s', '', 'g'), "\n"))
endfunc

" Test Vim::message({msg}) (display message {msg})
func Test_ruby_Vim_message()
  throw 'skipped: TODO: '
  ruby Vim::message('A message')
  let messages = split(execute('message'), "\n")
  call assert_equal('A message', messages[-1])
endfunc

func Test_ruby_print()
  func RubyPrint(expr)
    return trim(execute('ruby print ' . a:expr))
  endfunc

  call assert_equal('123', RubyPrint('123'))
  call assert_equal('1.23', RubyPrint('1.23'))
  call assert_equal('Hello World!', RubyPrint('"Hello World!"'))
  call assert_equal('[1, 2]', RubyPrint('[1, 2]'))
  call assert_equal('{"k1"=>"v1","k2"=>"v2"}', substitute(RubyPrint('({"k1" => "v1", "k2" => "v2"})'), '\s', '', 'g'))
  call assert_equal('true', RubyPrint('true'))
  call assert_equal('false', RubyPrint('false'))
  call assert_equal('', RubyPrint('nil'))
  call assert_match('Vim', RubyPrint('Vim'))
  call assert_match('Module', RubyPrint('Vim.class'))

  delfunc RubyPrint
endfunc

func Test_ruby_p()
  ruby p 'Just a test'
  let messages = GetMessages()
  call assert_equal('"Just a test"', messages[-1])

  " Check return values of p method

  call assert_equal(123, rubyeval('p(123)'))
  call assert_equal([1, 2, 3], rubyeval('p(1, 2, 3)'))

  " Avoid the "message maintainer" line.
  let $LANG = ''
  messages clear
  call assert_equal(v:true, rubyeval('p() == nil'))

  let messages = GetMessages()
  call assert_equal(0, len(messages))
endfunc

func Test_rubyeval_error()
  " On Linux or Windows the error matches:
  "   "syntax error, unexpected end-of-input"
  " whereas on macOS in CI, the error message makes less sense:
  "   "SyntaxError: array length must be 2"
  " Unclear why. The test does not check the error message.
  call assert_fails('call rubyeval("(")')
endfunc

" Test for various heredoc syntax
func Test_ruby_heredoc()
  ruby << END
Vim.command('let s = "A"')
END
  ruby <<
Vim.command('let s ..= "B"')
.
  ruby << trim END
    Vim.command('let s ..= "C"')
  END
  ruby << trim
    Vim.command('let s ..= "D"')
  .
  ruby << trim eof
    Vim.command('let s ..= "E"')
  eof
ruby << trimm
Vim.command('let s ..= "F"')
trimm
  call assert_equal('ABCDEF', s)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
