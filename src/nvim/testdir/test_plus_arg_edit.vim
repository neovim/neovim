" Tests for complicated + argument to :edit command
function Test_edit()
  call writefile(["foo|bar"], "Xfile1")
  call writefile(["foo/bar"], "Xfile2")
  edit +1|s/|/PIPE/|w Xfile1| e Xfile2|1 | s/\//SLASH/|w
  call assert_equal(["fooPIPEbar"], readfile("Xfile1"))
  call assert_equal(["fooSLASHbar"], readfile("Xfile2"))
  call delete('Xfile1')
  call delete('Xfile2')
endfunction

func Test_edit_bad()
  " Test loading a utf8 file with bad utf8 sequences.
  call writefile(["[\xff][\xc0][\xe2\x89\xf0][\xc2\xc2]"], "Xfile")
  new

  " Without ++bad=..., the default behavior is like ++bad=?
  e! ++enc=utf8 Xfile
  call assert_equal('[?][?][???][??]', getline(1))

  e! ++enc=utf8 ++bad=_ Xfile
  call assert_equal('[_][_][___][__]', getline(1))

  e! ++enc=utf8 ++bad=drop Xfile
  call assert_equal('[][][][]', getline(1))

  e! ++enc=utf8 ++bad=keep Xfile
  call assert_equal("[\xff][\xc0][\xe2\x89\xf0][\xc2\xc2]", getline(1))

  call assert_fails('e! ++enc=utf8 ++bad=foo Xfile', 'E474:')

  bw!
  call delete('Xfile')
endfunc
