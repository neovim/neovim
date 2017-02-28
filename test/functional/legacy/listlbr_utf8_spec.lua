local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')


local feed, execute, source, insert = helpers.feed, helpers.execute,
    helpers.source, helpers.insert
local session = helpers

describe("linebreak", function()
  local screen
  pending("temporary")

  before_each(function()
    session.clear()

    screen = Screen.new(20, 5)
    screen:attach()

    execute('set wildchar=<C-e>')
    execute('vert resize 20')
    execute('set ts=4 sw=4 sts=4 linebreak showbreak=+ wrap')
    execute("set linebreak list listchars=nbsp:␣,tab:▕—,trail:ˑ,eol:¶")
  end)

  after_each(function()
    screen:detach()
  end)

  it("set linebreak list with fancy listchars", function()
    execute("set linebreak list listchars=nbsp:␣,tab:▕—,trail:ˑ,eol:¶")
    feed("i\tabcdef hijklmn\tpqrstuvwxyz 1060ABCDEFGHIJKLMNOP ")
    screen:expect([[
    ▕———abcdef          |
    +hijklmn▕———        |
    +pqrstuvwxyz␣1060ABC|
    +DEFGHIJKLMNOPˑ^¶    |
    -- INSERT --        |
    ]])
  end)

  it("set list nolinebreak", function()
    execute("set list nolinebreak")
    feed("i\tabcdef hijklmn\tpqrstuvwxyz 1060ABCDEFGHIJKLMNOP ")
    screen:expect([[
    ▕———abcdef hijklmn▕—|
    +pqrstuvwxyz␣1060ABC|
    +DEFGHIJKLMNOPˑ^¶    |
    ~                   |
    -- INSERT --        |
    ]])
  end)

  it("set linebreak nolist", function()
    execute("set nolist linebreak")
    feed("i\t*mask = nil;")
    screen:expect([[
        *mask = nil;^    |
    ~                   |
    ~                   |
    ~                   |
    -- INSERT --        |
    ]])
  end)

  it("set linebreak list listchars and concealing", function()
    screen:try_resize(40, 9)
    source([[
    let c_defines=['#define ABCDE		1','#define ABCDEF		1','#define ABCDEFG		1','#define ABCDEFGH	1', '#define MSG_MODE_FILE			1','#define MSG_MODE_CONSOLE		2','#define MSG_MODE_FILE_AND_CONSOLE	3']
    call append(0, c_defines)
    ]])
    execute("set list linebreak listchars=tab:>- conceallevel=1")
    execute("verbose set sw? sts? ts?")
    -- see :h syn-cchar
    execute("syn match Conceal conceal cchar=>'AB\\|MSG_MODE'")
    screen:expect([[
    #define >CDE>--->---1                   |
    #define >CDEF>-->---1                   |
    #define >CDEFG>->---1                   |
    #define >CDEFGH>----1                   |
    #define >_FILE>--------->--->---1       |
    #define >_CONSOLE>---------->---2       |
    #define >_FILE_AND_CONSOLE>---------3   |
    ^                                        |
                                            |
    ]])
    execute("gg")
  end)

  it("set linebreak list listchars and concealing part2", function()
    -- should conceal 'bb'
    screen:try_resize(40, 6)
    source([[
    let c_defines=['bbeeeeee		;	some text']
    call append(0, c_defines)
    $]])
    -- concealcursor=n => just in normal mode
    -- cole=2 => not displayed if no cchar
    execute("set nowrap ts=2 list linebreak listchars=tab:>- cole=2 concealcursor=n")
    source([[
    syn clear
    syn match meaning    /;\s*\zs.*/
    syn match hasword    /^\x\{8}/    contains=word
    syn match word       /\<\x\{8}\>/ contains=beginword,endword contained
    syn match beginword  /\<\x\x/     contained conceal
    syn match endword    /\x\{6}\>/   contained
    hi meaning   guibg=blue
    hi beginword guibg=green
    hi endword   guibg=red
    ]])
    helpers.wait()
    screen:expect("eeeeee>--->-;>some text",
    nil,nil,nil, true )
  end)

  -- TODO update with new neovim system to check attributes
  -- or remove it if done somewhere else
  -- it("screenattributes for comment", function()
  --   execute("set ft=c ts=7 linebreak list listchars=nbsp:␣,tab:▕—,trail:ˑ,eol:¶")
  --   source([[
  --   syntax on
  --   hi SpecialKey term=underline ctermfg=red guifg=red
  --   let attr=[]
  --   nnoremap <expr> GG ":let attr += ['".screenattr(screenrow(),screencol())."']\n"
  --   $
  --   norm! zt0
  --   ]])
  --   -- GG being remapped
  --   feed('GGlGGlGGlGGlGGlGGlGGlGGlGGlGGl')
  --   screen:expect([[
  --   /*     and some more */
  --   ScreenAttributes for test6:
  --   Attribut 0 and 1 and 3 and 5 are different!
  --   ]])
  -- end)

  it("visual block append after multibyte char ", function()
    -- ...with set linebreak selection=exclusive
    -- reset cpo to its vim default values
    execute("set cpo&vim linebreak selection=exclusive")
    feed("ilong line: <Esc>40afoobar <Esc>aTARGETÃ' at end<Esc>")
    -- test v_b_a (visual block append): add the letter 'x' somewhere
    feed("$3B<C-v>eAx<Esc>")
      helpers.expect_any("long line: foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar TARGETÃx' at end")
  end)

  it("multibyte sign and colorcolumn", function()

    local buf = helpers.eval("nvim_get_current_buf()")
    local bufid = helpers.buffer("get_number", buf)
    screen:try_resize(10, 6)
    screen:set_default_attr_ignore( {{},
      {bold=true, foreground=Screen.colors.Blue1}, } )

    execute("set list nolinebreak colorcolumn=3")
    execute('sign define foo text=＋')
    insert([[
      
      a b c
      d e f
      ]])
    helpers.command('sign place 1 name=foo line=2 buffer='..bufid)

    feed("gg")
    screen:expect([[
    {1:  }{2:¶} {3: }       |
    ＋a {3:b} c{2:¶}    |
    {1:  }d {3:e} f{2:¶}    |
    {1:  }{2:^¶} {3: }       |
    {1:  }{2:~         }|
                |]]
    , {
      -- signcolumn group
      [1] = {foreground = Screen.colors.DarkBlue, background=Screen.colors.WebGray},
      -- fillchar
      [2] = { bold = true, foreground = Screen.colors.Blue1},
      -- colorcolumn
      [3] = {background = Screen.colors.LightRed}
    })
  end)
end)
