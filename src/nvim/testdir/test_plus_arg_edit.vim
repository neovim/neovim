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
