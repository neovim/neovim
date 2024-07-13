" These commands create the option window.
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Jul 12
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

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
func <SID>CR()

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
endfunc

" function to be called when <Space> is hit in the option-window
func <SID>Space()

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
endfunc

let s:local_to_window = gettext('(local to window)')
let s:local_to_buffer = gettext('(local to buffer)')
let s:global_or_local = gettext('(global or local to buffer)')

" find the window in which the option applies
" returns 0 for global option, 1 for local option, -1 for error
func <SID>Find(lnum)
    let line = getline(a:lnum - 1)
    if line =~ s:local_to_window || line =~ s:local_to_buffer
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
endfunc

" Update a "set" line in the option window
func <SID>Update(lnum, line, local, thiswin)
  " get the new value of the option and update the option window line
  if match(a:line, "=") >= 0
    let name = substitute(a:line, '^ \tset \([^=]*\)=.*', '\1', "")
  else
    let name = substitute(a:line, '^ \tset \(no\)\=\([a-z]*\).*', '\2', "")
  endif
  let val = escape(eval('&' . name), " \t\\\"|")
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
endfunc

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
call append(0, gettext('" Each "set" line shows the current value of an option (on the left).'))
call append(1, gettext('" Hit <Enter> on a "set" line to execute it.'))
call append(2, gettext('"            A boolean option will be toggled.'))
call append(3, gettext('"            For other options you can edit the value before hitting <Enter>.'))
call append(4, gettext('" Hit <Enter> on a help line to open a help window on this option.'))
call append(5, gettext('" Hit <Enter> on an index line to jump there.'))
call append(6, gettext('" Hit <Space> on a "set" line to refresh it.'))

" These functions are called often below.  Keep them fast!

" Add an option name and explanation.  The text can contain "\n" characters
" where a line break is to be inserted.
func <SID>AddOption(name, text)
  let lines = split(a:text, "\n")
  call append("$", a:name .. "\t" .. lines[0])
  for line in lines[1:]
    call append("$", "\t" .. line)
  endfor
endfunc

" Init a local binary option
func <SID>BinOptionL(name)
  let val = getwinvar(winnr('#'), '&' . a:name)
  call append("$", substitute(substitute(" \tset " . val . a:name . "\t" .
	\!val . a:name, "0", "no", ""), "1", "", ""))
endfunc

" Init a global binary option
func <SID>BinOptionG(name, val)
  call append("$", substitute(substitute(" \tset " . a:val . a:name . "\t" .
	\!a:val . a:name, "0", "no", ""), "1", "", ""))
endfunc

" Init a local string option
func <SID>OptionL(name)
  let val = escape(getwinvar(winnr('#'), '&' . a:name), " \t\\\"|")
  call append("$", " \tset " . a:name . "=" . val)
endfunc

" Init a global string option
func <SID>OptionG(name, val)
  call append("$", " \tset " . a:name . "=" . escape(a:val, " \t\\\"|"))
endfunc

let s:idx = 1
let s:lnum = line("$")
call append("$", "")

func <SID>Header(text)
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
endfunc

" Restore the previous value of 'cpoptions' here, it's used below.
let &cpo = s:cpo_save

" List of all options, organized by function.
" The text should be sufficient to know what the option is used for.

call <SID>Header(gettext("important"))
call <SID>AddOption("compatible", gettext("behave very Vi compatible (not advisable)"))
call <SID>BinOptionG("cp", &cp)
call <SID>AddOption("cpoptions", gettext("list of flags to specify Vi compatibility"))
call <SID>OptionG("cpo", &cpo)
call <SID>AddOption("paste", gettext("paste mode, insert typed text literally"))
call <SID>BinOptionG("paste", &paste)
call <SID>AddOption("runtimepath", gettext("list of directories used for runtime files and plugins"))
call <SID>OptionG("rtp", &rtp)
call <SID>AddOption("packpath", gettext("list of directories used for plugin packages"))
call <SID>OptionG("pp", &pp)
call <SID>AddOption("helpfile", gettext("name of the main help file"))
call <SID>OptionG("hf", &hf)


call <SID>Header(gettext("moving around, searching and patterns"))
call <SID>AddOption("whichwrap", gettext("list of flags specifying which commands wrap to another line"))
call <SID>OptionG("ww", &ww)
call <SID>AddOption("startofline", gettext("many jump commands move the cursor to the first non-blank\ncharacter of a line"))
call <SID>BinOptionG("sol", &sol)
call <SID>AddOption("paragraphs", gettext("nroff macro names that separate paragraphs"))
call <SID>OptionG("para", &para)
call <SID>AddOption("sections", gettext("nroff macro names that separate sections"))
call <SID>OptionG("sect", &sect)
call <SID>AddOption("path", gettext("list of directory names used for file searching"))
call append("$", "\t" .. s:global_or_local)
call <SID>OptionG("pa", &pa)
call <SID>AddOption("cdhome", gettext(":cd without argument goes to the home directory"))
call <SID>BinOptionG("cdh", &cdh)
call <SID>AddOption("cdpath", gettext("list of directory names used for :cd"))
call <SID>OptionG("cd", &cd)
if exists("+autochdir")
  call <SID>AddOption("autochdir", gettext("change to directory of file in buffer"))
  call <SID>BinOptionG("acd", &acd)
endif
call <SID>AddOption("wrapscan", gettext("search commands wrap around the end of the buffer"))
call <SID>BinOptionG("ws", &ws)
call <SID>AddOption("incsearch", gettext("show match for partly typed search command"))
call <SID>BinOptionG("is", &is)
call <SID>AddOption("magic", gettext("change the way backslashes are used in search patterns"))
call <SID>BinOptionG("magic", &magic)
call <SID>AddOption("regexpengine", gettext("select the default regexp engine used"))
call <SID>OptionG("re", &re)
call <SID>AddOption("ignorecase", gettext("ignore case when using a search pattern"))
call <SID>BinOptionG("ic", &ic)
call <SID>AddOption("smartcase", gettext("override 'ignorecase' when pattern has upper case characters"))
call <SID>BinOptionG("scs", &scs)
call <SID>AddOption("casemap", gettext("what method to use for changing case of letters"))
call <SID>OptionG("cmp", &cmp)
call <SID>AddOption("maxmempattern", gettext("maximum amount of memory in Kbyte used for pattern matching"))
call append("$", " \tset mmp=" . &mmp)
call <SID>AddOption("define", gettext("pattern for a macro definition line"))
call append("$", "\t" .. s:global_or_local)
call <SID>OptionG("def", &def)
if has("find_in_path")
  call <SID>AddOption("include", gettext("pattern for an include-file line"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("inc")
  call <SID>AddOption("includeexpr", gettext("expression used to transform an include line to a file name"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("inex")
endif


call <SID>Header(gettext("tags"))
call <SID>AddOption("tagbsearch", gettext("use binary searching in tags files"))
call <SID>BinOptionG("tbs", &tbs)
call <SID>AddOption("taglength", gettext("number of significant characters in a tag name or zero"))
call append("$", " \tset tl=" . &tl)
call <SID>AddOption("tags", gettext("list of file names to search for tags"))
call append("$", "\t" .. s:global_or_local)
call <SID>OptionG("tag", &tag)
call <SID>AddOption("tagcase", gettext("how to handle case when searching in tags files:\n\"followic\" to follow 'ignorecase', \"ignore\" or \"match\""))
call append("$", "\t" .. s:global_or_local)
call <SID>OptionG("tc", &tc)
call <SID>AddOption("tagrelative", gettext("file names in a tags file are relative to the tags file"))
call <SID>BinOptionG("tr", &tr)
call <SID>AddOption("tagstack", gettext("a :tag command will use the tagstack"))
call <SID>BinOptionG("tgst", &tgst)
call <SID>AddOption("showfulltag", gettext("when completing tags in Insert mode show more info"))
call <SID>BinOptionG("sft", &sft)
if has("eval")
  call <SID>AddOption("tagfunc", gettext("a function to be used to perform tag searches"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("tfu")
endif


call <SID>Header(gettext("displaying text"))
call <SID>AddOption("scroll", gettext("number of lines to scroll for CTRL-U and CTRL-D"))
call append("$", "\t" .. s:local_to_window)
call <SID>OptionL("scr")
call <SID>AddOption("smoothscroll", gettext("scroll by screen line"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("sms")
call <SID>AddOption("scrolloff", gettext("number of screen lines to show around the cursor"))
call append("$", " \tset so=" . &so)
call <SID>AddOption("wrap", gettext("long lines wrap"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("wrap")
call <SID>AddOption("linebreak", gettext("wrap long lines at a character in 'breakat'"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("lbr")
call <SID>AddOption("breakindent", gettext("preserve indentation in wrapped text"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("bri")
call <SID>AddOption("breakindentopt", gettext("adjust breakindent behaviour"))
call append("$", "\t" .. s:local_to_window)
call <SID>OptionL("briopt")
call <SID>AddOption("breakat", gettext("which characters might cause a line break"))
call <SID>OptionG("brk", &brk)
call <SID>AddOption("showbreak", gettext("string to put before wrapped screen lines"))
call <SID>OptionG("sbr", &sbr)
call <SID>AddOption("sidescroll", gettext("minimal number of columns to scroll horizontally"))
call append("$", " \tset ss=" . &ss)
call <SID>AddOption("sidescrolloff", gettext("minimal number of columns to keep left and right of the cursor"))
call append("$", " \tset siso=" . &siso)
call <SID>AddOption("display", gettext("include \"lastline\" to show the last line even if it doesn't fit\ninclude \"uhex\" to show unprintable characters as a hex number"))
call <SID>OptionG("dy", &dy)
call <SID>AddOption("fillchars", gettext("characters to use for the status line, folds and filler lines"))
call <SID>OptionG("fcs", &fcs)
call <SID>AddOption("cmdheight", gettext("number of lines used for the command-line"))
call append("$", " \tset ch=" . &ch)
call <SID>AddOption("columns", gettext("width of the display"))
call append("$", " \tset co=" . &co)
call <SID>AddOption("lines", gettext("number of lines in the display"))
call append("$", " \tset lines=" . &lines)
call <SID>AddOption("window", gettext("number of lines to scroll for CTRL-F and CTRL-B"))
call append("$", " \tset window=" . &window)
call <SID>AddOption("lazyredraw", gettext("don't redraw while executing macros"))
call <SID>BinOptionG("lz", &lz)
if has("reltime")
  call <SID>AddOption("redrawtime", gettext("timeout for 'hlsearch' and :match highlighting in msec"))
  call append("$", " \tset rdt=" . &rdt)
endif
call <SID>AddOption("writedelay", gettext("delay in msec for each char written to the display\n(for debugging)"))
call append("$", " \tset wd=" . &wd)
call <SID>AddOption("list", gettext("show <Tab> as ^I and end-of-line as $"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("list")
call <SID>AddOption("listchars", gettext("list of strings used for list mode"))
call <SID>OptionG("lcs", &lcs)
call <SID>AddOption("number", gettext("show the line number for each line"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("nu")
call <SID>AddOption("relativenumber", gettext("show the relative line number for each line"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("rnu")
if has("linebreak")
  call <SID>AddOption("numberwidth", gettext("number of columns to use for the line number"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("nuw")
endif
if has("conceal")
  call <SID>AddOption("conceallevel", gettext("controls whether concealable text is hidden"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("cole")
  call <SID>AddOption("concealcursor", gettext("modes in which text in the cursor line can be concealed"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("cocu")
endif


call <SID>Header(gettext("syntax, highlighting and spelling"))
call <SID>AddOption("background", gettext("\"dark\" or \"light\"; the background color brightness"))
call <SID>OptionG("bg", &bg)
call <SID>AddOption("filetype", gettext("type of file; triggers the FileType event when set"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("ft")
if has("syntax")
  call <SID>AddOption("syntax", gettext("name of syntax highlighting used"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("syn")
  call <SID>AddOption("synmaxcol", gettext("maximum column to look for syntax items"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("smc")
endif
call <SID>AddOption("highlight", gettext("which highlighting to use for various occasions"))
call <SID>OptionG("hl", &hl)
call <SID>AddOption("hlsearch", gettext("highlight all matches for the last used search pattern"))
call <SID>BinOptionG("hls", &hls)
if has("termguicolors")
  call <SID>AddOption("termguicolors", gettext("use GUI colors for the terminal"))
  call <SID>BinOptionG("tgc", &tgc)
endif
if has("syntax")
  call <SID>AddOption("cursorcolumn", gettext("highlight the screen column of the cursor"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("cuc")
  call <SID>AddOption("cursorline", gettext("highlight the screen line of the cursor"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("cul")
  call <SID>AddOption("cursorlineopt", gettext("specifies which area 'cursorline' highlights"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("culopt")
  call <SID>AddOption("colorcolumn", gettext("columns to highlight"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("cc")
  call <SID>AddOption("spell", gettext("highlight spelling mistakes"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("spell")
  call <SID>AddOption("spelllang", gettext("list of accepted languages"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("spl")
  call <SID>AddOption("spellfile", gettext("file that \"zg\" adds good words to"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("spf")
  call <SID>AddOption("spellcapcheck", gettext("pattern to locate the end of a sentence"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("spc")
  call <SID>AddOption("spelloptions", gettext("flags to change how spell checking works"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("spo")
  call <SID>AddOption("spellsuggest", gettext("methods used to suggest corrections"))
  call <SID>OptionG("sps", &sps)
  call <SID>AddOption("mkspellmem", gettext("amount of memory used by :mkspell before compressing"))
  call <SID>OptionG("msm", &msm)
endif


call <SID>Header(gettext("multiple windows"))
call <SID>AddOption("laststatus", gettext("0, 1, 2 or 3; when to use a status line for the last window"))
call append("$", " \tset ls=" . &ls)
if has("statusline")
  call <SID>AddOption("statuscolumn", gettext("custom format for the status column"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionG("stc", &stc)
  call <SID>AddOption("statusline", gettext("alternate format to be used for a status line"))
  call <SID>OptionG("stl", &stl)
endif
call append("$", "\t" .. s:local_to_window)
call <SID>AddOption("equalalways", gettext("make all windows the same size when adding/removing windows"))
call <SID>BinOptionG("ea", &ea)
call <SID>AddOption("eadirection", gettext("in which direction 'equalalways' works: \"ver\", \"hor\" or \"both\""))
call <SID>OptionG("ead", &ead)
call <SID>AddOption("winheight", gettext("minimal number of lines used for the current window"))
call append("$", " \tset wh=" . &wh)
call <SID>AddOption("winminheight", gettext("minimal number of lines used for any window"))
call append("$", " \tset wmh=" . &wmh)
call <SID>AddOption("winfixbuf", gettext("keep window focused on a single buffer"))
call <SID>OptionG("wfb", &wfb)
call <SID>AddOption("winfixheight", gettext("keep the height of the window"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("wfh")
call <SID>AddOption("winfixwidth", gettext("keep the width of the window"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("wfw")
call <SID>AddOption("winwidth", gettext("minimal number of columns used for the current window"))
call append("$", " \tset wiw=" . &wiw)
call <SID>AddOption("winminwidth", gettext("minimal number of columns used for any window"))
call append("$", " \tset wmw=" . &wmw)
call <SID>AddOption("helpheight", gettext("initial height of the help window"))
call append("$", " \tset hh=" . &hh)
if has("quickfix")
  " call <SID>AddOption("previewpopup", gettext("use a popup window for preview"))
  " call append("$", " \tset pvp=" . &pvp)
  call <SID>AddOption("previewheight", gettext("default height for the preview window"))
  call append("$", " \tset pvh=" . &pvh)
  call <SID>AddOption("previewwindow", gettext("identifies the preview window"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("pvw")
endif
call <SID>AddOption("hidden", gettext("don't unload a buffer when no longer shown in a window"))
call <SID>BinOptionG("hid", &hid)
call <SID>AddOption("switchbuf", gettext("\"useopen\" and/or \"split\"; which window to use when jumping\nto a buffer"))
call <SID>OptionG("swb", &swb)
call <SID>AddOption("splitbelow", gettext("a new window is put below the current one"))
call <SID>BinOptionG("sb", &sb)
call <SID>AddOption("splitkeep", gettext("determines scroll behavior for split windows"))
call <SID>OptionG("spk", &spk)
call <SID>AddOption("splitright", gettext("a new window is put right of the current one"))
call <SID>BinOptionG("spr", &spr)
call <SID>AddOption("scrollbind", gettext("this window scrolls together with other bound windows"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("scb")
call <SID>AddOption("scrollopt", gettext("\"ver\", \"hor\" and/or \"jump\"; list of options for 'scrollbind'"))
call <SID>OptionG("sbo", &sbo)
call <SID>AddOption("cursorbind", gettext("this window's cursor moves together with other bound windows"))
call append("$", "\t" .. s:local_to_window)
call <SID>BinOptionL("crb")
if has("terminal")
  call <SID>AddOption("termsize", gettext("size of a terminal window"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("tms")
  call <SID>AddOption("termkey", gettext("key that precedes Vim commands in a terminal window"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("tk")
endif


call <SID>Header(gettext("multiple tab pages"))
call <SID>AddOption("showtabline", gettext("0, 1 or 2; when to use a tab pages line"))
call append("$", " \tset stal=" . &stal)
call <SID>AddOption("tabclose", gettext("behaviour when closing tab pages: left, uselast or empty"))
call append("$", " \tset tcl=" . &tcl)
call <SID>AddOption("tabpagemax", gettext("maximum number of tab pages to open for -p and \"tab all\""))
call append("$", " \tset tpm=" . &tpm)
call <SID>AddOption("tabline", gettext("custom tab pages line"))
call <SID>OptionG("tal", &tal)
if has("gui")
  call <SID>AddOption("guitablabel", gettext("custom tab page label for the GUI"))
  call <SID>OptionG("gtl", &gtl)
  call <SID>AddOption("guitabtooltip", gettext("custom tab page tooltip for the GUI"))
  call <SID>OptionG("gtt", &gtt)
endif


call <SID>Header(gettext("terminal"))
call <SID>AddOption("scrolljump", gettext("minimal number of lines to scroll at a time"))
call append("$", " \tset sj=" . &sj)
if has("gui") || has("msdos") || has("win32")
  call <SID>AddOption("guicursor", gettext("specifies what the cursor looks like in different modes"))
  call <SID>OptionG("gcr", &gcr)
endif
if has("title")
  let &title = s:old_title
  call <SID>AddOption("title", gettext("show info in the window title"))
  call <SID>BinOptionG("title", &title)
  set notitle
  call <SID>AddOption("titlelen", gettext("percentage of 'columns' used for the window title"))
  call append("$", " \tset titlelen=" . &titlelen)
  call <SID>AddOption("titlestring", gettext("when not empty, string to be used for the window title"))
  call <SID>OptionG("titlestring", &titlestring)
  call <SID>AddOption("titleold", gettext("string to restore the title to when exiting Vim"))
  call <SID>OptionG("titleold", &titleold)
  let &icon = s:old_icon
  call <SID>AddOption("icon", gettext("set the text of the icon for this window"))
  call <SID>BinOptionG("icon", &icon)
  set noicon
  call <SID>AddOption("iconstring", gettext("when not empty, text for the icon of this window"))
  call <SID>OptionG("iconstring", &iconstring)
endif


call <SID>Header(gettext("using the mouse"))
call <SID>AddOption("mouse", gettext("list of flags for using the mouse"))
call <SID>OptionG("mouse", &mouse)
if has("gui")
  call <SID>AddOption("mousefocus", gettext("the window with the mouse pointer becomes the current one"))
  call <SID>BinOptionG("mousef", &mousef)
  call <SID>AddOption("mousehide", gettext("hide the mouse pointer while typing"))
  call <SID>BinOptionG("mh", &mh)
endif
call <SID>AddOption("mousemodel", gettext("\"extend\", \"popup\" or \"popup_setpos\"; what the right\nmouse button is used for"))
call <SID>OptionG("mousem", &mousem)
call <SID>AddOption("mousetime", gettext("maximum time in msec to recognize a double-click"))
call append("$", " \tset mouset=" . &mouset)
if has("mouseshape")
  call <SID>AddOption("mouseshape", gettext("what the mouse pointer looks like in different modes"))
  call <SID>OptionG("mouses", &mouses)
endif


if has("gui")
  call <SID>Header(gettext("GUI"))
  call <SID>AddOption("guifont", gettext("list of font names to be used in the GUI"))
  call <SID>OptionG("gfn", &gfn)
  if has("xfontset")
    call <SID>AddOption("guifontset", gettext("pair of fonts to be used, for multibyte editing"))
    call <SID>OptionG("gfs", &gfs)
  endif
  call <SID>AddOption("guifontwide", gettext("list of font names to be used for double-wide characters"))
  call <SID>OptionG("gfw", &gfw)
  call <SID>AddOption("guioptions", gettext("list of flags that specify how the GUI works"))
  call <SID>OptionG("go", &go)
  if has("gui_gtk")
    call <SID>AddOption("toolbar", gettext("\"icons\", \"text\" and/or \"tooltips\"; how to show the toolbar"))
    call <SID>OptionG("tb", &tb)
    if has("gui_gtk2")
      call <SID>AddOption("toolbariconsize", gettext("size of toolbar icons"))
      call <SID>OptionG("tbis", &tbis)
    endif
  endif
  if has("browse")
    call <SID>AddOption("browsedir", gettext("\"last\", \"buffer\" or \"current\": which directory used for the file browser"))
    call <SID>OptionG("bsdir", &bsdir)
  endif
  if has("multi_lang")
    call <SID>AddOption("langmenu", gettext("language to be used for the menus"))
    call <SID>OptionG("langmenu", &lm)
  endif
  call <SID>AddOption("menuitems", gettext("maximum number of items in one menu"))
  call append("$", " \tset mis=" . &mis)
  if has("winaltkeys")
    call <SID>AddOption("winaltkeys", gettext("\"no\", \"yes\" or \"menu\"; how to use the ALT key"))
    call <SID>OptionG("wak", &wak)
  endif
  call <SID>AddOption("linespace", gettext("number of pixel lines to use between characters"))
  call append("$", " \tset lsp=" . &lsp)
  if has("balloon_eval") || has("balloon_eval_term")
    call <SID>AddOption("balloondelay", gettext("delay in milliseconds before a balloon may pop up"))
    call append("$", " \tset bdlay=" . &bdlay)
    if has("balloon_eval")
      call <SID>AddOption("ballooneval", gettext("use balloon evaluation in the GUI"))
      call <SID>BinOptionG("beval", &beval)
    endif
    if has("balloon_eval_term")
      call <SID>AddOption("balloonevalterm", gettext("use balloon evaluation in the terminal"))
      call <SID>BinOptionG("bevalterm", &beval)
    endif
    if has("eval")
      call <SID>AddOption("balloonexpr", gettext("expression to show in balloon eval"))
      call append("$", " \tset bexpr=" . &bexpr)
    endif
  endif
endif

call <SID>Header(gettext("messages and info"))
call <SID>AddOption("terse", gettext("add 's' flag in 'shortmess' (don't show search message)"))
call <SID>BinOptionG("terse", &terse)
call <SID>AddOption("shortmess", gettext("list of flags to make messages shorter"))
call <SID>OptionG("shm", &shm)
call <SID>AddOption("showcmd", gettext("show (partial) command keys in location given by 'showcmdloc'"))
let &sc = s:old_sc
call <SID>BinOptionG("sc", &sc)
set nosc
call <SID>AddOption("showcmdloc", gettext("location where to show the (partial) command keys for 'showcmd'"))
  call <SID>OptionG("sloc", &sloc)
call <SID>AddOption("showmode", gettext("display the current mode in the status line"))
call <SID>BinOptionG("smd", &smd)
call <SID>AddOption("ruler", gettext("show cursor position below each window"))
let &ru = s:old_ru
call <SID>BinOptionG("ru", &ru)
set noru
if has("statusline")
  call <SID>AddOption("rulerformat", gettext("alternate format to be used for the ruler"))
  call <SID>OptionG("ruf", &ruf)
endif
call <SID>AddOption("report", gettext("threshold for reporting number of changed lines"))
call append("$", " \tset report=" . &report)
call <SID>AddOption("verbose", gettext("the higher the more messages are given"))
call append("$", " \tset vbs=" . &vbs)
call <SID>AddOption("verbosefile", gettext("file to write messages in"))
call <SID>OptionG("vfile", &vfile)
call <SID>AddOption("more", gettext("pause listings when the screen is full"))
call <SID>BinOptionG("more", &more)
if has("dialog_con") || has("dialog_gui")
  call <SID>AddOption("confirm", gettext("start a dialog when a command fails"))
  call <SID>BinOptionG("cf", &cf)
endif
call <SID>AddOption("errorbells", gettext("ring the bell for error messages"))
call <SID>BinOptionG("eb", &eb)
call <SID>AddOption("visualbell", gettext("use a visual bell instead of beeping"))
call <SID>BinOptionG("vb", &vb)
call <SID>AddOption("belloff", gettext("do not ring the bell for these reasons"))
call <SID>OptionG("belloff", &belloff)
if has("multi_lang")
  call <SID>AddOption("helplang", gettext("list of preferred languages for finding help"))
  call <SID>OptionG("hlg", &hlg)
endif


call <SID>Header(gettext("selecting text"))
call <SID>AddOption("selection", gettext("\"old\", \"inclusive\" or \"exclusive\"; how selecting text behaves"))
call <SID>OptionG("sel", &sel)
call <SID>AddOption("selectmode", gettext("\"mouse\", \"key\" and/or \"cmd\"; when to start Select mode\ninstead of Visual mode"))
call <SID>OptionG("slm", &slm)
if has("clipboard")
  call <SID>AddOption("clipboard", gettext("\"unnamed\" to use the * register like unnamed register\n\"autoselect\" to always put selected text on the clipboard"))
  call <SID>OptionG("cb", &cb)
endif
call <SID>AddOption("keymodel", gettext("\"startsel\" and/or \"stopsel\"; what special keys can do"))
call <SID>OptionG("km", &km)


call <SID>Header(gettext("editing text"))
call <SID>AddOption("undolevels", gettext("maximum number of changes that can be undone"))
call append("$", "\t" .. s:global_or_local)
call append("$", " \tset ul=" . s:old_ul)
call <SID>AddOption("undofile", gettext("automatically save and restore undo history"))
call <SID>BinOptionG("udf", &udf)
call <SID>AddOption("undodir", gettext("list of directories for undo files"))
call <SID>OptionG("udir", &udir)
call <SID>AddOption("undoreload", gettext("maximum number lines to save for undo on a buffer reload"))
call append("$", " \tset ur=" . &ur)
call <SID>AddOption("modified", gettext("changes have been made and not written to a file"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("mod")
call <SID>AddOption("readonly", gettext("buffer is not to be written"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("ro")
call <SID>AddOption("modifiable", gettext("changes to the text are possible"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("ma")
call <SID>AddOption("textwidth", gettext("line length above which to break a line"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("tw")
call <SID>AddOption("wrapmargin", gettext("margin from the right in which to break a line"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("wm")
call <SID>AddOption("backspace", gettext("specifies what <BS>, CTRL-W, etc. can do in Insert mode"))
call append("$", " \tset bs=" . &bs)
call <SID>AddOption("comments", gettext("definition of what comment lines look like"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("com")
call <SID>AddOption("formatoptions", gettext("list of flags that tell how automatic formatting works"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("fo")
call <SID>AddOption("formatlistpat", gettext("pattern to recognize a numbered list"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("flp")
if has("eval")
  call <SID>AddOption("formatexpr", gettext("expression used for \"gq\" to format lines"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("fex")
endif
if has("insert_expand")
  call <SID>AddOption("complete", gettext("specifies how Insert mode completion works for CTRL-N and CTRL-P"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("cpt")
  call <SID>AddOption("completeopt", gettext("whether to use a popup menu for Insert mode completion"))
  call <SID>OptionL("cot")
  call <SID>AddOption("pumheight", gettext("maximum height of the popup menu"))
  call <SID>OptionG("ph", &ph)
  call <SID>AddOption("pumwidth", gettext("minimum width of the popup menu"))
  call <SID>OptionG("pw", &pw)
  call <SID>AddOption("completefunc", gettext("user defined function for Insert mode completion"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("cfu")
  call <SID>AddOption("omnifunc", gettext("function for filetype-specific Insert mode completion"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("ofu")
  call <SID>AddOption("dictionary", gettext("list of dictionary files for keyword completion"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("dict", &dict)
  call <SID>AddOption("thesaurus", gettext("list of thesaurus files for keyword completion"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("tsr", &tsr)
  call <SID>AddOption("thesaurusfunc", gettext("function used for thesaurus completion"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("tsrfu", &tsrfu)
endif
call <SID>AddOption("infercase", gettext("adjust case of a keyword completion match"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("inf")
if has("digraphs")
  call <SID>AddOption("digraph", gettext("enable entering digraphs with c1 <BS> c2"))
  call <SID>BinOptionG("dg", &dg)
endif
call <SID>AddOption("tildeop", gettext("the \"~\" command behaves like an operator"))
call <SID>BinOptionG("top", &top)
call <SID>AddOption("operatorfunc", gettext("function called for the \"g@\" operator"))
call <SID>OptionG("opfunc", &opfunc)
call <SID>AddOption("showmatch", gettext("when inserting a bracket, briefly jump to its match"))
call <SID>BinOptionG("sm", &sm)
call <SID>AddOption("matchtime", gettext("tenth of a second to show a match for 'showmatch'"))
call append("$", " \tset mat=" . &mat)
call <SID>AddOption("matchpairs", gettext("list of pairs that match for the \"%\" command"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("mps")
call <SID>AddOption("joinspaces", gettext("use two spaces after '.' when joining a line"))
call <SID>BinOptionG("js", &js)
call <SID>AddOption("nrformats", gettext("\"alpha\", \"octal\", \"hex\", \"bin\" and/or \"unsigned\"; number formats\nrecognized for CTRL-A and CTRL-X commands"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("nf")


call <SID>Header(gettext("tabs and indenting"))
call <SID>AddOption("tabstop", gettext("number of spaces a <Tab> in the text stands for"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("ts")
call <SID>AddOption("shiftwidth", gettext("number of spaces used for each step of (auto)indent"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("sw")
if has("vartabs")
  call <SID>AddOption("vartabstop", gettext("list of number of spaces a tab counts for"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("vts")
  call <SID>AddOption("varsofttabstop", gettext("list of number of spaces a soft tabsstop counts for"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("vsts")
endif
call <SID>AddOption("smarttab", gettext("a <Tab> in an indent inserts 'shiftwidth' spaces"))
call <SID>BinOptionG("sta", &sta)
call <SID>AddOption("softtabstop", gettext("if non-zero, number of spaces to insert for a <Tab>"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("sts")
call <SID>AddOption("shiftround", gettext("round to 'shiftwidth' for \"<<\" and \">>\""))
call <SID>BinOptionG("sr", &sr)
call <SID>AddOption("expandtab", gettext("expand <Tab> to spaces in Insert mode"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("et")
call <SID>AddOption("autoindent", gettext("automatically set the indent of a new line"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("ai")
if has("smartindent")
  call <SID>AddOption("smartindent", gettext("do clever autoindenting"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>BinOptionL("si")
endif
if has("cindent")
  call <SID>AddOption("cindent", gettext("enable specific indenting for C code"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>BinOptionL("cin")
  call <SID>AddOption("cinoptions", gettext("options for C-indenting"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("cino")
  call <SID>AddOption("cinkeys", gettext("keys that trigger C-indenting in Insert mode"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("cink")
  call <SID>AddOption("cinwords", gettext("list of words that cause more C-indent"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("cinw")
  call <SID>AddOption("cinscopedecls", gettext("list of scope declaration names used by cino-g"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("cinsd")
  call <SID>AddOption("indentexpr", gettext("expression used to obtain the indent of a line"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("inde")
  call <SID>AddOption("indentkeys", gettext("keys that trigger indenting with 'indentexpr' in Insert mode"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("indk")
endif
call <SID>AddOption("copyindent", gettext("copy whitespace for indenting from previous line"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("ci")
call <SID>AddOption("preserveindent", gettext("preserve kind of whitespace when changing indent"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("pi")
if has("lispindent")
  call <SID>AddOption("lisp", gettext("enable lisp mode"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>BinOptionL("lisp")
  call <SID>AddOption("lispwords", gettext("words that change how lisp indenting works"))
  call <SID>OptionL("lw")
  call <SID>AddOption("lispoptions", gettext("options for Lisp indenting"))
  call <SID>OptionL("lop")
endif


if has("folding")
  call <SID>Header(gettext("folding"))
  call <SID>AddOption("foldenable", gettext("unset to display all folds open"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("fen")
  call <SID>AddOption("foldlevel", gettext("folds with a level higher than this number will be closed"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fdl")
  call <SID>AddOption("foldlevelstart", gettext("value for 'foldlevel' when starting to edit a file"))
  call append("$", " \tset fdls=" . &fdls)
  call <SID>AddOption("foldcolumn", gettext("width of the column used to indicate folds"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fdc")
  call <SID>AddOption("foldtext", gettext("expression used to display the text of a closed fold"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fdt")
  call <SID>AddOption("foldclose", gettext("set to \"all\" to close a fold when the cursor leaves it"))
  call <SID>OptionG("fcl", &fcl)
  call <SID>AddOption("foldopen", gettext("specifies for which commands a fold will be opened"))
  call <SID>OptionG("fdo", &fdo)
  call <SID>AddOption("foldminlines", gettext("minimum number of screen lines for a fold to be closed"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fml")
  call <SID>AddOption("commentstring", gettext("template for comments; used to put the marker in"))
  call <SID>OptionL("cms")
  call <SID>AddOption("foldmethod", gettext("folding type: \"manual\", \"indent\", \"expr\", \"marker\",\n\"syntax\" or \"diff\""))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fdm")
  call <SID>AddOption("foldexpr", gettext("expression used when 'foldmethod' is \"expr\""))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fde")
  call <SID>AddOption("foldignore", gettext("used to ignore lines when 'foldmethod' is \"indent\""))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fdi")
  call <SID>AddOption("foldmarker", gettext("markers used when 'foldmethod' is \"marker\""))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fmr")
  call <SID>AddOption("foldnestmax", gettext("maximum fold depth for when 'foldmethod' is \"indent\" or \"syntax\""))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("fdn")
endif


if has("diff")
  call <SID>Header(gettext("diff mode"))
  call <SID>AddOption("diff", gettext("use diff mode for the current window"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("diff")
  call <SID>AddOption("diffopt", gettext("options for using diff mode"))
  call <SID>OptionG("dip", &dip)
  call <SID>AddOption("diffexpr", gettext("expression used to obtain a diff file"))
  call <SID>OptionG("dex", &dex)
  call <SID>AddOption("patchexpr", gettext("expression used to patch a file"))
  call <SID>OptionG("pex", &pex)
endif


call <SID>Header(gettext("mapping"))
call <SID>AddOption("maxmapdepth", gettext("maximum depth of mapping"))
call append("$", " \tset mmd=" . &mmd)
call <SID>AddOption("timeout", gettext("allow timing out halfway into a mapping"))
call <SID>BinOptionG("to", &to)
call <SID>AddOption("ttimeout", gettext("allow timing out halfway into a key code"))
call <SID>BinOptionG("ttimeout", &ttimeout)
call <SID>AddOption("timeoutlen", gettext("time in msec for 'timeout'"))
call append("$", " \tset tm=" . &tm)
call <SID>AddOption("ttimeoutlen", gettext("time in msec for 'ttimeout'"))
call append("$", " \tset ttm=" . &ttm)


call <SID>Header(gettext("reading and writing files"))
call <SID>AddOption("modeline", gettext("enable using settings from modelines when reading a file"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("ml")
call <SID>AddOption("modelineexpr", gettext("allow setting expression options from a modeline"))
call <SID>BinOptionG("mle", &mle)
call <SID>AddOption("modelines", gettext("number of lines to check for modelines"))
call append("$", " \tset mls=" . &mls)
call <SID>AddOption("binary", gettext("binary file editing"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("bin")
call <SID>AddOption("endofline", gettext("last line in the file has an end-of-line"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("eol")
call <SID>AddOption("endoffile", gettext("last line in the file followed by CTRL-Z"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("eof")
call <SID>AddOption("fixendofline", gettext("fixes missing end-of-line at end of text file"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("fixeol")
call <SID>AddOption("bomb", gettext("prepend a Byte Order Mark to the file"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("bomb")
call <SID>AddOption("fileformat", gettext("end-of-line format: \"dos\", \"unix\" or \"mac\""))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("ff")
call <SID>AddOption("fileformats", gettext("list of file formats to look for when editing a file"))
call <SID>OptionG("ffs", &ffs)
call <SID>AddOption("write", gettext("writing files is allowed"))
call <SID>BinOptionG("write", &write)
call <SID>AddOption("writebackup", gettext("write a backup file before overwriting a file"))
call <SID>BinOptionG("wb", &wb)
call <SID>AddOption("backup", gettext("keep a backup after overwriting a file"))
call <SID>BinOptionG("bk", &bk)
call <SID>AddOption("backupskip", gettext("patterns that specify for which files a backup is not made"))
call append("$", " \tset bsk=" . &bsk)
call <SID>AddOption("backupcopy", gettext("whether to make the backup as a copy or rename the existing file"))
call append("$", "\t" .. s:global_or_local)
call append("$", " \tset bkc=" . &bkc)
call <SID>AddOption("backupdir", gettext("list of directories to put backup files in"))
call <SID>OptionG("bdir", &bdir)
call <SID>AddOption("backupext", gettext("file name extension for the backup file"))
call <SID>OptionG("bex", &bex)
call <SID>AddOption("autowrite", gettext("automatically write a file when leaving a modified buffer"))
call <SID>BinOptionG("aw", &aw)
call <SID>AddOption("autowriteall", gettext("as 'autowrite', but works with more commands"))
call <SID>BinOptionG("awa", &awa)
call <SID>AddOption("writeany", gettext("always write without asking for confirmation"))
call <SID>BinOptionG("wa", &wa)
call <SID>AddOption("autoread", gettext("automatically read a file when it was modified outside of Vim"))
call append("$", "\t" .. s:global_or_local)
call <SID>BinOptionG("ar", &ar)
call <SID>AddOption("patchmode", gettext("keep oldest version of a file; specifies file name extension"))
call <SID>OptionG("pm", &pm)
call <SID>AddOption("fsync", gettext("forcibly sync the file to disk after writing it"))
call <SID>BinOptionG("fs", &fs)


call <SID>Header(gettext("the swap file"))
call <SID>AddOption("directory", gettext("list of directories for the swap file"))
call <SID>OptionG("dir", &dir)
call <SID>AddOption("swapfile", gettext("use a swap file for this buffer"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("swf")
call <SID>AddOption("updatecount", gettext("number of characters typed to cause a swap file update"))
call append("$", " \tset uc=" . &uc)
call <SID>AddOption("updatetime", gettext("time in msec after which the swap file will be updated"))
call append("$", " \tset ut=" . &ut)


call <SID>Header(gettext("command line editing"))
call <SID>AddOption("history", gettext("how many command lines are remembered"))
call append("$", " \tset hi=" . &hi)
call <SID>AddOption("wildchar", gettext("key that triggers command-line expansion"))
call append("$", " \tset wc=" . &wc)
call <SID>AddOption("wildcharm", gettext("like 'wildchar' but can also be used in a mapping"))
call append("$", " \tset wcm=" . &wcm)
call <SID>AddOption("wildmode", gettext("specifies how command line completion works"))
call <SID>OptionG("wim", &wim)
if has("wildoptions")
  call <SID>AddOption("wildoptions", gettext("empty or \"tagfile\" to list file name of matching tags"))
  call <SID>OptionG("wop", &wop)
endif
call <SID>AddOption("suffixes", gettext("list of file name extensions that have a lower priority"))
call <SID>OptionG("su", &su)
if has("file_in_path")
  call <SID>AddOption("suffixesadd", gettext("list of file name extensions added when searching for a file"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("sua")
endif
if has("wildignore")
  call <SID>AddOption("wildignore", gettext("list of patterns to ignore files for file name completion"))
  call <SID>OptionG("wig", &wig)
endif
call <SID>AddOption("fileignorecase", gettext("ignore case when using file names"))
call <SID>BinOptionG("fic", &fic)
call <SID>AddOption("wildignorecase", gettext("ignore case when completing file names"))
call <SID>BinOptionG("wic", &wic)
if has("wildmenu")
  call <SID>AddOption("wildmenu", gettext("command-line completion shows a list of matches"))
  call <SID>BinOptionG("wmnu", &wmnu)
endif
call <SID>AddOption("cedit", gettext("key used to open the command-line window"))
call <SID>OptionG("cedit", &cedit)
call <SID>AddOption("cmdwinheight", gettext("height of the command-line window"))
call <SID>OptionG("cwh", &cwh)


call <SID>Header(gettext("executing external commands"))
call <SID>AddOption("shell", gettext("name of the shell program used for external commands"))
call <SID>OptionG("sh", &sh)
call <SID>AddOption("shellquote", gettext("character(s) to enclose a shell command in"))
call <SID>OptionG("shq", &shq)
call <SID>AddOption("shellxquote", gettext("like 'shellquote' but include the redirection"))
call <SID>OptionG("sxq", &sxq)
call <SID>AddOption("shellxescape", gettext("characters to escape when 'shellxquote' is ("))
call <SID>OptionG("sxe", &sxe)
call <SID>AddOption("shellcmdflag", gettext("argument for 'shell' to execute a command"))
call <SID>OptionG("shcf", &shcf)
call <SID>AddOption("shellredir", gettext("used to redirect command output to a file"))
call <SID>OptionG("srr", &srr)
call <SID>AddOption("shelltemp", gettext("use a temp file for shell commands instead of using a pipe"))
call <SID>BinOptionG("stmp", &stmp)
call <SID>AddOption("equalprg", gettext("program used for \"=\" command"))
call append("$", "\t" .. s:global_or_local)
call <SID>OptionG("ep", &ep)
call <SID>AddOption("formatprg", gettext("program used to format lines with \"gq\" command"))
call <SID>OptionG("fp", &fp)
call <SID>AddOption("keywordprg", gettext("program used for the \"K\" command"))
call <SID>OptionG("kp", &kp)
call <SID>AddOption("warn", gettext("warn when using a shell command and a buffer has changes"))
call <SID>BinOptionG("warn", &warn)


if has("quickfix")
  call <SID>Header(gettext("running make and jumping to errors (quickfix)"))
  call <SID>AddOption("errorfile", gettext("name of the file that contains error messages"))
  call <SID>OptionG("ef", &ef)
  call <SID>AddOption("errorformat", gettext("list of formats for error messages"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("efm", &efm)
  call <SID>AddOption("makeprg", gettext("program used for the \":make\" command"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("mp", &mp)
  call <SID>AddOption("shellpipe", gettext("string used to put the output of \":make\" in the error file"))
  call <SID>OptionG("sp", &sp)
  call <SID>AddOption("makeef", gettext("name of the errorfile for the 'makeprg' command"))
  call <SID>OptionG("mef", &mef)
  call <SID>AddOption("grepprg", gettext("program used for the \":grep\" command"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("gp", &gp)
  call <SID>AddOption("grepformat", gettext("list of formats for output of 'grepprg'"))
  call <SID>OptionG("gfm", &gfm)
  call <SID>AddOption("makeencoding", gettext("encoding of the \":make\" and \":grep\" output"))
  call append("$", "\t" .. s:global_or_local)
  call <SID>OptionG("menc", &menc)
endif


if has("win32")
  call <SID>Header(gettext("system specific"))
  call <SID>AddOption("shellslash", gettext("use forward slashes in file names; for Unix-like shells"))
  call <SID>BinOptionG("ssl", &ssl)
  call <SID>AddOption("completeslash", gettext("specifies slash/backslash used for completion"))
  call <SID>OptionG("csl", &csl)
endif


call <SID>Header(gettext("language specific"))
call <SID>AddOption("isfname", gettext("specifies the characters in a file name"))
call <SID>OptionG("isf", &isf)
call <SID>AddOption("isident", gettext("specifies the characters in an identifier"))
call <SID>OptionG("isi", &isi)
call <SID>AddOption("iskeyword", gettext("specifies the characters in a keyword"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("isk")
call <SID>AddOption("isprint", gettext("specifies printable characters"))
call <SID>OptionG("isp", &isp)
if has("textobjects")
  call <SID>AddOption("quoteescape", gettext("specifies escape characters in a string"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("qe")
endif
if has("rightleft")
  call <SID>AddOption("rightleft", gettext("display the buffer right-to-left"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("rl")
  call <SID>AddOption("rightleftcmd", gettext("when to edit the command-line right-to-left"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>OptionL("rlc")
  call <SID>AddOption("revins", gettext("insert characters backwards"))
  call <SID>BinOptionG("ri", &ri)
  call <SID>AddOption("allowrevins", gettext("allow CTRL-_ in Insert and Command-line mode to toggle 'revins'"))
  call <SID>BinOptionG("ari", &ari)
  call <SID>AddOption("aleph", gettext("the ASCII code for the first letter of the Hebrew alphabet"))
  call append("$", " \tset al=" . &al)
  call <SID>AddOption("hkmap", gettext("use Hebrew keyboard mapping"))
  call <SID>BinOptionG("hk", &hk)
  call <SID>AddOption("hkmapp", gettext("use phonetic Hebrew keyboard mapping"))
  call <SID>BinOptionG("hkp", &hkp)
endif
if has("arabic")
  call <SID>AddOption("arabic", gettext("prepare for editing Arabic text"))
  call append("$", "\t" .. s:local_to_window)
  call <SID>BinOptionL("arab")
  call <SID>AddOption("arabicshape", gettext("perform shaping of Arabic characters"))
  call <SID>BinOptionG("arshape", &arshape)
  call <SID>AddOption("termbidi", gettext("terminal will perform bidi handling"))
  call <SID>BinOptionG("tbidi", &tbidi)
endif
if has("keymap")
  call <SID>AddOption("keymap", gettext("name of a keyboard mapping"))
  call <SID>OptionL("kmp")
endif
if has("langmap")
  call <SID>AddOption("langmap", gettext("list of characters that are translated in Normal mode"))
  call <SID>OptionG("lmap", &lmap)
  call <SID>AddOption("langremap", gettext("apply 'langmap' to mapped characters"))
  call <SID>BinOptionG("lrm", &lrm)
endif
if has("xim")
  call <SID>AddOption("imdisable", gettext("when set never use IM; overrules following IM options"))
  call <SID>BinOptionG("imd", &imd)
endif
call <SID>AddOption("iminsert", gettext("in Insert mode: 1: use :lmap; 2: use IM; 0: neither"))
call append("$", "\t" .. s:local_to_window)
call <SID>OptionL("imi")
call <SID>AddOption("imsearch", gettext("entering a search pattern: 1: use :lmap; 2: use IM; 0: neither"))
call append("$", "\t" .. s:local_to_window)
call <SID>OptionL("ims")
if has("xim")
  call <SID>AddOption("imcmdline", gettext("when set always use IM when starting to edit a command line"))
  call <SID>BinOptionG("imc", &imc)
  call <SID>AddOption("imstatusfunc", gettext("function to obtain IME status"))
  call <SID>OptionG("imsf", &imsf)
  call <SID>AddOption("imactivatefunc", gettext("function to enable/disable IME"))
  call <SID>OptionG("imaf", &imaf)
endif


call <SID>Header(gettext("multi-byte characters"))
call <SID>AddOption("encoding", gettext("character encoding used in Nvim: \"utf-8\""))
call <SID>OptionG("enc", &enc)
call <SID>AddOption("fileencoding", gettext("character encoding for the current file"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>OptionL("fenc")
call <SID>AddOption("fileencodings", gettext("automatically detected character encodings"))
call <SID>OptionG("fencs", &fencs)
call <SID>AddOption("charconvert", gettext("expression used for character encoding conversion"))
call <SID>OptionG("ccv", &ccv)
call <SID>AddOption("delcombine", gettext("delete combining (composing) characters on their own"))
call <SID>BinOptionG("deco", &deco)
call <SID>AddOption("maxcombine", gettext("maximum number of combining (composing) characters displayed"))
call <SID>OptionG("mco", &mco)
if has("xim") && has("gui_gtk")
  call <SID>AddOption("imactivatekey", gettext("key that activates the X input method"))
  call <SID>OptionG("imak", &imak)
endif
call <SID>AddOption("ambiwidth", gettext("width of ambiguous width characters"))
call <SID>OptionG("ambw", &ambw)
call <SID>AddOption("emoji", gettext("emoji characters are full width"))
call <SID>BinOptionG("emo", &emo)


call <SID>Header(gettext("various"))
call <SID>AddOption("virtualedit", gettext("when to use virtual editing: \"block\", \"insert\", \"all\"\nand/or \"onemore\""))
call <SID>OptionG("ve", &ve)
call <SID>AddOption("eventignore", gettext("list of autocommand events which are to be ignored"))
call <SID>OptionG("ei", &ei)
call <SID>AddOption("loadplugins", gettext("load plugin scripts when starting up"))
call <SID>BinOptionG("lpl", &lpl)
call <SID>AddOption("exrc", gettext("enable reading .vimrc/.exrc/.gvimrc in the current directory"))
call <SID>BinOptionG("ex", &ex)
call <SID>AddOption("secure", gettext("safer working with script files in the current directory"))
call <SID>BinOptionG("secure", &secure)
call <SID>AddOption("gdefault", gettext("use the 'g' flag for \":substitute\""))
call <SID>BinOptionG("gd", &gd)
if exists("+opendevice")
  call <SID>AddOption("opendevice", gettext("allow reading/writing devices"))
  call <SID>BinOptionG("odev", &odev)
endif
if exists("+maxfuncdepth")
  call <SID>AddOption("maxfuncdepth", gettext("maximum depth of function calls"))
  call append("$", " \tset mfd=" . &mfd)
endif
if has("mksession")
  call <SID>AddOption("sessionoptions", gettext("list of words that specifies what to put in a session file"))
  call <SID>OptionG("ssop", &ssop)
  call <SID>AddOption("viewoptions", gettext("list of words that specifies what to save for :mkview"))
  call <SID>OptionG("vop", &vop)
  call <SID>AddOption("viewdir", gettext("directory where to store files with :mkview"))
  call <SID>OptionG("vdir", &vdir)
endif
if has("shada")
  call <SID>AddOption("viminfo", gettext("list that specifies what to write in the ShaDa file"))
  call <SID>OptionG("vi", &vi)
endif
if has("quickfix")
  call <SID>AddOption("bufhidden", gettext("what happens with a buffer when it's no longer in a window"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("bh")
  call <SID>AddOption("buftype", gettext("empty, \"nofile\", \"nowrite\", \"quickfix\", etc.: type of buffer"))
  call append("$", "\t" .. s:local_to_buffer)
  call <SID>OptionL("bt")
endif
call <SID>AddOption("buflisted", gettext("whether the buffer shows up in the buffer list"))
call append("$", "\t" .. s:local_to_buffer)
call <SID>BinOptionL("bl")
call <SID>AddOption("debug", gettext("set to \"msg\" to see all error messages"))
call append("$", " \tset debug=" . &debug)
call <SID>AddOption("signcolumn", gettext("whether to show the signcolumn"))
call append("$", "\t" .. s:local_to_window)
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
  call <SID>AddOption("mzschemedll", gettext("name of the MzScheme dynamic library"))
  call <SID>OptionG("mzschemedll", &mzschemedll)
  call <SID>AddOption("mzschemegcdll", gettext("name of the MzScheme GC dynamic library"))
  call <SID>OptionG("mzschemegcdll", &mzschemegcdll)
endif
if has('pythonx')
  call <SID>AddOption("pyxversion", gettext("whether to use Python 2 or 3"))
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

func <SID>unload()
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
endfunc

" Restore the previous value of 'title' and 'icon'.
let &title = s:old_title
let &icon = s:old_icon
let &ru = s:old_ru
let &sc = s:old_sc
let &cpo = s:cpo_save
let &ul = s:old_ul
unlet s:old_title s:old_icon s:old_ru s:old_sc s:cpo_save s:idx s:lnum s:old_ul

" vim: ts=8 sw=2 sts=2
