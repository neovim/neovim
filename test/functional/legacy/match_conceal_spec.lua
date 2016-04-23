-- Test for matchadd() and conceal feature

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local expect = helpers.expect
local source = helpers.source

describe('match_conceal', function()
  before_each(function()
    clear()

    source([[
      set wildchar=^E
      10new
      vsp
      vert resize 20
      put =\"\#\ This\ is\ a\ Test\"
      norm! mazt
      
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
      
      fu! ScreenAttr(line, pos, eval)
        let g:attr=[]
        for col in a:pos
          call add(g:attr, screenattr(a:line,col))
        endfor
        " In case all values are zero, probably the terminal
        " isn't set correctly, so catch that case
        let null = (eval(join(g:attr, '+')) == 0)
        let str=substitute(a:eval, '\d\+', 'g:attr[&]', 'g')
        if null || eval(str)
          let g:attr_test="OK: ". str
        else
          let g:attr_test="FAILED: ".str
          let g:attr_test.="\n". join(g:attr, ' ')
          let g:attr_test.="\n TERM: ". &term
        endif
      endfu
      
      fu! DoRecordScreen()
        wincmd l
        $put =printf(\"\n%s\", g:test)
        $put =g:line
        $put =g:attr_test
        wincmd p
      endfu
    ]])
  end)

  it('is working', function()
    source([=[
      let g:test ="Test 1: simple addmatch()"
      call matchadd('Conceal', '\%2l ')
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()

      let g:test ="Test 2: simple addmatch() and conceal (should be: #XThisXisXaXTest)"
      norm! 'azt
      call clearmatches()
      syntax on
      set concealcursor=n conceallevel=1
      call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'X'})
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()

      let g:test ="Test 3: addmatch() and conceallevel=3 (should be: #ThisisaTest)"
      norm! 'azt
      set conceallevel=3
      call clearmatches()
      call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'X'})
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0==1 && 1==2 && 1==3 && 1==4 && 0!=5")
      call DoRecordScreen()

      let g:test ="Test 4: more match() (should be: #Thisisa Test)"
      norm! 'azt
      call matchadd('ErrorMsg', '\%2l Test', 20, -1, {'conceal': 'X'})
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0==1 && 1==2 && 0!=3 && 3==4 && 0!=5 && 3!=5")
      call DoRecordScreen()

      let g:test ="Test 5/1: default conceal char (should be: # This is a Test)"
      norm! 'azt
      call clearmatches()
      set conceallevel=1
      call matchadd('Conceal', '\%2l ', 10, -1, {})
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()
      let g:test ="Test 5/2: default conceal char (should be: #+This+is+a+Test)"
      norm! 'azt
      set listchars=conceal:+
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()
      set listchars&vi

      let g:test ="Test 6/1: syn and match conceal (should be: #ZThisZisZaZTest)"
      norm! 'azt
      call clearmatches()
      set conceallevel=1
      call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'Z'})
      syn match MyConceal /\%2l / conceal containedin=ALL cchar=*
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()
      let g:test ="Test 6/2: syn and match conceal (should be: #*This*is*a*Test)"
      norm! 'azt
      call clearmatches()
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()

      let g:test ="Test 7/1: clear matches"
      norm! 'azt
      syn on
      call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'Z'})
      let a=getmatches()
      call clearmatches()
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0==1 && 0==2 && 0==3 && 0==4 && 0==5")
      call DoRecordScreen()
      $put =a
      call setmatches(a)
      norm! 'azt
      let g:test ="Test 7/2: reset match using setmatches()"
      norm! 'azt
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()

      let g:test ="Test 8: using matchaddpos() (should be #Pis a Test"
      norm! 'azt
      call clearmatches()
      call matchaddpos('Conceal', [[2,2,6]], 10, -1, {'conceal': 'P'})
      let a=getmatches()
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1!=2 && 0==2 && 0==3 && 0!=4 && 0!=5 && 4==5")
      call DoRecordScreen()
      $put =a

      let g:test ="Test 9: match using multibyte conceal char (should be: #ˑThisˑisˑaˑTest)"
      norm! 'azt
      call clearmatches()
      call matchadd('Conceal', '\%2l ', 20, -1, {'conceal': "\u02d1"})
      redraw!
      let line=ScreenChar(winwidth(0),1)
      call ScreenAttr(1,[1,2,7,10,12,16], "0!=1 && 1==2 && 1==3 && 1==4 && 0==5")
      call DoRecordScreen()
    ]=])

    expect([=[
      
      # This is a Test
      
      Test 1: simple addmatch()
      # This is a Test    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 2: simple addmatch() and conceal (should be: #XThisXisXaXTest)
      #XThisXisXaXTest    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 3: addmatch() and conceallevel=3 (should be: #ThisisaTest)
      #ThisisaTest        
      OK: g:attr[0]==g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]!=g:attr[5]
      
      Test 4: more match() (should be: #Thisisa Test)
      #Thisisa Test       
      OK: g:attr[0]==g:attr[1] && g:attr[1]==g:attr[2] && g:attr[0]!=g:attr[3] && g:attr[3]==g:attr[4] && g:attr[0]!=g:attr[5] && g:attr[3]!=g:attr[5]
      
      Test 5/1: default conceal char (should be: # This is a Test)
      # This is a Test    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 5/2: default conceal char (should be: #+This+is+a+Test)
      #+This+is+a+Test    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 6/1: syn and match conceal (should be: #ZThisZisZaZTest)
      #ZThisZisZaZTest    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 6/2: syn and match conceal (should be: #*This*is*a*Test)
      #*This*is*a*Test    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 7/1: clear matches
      # This is a Test    
      OK: g:attr[0]==g:attr[1] && g:attr[0]==g:attr[2] && g:attr[0]==g:attr[3] && g:attr[0]==g:attr[4] && g:attr[0]==g:attr[5]
      {'group': 'Conceal', 'pattern': '\%2l ', 'priority': 10, 'id': 10, 'conceal': 'Z'}
      
      Test 7/2: reset match using setmatches()
      #ZThisZisZaZTest    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]
      
      Test 8: using matchaddpos() (should be #Pis a Test
      #Pis a Test         
      OK: g:attr[0]!=g:attr[1] && g:attr[1]!=g:attr[2] && g:attr[0]==g:attr[2] && g:attr[0]==g:attr[3] && g:attr[0]!=g:attr[4] && g:attr[0]!=g:attr[5] && g:attr[4]==g:attr[5]
      {'group': 'Conceal', 'id': 11, 'priority': 10, 'pos1': [2, 2, 6], 'conceal': 'P'}
      
      Test 9: match using multibyte conceal char (should be: #ˑThisˑisˑaˑTest)
      #ˑThisˑisˑaˑTest    
      OK: g:attr[0]!=g:attr[1] && g:attr[1]==g:attr[2] && g:attr[1]==g:attr[3] && g:attr[1]==g:attr[4] && g:attr[0]==g:attr[5]]=])
  end)
end)
