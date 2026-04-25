-- Test for linebreak and list option in utf-8 mode

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local source = n.source
local feed = n.feed
local exec = n.exec
local clear, expect = n.clear, n.expect

describe('linebreak', function()
  before_each(clear)

  -- luacheck: ignore 621 (Indentation)
  -- luacheck: ignore 613 (Trailing whitespaces in a string)
  it('is working', function()
    source([[
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
      "
      let g:test ="Test 1: set linebreak + set list + fancy listchars"
      exe "set linebreak list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6"
      redraw!
      let line=ScreenChar(winwidth(0),4)
      call DoRecordScreen()
      "
      let g:test ="Test 2: set nolinebreak list"
      set list nolinebreak
      redraw!
      let line=ScreenChar(winwidth(0),4)
      call DoRecordScreen()
      "
      let g:test ="Test 3: set linebreak nolist"
      $put =\"\t*mask = nil;\"
      $
      norm! zt
      set nolist linebreak
      redraw!
      let line=ScreenChar(winwidth(0),4)
      call DoRecordScreen()
      "
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
      "
      let g:test ="Test 5: set linebreak list listchars and concealing part2"
      let c_defines=['bbeeeeee		;	some text']
      call append('$', c_defines)
      $
      norm! zt
      set nowrap ts=2 list linebreak listchars=tab:>- cole=2 concealcursor=n
      syn clear
      syn match meaning    /;\s*\zs.*/
      syn match hasword    /^\x\{8}/    contains=word
      syn match word       /\<\x\{8}\>/ contains=beginword,endword contained
      syn match beginword  /\<\x\x/     contained conceal
      syn match endword    /\x\{6}\>/   contained
      hi meaning   guibg=blue
      hi beginword guibg=green
      hi endword   guibg=red
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call DoRecordScreen()
      "
      let g:test ="Test 6: Screenattributes for comment"
      $put =g:test
      call append('$', ' /*		 and some more */')
      exe "set ft=c ts=7 linebreak list listchars=nbsp:\u2423,tab:\u2595\u2014,trail:\u02d1,eol:\ub6"
      syntax on
      hi SpecialKey term=underline ctermfg=red guifg=red
      let attr=[]
      nnoremap <expr> GG ":let attr += ['".screenattr(screenrow(),screencol())."']\n"
      $
      norm! zt0
    ]])
    feed('GGlGGlGGlGGlGGlGGlGGlGGlGGlGGl')
    source([[
      call append('$', ['ScreenAttributes for test6:'])
      if attr[0] != attr[1] && attr[1] != attr[3] && attr[3] != attr[5]
         call append('$', "Attribut 0 and 1 and 3 and 5 are different!")
      else
         call append('$', "Not all attributes are different")
      endif
      set cpo&vim linebreak selection=exclusive
      let g:test ="Test 8: set linebreak with visual block mode and v_b_A and selection=exclusive and multibyte char"
      $put =g:test
    ]])
    feed("Golong line: <Esc>40afoobar <Esc>aTARGETÃ' at end<Esc>")
    source([[
      exe "norm! $3B\<C-v>eAx\<Esc>"
      "
      let g:test ="Test 9: a multibyte sign and colorcolumn"
      let attr=[]
      let attr2=[]
      $put =''
      $put ='a b c'
      $put ='a b c'
      set list nolinebreak cc=3
    ]])
    feed(':sign define foo text=<C-v>uff0b<CR>')
    source([[
      sign place 1 name=foo line=50 buffer=2
      norm! 2kztj
      let line1=line('.')
    ]])
    feed('0GGlGGlGGlGGl')
    source([[
      let line2=line('.')
      let attr2=attr
      let attr=[]
    ]])
    feed('0GGlGGlGGlGGl')
    source([[
      redraw!
      let line=ScreenChar(winwidth(0),3)
      call DoRecordScreen()
      " expected: attr[2] is different because of colorcolumn
      if attr[0] != attr2[0] || attr[1] != attr2[1] || attr[2] != attr2[2]
         call append('$', "Screen attributes are different!")
      else
         call append('$', "Screen attributes are the same!")
      endif
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
      #define >_FILE_AND_CONSOLE>---------3   
      bbeeeeee		;	some text

      Test 5: set linebreak list listchars and concealing part2
      eeeeee>--->-;>some text                 
      Test 6: Screenattributes for comment
       /*		 and some more */
      ScreenAttributes for test6:
      Attribut 0 and 1 and 3 and 5 are different!
      Test 8: set linebreak with visual block mode and v_b_A and selection=exclusive and multibyte char
      long line: foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar TARGETÃx' at end

      a b c
      a b c

      Test 9: a multibyte sign and colorcolumn
        ¶                                     
      ＋a b c¶                                
        a b c¶                                
      Screen attributes are the same!]])
  end)

  -- oldtest: Test_visual_ends_before_showbreak()
  it("Visual area is correct when it ends before multibyte 'showbreak'", function()
    local screen = Screen.new(60, 6)
    exec([[
      let &wrap = v:true
      let &linebreak = v:true
      let &showbreak = '↪ '
      eval ['xxxxx ' .. 'y'->repeat(&columns - 6) .. ' zzzz']->setline(1)
      normal! wvel
    ]])
    screen:expect([[
      xxxxx                                                       |
      {1:↪ }{17:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy}^ {17:   }|
      {1:↪ }zzzz                                                      |
      {1:~                                                           }|*2
      {5:-- VISUAL --}                                                |
    ]])
  end)

  it("Visual block highlight is correct with 'linebreak'", function()
    local screen = Screen.new(60, 6)
    exec('set laststatus=0 showcmd ruler')

    -- 'linebreak' after end char (initially fixed by patch 7.4.467)
    exec([[
      20vnew
      setlocal linebreak
      call setline(1, ['foo ' .. repeat('x', 10), 'foo ' .. repeat('x', 20)])
      exe "normal! gg0\<C-V>3lj"
    ]])
    screen:expect([[
      {17:foo }xxxxxxxxxx      │                                       |
      {17:foo}^                 │{1:~                                      }|
      xxxxxxxxxxxxxxxxxxxx│{1:~                                      }|
      {1:~                   }│{1:~                                      }|*2
      {5:-- VISUAL BLOCK --}              2x4       2,4           All |
    ]])

    -- TAB as end char: 'linebreak' shouldn't break Visual block hl
    exec([[
      bwipe!
      setlocal nolinebreak
      call setline(1, ["foo\tbar", 'foo12345bar', "foo\tbar"])
      exe "normal! gg03l\<C-V>2j2h"
    ]])
    screen:expect([[
      f{17:oo     }bar                                                 |
      f{17:oo12345}bar                                                 |
      f^o{17:o     }bar                                                 |
      {1:~                                                           }|*2
      {5:-- VISUAL BLOCK --}              3x7       3,2           All |
    ]])
    feed('<Esc>:setlocal linebreak<CR>gv')
    screen:expect_unchanged(true)

    -- Unprintable end char: 'linebreak' shouldn't break Visual block hl
    exec([[
      bwipe!
      setlocal nolinebreak
      call setline(1, ["foo\uffffbar", 'foo123456bar', "foo\uffffbar"])
      exe "normal! gg03l\<C-V>2j2h"
    ]])
    screen:expect([[
      f{17:oo<ffff>}bar                                                |
      f{17:oo123456}bar                                                |
      f^o{17:o<ffff>}bar                                                |
      {1:~                                                           }|*2
      {5:-- VISUAL BLOCK --}              3x8       3,2           All |
    ]])
    feed('<Esc>:setlocal linebreak<CR>gv')
    screen:expect_unchanged(true)

    -- Virtual text before end char: 'linebreak' shouldn't break Visual block hl
    exec([=[
      bwipe!
      setlocal nolinebreak
      call setline(1, [repeat('x', 15), repeat('x', 10), repeat('x', 10)])
      let s:ns = nvim_create_namespace('test')
      call nvim_buf_set_extmark(0, s:ns, 1, 4, #{virt_text: [['foo: ']],
                                               \ virt_text_pos: 'inline'})
      call nvim_buf_set_extmark(0, s:ns, 2, 4, #{virt_text: [['bar: ']],
                                               \ virt_text_pos: 'inline'})
      exe "normal! gg02l\<C-V>2j2l"
    ]=])
    screen:expect([[
      xx{17:xxxxxxxx}xxxxx                                             |
      xx{17:xx}foo: {17:x}xxxxx                                             |
      xx{17:xx}bar: ^xxxxxx                                             |
      {1:~                                                           }|*2
      {5:-- VISUAL BLOCK --}              3x8       3,5-10        All |
    ]])
    feed('<Esc>:setlocal linebreak<CR>gv')
    screen:expect_unchanged(true)
  end)
end)
