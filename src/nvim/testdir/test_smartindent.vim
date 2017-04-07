
" Tests for not doing smart indenting when it isn't set.
function! Test_nosmartindent()
  new
  call append(0, ["		some test text",
      	\ "		test text",
      	\ "test text",
      	\ "		test text"])
  set nocindent nosmartindent autoindent
  exe "normal! gg/some\<CR>"
  exe "normal! 2cc#test\<Esc>"
  call assert_equal("		#test", getline(1))
  enew! | close
endfunction
