" These commands create the option window.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2019 Jul 18

" If there already is an option window, jump to that one.
let buf = bufnr('option-window')
if buf >= 0
  let winids = win_findbuf(buf)
  if len(winids) > 0
    if win_gotoid(winids[0]) == 1
      finish
    endif
  endif
endif

" Make sure the '<' flag is not included in 'cpoptions', otherwise <CR> would
" not be recognized.  See ":help 'cpoptions'".
let s:cpo_save = &cpo
set cpo&vim

" function to be called when <CR> is hit in the option-window
fun! <SID>CR()

  " If on a continued comment line, go back to the first comment line
  let lnum = search("^[^\t]", 'bWcn')
  let line = getline(lnum)

  " <CR> on a "set" line executes the option line
  if match(line, "^ \tset ") >= 0

    " For a local option: go to the previous window
    " If this is a help window, go to the window below it
    let thiswin = winnr()
    let local = <SID>Find(lnum)
    if local >= 0
      exe line
      call <SID>Update(lnum, line, local, thiswin)
    endif

  " <CR> on a "option" line shows help for that option
  elseif match(line, "^[a-z]") >= 0
    let name = substitute(line, '\([^\t]*\).*', '\1', "")
    exe "help '" . name . "'"

  " <CR> on an index line jumps to the group
  elseif match(line, '^ \=[0-9]') >= 0
    exe "norm! /" . line . "\<CR>zt"
  endif
endfun

" function to be called when <Space> is hit in the option-window
fun! <SID>Space()

  let lnum = line(".")
  let line = getline(lnum)

  " <Space> on a "set" line refreshes the option line
  if match(line, "^ \tset ") >= 0

    " For a local option: go to the previous window
    " If this is a help window, go to the window below it
    let thiswin = winnr()
    let local = <SID>Find(lnum)
    if local >= 0
      call <SID>Update(lnum, line, local, thiswin)
    endif

  endif
endfun

" find the window in which the option applies
" returns 0 for global option, 1 for local option, -1 for error
fun! <SID>Find(lnum)
    if getline(a:lnum - 1) =~ "(local to"
      let local = 1
      let thiswin = winnr()
      wincmd p
      if exists("b:current_syntax") && b:current_syntax == "help"
	wincmd j
	if winnr() == thiswin
	  wincmd j
	endif
      endif
    else
      let local = 0
    endif
    if local && (winnr() == thiswin || (exists("b:current_syntax")
	\ && b:current_syntax == "help"))
      echo "Don't know in which window"
      let local = -1
    endif
    return local
endfun

" Update a "set" line in the option window
fun! <SID>Update(lnum, line, local, thiswin)
  " get the new value of the option and update the option window line
  if match(a:line, "=") >= 0
    let name = substitute(a:line, '^ \tset \([^=]*\)=.*', '\1', "")
  else
    let name = substitute(a:line, '^ \tset \(no\)\=\([a-z]*\).*', '\2', "")
  endif
  if name == "pt" && &pt =~ "\x80"
    let val = <SID>PTvalue()
  else
    let val = escape(eval('&' . name), " \t\\\"|")
  endif
  if a:local
    exe a:thiswin . "wincmd w"
  endif
  if match(a:line, "=") >= 0 || (val != "0" && val != "1")
    call setline(a:lnum, " \tset " . name . "=" . val)
  else
    if val
      call setline(a:lnum, " \tset " . name . "\tno" . name)
    else
      call setline(a:lnum, " \tset no" . name . "\t" . name)
    endif
  endif
  set nomodified
endfun

" Reset 'title' and 'icon' to make it work faster.
" Reset 'undolevels' to avoid undo'ing until the buffer is empty.
let s:old_title = &title
let s:old_icon = &icon
let s:old_sc = &sc
let s:old_ru = &ru
let s:old_ul = &ul
set notitle noicon nosc noru ul=-1

" If the current window is a help window, try finding a non-help window.
" Relies on syntax highlighting to be switched on.
let s:thiswin = winnr()
while exists("b:current_syntax") && b:current_syntax == "help"
  wincmd w
  if s:thiswin == winnr()
    break
  endif
endwhile

" Open the window.  $OPTWIN_CMD is set to "tab" for ":tab options".
exe $OPTWIN_CMD . ' new option-window'
setlocal ts=15 tw=0 noro buftype=nofile

" Insert help and a "set" command for each option.
call append(0, '" Each "set" line shows the current value of an option (on the left).')
call append(1, '" Hit <CR> on a "set" line to execute it.')
call append(2, '"            A boolean option will be toggled.')
call append(3, '"            For other options you can edit the value before hitting <CR>.')
call append(4, '" Hit <CR> on a help line to open a help window on this option.')
call append(5, '" Hit <CR> on an index line to jump there.')
call append(6, '" Hit <Space> on a "set" line to refresh it.')

" These functions are called often below.  Keep them fast!

" Init a local binary option
fun! <SID>BinOptionL(name)
  let val = getwinvar(winnr('#'), '&' . a:name)
  call append("$", substitute(substitute(" \tset " . val . a:name . "\t" .
	\!val . a:name, "0", "no", ""), "1", "", ""))
endfun

" Init a global binary option
fun! <SID>BinOptionG(name, val)
  call append("$", substitute(substitute(" \tset " . a:val . a:name . "\t" .
	\!a:val . a:name, "0", "no", ""), "1", "", ""))
endfun

" Init a local string option
fun! <SID>OptionL(name)
  let val = escape(getwinvar(winnr('#'), '&' . a:name), " \t\\\"|")
  call append("$", " \tset " . a:name . "=" . val)
endfun

" Init a global string option
fun! <SID>OptionG(name, val)
  call append("$", " \tset " . a:name . "=" . escape(a:val, " \t\\\"|"))
endfun

let s:idx = 1
let s:lnum = line("$")
call append("$", "")

fun! <SID>Header(text)
  let line = s:idx . " " . a:text
  if s:idx < 10
    let line = " " . line
  endif
  call append("$", "")
  call append("$", line)
  call append("$", "")
  call append(s:lnum, line)
  let s:idx = s:idx + 1
  let s:lnum = s:lnum + 1
endfun

" Get the value of 'pastetoggle'.  It could be a special key.
fun! <SID>PTvalue()
  redir @a
  silent set pt
  redir END
  return substitute(@a, '[^=]*=\(.*\)', '\1', "")
endfun

" Restore the previous value of 'cpoptions' here, it's used below.
let &cpo = s:cpo_save

" List of all options, organized by function.
" The text should be sufficient to know what the option is used for.

call <SID>Header("important")
call append("$", "compatible\tbehave very Vi compatible (not advisable)")
call <SID>BinOptionG("cp", &cp)
call append("$", "cpoptions\tlist of flags to specify Vi compatibility")
call <SID>OptionG("cpo", &cpo)
call append("$", "insertmode\tuse Insert mode as the default mode")
call <SID>BinOptionG("im", &im)
call append("$", "paste\tpaste mode, insert typed text literally")
call <SID>BinOptionG("paste", &paste)
call append("$", "pastetoggle\tkey sequence to toggle paste mode")
if &pt =~ "\x80"
  call append("$", " \tset pt=" . <SID>PTvalue())
else
  call <SID>OptionG("pt", &pt)
endif
call append("$", "runtimepath\tlist of directories used for runtime files and plugins")
call <SID>OptionG("rtp", &rtp)
call append("$", "packpath\tlist of directories used for plugin packages")
call <SID>OptionG("pp", &pp)
call append("$", "helpfile\tname of the main help file")
call <SID>OptionG("hf", &hf)


call <SID>Header("moving around, searching and patterns")
call append("$", "whichwrap\tlist of flags specifying which commands wrap to another line")
call append("$", "\t(local to window)")
call <SID>OptionL("ww")
call append("$", "startofline\tmany jump commands move the cursor to the first non-blank")
call append("$", "\tcharacter of a line")
call <SID>BinOptionG("sol", &sol)
call append("$", "paragraphs\tnroff macro names that separate paragraphs")
call <SID>OptionG("para", &para)
call append("$", "sections\tnroff macro names that separate sections")
call <SID>OptionG("sect", &sect)
call append("$", "path\tlist of directory names used for file searching")
call append("$", "\t(global or local to buffer)")
call <SID>OptionG("pa", &pa)
call append("$", "cdpath\tlist of directory names used for :cd")
call <SID>OptionG("cd", &cd)
if exists("+autochdir")
  call append("$", "autochdir\tchange to directory of file in buffer")
  call <SID>BinOptionG("acd", &acd)
endif
call append("$", "wrapscan\tsearch commands wrap around the end of the buffer")
call <SID>BinOptionG("ws", &ws)
call append("$", "incsearch\tshow match for partly typed search command")
call <SID>BinOptionG("is", &is)
call append("$", "magic\tchange the way backslashes are used in search patterns")
call <SID>BinOptionG("magic", &magic)
call append("$", "regexpengine\tselect the default regexp engine used")
call <SID>OptionG("re", &re)
call append("$", "ignorecase\tignore case when using a search pattern")
call <SID>BinOptionG("ic", &ic)
call append("$", "smartcase\toverride 'ignorecase' when pattern has upper case characters")
call <SID>BinOptionG("scs", &scs)
call append("$", "casemap\twhat method to use for changing case of letters")
call <SID>OptionG("cmp", &cmp)
call append("$", "maxmempattern\tmaximum amount of memory in Kbyte used for pattern matching")
call append("$", " \tset mmp=" . &mmp)
call append("$", "define\tpattern for a macro definition line")
call append("$", "\t(global or local to buffer)")
call <SID>OptionG("def", &def)
if has("find_in_path")
  call append("$", "include\tpattern for an include-file line")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("inc")
  call append("$", "includeexpr\texpression used to transform an include line to a file name")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("inex")
endif


call <SID>Header("tags")
call append("$", "tagbsearch\tuse binary searching in tags files")
call <SID>BinOptionG("tbs", &tbs)
call append("$", "taglength\tnumber of significant characters in a tag name or zero")
call append("$", " \tset tl=" . &tl)
call append("$", "tags\tlist of file names to search for tags")
call append("$", "\t(global or local to buffer)")
call <SID>OptionG("tag", &tag)
call append("$", "tagcase\thow to handle case when searching in tags files:")
call append("$", "\t\"followic\" to follow 'ignorecase', \"ignore\" or \"match\"")
call append("$", "\t(global or local to buffer)")
call <SID>OptionG("tc", &tc)
call append("$", "tagrelative\tfile names in a tags file are relative to the tags file")
call <SID>BinOptionG("tr", &tr)
call append("$", "tagstack\ta :tag command will use the tagstack")
call <SID>BinOptionG("tgst", &tgst)
call append("$", "showfulltag\twhen completing tags in Insert mode show more info")
call <SID>BinOptionG("sft", &sft)
if has("eval")
  call append("$", "tagfunc\ta function to be used to perform tag searches")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("tfu")
endif
if has("cscope")
  call append("$", "cscopeprg\tcommand for executing cscope")
  call <SID>OptionG("csprg", &csprg)
  call append("$", "cscopetag\tuse cscope for tag commands")
  call <SID>BinOptionG("cst", &cst)
  call append("$", "cscopetagorder\t0 or 1; the order in which \":cstag\" performs a search")
  call append("$", " \tset csto=" . &csto)
  call append("$", "cscopeverbose\tgive messages when adding a cscope database")
  call <SID>BinOptionG("csverb", &csverb)
  call append("$", "cscopepathcomp\thow many components of the path to show")
  call append("$", " \tset cspc=" . &cspc)
  call append("$", "cscopequickfix\twhen to open a quickfix window for cscope")
  call <SID>OptionG("csqf", &csqf)
  call append("$", "cscoperelative\tfile names in a cscope file are relative to that file")
  call <SID>BinOptionG("csre", &csre)
endif


call <SID>Header("displaying text")
call append("$", "scroll\tnumber of lines to scroll for CTRL-U and CTRL-D")
call append("$", "\t(local to window)")
call <SID>OptionL("scr")
call append("$", "scrolloff\tnumber of screen lines to show around the cursor")
call append("$", " \tset so=" . &so)
call append("$", "wrap\tlong lines wrap")
call append("$", "\t(local to window)")
call <SID>BinOptionL("wrap")
call append("$", "linebreak\twrap long lines at a character in 'breakat'")
call append("$", "\t(local to window)")
call <SID>BinOptionL("lbr")
call append("$", "breakindent\tpreserve indentation in wrapped text")
call append("$", "\t(local to window)")
call <SID>BinOptionL("bri")
call append("$", "breakindentopt\tadjust breakindent behaviour")
call append("$", "\t(local to window)")
call <SID>OptionL("briopt")
call append("$", "breakat\twhich characters might cause a line break")
call <SID>OptionG("brk", &brk)
call append("$", "showbreak\tstring to put before wrapped screen lines")
call <SID>OptionG("sbr", &sbr)
call append("$", "sidescroll\tminimal number of columns to scroll horizontally")
call append("$", " \tset ss=" . &ss)
call append("$", "sidescrolloff\tminimal number of columns to keep left and right of the cursor")
call append("$", " \tset siso=" . &siso)
call append("$", "display\tinclude \"lastline\" to show the last line even if it doesn't fit")
call append("$", "\tinclude \"uhex\" to show unprintable characters as a hex number")
call <SID>OptionG("dy", &dy)
call append("$", "fillchars\tcharacters to use for the status line, folds and filler lines")
call <SID>OptionG("fcs", &fcs)
call append("$", "cmdheight\tnumber of lines used for the command-line")
call append("$", " \tset ch=" . &ch)
call append("$", "columns\twidth of the display")
call append("$", " \tset co=" . &co)
call append("$", "lines\tnumber of lines in the display")
call append("$", " \tset lines=" . &lines)
call append("$", "window\tnumber of lines to scroll for CTRL-F and CTRL-B")
call append("$", " \tset window=" . &window)
call append("$", "lazyredraw\tdon't redraw while executing macros")
call <SID>BinOptionG("lz", &lz)
if has("reltime")
  call append("$", "redrawtime\ttimeout for 'hlsearch' and :match highlighting in msec")
  call append("$", " \tset rdt=" . &rdt)
endif
call append("$", "writedelay\tdelay in msec for each char written to the display")
call append("$", "\t(for debugging)")
call append("$", " \tset wd=" . &wd)
call append("$", "list\tshow <Tab> as ^I and end-of-line as $")
call append("$", "\t(local to window)")
call <SID>BinOptionL("list")
call append("$", "listchars\tlist of strings used for list mode")
call <SID>OptionG("lcs", &lcs)
call append("$", "number\tshow the line number for each line")
call append("$", "\t(local to window)")
call <SID>BinOptionL("nu")
call append("$", "relativenumber\tshow the relative line number for each line")
call append("$", "\t(local to window)")
call <SID>BinOptionL("rnu")
if has("linebreak")
  call append("$", "numberwidth\tnumber of columns to use for the line number")
  call append("$", "\t(local to window)")
  call <SID>OptionL("nuw")
endif
if has("conceal")
  call append("$", "conceallevel\tcontrols whether concealable text is hidden")
  call append("$", "\t(local to window)")
  call <SID>OptionL("cole")
  call append("$", "concealcursor\tmodes in which text in the cursor line can be concealed")
  call append("$", "\t(local to window)")
  call <SID>OptionL("cocu")
endif


call <SID>Header("syntax, highlighting and spelling")
call append("$", "background\t\"dark\" or \"light\"; the background color brightness")
call <SID>OptionG("bg", &bg)
call append("$", "filetype\ttype of file; triggers the FileType event when set")
call append("$", "\t(local to buffer)")
call <SID>OptionL("ft")
if has("syntax")
  call append("$", "syntax\tname of syntax highlighting used")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("syn")
  call append("$", "synmaxcol\tmaximum column to look for syntax items")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("smc")
endif
call append("$", "highlight\twhich highlighting to use for various occasions")
call <SID>OptionG("hl", &hl)
call append("$", "hlsearch\thighlight all matches for the last used search pattern")
call <SID>BinOptionG("hls", &hls)
if has("termguicolors")
  call append("$", "termguicolors\tuse GUI colors for the terminal")
  call <SID>BinOptionG("tgc", &tgc)
endif
if has("syntax")
  call append("$", "cursorcolumn\thighlight the screen column of the cursor")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("cuc")
  call append("$", "cursorline\thighlight the screen line of the cursor")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("cul")
  call append("$", "colorcolumn\tcolumns to highlight")
  call append("$", "\t(local to window)")
  call <SID>OptionL("cc")
  call append("$", "spell\thighlight spelling mistakes")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("spell")
  call append("$", "spelllang\tlist of accepted languages")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("spl")
  call append("$", "spellfile\tfile that \"zg\" adds good words to")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("spf")
  call append("$", "spellcapcheck\tpattern to locate the end of a sentence")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("spc")
  call append("$", "spellsuggest\tmethods used to suggest corrections")
  call <SID>OptionG("sps", &sps)
  call append("$", "mkspellmem\tamount of memory used by :mkspell before compressing")
  call <SID>OptionG("msm", &msm)
endif


call <SID>Header("multiple windows")
call append("$", "laststatus\t0, 1 or 2; when to use a status line for the last window")
call append("$", " \tset ls=" . &ls)
if has("statusline")
  call append("$", "statusline\talternate format to be used for a status line")
  call <SID>OptionG("stl", &stl)
endif
call append("$", "equalalways\tmake all windows the same size when adding/removing windows")
call <SID>BinOptionG("ea", &ea)
call append("$", "eadirection\tin which direction 'equalalways' works: \"ver\", \"hor\" or \"both\"")
call <SID>OptionG("ead", &ead)
call append("$", "winheight\tminimal number of lines used for the current window")
call append("$", " \tset wh=" . &wh)
call append("$", "winminheight\tminimal number of lines used for any window")
call append("$", " \tset wmh=" . &wmh)
call append("$", "winfixheight\tkeep the height of the window")
call append("$", "\t(local to window)")
call <SID>BinOptionL("wfh")
call append("$", "winfixwidth\tkeep the width of the window")
call append("$", "\t(local to window)")
call <SID>BinOptionL("wfw")
call append("$", "winwidth\tminimal number of columns used for the current window")
call append("$", " \tset wiw=" . &wiw)
call append("$", "winminwidth\tminimal number of columns used for any window")
call append("$", " \tset wmw=" . &wmw)
call append("$", "helpheight\tinitial height of the help window")
call append("$", " \tset hh=" . &hh)
if has("quickfix")
  " call append("$", "previewpopup\tuse a popup window for preview")
  " call append("$", " \tset pvp=" . &pvp)
  call append("$", "previewheight\tdefault height for the preview window")
  call append("$", " \tset pvh=" . &pvh)
  call append("$", "previewwindow\tidentifies the preview window")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("pvw")
endif
call append("$", "hidden\tdon't unload a buffer when no longer shown in a window")
call <SID>BinOptionG("hid", &hid)
call append("$", "switchbuf\t\"useopen\" and/or \"split\"; which window to use when jumping")
call append("$", "\tto a buffer")
call <SID>OptionG("swb", &swb)
call append("$", "splitbelow\ta new window is put below the current one")
call <SID>BinOptionG("sb", &sb)
call append("$", "splitright\ta new window is put right of the current one")
call <SID>BinOptionG("spr", &spr)
call append("$", "scrollbind\tthis window scrolls together with other bound windows")
call append("$", "\t(local to window)")
call <SID>BinOptionL("scb")
call append("$", "scrollopt\t\"ver\", \"hor\" and/or \"jump\"; list of options for 'scrollbind'")
call <SID>OptionG("sbo", &sbo)
call append("$", "cursorbind\tthis window's cursor moves together with other bound windows")
call append("$", "\t(local to window)")
call <SID>BinOptionL("crb")
if has("terminal")
  call append("$", "termsize\tsize of a terminal window")
  call append("$", "\t(local to window)")
  call <SID>OptionL("tms")
  call append("$", "termkey\tkey that precedes Vim commands in a terminal window")
  call append("$", "\t(local to window)")
  call <SID>OptionL("tk")
endif


call <SID>Header("multiple tab pages")
call append("$", "showtabline\t0, 1 or 2; when to use a tab pages line")
call append("$", " \tset stal=" . &stal)
call append("$", "tabpagemax\tmaximum number of tab pages to open for -p and \"tab all\"")
call append("$", " \tset tpm=" . &tpm)
call append("$", "tabline\tcustom tab pages line")
call <SID>OptionG("tal", &tal)
if has("gui")
  call append("$", "guitablabel\tcustom tab page label for the GUI")
  call <SID>OptionG("gtl", &gtl)
  call append("$", "guitabtooltip\tcustom tab page tooltip for the GUI")
  call <SID>OptionG("gtt", &gtt)
endif


call <SID>Header("terminal")
call append("$", "scrolljump\tminimal number of lines to scroll at a time")
call append("$", " \tset sj=" . &sj)
if has("gui") || has("msdos") || has("win32")
  call append("$", "guicursor\tspecifies what the cursor looks like in different modes")
  call <SID>OptionG("gcr", &gcr)
endif
if has("title")
  let &title = s:old_title
  call append("$", "title\tshow info in the window title")
  call <SID>BinOptionG("title", &title)
  set notitle
  call append("$", "titlelen\tpercentage of 'columns' used for the window title")
  call append("$", " \tset titlelen=" . &titlelen)
  call append("$", "titlestring\twhen not empty, string to be used for the window title")
  call <SID>OptionG("titlestring", &titlestring)
  call append("$", "titleold\tstring to restore the title to when exiting Vim")
  call <SID>OptionG("titleold", &titleold)
  let &icon = s:old_icon
  call append("$", "icon\tset the text of the icon for this window")
  call <SID>BinOptionG("icon", &icon)
  set noicon
  call append("$", "iconstring\twhen not empty, text for the icon of this window")
  call <SID>OptionG("iconstring", &iconstring)
endif


call <SID>Header("using the mouse")
call append("$", "mouse\tlist of flags for using the mouse")
call <SID>OptionG("mouse", &mouse)
if has("gui")
  call append("$", "mousefocus\tthe window with the mouse pointer becomes the current one")
  call <SID>BinOptionG("mousef", &mousef)
  call append("$", "mousehide\thide the mouse pointer while typing")
  call <SID>BinOptionG("mh", &mh)
endif
call append("$", "mousemodel\t\"extend\", \"popup\" or \"popup_setpos\"; what the right")
call append("$", "\tmouse button is used for")
call <SID>OptionG("mousem", &mousem)
call append("$", "mousetime\tmaximum time in msec to recognize a double-click")
call append("$", " \tset mouset=" . &mouset)
if has("mouseshape")
  call append("$", "mouseshape\twhat the mouse pointer looks like in different modes")
  call <SID>OptionG("mouses", &mouses)
endif


if has("gui")
  call <SID>Header("GUI")
  call append("$", "guifont\tlist of font names to be used in the GUI")
  call <SID>OptionG("gfn", &gfn)
  if has("xfontset")
    call append("$", "guifontset\tpair of fonts to be used, for multibyte editing")
    call <SID>OptionG("gfs", &gfs)
  endif
  call append("$", "guifontwide\tlist of font names to be used for double-wide characters")
  call <SID>OptionG("gfw", &gfw)
  call append("$", "guioptions\tlist of flags that specify how the GUI works")
  call <SID>OptionG("go", &go)
  if has("gui_gtk")
    call append("$", "toolbar\t\"icons\", \"text\" and/or \"tooltips\"; how to show the toolbar")
    call <SID>OptionG("tb", &tb)
    if has("gui_gtk2")
      call append("$", "toolbariconsize\tsize of toolbar icons")
      call <SID>OptionG("tbis", &tbis)
    endif
  endif
  if has("browse")
    call append("$", "browsedir\t\"last\", \"buffer\" or \"current\": which directory used for the file browser")
    call <SID>OptionG("bsdir", &bsdir)
  endif
  if has("multi_lang")
    call append("$", "langmenu\tlanguage to be used for the menus")
    call <SID>OptionG("langmenu", &lm)
  endif
  call append("$", "menuitems\tmaximum number of items in one menu")
  call append("$", " \tset mis=" . &mis)
  if has("winaltkeys")
    call append("$", "winaltkeys\t\"no\", \"yes\" or \"menu\"; how to use the ALT key")
    call <SID>OptionG("wak", &wak)
  endif
  call append("$", "linespace\tnumber of pixel lines to use between characters")
  call append("$", " \tset lsp=" . &lsp)
  if has("balloon_eval") || has("balloon_eval_term")
    call append("$", "balloondelay\tdelay in milliseconds before a balloon may pop up")
    call append("$", " \tset bdlay=" . &bdlay)
    if has("balloon_eval")
      call append("$", "ballooneval\tuse balloon evaluation in the GUI")
      call <SID>BinOptionG("beval", &beval)
    endif
    if has("balloon_eval_term")
      call append("$", "balloonevalterm\tuse balloon evaluation in the terminal")
      call <SID>BinOptionG("bevalterm", &beval)
    endif
    if has("eval")
      call append("$", "balloonexpr\texpression to show in balloon eval")
      call append("$", " \tset bexpr=" . &bexpr)
    endif
  endif
endif

if has("printer")
  call <SID>Header("printing")
  call append("$", "printoptions\tlist of items that control the format of :hardcopy output")
  call <SID>OptionG("popt", &popt)
  call append("$", "printdevice\tname of the printer to be used for :hardcopy")
  call <SID>OptionG("pdev", &pdev)
  if has("postscript")
    call append("$", "printexpr\texpression used to print the PostScript file for :hardcopy")
    call <SID>OptionG("pexpr", &pexpr)
  endif
  call append("$", "printfont\tname of the font to be used for :hardcopy")
  call <SID>OptionG("pfn", &pfn)
  call append("$", "printheader\tformat of the header used for :hardcopy")
  call <SID>OptionG("pheader", &pheader)
  if has("postscript")
    call append("$", "printencoding\tencoding used to print the PostScript file for :hardcopy")
    call <SID>OptionG("penc", &penc)
  endif
  if has("multi_byte")
    call append("$", "printmbcharset\tthe CJK character set to be used for CJK output from :hardcopy")
    call <SID>OptionG("pmbcs", &pmbcs)
    call append("$", "printmbfont\tlist of font names to be used for CJK output from :hardcopy")
    call <SID>OptionG("pmbfn", &pmbfn)
  endif
endif

call <SID>Header("messages and info")
call append("$", "terse\tadd 's' flag in 'shortmess' (don't show search message)")
call <SID>BinOptionG("terse", &terse)
call append("$", "shortmess\tlist of flags to make messages shorter")
call <SID>OptionG("shm", &shm)
call append("$", "showcmd\tshow (partial) command keys in the status line")
let &sc = s:old_sc
call <SID>BinOptionG("sc", &sc)
set nosc
call append("$", "showmode\tdisplay the current mode in the status line")
call <SID>BinOptionG("smd", &smd)
call append("$", "ruler\tshow cursor position below each window")
let &ru = s:old_ru
call <SID>BinOptionG("ru", &ru)
set noru
if has("statusline")
  call append("$", "rulerformat\talternate format to be used for the ruler")
  call <SID>OptionG("ruf", &ruf)
endif
call append("$", "report\tthreshold for reporting number of changed lines")
call append("$", " \tset report=" . &report)
call append("$", "verbose\tthe higher the more messages are given")
call append("$", " \tset vbs=" . &vbs)
call append("$", "verbosefile\tfile to write messages in")
call <SID>OptionG("vfile", &vfile)
call append("$", "more\tpause listings when the screen is full")
call <SID>BinOptionG("more", &more)
if has("dialog_con") || has("dialog_gui")
  call append("$", "confirm\tstart a dialog when a command fails")
  call <SID>BinOptionG("cf", &cf)
endif
call append("$", "errorbells\tring the bell for error messages")
call <SID>BinOptionG("eb", &eb)
call append("$", "visualbell\tuse a visual bell instead of beeping")
call <SID>BinOptionG("vb", &vb)
call append("$", "belloff\tdo not ring the bell for these reasons")
call <SID>OptionG("belloff", &belloff)
if has("multi_lang")
  call append("$", "helplang\tlist of preferred languages for finding help")
  call <SID>OptionG("hlg", &hlg)
endif


call <SID>Header("selecting text")
call append("$", "selection\t\"old\", \"inclusive\" or \"exclusive\"; how selecting text behaves")
call <SID>OptionG("sel", &sel)
call append("$", "selectmode\t\"mouse\", \"key\" and/or \"cmd\"; when to start Select mode")
call append("$", "\tinstead of Visual mode")
call <SID>OptionG("slm", &slm)
if has("clipboard")
  call append("$", "clipboard\t\"unnamed\" to use the * register like unnamed register")
  call append("$", "\t\"autoselect\" to always put selected text on the clipboard")
  call <SID>OptionG("cb", &cb)
endif
call append("$", "keymodel\t\"startsel\" and/or \"stopsel\"; what special keys can do")
call <SID>OptionG("km", &km)


call <SID>Header("editing text")
call append("$", "undolevels\tmaximum number of changes that can be undone")
call append("$", "\t(global or local to buffer)")
call append("$", " \tset ul=" . s:old_ul)
call append("$", "undofile\tautomatically save and restore undo history")
call <SID>BinOptionG("udf", &udf)
call append("$", "undodir\tlist of directories for undo files")
call <SID>OptionG("udir", &udir)
call append("$", "undoreload\tmaximum number lines to save for undo on a buffer reload")
call append("$", " \tset ur=" . &ur)
call append("$", "modified\tchanges have been made and not written to a file")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("mod")
call append("$", "readonly\tbuffer is not to be written")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("ro")
call append("$", "modifiable\tchanges to the text are not possible")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("ma")
call append("$", "textwidth\tline length above which to break a line")
call append("$", "\t(local to buffer)")
call <SID>OptionL("tw")
call append("$", "wrapmargin\tmargin from the right in which to break a line")
call append("$", "\t(local to buffer)")
call <SID>OptionL("wm")
call append("$", "backspace\tspecifies what <BS>, CTRL-W, etc. can do in Insert mode")
call append("$", " \tset bs=" . &bs)
call append("$", "comments\tdefinition of what comment lines look like")
call append("$", "\t(local to buffer)")
call <SID>OptionL("com")
call append("$", "formatoptions\tlist of flags that tell how automatic formatting works")
call append("$", "\t(local to buffer)")
call <SID>OptionL("fo")
call append("$", "formatlistpat\tpattern to recognize a numbered list")
call append("$", "\t(local to buffer)")
call <SID>OptionL("flp")
if has("eval")
  call append("$", "formatexpr\texpression used for \"gq\" to format lines")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("fex")
endif
if has("insert_expand")
  call append("$", "complete\tspecifies how Insert mode completion works for CTRL-N and CTRL-P")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("cpt")
  call append("$", "completeopt\twhether to use a popup menu for Insert mode completion")
  call <SID>OptionG("cot", &cot)
  call append("$", "pumheight\tmaximum height of the popup menu")
  call <SID>OptionG("ph", &ph)
  if exists("&pw")
    call append("$", "pumwidth\tminimum width of the popup menu")
    call <SID>OptionG("pw", &pw)
  endif
  call append("$", "completefunc\tuser defined function for Insert mode completion")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("cfu")
  call append("$", "omnifunc\tfunction for filetype-specific Insert mode completion")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("ofu")
  call append("$", "dictionary\tlist of dictionary files for keyword completion")
  call append("$", "\t(global or local to buffer)")
  call <SID>OptionG("dict", &dict)
  call append("$", "thesaurus\tlist of thesaurus files for keyword completion")
  call append("$", "\t(global or local to buffer)")
  call <SID>OptionG("tsr", &tsr)
endif
call append("$", "infercase\tadjust case of a keyword completion match")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("inf")
if has("digraphs")
  call append("$", "digraph\tenable entering digraphs with c1 <BS> c2")
  call <SID>BinOptionG("dg", &dg)
endif
call append("$", "tildeop\tthe \"~\" command behaves like an operator")
call <SID>BinOptionG("top", &top)
call append("$", "operatorfunc\tfunction called for the\"g@\"  operator")
call <SID>OptionG("opfunc", &opfunc)
call append("$", "showmatch\twhen inserting a bracket, briefly jump to its match")
call <SID>BinOptionG("sm", &sm)
call append("$", "matchtime\ttenth of a second to show a match for 'showmatch'")
call append("$", " \tset mat=" . &mat)
call append("$", "matchpairs\tlist of pairs that match for the \"%\" command")
call append("$", "\t(local to buffer)")
call <SID>OptionL("mps")
call append("$", "joinspaces\tuse two spaces after '.' when joining a line")
call <SID>BinOptionG("js", &js)
call append("$", "nrformats\t\"alpha\", \"octal\" and/or \"hex\"; number formats recognized for")
call append("$", "\tCTRL-A and CTRL-X commands")
call append("$", "\t(local to buffer)")
call <SID>OptionL("nf")


call <SID>Header("tabs and indenting")
call append("$", "tabstop\tnumber of spaces a <Tab> in the text stands for")
call append("$", "\t(local to buffer)")
call <SID>OptionL("ts")
call append("$", "shiftwidth\tnumber of spaces used for each step of (auto)indent")
call append("$", "\t(local to buffer)")
call <SID>OptionL("sw")
call append("$", "smarttab\ta <Tab> in an indent inserts 'shiftwidth' spaces")
call <SID>BinOptionG("sta", &sta)
call append("$", "softtabstop\tif non-zero, number of spaces to insert for a <Tab>")
call append("$", "\t(local to buffer)")
call <SID>OptionL("sts")
call append("$", "shiftround\tround to 'shiftwidth' for \"<<\" and \">>\"")
call <SID>BinOptionG("sr", &sr)
call append("$", "expandtab\texpand <Tab> to spaces in Insert mode")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("et")
call append("$", "autoindent\tautomatically set the indent of a new line")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("ai")
if has("smartindent")
  call append("$", "smartindent\tdo clever autoindenting")
  call append("$", "\t(local to buffer)")
  call <SID>BinOptionL("si")
endif
if has("cindent")
  call append("$", "cindent\tenable specific indenting for C code")
  call append("$", "\t(local to buffer)")
  call <SID>BinOptionL("cin")
  call append("$", "cinoptions\toptions for C-indenting")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("cino")
  call append("$", "cinkeys\tkeys that trigger C-indenting in Insert mode")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("cink")
  call append("$", "cinwords\tlist of words that cause more C-indent")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("cinw")
  call append("$", "indentexpr\texpression used to obtain the indent of a line")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("inde")
  call append("$", "indentkeys\tkeys that trigger indenting with 'indentexpr' in Insert mode")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("indk")
endif
call append("$", "copyindent\tcopy whitespace for indenting from previous line")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("ci")
call append("$", "preserveindent\tpreserve kind of whitespace when changing indent")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("pi")
if has("lispindent")
  call append("$", "lisp\tenable lisp mode")
  call append("$", "\t(local to buffer)")
  call <SID>BinOptionL("lisp")
  call append("$", "lispwords\twords that change how lisp indenting works")
  call <SID>OptionL("lw")
endif


if has("folding")
  call <SID>Header("folding")
  call append("$", "foldenable\tset to display all folds open")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("fen")
  call append("$", "foldlevel\tfolds with a level higher than this number will be closed")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fdl")
  call append("$", "foldlevelstart\tvalue for 'foldlevel' when starting to edit a file")
  call append("$", " \tset fdls=" . &fdls)
  call append("$", "foldcolumn\twidth of the column used to indicate folds")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fdc")
  call append("$", "foldtext\texpression used to display the text of a closed fold")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fdt")
  call append("$", "foldclose\tset to \"all\" to close a fold when the cursor leaves it")
  call <SID>OptionG("fcl", &fcl)
  call append("$", "foldopen\tspecifies for which commands a fold will be opened")
  call <SID>OptionG("fdo", &fdo)
  call append("$", "foldminlines\tminimum number of screen lines for a fold to be closed")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fml")
  call append("$", "commentstring\ttemplate for comments; used to put the marker in")
  call <SID>OptionL("cms")
  call append("$", "foldmethod\tfolding type: \"manual\", \"indent\", \"expr\", \"marker\" or \"syntax\"")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fdm")
  call append("$", "foldexpr\texpression used when 'foldmethod' is \"expr\"")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fde")
  call append("$", "foldignore\tused to ignore lines when 'foldmethod' is \"indent\"")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fdi")
  call append("$", "foldmarker\tmarkers used when 'foldmethod' is \"marker\"")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fmr")
  call append("$", "foldnestmax\tmaximum fold depth for when 'foldmethod' is \"indent\" or \"syntax\"")
  call append("$", "\t(local to window)")
  call <SID>OptionL("fdn")
endif


if has("diff")
  call <SID>Header("diff mode")
  call append("$", "diff\tuse diff mode for the current window")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("diff")
  call append("$", "diffopt\toptions for using diff mode")
  call <SID>OptionG("dip", &dip)
  call append("$", "diffexpr\texpression used to obtain a diff file")
  call <SID>OptionG("dex", &dex)
  call append("$", "patchexpr\texpression used to patch a file")
  call <SID>OptionG("pex", &pex)
endif


call <SID>Header("mapping")
call append("$", "maxmapdepth\tmaximum depth of mapping")
call append("$", " \tset mmd=" . &mmd)
call append("$", "remap\trecognize mappings in mapped keys")
call <SID>BinOptionG("remap", &remap)
call append("$", "timeout\tallow timing out halfway into a mapping")
call <SID>BinOptionG("to", &to)
call append("$", "ttimeout\tallow timing out halfway into a key code")
call <SID>BinOptionG("ttimeout", &ttimeout)
call append("$", "timeoutlen\ttime in msec for 'timeout'")
call append("$", " \tset tm=" . &tm)
call append("$", "ttimeoutlen\ttime in msec for 'ttimeout'")
call append("$", " \tset ttm=" . &ttm)


call <SID>Header("reading and writing files")
call append("$", "modeline\tenable using settings from modelines when reading a file")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("ml")
call append("$", "modelineexpr\tallow setting expression options from a modeline")
call <SID>BinOptionG("mle", &mle)
call append("$", "modelines\tnumber of lines to check for modelines")
call append("$", " \tset mls=" . &mls)
call append("$", "binary\tbinary file editing")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("bin")
call append("$", "endofline\tlast line in the file has an end-of-line")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("eol")
call append("$", "fixendofline\tfixes missing end-of-line at end of text file")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("fixeol")
if has("multi_byte")
  call append("$", "bomb\tprepend a Byte Order Mark to the file")
  call append("$", "\t(local to buffer)")
  call <SID>BinOptionL("bomb")
endif
call append("$", "fileformat\tend-of-line format: \"dos\", \"unix\" or \"mac\"")
call append("$", "\t(local to buffer)")
call <SID>OptionL("ff")
call append("$", "fileformats\tlist of file formats to look for when editing a file")
call <SID>OptionG("ffs", &ffs)
call append("$", "\t(local to buffer)")
call append("$", "write\twriting files is allowed")
call <SID>BinOptionG("write", &write)
call append("$", "writebackup\twrite a backup file before overwriting a file")
call <SID>BinOptionG("wb", &wb)
call append("$", "backup\tkeep a backup after overwriting a file")
call <SID>BinOptionG("bk", &bk)
call append("$", "backupskip\tpatterns that specify for which files a backup is not made")
call append("$", " \tset bsk=" . &bsk)
call append("$", "backupcopy\twhether to make the backup as a copy or rename the existing file")
call append("$", "\t(global or local to buffer)")
call append("$", " \tset bkc=" . &bkc)
call append("$", "backupdir\tlist of directories to put backup files in")
call <SID>OptionG("bdir", &bdir)
call append("$", "backupext\tfile name extension for the backup file")
call <SID>OptionG("bex", &bex)
call append("$", "autowrite\tautomatically write a file when leaving a modified buffer")
call <SID>BinOptionG("aw", &aw)
call append("$", "autowriteall\tas 'autowrite', but works with more commands")
call <SID>BinOptionG("awa", &awa)
call append("$", "writeany\talways write without asking for confirmation")
call <SID>BinOptionG("wa", &wa)
call append("$", "autoread\tautomatically read a file when it was modified outside of Vim")
call append("$", "\t(global or local to buffer)")
call <SID>BinOptionG("ar", &ar)
call append("$", "patchmode\tkeep oldest version of a file; specifies file name extension")
call <SID>OptionG("pm", &pm)
call append("$", "fsync\tforcibly sync the file to disk after writing it")
call <SID>BinOptionG("fs", &fs)


call <SID>Header("the swap file")
call append("$", "directory\tlist of directories for the swap file")
call <SID>OptionG("dir", &dir)
call append("$", "swapfile\tuse a swap file for this buffer")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("swf")
call append("$", "updatecount\tnumber of characters typed to cause a swap file update")
call append("$", " \tset uc=" . &uc)
call append("$", "updatetime\ttime in msec after which the swap file will be updated")
call append("$", " \tset ut=" . &ut)


call <SID>Header("command line editing")
call append("$", "history\thow many command lines are remembered ")
call append("$", " \tset hi=" . &hi)
call append("$", "wildchar\tkey that triggers command-line expansion")
call append("$", " \tset wc=" . &wc)
call append("$", "wildcharm\tlike 'wildchar' but can also be used in a mapping")
call append("$", " \tset wcm=" . &wcm)
call append("$", "wildmode\tspecifies how command line completion works")
call <SID>OptionG("wim", &wim)
if has("wildoptions")
  call append("$", "wildoptions\tempty or \"tagfile\" to list file name of matching tags")
  call <SID>OptionG("wop", &wop)
endif
call append("$", "suffixes\tlist of file name extensions that have a lower priority")
call <SID>OptionG("su", &su)
if has("file_in_path")
  call append("$", "suffixesadd\tlist of file name extensions added when searching for a file")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("sua")
endif
if has("wildignore")
  call append("$", "wildignore\tlist of patterns to ignore files for file name completion")
  call <SID>OptionG("wig", &wig)
endif
call append("$", "fileignorecase\tignore case when using file names")
call <SID>BinOptionG("fic", &fic)
call append("$", "wildignorecase\tignore case when completing file names")
call <SID>BinOptionG("wic", &wic)
if has("wildmenu")
  call append("$", "wildmenu\tcommand-line completion shows a list of matches")
  call <SID>BinOptionG("wmnu", &wmnu)
endif
call append("$", "cedit\tkey used to open the command-line window")
call <SID>OptionG("cedit", &cedit)
call append("$", "cmdwinheight\theight of the command-line window")
call <SID>OptionG("cwh", &cwh)


call <SID>Header("executing external commands")
call append("$", "shell\tname of the shell program used for external commands")
call <SID>OptionG("sh", &sh)
call append("$", "shellquote\tcharacter(s) to enclose a shell command in")
call <SID>OptionG("shq", &shq)
call append("$", "shellxquote\tlike 'shellquote' but include the redirection")
call <SID>OptionG("sxq", &sxq)
call append("$", "shellxescape\tcharacters to escape when 'shellxquote' is (")
call <SID>OptionG("sxe", &sxe)
call append("$", "shellcmdflag\targument for 'shell' to execute a command")
call <SID>OptionG("shcf", &shcf)
call append("$", "shellredir\tused to redirect command output to a file")
call <SID>OptionG("srr", &srr)
call append("$", "shelltemp\tuse a temp file for shell commands instead of using a pipe")
call <SID>BinOptionG("stmp", &stmp)
call append("$", "equalprg\tprogram used for \"=\" command")
call append("$", "\t(global or local to buffer)")
call <SID>OptionG("ep", &ep)
call append("$", "formatprg\tprogram used to format lines with \"gq\" command")
call <SID>OptionG("fp", &fp)
call append("$", "keywordprg\tprogram used for the \"K\" command")
call <SID>OptionG("kp", &kp)
call append("$", "warn\twarn when using a shell command and a buffer has changes")
call <SID>BinOptionG("warn", &warn)


if has("quickfix")
  call <SID>Header("running make and jumping to errors")
  call append("$", "errorfile\tname of the file that contains error messages")
  call <SID>OptionG("ef", &ef)
  call append("$", "errorformat\tlist of formats for error messages")
  call append("$", "\t(global or local to buffer)")
  call <SID>OptionG("efm", &efm)
  call append("$", "makeprg\tprogram used for the \":make\" command")
  call append("$", "\t(global or local to buffer)")
  call <SID>OptionG("mp", &mp)
  call append("$", "shellpipe\tstring used to put the output of \":make\" in the error file")
  call <SID>OptionG("sp", &sp)
  call append("$", "makeef\tname of the errorfile for the 'makeprg' command")
  call <SID>OptionG("mef", &mef)
  call append("$", "grepprg\tprogram used for the \":grep\" command")
  call append("$", "\t(global or local to buffer)")
  call <SID>OptionG("gp", &gp)
  call append("$", "grepformat\tlist of formats for output of 'grepprg'")
  call <SID>OptionG("gfm", &gfm)
  call append("$", "makeencoding\tencoding of the \":make\" and \":grep\" output")
  call append("$", "\t(global or local to buffer)")
  call <SID>OptionG("menc", &menc)
endif


if has("msdos") || has("win16") || has("win32")
  call <SID>Header("system specific")
  if has("msdos") || has("win16") || has("win32")
    call append("$", "shellslash\tuse forward slashes in file names; for Unix-like shells")
    call <SID>BinOptionG("ssl", &ssl)
  endif
endif


call <SID>Header("language specific")
call append("$", "isfname\tspecifies the characters in a file name")
call <SID>OptionG("isf", &isf)
call append("$", "isident\tspecifies the characters in an identifier")
call <SID>OptionG("isi", &isi)
call append("$", "iskeyword\tspecifies the characters in a keyword")
call append("$", "\t(local to buffer)")
call <SID>OptionL("isk")
call append("$", "isprint\tspecifies printable characters")
call <SID>OptionG("isp", &isp)
if has("textobjects")
  call append("$", "quoteescape\tspecifies escape characters in a string")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("qe")
endif
if has("rightleft")
  call append("$", "rightleft\tdisplay the buffer right-to-left")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("rl")
  call append("$", "rightleftcmd\twhen to edit the command-line right-to-left")
  call append("$", "\t(local to window)")
  call <SID>OptionL("rlc")
  call append("$", "revins\tinsert characters backwards")
  call <SID>BinOptionG("ri", &ri)
  call append("$", "allowrevins\tallow CTRL-_ in Insert and Command-line mode to toggle 'revins'")
  call <SID>BinOptionG("ari", &ari)
  call append("$", "aleph\tthe ASCII code for the first letter of the Hebrew alphabet")
  call append("$", " \tset al=" . &al)
  call append("$", "hkmap\tuse Hebrew keyboard mapping")
  call <SID>BinOptionG("hk", &hk)
  call append("$", "hkmapp\tuse phonetic Hebrew keyboard mapping")
  call <SID>BinOptionG("hkp", &hkp)
endif
if has("arabic")
  call append("$", "arabic\tprepare for editing Arabic text")
  call append("$", "\t(local to window)")
  call <SID>BinOptionL("arab")
  call append("$", "arabicshape\tperform shaping of Arabic characters")
  call <SID>BinOptionG("arshape", &arshape)
  call append("$", "termbidi\tterminal will perform bidi handling")
  call <SID>BinOptionG("tbidi", &tbidi)
endif
if has("keymap")
  call append("$", "keymap\tname of a keyboard mapping")
  call <SID>OptionL("kmp")
endif
if has("langmap")
  call append("$", "langmap\tlist of characters that are translated in Normal mode")
  call <SID>OptionG("lmap", &lmap)
  call append("$", "langremap\tapply 'langmap' to mapped characters")
  call <SID>BinOptionG("lrm", &lrm)
endif
if has("xim")
  call append("$", "imdisable\twhen set never use IM; overrules following IM options")
  call <SID>BinOptionG("imd", &imd)
endif
call append("$", "iminsert\tin Insert mode: 1: use :lmap; 2: use IM; 0: neither")
call append("$", "\t(local to window)")
call <SID>OptionL("imi")
call append("$", "imsearch\tentering a search pattern: 1: use :lmap; 2: use IM; 0: neither")
call append("$", "\t(local to window)")
call <SID>OptionL("ims")
if has("xim")
  call append("$", "imcmdline\twhen set always use IM when starting to edit a command line")
  call <SID>BinOptionG("imc", &imc)
  call append("$", "imstatusfunc\tfunction to obtain IME status")
  call <SID>OptionG("imsf", &imsf)
  call append("$", "imactivatefunc\tfunction to enable/disable IME")
  call <SID>OptionG("imaf", &imaf)
endif


if has("multi_byte")
  call <SID>Header("multi-byte characters")
  call append("$", "encoding\tcharacter encoding used in Vim: \"latin1\", \"utf-8\"")
  call append("$", "\t\"euc-jp\", \"big5\", etc.")
  call <SID>OptionG("enc", &enc)
  call append("$", "fileencoding\tcharacter encoding for the current file")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("fenc")
  call append("$", "fileencodings\tautomatically detected character encodings")
  call <SID>OptionG("fencs", &fencs)
  call append("$", "charconvert\texpression used for character encoding conversion")
  call <SID>OptionG("ccv", &ccv)
  call append("$", "delcombine\tdelete combining (composing) characters on their own")
  call <SID>BinOptionG("deco", &deco)
  call append("$", "maxcombine\tmaximum number of combining (composing) characters displayed")
  call <SID>OptionG("mco", &mco)
  if has("xim") && has("gui_gtk")
    call append("$", "imactivatekey\tkey that activates the X input method")
    call <SID>OptionG("imak", &imak)
  endif
  call append("$", "ambiwidth\twidth of ambiguous width characters")
  call <SID>OptionG("ambw", &ambw)
  call append("$", "emoji\temoji characters are full width")
  call <SID>BinOptionG("emo", &emo)
endif


call <SID>Header("various")
call append("$", "virtualedit\twhen to use virtual editing: \"block\", \"insert\" and/or \"all\"")
call <SID>OptionG("ve", &ve)
call append("$", "eventignore\tlist of autocommand events which are to be ignored")
call <SID>OptionG("ei", &ei)
call append("$", "loadplugins\tload plugin scripts when starting up")
call <SID>BinOptionG("lpl", &lpl)
call append("$", "exrc\tenable reading .vimrc/.exrc/.gvimrc in the current directory")
call <SID>BinOptionG("ex", &ex)
call append("$", "secure\tsafer working with script files in the current directory")
call <SID>BinOptionG("secure", &secure)
call append("$", "gdefault\tuse the 'g' flag for \":substitute\"")
call <SID>BinOptionG("gd", &gd)
if exists("+opendevice")
  call append("$", "opendevice\tallow reading/writing devices")
  call <SID>BinOptionG("odev", &odev)
endif
if exists("+maxfuncdepth")
  call append("$", "maxfuncdepth\tmaximum depth of function calls")
  call append("$", " \tset mfd=" . &mfd)
endif
if has("mksession")
  call append("$", "sessionoptions\tlist of words that specifies what to put in a session file")
  call <SID>OptionG("ssop", &ssop)
  call append("$", "viewoptions\tlist of words that specifies what to save for :mkview")
  call <SID>OptionG("vop", &vop)
  call append("$", "viewdir\tdirectory where to store files with :mkview")
  call <SID>OptionG("vdir", &vdir)
endif
if has("shada")
  call append("$", "viminfo\tlist that specifies what to write in the ShaDa file")
  call <SID>OptionG("vi", &vi)
endif
if has("quickfix")
  call append("$", "bufhidden\twhat happens with a buffer when it's no longer in a window")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("bh")
  call append("$", "buftype\t\"\", \"nofile\", \"nowrite\" or \"quickfix\": type of buffer")
  call append("$", "\t(local to buffer)")
  call <SID>OptionL("bt")
endif
call append("$", "buflisted\twhether the buffer shows up in the buffer list")
call append("$", "\t(local to buffer)")
call <SID>BinOptionL("bl")
call append("$", "debug\tset to \"msg\" to see all error messages")
call append("$", " \tset debug=" . &debug)
call append("$", "signcolumn\twhether to show the signcolumn")
call append("$", "\t(local to window)")
call <SID>OptionL("scl")

set cpo&vim

" go to first line
1

" reset 'modified', so that ":q" can be used to close the window
setlocal nomodified

if has("syntax")
  " Use Vim highlighting, with some additional stuff
  setlocal ft=vim
  syn match optwinHeader "^ \=[0-9].*"
  syn match optwinName "^[a-z]*\t" nextgroup=optwinComment
  syn match optwinComment ".*" contained
  syn match optwinComment "^\t.*"
  if !exists("did_optwin_syntax_inits")
    let did_optwin_syntax_inits = 1
    hi link optwinHeader Title
    hi link optwinName Identifier
    hi link optwinComment Comment
  endif
endif
if exists("&mzschemedll")
  call append("$", "mzschemedll\tname of the Tcl dynamic library")
  call <SID>OptionG("mzschemedll", &mzschemedll)
  call append("$", "mzschemegcdll\tname of the Tcl GC dynamic library")
  call <SID>OptionG("mzschemegcdll", &mzschemegcdll)
endif
if has('pythonx')
  call append("$", "pyxversion\twhether to use Python 2 or 3")
  call append("$", " \tset pyx=" . &wd)
endif

" Install autocommands to enable mappings in option-window
noremap <silent> <buffer> <CR> <C-\><C-N>:call <SID>CR()<CR>
inoremap <silent> <buffer> <CR> <Esc>:call <SID>CR()<CR>
noremap <silent> <buffer> <Space> :call <SID>Space()<CR>

" Make the buffer be deleted when the window is closed.
setlocal buftype=nofile bufhidden=delete noswapfile

augroup optwin
  au! BufUnload,BufHidden option-window nested
	\ call <SID>unload() | delfun <SID>unload
augroup END

fun! <SID>unload()
  delfun <SID>CR
  delfun <SID>Space
  delfun <SID>Find
  delfun <SID>Update
  delfun <SID>OptionL
  delfun <SID>OptionG
  delfun <SID>BinOptionL
  delfun <SID>BinOptionG
  delfun <SID>Header
  au! optwin
endfun

" Restore the previous value of 'title' and 'icon'.
let &title = s:old_title
let &icon = s:old_icon
let &ru = s:old_ru
let &sc = s:old_sc
let &cpo = s:cpo_save
let &ul = s:old_ul
unlet s:old_title s:old_icon s:old_ru s:old_sc s:cpo_save s:idx s:lnum s:old_ul

" vim: ts=8 sw=2 sts=2
