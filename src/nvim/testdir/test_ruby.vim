" Tests for ruby interface

if !has('ruby')
  finish
end

func Test_ruby_change_buffer()
  call setline(line('$'), ['1 line 1'])
  ruby Vim.command("normal /^1\n")
  ruby $curbuf.line = "1 changed line 1"
  call assert_equal('1 changed line 1', getline('$'))
endfunc

func Test_ruby_evaluate_list()
  call setline(line('$'), ['2 line 2'])
  ruby Vim.command("normal /^2\n")
  let l = ["abc", "def"]
  ruby << EOF
  curline = $curbuf.line_number
  l = Vim.evaluate("l");
  $curbuf.append(curline, l.join("\n"))
EOF
  normal j
  .rubydo $_ = $_.gsub(/\n/, '/')
  call assert_equal('abc/def', getline('$'))
endfunc

func Test_ruby_evaluate_dict()
  let d = {'a': 'foo', 'b': 123}
  redir => l:out
  ruby d = Vim.evaluate("d"); print d
  redir END
  call assert_equal(['{"a"=>"foo", "b"=>123}'], split(l:out, "\n"))
endfunc

func Test_rubydo()
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
  bwipe!
  bwipe!
endfunc

func Test_rubyfile()
  " Check :rubyfile does not SEGV with Ruby level exception but just fails
  let tempfile = tempname() . '.rb'
  call writefile(['raise "vim!"'], tempfile)
  call assert_fails('rubyfile ' . tempfile)
  call delete(tempfile)
endfunc
