-- Test for linebreak and list option in utf-8 mode

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('linebreak', function()
  setup(clear)

  it('is working', function()
    source([[
      set scrolloff=0
      set wildchar=^E
      10new
      vsp
      vert resize 20
      put =\"\tabcdef hijklmn\tpqrstuvwxyz\u00a01060ABCDEFGHIJKLMNOP \"
      norm! zt
      set ts=4 sw=4 sts=4 linebreak sbr=+ wrap
      fu! ScreenChar(width, lines)
      	let c=''
      	for j in range(1,a:lines)
      	    for i in range(1,a:width)
      	    	let c.=nr2char(screenchar(j, i))
      	    endfor
                 let c.="\n"
      	endfor
      	return c
      endfu
      fu! DoRecordScreen()
      	wincmd l
      	$put =printf(\"\n%s\", g:test)
      	$put =g:line
      	wincmd p
      endfu
      let g:test ="Test 1: set linebreak + set list + fancy listchars"
      exe "set linebreak list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6"
      redraw!
      let line=ScreenChar(winwidth(0),4)
      call DoRecordScreen()
      let g:test ="Test 2: set nolinebreak list"
      set list nolinebreak
      redraw!
      let line=ScreenChar(winwidth(0),4)
      call DoRecordScreen()
      let g:test ="Test 3: set linebreak nolist"
      $put =\"\t*mask = nil;\"
      $
      norm! zt
      set nolist linebreak
      redraw!
      let line=ScreenChar(winwidth(0),4)
      call DoRecordScreen()
      let g:test ="Test 4: set linebreak list listchars and concealing"
      let c_defines=['#define ABCDE		1','#define ABCDEF		1','#define ABCDEFG		1','#define ABCDEFGH	1', '#define MSG_MODE_FILE			1','#define MSG_MODE_CONSOLE		2','#define MSG_MODE_FILE_AND_CONSOLE	3','#define MSG_MODE_FILE_THEN_CONSOLE	4']
      call append('$', c_defines)
      vert resize 40
      $-7
      norm! zt
      set list linebreak listchars=tab:>- cole=1
      syn match Conceal conceal cchar=>'AB\|MSG_MODE'
      redraw!
      let line=ScreenChar(winwidth(0),7)
      call DoRecordScreen()
    ]])

    -- Assert buffer contents.
    expect([[
      
      	abcdef hijklmn	pqrstuvwxyz 1060ABCDEFGHIJKLMNOP 
      
      Test 1: set linebreak + set list + fancy listchars
      ▕———abcdef          
      +hijklmn▕———        
      +pqrstuvwxyz␣1060ABC
      +DEFGHIJKLMNOPˑ¶    
      
      Test 2: set nolinebreak list
      ▕———abcdef hijklmn▕—
      +pqrstuvwxyz␣1060ABC
      +DEFGHIJKLMNOPˑ¶    
      ¶                   
      	*mask = nil;
      
      Test 3: set linebreak nolist
          *mask = nil;    
      ~                   
      ~                   
      ~                   
      #define ABCDE		1
      #define ABCDEF		1
      #define ABCDEFG		1
      #define ABCDEFGH	1
      #define MSG_MODE_FILE			1
      #define MSG_MODE_CONSOLE		2
      #define MSG_MODE_FILE_AND_CONSOLE	3
      #define MSG_MODE_FILE_THEN_CONSOLE	4
      
      Test 4: set linebreak list listchars and concealing
      #define ABCDE>-->---1                   
      #define >CDEF>-->---1                   
      #define >CDEFG>->---1                   
      #define >CDEFGH>----1                   
      #define >_FILE>--------->--->---1       
      #define >_CONSOLE>---------->---2       
      #define >_FILE_AND_CONSOLE>---------3   ]])
  end)
end)
