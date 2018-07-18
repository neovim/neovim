" Simplistic testing of Farsi mode.
" Note: must be edited with latin1 encoding.

if !has('farsi') || has('nvim')  " Not supported in Nvim. #6192
  finish
endif
" Farsi uses a single byte encoding.
set enc=latin1

func Test_farsi_toggle()
  new

  set altkeymap
  call assert_equal(0, &fkmap)
  call assert_equal(0, &rl)
  call feedkeys("\<F8>", 'x')
  call assert_equal(1, &fkmap)
  call assert_equal(1, &rl)
  call feedkeys("\<F8>", 'x')
  call assert_equal(0, &fkmap)
  call assert_equal(0, &rl)

  set rl
  " conversion from Farsi 3342 to Farsi VIM.
  call setline(1, join(map(range(0x80, 0xff), 'nr2char(v:val)'), ''))
  call feedkeys("\<F9>", 'x')
  let exp = [0xfc, 0xf8, 0xc1, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7,
	   \ 0xc8, 0xc9, 0xca, 0xd0, 0xd1, 0xd2, 0xd3, 0xd6,
	   \ 0xd6, 0xd6, 0xd7, 0xd7, 0xd7, 0xd8, 0xd9, 0xda,
	   \ 0xdb, 0xdc, 0xdc, 0xc1, 0xdd, 0xde, 0xe0, 0xe0,
	   \ 0xe1, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6,
	   \ 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae,
	   \ 0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
	   \ 0xb7, 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe,
	   \ 0xbf, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6,
	   \ 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce,
	   \ 0xcf, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6,
	   \ 0xd7, 0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde,
	   \ 0xdf, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6,
	   \ 0xe7, 0xe8, 0xe9, 0xea, 0xeb, 0xfb, 0xfb, 0xfe,
	   \ 0xfe, 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6,
	   \ 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xe1,
           \ ]
  call assert_equal(join(map(exp, 'nr2char(v:val)'), ''), getline(1))

  " conversion from Farsi VIM to Farsi 3342.
  call setline(1, join(map(range(0x80, 0xff), 'nr2char(v:val)'), ''))
  call feedkeys("\<F9>", 'x')
  let exp = [0xfc, 0xf8, 0xc1, 0x83, 0x84, 0x85, 0x86, 0x87,
	   \ 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x90,
	   \ 0x90, 0x90, 0x92, 0x93, 0x93, 0x95, 0x96, 0x97,
	   \ 0x98, 0xdc, 0x9a, 0x9b, 0x9c, 0x9e, 0x9e, 0xff,
	   \ 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
	   \ 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf,
	   \ 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7,
	   \ 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf,
	   \ 0xc0, 0xc1, 0xc2, 0x83, 0x84, 0x85, 0x86, 0x87,
	   \ 0x88, 0x89, 0x8a, 0xcb, 0xcc, 0xcd, 0xce, 0xcf,
	   \ 0x8b, 0x8c, 0x8d, 0x8e, 0xd4, 0xd5, 0x90, 0x93,
	   \ 0x95, 0x96, 0x97, 0x98, 0x99, 0x9b, 0x9c, 0xdf,
	   \ 0x9d, 0xff, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7,
	   \ 0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xec, 0xee, 0xef,
	   \ 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
	   \ 0xf8, 0xf9, 0xfa, 0xec, 0x80, 0xfd, 0xee, 0xff,
           \ ]
  call assert_equal(join(map(exp, 'nr2char(v:val)'), ''), getline(1))

  bwipe!
endfunc

func Test_farsi_map()
  new

  set altkeymap
  set rl
  " RHS of mapping is reversed.
  imap xyz abc
  call feedkeys("axyz\<Esc>", 'tx')
  call assert_equal('cba', getline(1))

  set norl
  iunmap xyz
  set noaltkeymap
  bwipe!
endfunc

func Test_input_farsi()
  new
  setlocal rightleft fkmap
  " numbers switch input direction
  call feedkeys("aabc0123456789.+-^%#=xyz\<Esc>", 'tx')
  call assert_equal("\x8c�ν�����������������\x93�", getline('.'))

  " all non-number special chars with spaces
  call feedkeys("oB E F H I K L M O P Q R T U W Y ` !  @ # $ % ^ & * () - _ = + \\ | : \" .  / < > ? \<Esc>", 'tx')
  call assert_equal("������������ [�]��������񠢠���������������蠨����頽����꠺��������������", getline('.'))

  " all non-number special chars without spaces
  call feedkeys("oBEFHIKLMOPQRTUWY`!@#$%^&*()-_=+\\|:\"./<>?\<Esc>",'tx')
  call assert_equal("��������[]�����񢣧�����訩�齫�꺻�����", getline('.'))

  " all letter chars with spaces
  call feedkeys("oa A b c C d D e f g G h i j J k l m n N o p q r s S t u v V w x X y z Z ; \ , [ ] \<Esc>", 'tx')
  call assert_equal("Ѡ��̠ΠϠ���Ơàܠ�����Š��ޠݠĠˠˠʠɠӠ٠Р��ؠ֠͠͠ҠԠԠנՠ��ڠ�ߠǠȠ", getline('.'))

  " all letter chars without spaces
  call feedkeys("oaAbcCdDefgGhijJklmnNopqrsStuvVwxXyzZ;\,[]\<Esc>", 'tx')
  call assert_equal("\x8c����\x9f�\x86\x83���\x9d\x85\x80\x9c\x9b\x84��\x8a\x89\x8e\x96\x8b�\x95\x90��\x8d��\x93��\x97�\x87\x88", getline('.'))

  bwipe!
endfunc

func Test_command_line_farsi()
  set allowrevins altkeymap

  " letter characters with spaces
  call feedkeys(":\"\<C-_>a A b c C d D e f g G h i j J k l m n N o p q r s S t u v V w x X y z Z ; \\ , [ ]\<CR>", 'tx')
  call assert_equal("\"\x88�Ǡߠ�ڠՠՠנԠԠҠ֠͠͠ؠ��Р٠ӠɠʠˠˠĠݠޠ��Š�����ܠàƠ���ϠΠ̠���", getreg(':'))
 
  " letter characters without spaces
  call feedkeys(":\"\<C-_>aAbcCdDefgGhijJklmnNopqrsStuvVwxXyzZ;\\,[]\<CR>", 'tx')
  call assert_equal("\"\x88\x87�����\x93��\x8d��\x90\x95�\x8b\x96\x8e\x89\x8a��\x84\x9b\x9c\x80\x85\x9d���\x83\x86�\x9f����\x8c", getreg(':'))
 
  " other characters with spaces
  call feedkeys(":\"\<C-_>0 1 2 3 4 5 6 7 8 9 ` .  !  \" $ % ^ & / () = \\ ?  + - _ * : # ~ @ < > { } | B E F H I K L M O P Q R T U W Y\<CR>", 'tx')
  call assert_equal("\"��������]�[� �������������}�{�������~������頭������렽�������������������������������������������", getreg(':'))

  " other characters without spaces
  call feedkeys(":\"\<C-_>0123456789`.!\"$%^&/()=\\?+-_*:#~@<>{}|BEFHIKLMOPQRTUWY\<CR>", 'tx')
  call assert_equal("\"������][���������}{���~���魫�뽩��������������������", getreg(':'))

  set noallowrevins noaltkeymap
endfunc
