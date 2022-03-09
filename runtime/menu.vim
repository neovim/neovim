" Vim support file to define the default menus
" You can also use this as a start for your own set of menus.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2019 Dec 10

" Note that ":an" (short for ":anoremenu") is often used to make a menu work
" in all modes and avoid side effects from mappings defined by the user.

" Make sure the '<' and 'C' flags are not included in 'cpoptions', otherwise
" <CR> would not be recognized.  See ":help 'cpoptions'".
let s:cpo_save = &cpo
set cpo&vim

" Avoid installing the menus twice
if !exists("did_install_default_menus")
let did_install_default_menus = 1


if exists("v:lang") || &langmenu != ""
  " Try to find a menu translation file for the current language.
  if &langmenu != ""
    if &langmenu =~ "none"
      let s:lang = ""
    else
      let s:lang = &langmenu
    endif
  else
    let s:lang = v:lang
  endif
  " A language name must be at least two characters, don't accept "C"
  " Also skip "en_US" to avoid picking up "en_gb" translations.
  if strlen(s:lang) > 1 && s:lang !~? '^en_us'
    " When the language does not include the charset add 'encoding'
    if s:lang =~ '^\a\a$\|^\a\a_\a\a$'
      let s:lang = s:lang . '.' . &enc
    endif

    " We always use a lowercase name.
    " Change "iso-8859" to "iso_8859" and "iso8859" to "iso_8859", some
    " systems appear to use this.
    " Change spaces to underscores.
    let s:lang = substitute(tolower(s:lang), '\.iso-', ".iso_", "")
    let s:lang = substitute(s:lang, '\.iso8859', ".iso_8859", "")
    let s:lang = substitute(s:lang, " ", "_", "g")
    " Remove "@euro", otherwise "LC_ALL=de_DE@euro gvim" will show English menus
    let s:lang = substitute(s:lang, "@euro", "", "")
    " Change "iso_8859-1" and "iso_8859-15" to "latin1", we always use the
    " same menu file for them.
    let s:lang = substitute(s:lang, 'iso_8859-15\=$', "latin1", "")
    menutrans clear
    exe "runtime! lang/menu_" . s:lang . ".vim"

    if !exists("did_menu_trans")
      " There is no exact match, try matching with a wildcard added
      " (e.g. find menu_de_de.iso_8859-1.vim if s:lang == de_DE).
      let s:lang = substitute(s:lang, '\.[^.]*', "", "")
      exe "runtime! lang/menu_" . s:lang . "[^a-z]*vim"

      if !exists("did_menu_trans") && s:lang =~ '_'
	" If the language includes a region try matching without that region.
	" (e.g. find menu_de.vim if s:lang == de_DE).
	let langonly = substitute(s:lang, '_.*', "", "")
	exe "runtime! lang/menu_" . langonly . "[^a-z]*vim"
      endif

      if !exists("did_menu_trans") && strlen($LANG) > 1 && s:lang !~ '^en_us'
	" On windows locale names are complicated, try using $LANG, it might
	" have been set by set_init_1().  But don't do this for "en" or "en_us".
	" But don't match "slovak" when $LANG is "sl".
	exe "runtime! lang/menu_" . tolower($LANG) . "[^a-z]*vim"
      endif
    endif
  endif
endif


" Help menu
an 9999.10 &Help.&Overview<Tab><F1>	:help<CR>
an 9999.20 &Help.&User\ Manual		:help usr_toc<CR>
an 9999.30 &Help.&How-To\ Links		:help how-to<CR>
an <silent> 9999.40 &Help.&Find\.\.\.	:call <SID>Helpfind()<CR>
an 9999.45 &Help.-sep1-			<Nop>
an 9999.50 &Help.&Credits		:help credits<CR>
an 9999.60 &Help.Co&pying		:help copying<CR>
an 9999.70 &Help.&Sponsor/Register	:help sponsor<CR>
an 9999.70 &Help.O&rphans		:help kcc<CR>
an 9999.75 &Help.-sep2-			<Nop>
an 9999.80 &Help.&Version		:version<CR>
an 9999.90 &Help.&About			:intro<CR>

fun! s:Helpfind()
  if !exists("g:menutrans_help_dialog")
    let g:menutrans_help_dialog = "Enter a command or word to find help on:\n\nPrepend i_ for Input mode commands (e.g.: i_CTRL-X)\nPrepend c_ for command-line editing commands (e.g.: c_<Del>)\nPrepend ' for an option name (e.g.: 'shiftwidth')"
  endif
  let h = inputdialog(g:menutrans_help_dialog)
  if h != ""
    let v:errmsg = ""
    silent! exe "help " . h
    if v:errmsg != ""
      echo v:errmsg
    endif
  endif
endfun

" File menu
an 10.310 &File.&Open\.\.\.<Tab>:e		:browse confirm e<CR>
an 10.320 &File.Sp&lit-Open\.\.\.<Tab>:sp	:browse sp<CR>
an 10.320 &File.Open\ Tab\.\.\.<Tab>:tabnew	:browse tabnew<CR>
an 10.325 &File.&New<Tab>:enew			:confirm enew<CR>
an <silent> 10.330 &File.&Close<Tab>:close
	\ :if winheight(2) < 0 && tabpagewinnr(2) == 0 <Bar>
	\   confirm enew <Bar>
	\ else <Bar>
	\   confirm close <Bar>
	\ endif<CR>
an 10.335 &File.-SEP1-				<Nop>
an <silent> 10.340 &File.&Save<Tab>:w		:if expand("%") == ""<Bar>browse confirm w<Bar>else<Bar>confirm w<Bar>endif<CR>
an 10.350 &File.Save\ &As\.\.\.<Tab>:sav	:browse confirm saveas<CR>

if has("diff")
  an 10.400 &File.-SEP2-			<Nop>
  an 10.410 &File.Split\ &Diff\ With\.\.\.	:browse vert diffsplit<CR>
  an 10.420 &File.Split\ Patched\ &By\.\.\.	:browse vert diffpatch<CR>
endif

if has("printer")
  an 10.500 &File.-SEP3-			<Nop>
  an 10.510 &File.&Print			:hardcopy<CR>
  vunmenu   &File.&Print
  vnoremenu &File.&Print			:hardcopy<CR>
elseif has("unix")
  an 10.500 &File.-SEP3-			<Nop>
  an 10.510 &File.&Print			:w !lpr<CR>
  vunmenu   &File.&Print
  vnoremenu &File.&Print			:w !lpr<CR>
endif
an 10.600 &File.-SEP4-				<Nop>
an 10.610 &File.Sa&ve-Exit<Tab>:wqa		:confirm wqa<CR>
an 10.620 &File.E&xit<Tab>:qa			:confirm qa<CR>

func! <SID>SelectAll()
  exe "norm! gg" . (&slm == "" ? "VG" : "gH\<C-O>G")
endfunc

func! s:FnameEscape(fname)
  if exists('*fnameescape')
    return fnameescape(a:fname)
  endif
  return escape(a:fname, " \t\n*?[{`$\\%#'\"|!<")
endfunc

" Edit menu
an 20.310 &Edit.&Undo<Tab>u			u
an 20.320 &Edit.&Redo<Tab>^R			<C-R>
an 20.330 &Edit.Rep&eat<Tab>\.			.

an 20.335 &Edit.-SEP1-				<Nop>
vnoremenu 20.340 &Edit.Cu&t<Tab>"+x		"+x
vnoremenu 20.350 &Edit.&Copy<Tab>"+y		"+y
cnoremenu 20.350 &Edit.&Copy<Tab>"+y		<C-Y>
if exists(':tlmenu')
  tlnoremenu 20.350 &Edit.&Copy<Tab>"+y 	<C-W>:<C-Y><CR>
endif
nnoremenu 20.360 &Edit.&Paste<Tab>"+gP		"+gP
cnoremenu	 &Edit.&Paste<Tab>"+gP		<C-R>+
exe 'vnoremenu <script> &Edit.&Paste<Tab>"+gP	' . paste#paste_cmd['v']
exe 'inoremenu <script> &Edit.&Paste<Tab>"+gP	' . paste#paste_cmd['i']
nnoremenu 20.370 &Edit.Put\ &Before<Tab>[p	[p
inoremenu	 &Edit.Put\ &Before<Tab>[p	<C-O>[p
nnoremenu 20.380 &Edit.Put\ &After<Tab>]p	]p
inoremenu	 &Edit.Put\ &After<Tab>]p	<C-O>]p
if has("win32")
  vnoremenu 20.390 &Edit.&Delete<Tab>x		x
endif
noremenu  <script> <silent> 20.400 &Edit.&Select\ All<Tab>ggVG	:<C-U>call <SID>SelectAll()<CR>
inoremenu <script> <silent> 20.400 &Edit.&Select\ All<Tab>ggVG	<C-O>:call <SID>SelectAll()<CR>
cnoremenu <script> <silent> 20.400 &Edit.&Select\ All<Tab>ggVG	<C-U>call <SID>SelectAll()<CR>

an 20.405	 &Edit.-SEP2-				<Nop>
if has("win32") || has("gui_gtk") || has("gui_kde") || has("gui_motif")
  an 20.410	 &Edit.&Find\.\.\.			:promptfind<CR>
  vunmenu	 &Edit.&Find\.\.\.
  vnoremenu <silent>	 &Edit.&Find\.\.\.		y:promptfind <C-R>=<SID>FixFText()<CR><CR>
  an 20.420	 &Edit.Find\ and\ Rep&lace\.\.\.	:promptrepl<CR>
  vunmenu	 &Edit.Find\ and\ Rep&lace\.\.\.
  vnoremenu <silent>	 &Edit.Find\ and\ Rep&lace\.\.\. y:promptrepl <C-R>=<SID>FixFText()<CR><CR>
else
  an 20.410	 &Edit.&Find<Tab>/			/
  an 20.420	 &Edit.Find\ and\ Rep&lace<Tab>:%s	:%s/
  vunmenu	 &Edit.Find\ and\ Rep&lace<Tab>:%s
  vnoremenu	 &Edit.Find\ and\ Rep&lace<Tab>:s	:s/
endif

an 20.425	 &Edit.-SEP3-				<Nop>
an 20.430	 &Edit.Settings\ &Window		:options<CR>
an 20.435	 &Edit.Startup\ &Settings		:call <SID>EditVimrc()<CR>

fun! s:EditVimrc()
  if $MYVIMRC != ''
    let fname = $MYVIMRC
  elseif has("win32")
    if $HOME != ''
      let fname = $HOME . "/_vimrc"
    else
      let fname = $VIM . "/_vimrc"
    endif
  elseif has("amiga")
    let fname = "s:.vimrc"
  else
    let fname = $HOME . "/.vimrc"
  endif
  let fname = s:FnameEscape(fname)
  if &mod
    exe "split " . fname
  else
    exe "edit " . fname
  endif
endfun

fun! s:FixFText()
  " Fix text in nameless register to be used with :promptfind.
  return substitute(@", "[\r\n]", '\\n', 'g')
endfun

" Edit/Global Settings
an 20.440.100 &Edit.&Global\ Settings.Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	:set hls! hls?<CR>
an 20.440.110 &Edit.&Global\ Settings.Toggle\ &Ignoring\ Case<Tab>:set\ ic!	:set ic! ic?<CR>
an 20.440.110 &Edit.&Global\ Settings.Toggle\ &Showing\ Matched\ Pairs<Tab>:set\ sm!	:set sm! sm?<CR>

an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 1\  :set so=1<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 2\  :set so=2<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 3\  :set so=3<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 4\  :set so=4<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 5\  :set so=5<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 7\  :set so=7<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 10\  :set so=10<CR>
an 20.440.120 &Edit.&Global\ Settings.&Context\ Lines.\ 100\  :set so=100<CR>

an 20.440.130.40 &Edit.&Global\ Settings.&Virtual\ Edit.Never :set ve=<CR>
an 20.440.130.50 &Edit.&Global\ Settings.&Virtual\ Edit.Block\ Selection :set ve=block<CR>
an 20.440.130.60 &Edit.&Global\ Settings.&Virtual\ Edit.Insert\ Mode :set ve=insert<CR>
an 20.440.130.70 &Edit.&Global\ Settings.&Virtual\ Edit.Block\ and\ Insert :set ve=block,insert<CR>
an 20.440.130.80 &Edit.&Global\ Settings.&Virtual\ Edit.Always :set ve=all<CR>
an 20.440.140 &Edit.&Global\ Settings.Toggle\ Insert\ &Mode<Tab>:set\ im!	:set im!<CR>
an 20.440.145 &Edit.&Global\ Settings.Toggle\ Vi\ C&ompatibility<Tab>:set\ cp!	:set cp!<CR>
an <silent> 20.440.150 &Edit.&Global\ Settings.Search\ &Path\.\.\.  :call <SID>SearchP()<CR>
an <silent> 20.440.160 &Edit.&Global\ Settings.Ta&g\ Files\.\.\.  :call <SID>TagFiles()<CR>
"
" GUI options
an 20.440.300 &Edit.&Global\ Settings.-SEP1-				<Nop>
an <silent> 20.440.310 &Edit.&Global\ Settings.Toggle\ &Toolbar		:call <SID>ToggleGuiOption("T")<CR>
an <silent> 20.440.320 &Edit.&Global\ Settings.Toggle\ &Bottom\ Scrollbar :call <SID>ToggleGuiOption("b")<CR>
an <silent> 20.440.330 &Edit.&Global\ Settings.Toggle\ &Left\ Scrollbar	:call <SID>ToggleGuiOption("l")<CR>
an <silent> 20.440.340 &Edit.&Global\ Settings.Toggle\ &Right\ Scrollbar :call <SID>ToggleGuiOption("r")<CR>

fun! s:SearchP()
  if !exists("g:menutrans_path_dialog")
    let g:menutrans_path_dialog = "Enter search path for files.\nSeparate directory names with a comma."
  endif
  let n = inputdialog(g:menutrans_path_dialog, substitute(&path, '\\ ', ' ', 'g'))
  if n != ""
    let &path = substitute(n, ' ', '\\ ', 'g')
  endif
endfun

fun! s:TagFiles()
  if !exists("g:menutrans_tags_dialog")
    let g:menutrans_tags_dialog = "Enter names of tag files.\nSeparate the names with a comma."
  endif
  let n = inputdialog(g:menutrans_tags_dialog, substitute(&tags, '\\ ', ' ', 'g'))
  if n != ""
    let &tags = substitute(n, ' ', '\\ ', 'g')
  endif
endfun

fun! s:ToggleGuiOption(option)
    " If a:option is already set in guioptions, then we want to remove it
    if match(&guioptions, "\\C" . a:option) > -1
	exec "set go-=" . a:option
    else
	exec "set go+=" . a:option
    endif
endfun

" Edit/File Settings

" Boolean options
an 20.440.100 &Edit.F&ile\ Settings.Toggle\ Line\ &Numbering<Tab>:set\ nu!	:set nu! nu?<CR>
an 20.440.105 &Edit.F&ile\ Settings.Toggle\ Relati&ve\ Line\ Numbering<Tab>:set\ rnu!	:set rnu! rnu?<CR>
an 20.440.110 &Edit.F&ile\ Settings.Toggle\ &List\ Mode<Tab>:set\ list!	:set list! list?<CR>
an 20.440.120 &Edit.F&ile\ Settings.Toggle\ Line\ &Wrapping<Tab>:set\ wrap!	:set wrap! wrap?<CR>
an 20.440.130 &Edit.F&ile\ Settings.Toggle\ W&rapping\ at\ Word<Tab>:set\ lbr!	:set lbr! lbr?<CR>
an 20.440.160 &Edit.F&ile\ Settings.Toggle\ Tab\ &Expanding<Tab>:set\ et!	:set et! et?<CR>
an 20.440.170 &Edit.F&ile\ Settings.Toggle\ &Auto\ Indenting<Tab>:set\ ai!	:set ai! ai?<CR>
an 20.440.180 &Edit.F&ile\ Settings.Toggle\ &C-Style\ Indenting<Tab>:set\ cin!	:set cin! cin?<CR>

" other options
an 20.440.600 &Edit.F&ile\ Settings.-SEP2-		<Nop>
an 20.440.610.20 &Edit.F&ile\ Settings.&Shiftwidth.2	:set sw=2 sw?<CR>
an 20.440.610.30 &Edit.F&ile\ Settings.&Shiftwidth.3	:set sw=3 sw?<CR>
an 20.440.610.40 &Edit.F&ile\ Settings.&Shiftwidth.4	:set sw=4 sw?<CR>
an 20.440.610.50 &Edit.F&ile\ Settings.&Shiftwidth.5	:set sw=5 sw?<CR>
an 20.440.610.60 &Edit.F&ile\ Settings.&Shiftwidth.6	:set sw=6 sw?<CR>
an 20.440.610.80 &Edit.F&ile\ Settings.&Shiftwidth.8	:set sw=8 sw?<CR>

an 20.440.620.20 &Edit.F&ile\ Settings.Soft\ &Tabstop.2	:set sts=2 sts?<CR>
an 20.440.620.30 &Edit.F&ile\ Settings.Soft\ &Tabstop.3	:set sts=3 sts?<CR>
an 20.440.620.40 &Edit.F&ile\ Settings.Soft\ &Tabstop.4	:set sts=4 sts?<CR>
an 20.440.620.50 &Edit.F&ile\ Settings.Soft\ &Tabstop.5	:set sts=5 sts?<CR>
an 20.440.620.60 &Edit.F&ile\ Settings.Soft\ &Tabstop.6	:set sts=6 sts?<CR>
an 20.440.620.80 &Edit.F&ile\ Settings.Soft\ &Tabstop.8	:set sts=8 sts?<CR>

an <silent> 20.440.630 &Edit.F&ile\ Settings.Te&xt\ Width\.\.\.  :call <SID>TextWidth()<CR>
an <silent> 20.440.640 &Edit.F&ile\ Settings.&File\ Format\.\.\.  :call <SID>FileFormat()<CR>
fun! s:TextWidth()
  if !exists("g:menutrans_textwidth_dialog")
    let g:menutrans_textwidth_dialog = "Enter new text width (0 to disable formatting): "
  endif
  let n = inputdialog(g:menutrans_textwidth_dialog, &tw)
  if n != ""
    " Remove leading zeros to avoid it being used as an octal number.
    " But keep a zero by itself.
    let tw = substitute(n, "^0*", "", "")
    let &tw = tw == '' ? 0 : tw
  endif
endfun

fun! s:FileFormat()
  if !exists("g:menutrans_fileformat_dialog")
    let g:menutrans_fileformat_dialog = "Select format for writing the file"
  endif
  if !exists("g:menutrans_fileformat_choices")
    let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\n&Cancel"
  endif
  if &ff == "dos"
    let def = 2
  elseif &ff == "mac"
    let def = 3
  else
    let def = 1
  endif
  let n = confirm(g:menutrans_fileformat_dialog, g:menutrans_fileformat_choices, def, "Question")
  if n == 1
    set ff=unix
  elseif n == 2
    set ff=dos
  elseif n == 3
    set ff=mac
  endif
endfun

let s:did_setup_color_schemes = 0

" Setup the Edit.Color Scheme submenu
func! s:SetupColorSchemes() abort
  if s:did_setup_color_schemes
    return
  endif
  let s:did_setup_color_schemes = 1

  let n = globpath(&runtimepath, "colors/*.vim", 1, 1)
  let n += globpath(&packpath, "pack/*/start/*/colors/*.vim", 1, 1)
  let n += globpath(&packpath, "pack/*/opt/*/colors/*.vim", 1, 1)

  " Ignore case for VMS and windows, sort on name
  let names = sort(map(n, 'substitute(v:val, "\\c.*[/\\\\:\\]]\\([^/\\\\:]*\\)\\.vim", "\\1", "")'), 1)

  " define all the submenu entries
  let idx = 100
  for name in names
    exe "an 20.450." . idx . ' &Edit.C&olor\ Scheme.' . name . " :colors " . name . "<CR>"
    let idx = idx + 10
  endfor
  silent! aunmenu &Edit.Show\ C&olor\ Schemes\ in\ Menu
endfun
if exists("do_no_lazyload_menus")
  call s:SetupColorSchemes()
else
  an <silent> 20.450 &Edit.Show\ C&olor\ Schemes\ in\ Menu :call <SID>SetupColorSchemes()<CR>
endif


" Setup the Edit.Keymap submenu
if has("keymap")
  let s:did_setup_keymaps = 0

  func! s:SetupKeymaps() abort
    if s:did_setup_keymaps
      return
    endif
    let s:did_setup_keymaps = 1

    let n = globpath(&runtimepath, "keymap/*.vim", 1, 1)
    if !empty(n)
      let idx = 100
      an 20.460.90 &Edit.&Keymap.None :set keymap=<CR>
      for name in n
	" Ignore case for VMS and windows
	let name = substitute(name, '\c.*[/\\:\]]\([^/\\:_]*\)\(_[0-9a-zA-Z-]*\)\=\.vim', '\1', '')
	exe "an 20.460." . idx . ' &Edit.&Keymap.' . name . " :set keymap=" . name . "<CR>"
	let idx = idx + 10
      endfor
    endif
    silent! aunmenu &Edit.Show\ &Keymaps\ in\ Menu
  endfun
  if exists("do_no_lazyload_menus")
    call s:SetupKeymaps()
  else
    an <silent> 20.460 &Edit.Show\ &Keymaps\ in\ Menu :call <SID>SetupKeymaps()<CR>
  endif
endif
if has("win32") || has("gui_motif") || has("gui_gtk") || has("gui_kde") || has("gui_photon") || has("gui_mac")
  an 20.470 &Edit.Select\ Fo&nt\.\.\.	:set guifont=*<CR>
endif

" Programming menu
if !exists("g:ctags_command")
  if has("vms")
    let g:ctags_command = "mc vim:ctags *.*"
  else
    let g:ctags_command = "ctags -R ."
  endif
endif

an 40.300 &Tools.&Jump\ to\ This\ Tag<Tab>g^]	g<C-]>
vunmenu &Tools.&Jump\ to\ This\ Tag<Tab>g^]
vnoremenu &Tools.&Jump\ to\ This\ Tag<Tab>g^]	g<C-]>
an 40.310 &Tools.Jump\ &Back<Tab>^T		<C-T>
an 40.320 &Tools.Build\ &Tags\ File		:exe "!" . g:ctags_command<CR>

if has("folding") || has("spell")
  an 40.330 &Tools.-SEP1-						<Nop>
endif

" Tools.Spelling Menu
if has("spell")
  an 40.335.110 &Tools.&Spelling.&Spell\ Check\ On		:set spell<CR>
  an 40.335.120 &Tools.&Spelling.Spell\ Check\ &Off		:set nospell<CR>
  an 40.335.130 &Tools.&Spelling.To\ &Next\ Error<Tab>]s	]s
  an 40.335.130 &Tools.&Spelling.To\ &Previous\ Error<Tab>[s	[s
  an 40.335.140 &Tools.&Spelling.Suggest\ &Corrections<Tab>z=	z=
  an 40.335.150 &Tools.&Spelling.&Repeat\ Correction<Tab>:spellrepall	:spellrepall<CR>
  an 40.335.200 &Tools.&Spelling.-SEP1-				<Nop>
  an 40.335.210 &Tools.&Spelling.Set\ Language\ to\ "en"	:set spl=en spell<CR>
  an 40.335.220 &Tools.&Spelling.Set\ Language\ to\ "en_au"	:set spl=en_au spell<CR>
  an 40.335.230 &Tools.&Spelling.Set\ Language\ to\ "en_ca"	:set spl=en_ca spell<CR>
  an 40.335.240 &Tools.&Spelling.Set\ Language\ to\ "en_gb"	:set spl=en_gb spell<CR>
  an 40.335.250 &Tools.&Spelling.Set\ Language\ to\ "en_nz"	:set spl=en_nz spell<CR>
  an 40.335.260 &Tools.&Spelling.Set\ Language\ to\ "en_us"	:set spl=en_us spell<CR>
  an <silent> 40.335.270 &Tools.&Spelling.&Find\ More\ Languages	:call <SID>SpellLang()<CR>

  let s:undo_spelllang = ['aun &Tools.&Spelling.&Find\ More\ Languages']
  func! s:SpellLang()
    for cmd in s:undo_spelllang
      exe "silent! " . cmd
    endfor
    let s:undo_spelllang = []

    if &enc == "iso-8859-15"
      let enc = "latin1"
    else
      let enc = &enc
    endif

    if !exists("g:menutrans_set_lang_to")
      let g:menutrans_set_lang_to = 'Set Language to'
    endif

    let found = 0
    let s = globpath(&runtimepath, "spell/*." . enc . ".spl", 1, 1)
    if !empty(s)
      let n = 300
      for f in s
	let nm = substitute(f, '.*spell[/\\]\(..\)\.[^/\\]*\.spl', '\1', "")
	if nm != "en" && nm !~ '/'
          let _nm = nm
	  let found += 1
	  let menuname = '&Tools.&Spelling.' . escape(g:menutrans_set_lang_to, "\\. \t|") . '\ "' . nm . '"'
	  exe 'an 40.335.' . n . ' ' . menuname . ' :set spl=' . nm . ' spell<CR>'
	  let s:undo_spelllang += ['aun ' . menuname]
	endif
	let n += 10
      endfor
    endif
    if found == 0
      echomsg "Could not find other spell files"
    elseif found == 1
      echomsg "Found spell file " . _nm
    else
      echomsg "Found " . found . " more spell files"
    endif
    " Need to redo this when 'encoding' is changed.
    augroup spellmenu
    au! EncodingChanged * call <SID>SpellLang()
    augroup END
  endfun

endif

" Tools.Fold Menu
if has("folding")
  " open close folds
  an 40.340.110 &Tools.&Folding.&Enable/Disable\ Folds<Tab>zi		zi
  an 40.340.120 &Tools.&Folding.&View\ Cursor\ Line<Tab>zv		zv
  an 40.340.120 &Tools.&Folding.Vie&w\ Cursor\ Line\ Only<Tab>zMzx	zMzx
  inoremenu 40.340.120 &Tools.&Folding.Vie&w\ Cursor\ Line\ Only<Tab>zMzx  <C-O>zM<C-O>zx
  an 40.340.130 &Tools.&Folding.C&lose\ More\ Folds<Tab>zm		zm
  an 40.340.140 &Tools.&Folding.&Close\ All\ Folds<Tab>zM		zM
  an 40.340.150 &Tools.&Folding.O&pen\ More\ Folds<Tab>zr		zr
  an 40.340.160 &Tools.&Folding.&Open\ All\ Folds<Tab>zR		zR
  " fold method
  an 40.340.200 &Tools.&Folding.-SEP1-			<Nop>
  an 40.340.210 &Tools.&Folding.Fold\ Met&hod.M&anual	:set fdm=manual<CR>
  an 40.340.210 &Tools.&Folding.Fold\ Met&hod.I&ndent	:set fdm=indent<CR>
  an 40.340.210 &Tools.&Folding.Fold\ Met&hod.E&xpression :set fdm=expr<CR>
  an 40.340.210 &Tools.&Folding.Fold\ Met&hod.S&yntax	:set fdm=syntax<CR>
  an 40.340.210 &Tools.&Folding.Fold\ Met&hod.&Diff	:set fdm=diff<CR>
  an 40.340.210 &Tools.&Folding.Fold\ Met&hod.Ma&rker	:set fdm=marker<CR>
  " create and delete folds
  vnoremenu 40.340.220 &Tools.&Folding.Create\ &Fold<Tab>zf	zf
  an 40.340.230 &Tools.&Folding.&Delete\ Fold<Tab>zd		zd
  an 40.340.240 &Tools.&Folding.Delete\ &All\ Folds<Tab>zD	zD
  " moving around in folds
  an 40.340.300 &Tools.&Folding.-SEP2-				<Nop>
  an 40.340.310.10 &Tools.&Folding.Fold\ Col&umn\ Width.\ &0\ 	:set fdc=0<CR>
  an 40.340.310.20 &Tools.&Folding.Fold\ Col&umn\ Width.\ &2\ 	:set fdc=2<CR>
  an 40.340.310.30 &Tools.&Folding.Fold\ Col&umn\ Width.\ &3\ 	:set fdc=3<CR>
  an 40.340.310.40 &Tools.&Folding.Fold\ Col&umn\ Width.\ &4\ 	:set fdc=4<CR>
  an 40.340.310.50 &Tools.&Folding.Fold\ Col&umn\ Width.\ &5\ 	:set fdc=5<CR>
  an 40.340.310.60 &Tools.&Folding.Fold\ Col&umn\ Width.\ &6\ 	:set fdc=6<CR>
  an 40.340.310.70 &Tools.&Folding.Fold\ Col&umn\ Width.\ &7\ 	:set fdc=7<CR>
  an 40.340.310.80 &Tools.&Folding.Fold\ Col&umn\ Width.\ &8\ 	:set fdc=8<CR>
endif  " has folding

if has("diff")
  an 40.350.100 &Tools.&Diff.&Update		:diffupdate<CR>
  an 40.350.110 &Tools.&Diff.&Get\ Block	:diffget<CR>
  vunmenu &Tools.&Diff.&Get\ Block
  vnoremenu &Tools.&Diff.&Get\ Block		:diffget<CR>
  an 40.350.120 &Tools.&Diff.&Put\ Block	:diffput<CR>
  vunmenu &Tools.&Diff.&Put\ Block
  vnoremenu &Tools.&Diff.&Put\ Block		:diffput<CR>
endif

an 40.358 &Tools.-SEP2-					<Nop>
an 40.360 &Tools.&Make<Tab>:make			:make<CR>
an 40.370 &Tools.&List\ Errors<Tab>:cl			:cl<CR>
an 40.380 &Tools.L&ist\ Messages<Tab>:cl!		:cl!<CR>
an 40.390 &Tools.&Next\ Error<Tab>:cn			:cn<CR>
an 40.400 &Tools.&Previous\ Error<Tab>:cp		:cp<CR>
an 40.410 &Tools.&Older\ List<Tab>:cold			:colder<CR>
an 40.420 &Tools.N&ewer\ List<Tab>:cnew			:cnewer<CR>
an 40.430.50 &Tools.Error\ &Window.&Update<Tab>:cwin	:cwin<CR>
an 40.430.60 &Tools.Error\ &Window.&Open<Tab>:copen	:copen<CR>
an 40.430.70 &Tools.Error\ &Window.&Close<Tab>:cclose	:cclose<CR>

an 40.520 &Tools.-SEP3-					<Nop>
an <silent> 40.530 &Tools.&Convert\ to\ HEX<Tab>:%!xxd
	\ :call <SID>XxdConv()<CR>
an <silent> 40.540 &Tools.Conve&rt\ Back<Tab>:%!xxd\ -r
	\ :call <SID>XxdBack()<CR>

" Use a function to do the conversion, so that it also works with 'insertmode'
" set.
func! s:XxdConv()
  let mod = &mod
  if has("vms")
    %!mc vim:xxd
  else
    call s:XxdFind()
    exe ':%!' . g:xxdprogram
  endif
  if getline(1) =~ "^00000000:"		" only if it worked
    set ft=xxd
  endif
  let &mod = mod
endfun

func! s:XxdBack()
  let mod = &mod
  if has("vms")
    %!mc vim:xxd -r
  else
    call s:XxdFind()
    exe ':%!' . g:xxdprogram . ' -r'
  endif
  set ft=
  doautocmd filetypedetect BufReadPost
  let &mod = mod
endfun

func! s:XxdFind()
  if !exists("g:xxdprogram")
    " On the PC xxd may not be in the path but in the install directory
    if has("win32") && !executable("xxd")
      let g:xxdprogram = $VIMRUNTIME . (&shellslash ? '/' : '\') . "xxd.exe"
      if g:xxdprogram =~ ' '
	let g:xxdprogram = '"' .. g:xxdprogram .. '"'
      endif
    else
      let g:xxdprogram = "xxd"
    endif
  endif
endfun

let s:did_setup_compilers = 0

" Setup the Tools.Compiler submenu
func! s:SetupCompilers() abort
  if s:did_setup_compilers
    return
  endif
  let s:did_setup_compilers = 1

  let n = globpath(&runtimepath, "compiler/*.vim", 1, 1)
  let idx = 100
  for name in n
    " Ignore case for VMS and windows
    let name = substitute(name, '\c.*[/\\:\]]\([^/\\:]*\)\.vim', '\1', '')
    exe "an 30.440." . idx . ' &Tools.Se&t\ Compiler.' . name . " :compiler " . name . "<CR>"
    let idx = idx + 10
  endfor
  silent! aunmenu &Tools.Show\ Compiler\ Se&ttings\ in\ Menu
endfun
if exists("do_no_lazyload_menus")
  call s:SetupCompilers()
else
  an <silent> 30.440 &Tools.Show\ Compiler\ Se&ttings\ in\ Menu :call <SID>SetupCompilers()<CR>
endif

" Load ColorScheme, Compiler Setting and Keymap menus when idle.
if !exists("do_no_lazyload_menus")
  func! s:SetupLazyloadMenus()
    call s:SetupColorSchemes()
    call s:SetupCompilers()
    if has("keymap")
      call s:SetupKeymaps()
    endif
  endfunc
  augroup SetupLazyloadMenus
    au!
    au CursorHold,CursorHoldI * call <SID>SetupLazyloadMenus() | au! SetupLazyloadMenus
  augroup END
endif


if !exists("no_buffers_menu")

" Buffer list menu -- Setup functions & actions

" wait with building the menu until after loading 'session' files. Makes
" startup faster.
let s:bmenu_wait = 1

if !exists("bmenu_priority")
  let bmenu_priority = 60
endif

func! s:BMAdd()
  if s:bmenu_wait == 0
    " when adding too many buffers, redraw in short format
    if s:bmenu_count == &menuitems && s:bmenu_short == 0
      call s:BMShow()
    else
      call <SID>BMFilename(expand("<afile>"), expand("<abuf>"))
      let s:bmenu_count = s:bmenu_count + 1
    endif
  endif
endfunc

func! s:BMRemove()
  if s:bmenu_wait == 0
    let name = expand("<afile>")
    if isdirectory(name)
      return
    endif
    let munge = <SID>BMMunge(name, expand("<abuf>"))

    if s:bmenu_short == 0
      exe 'silent! aun &Buffers.' . munge
    else
      exe 'silent! aun &Buffers.' . <SID>BMHash2(munge) . munge
    endif
    let s:bmenu_count = s:bmenu_count - 1
  endif
endfunc

" Create the buffer menu (delete an existing one first).
func! s:BMShow(...)
  let s:bmenu_wait = 1
  let s:bmenu_short = 1
  let s:bmenu_count = 0
  "
  " get new priority, if exists
  if a:0 == 1
    let g:bmenu_priority = a:1
  endif

  " Remove old menu, if exists; keep one entry to avoid a torn off menu to
  " disappear.  Use try/catch to avoid setting v:errmsg
  try | unmenu &Buffers | catch | endtry
  exe 'noremenu ' . g:bmenu_priority . ".1 &Buffers.Dummy l"
  try | unmenu! &Buffers | catch | endtry

  " create new menu; set 'cpo' to include the <CR>
  let cpo_save = &cpo
  set cpo&vim
  exe 'an <silent> ' . g:bmenu_priority . ".2 &Buffers.&Refresh\\ menu :call <SID>BMShow()<CR>"
  exe 'an ' . g:bmenu_priority . ".4 &Buffers.&Delete :confirm bd<CR>"
  exe 'an ' . g:bmenu_priority . ".6 &Buffers.&Alternate :confirm b #<CR>"
  exe 'an ' . g:bmenu_priority . ".7 &Buffers.&Next :confirm bnext<CR>"
  exe 'an ' . g:bmenu_priority . ".8 &Buffers.&Previous :confirm bprev<CR>"
  exe 'an ' . g:bmenu_priority . ".9 &Buffers.-SEP- :"
  let &cpo = cpo_save
  unmenu &Buffers.Dummy

  " figure out how many buffers there are
  let buf = 1
  while buf <= bufnr('$')
    if bufexists(buf) && !isdirectory(bufname(buf)) && buflisted(buf)
      let s:bmenu_count = s:bmenu_count + 1
    endif
    let buf = buf + 1
  endwhile
  if s:bmenu_count <= &menuitems
    let s:bmenu_short = 0
  endif

  " iterate through buffer list, adding each buffer to the menu:
  let buf = 1
  while buf <= bufnr('$')
    if bufexists(buf) && !isdirectory(bufname(buf)) && buflisted(buf)
      call <SID>BMFilename(bufname(buf), buf)
    endif
    let buf = buf + 1
  endwhile
  let s:bmenu_wait = 0
  aug buffer_list
  au!
  au BufCreate,BufFilePost * call <SID>BMAdd()
  au BufDelete,BufFilePre * call <SID>BMRemove()
  aug END
endfunc

func! s:BMHash(name)
  " Make name all upper case, so that chars are between 32 and 96
  let nm = substitute(a:name, ".*", '\U\0', "")
  if has("ebcdic")
    " HACK: Replace all non alphabetics with 'Z'
    "       Just to make it work for now.
    let nm = substitute(nm, "[^A-Z]", 'Z', "g")
    let sp = char2nr('A') - 1
  else
    let sp = char2nr(' ')
  endif
  " convert first six chars into a number for sorting:
  return (char2nr(nm[0]) - sp) * 0x800000 + (char2nr(nm[1]) - sp) * 0x20000 + (char2nr(nm[2]) - sp) * 0x1000 + (char2nr(nm[3]) - sp) * 0x80 + (char2nr(nm[4]) - sp) * 0x20 + (char2nr(nm[5]) - sp)
endfunc

func! s:BMHash2(name)
  let nm = substitute(a:name, ".", '\L\0', "")
  " Not exactly right for EBCDIC...
  if nm[0] < 'a' || nm[0] > 'z'
    return '&others.'
  elseif nm[0] <= 'd'
    return '&abcd.'
  elseif nm[0] <= 'h'
    return '&efgh.'
  elseif nm[0] <= 'l'
    return '&ijkl.'
  elseif nm[0] <= 'p'
    return '&mnop.'
  elseif nm[0] <= 't'
    return '&qrst.'
  else
    return '&u-z.'
  endif
endfunc

" insert a buffer name into the buffer menu:
func! s:BMFilename(name, num)
  if isdirectory(a:name)
    return
  endif
  let munge = <SID>BMMunge(a:name, a:num)
  let hash = <SID>BMHash(munge)
  if s:bmenu_short == 0
    let name = 'an ' . g:bmenu_priority . '.' . hash . ' &Buffers.' . munge
  else
    let name = 'an ' . g:bmenu_priority . '.' . hash . '.' . hash . ' &Buffers.' . <SID>BMHash2(munge) . munge
  endif
  " set 'cpo' to include the <CR>
  let cpo_save = &cpo
  set cpo&vim
  exe name . ' :confirm b' . a:num . '<CR>'
  let &cpo = cpo_save
endfunc

" Truncate a long path to fit it in a menu item.
if !exists("g:bmenu_max_pathlen")
  let g:bmenu_max_pathlen = 35
endif
func! s:BMTruncName(fname)
  let name = a:fname
  if g:bmenu_max_pathlen < 5
    let name = ""
  else
    let len = strlen(name)
    if len > g:bmenu_max_pathlen
      let amountl = (g:bmenu_max_pathlen / 2) - 2
      let amountr = g:bmenu_max_pathlen - amountl - 3
      let pattern = '^\(.\{,' . amountl . '}\).\{-}\(.\{,' . amountr . '}\)$'
      let left = substitute(name, pattern, '\1', '')
      let right = substitute(name, pattern, '\2', '')
      if strlen(left) + strlen(right) < len
	let name = left . '...' . right
      endif
    endif
  endif
  return name
endfunc

func! s:BMMunge(fname, bnum)
  let name = a:fname
  if name == ''
    if !exists("g:menutrans_no_file")
      let g:menutrans_no_file = "[No Name]"
    endif
    let name = g:menutrans_no_file
  else
    let name = fnamemodify(name, ':p:~')
  endif
  " detach file name and separate it out:
  let name2 = fnamemodify(name, ':t')
  if a:bnum >= 0
    let name2 = name2 . ' (' . a:bnum . ')'
  endif
  let name = name2 . "\t" . <SID>BMTruncName(fnamemodify(name,':h'))
  let name = escape(name, "\\. \t|")
  let name = substitute(name, "&", "&&", "g")
  let name = substitute(name, "\n", "^@", "g")
  return name
endfunc

" When just starting Vim, load the buffer menu later
if has("vim_starting")
  augroup LoadBufferMenu
    au! VimEnter * if !exists("no_buffers_menu") | call <SID>BMShow() | endif
    au  VimEnter * au! LoadBufferMenu
  augroup END
else
  call <SID>BMShow()
endif

endif " !exists("no_buffers_menu")

" Window menu
an 70.300 &Window.&New<Tab>^Wn			<C-W>n
an 70.310 &Window.S&plit<Tab>^Ws		<C-W>s
an 70.320 &Window.Sp&lit\ To\ #<Tab>^W^^	<C-W><C-^>
an 70.330 &Window.Split\ &Vertically<Tab>^Wv	<C-W>v
an <silent> 70.332 &Window.Split\ File\ E&xplorer	:call MenuExplOpen()<CR>
if !exists("*MenuExplOpen")
  fun MenuExplOpen()
    if @% == ""
      20vsp .
    else
      exe "20vsp " . s:FnameEscape(expand("%:p:h"))
    endif
  endfun
endif
an 70.335 &Window.-SEP1-				<Nop>
an 70.340 &Window.&Close<Tab>^Wc			:confirm close<CR>
an 70.345 &Window.Close\ &Other(s)<Tab>^Wo		:confirm only<CR>
an 70.350 &Window.-SEP2-				<Nop>
an 70.355 &Window.Move\ &To.&Top<Tab>^WK		<C-W>K
an 70.355 &Window.Move\ &To.&Bottom<Tab>^WJ		<C-W>J
an 70.355 &Window.Move\ &To.&Left\ Side<Tab>^WH		<C-W>H
an 70.355 &Window.Move\ &To.&Right\ Side<Tab>^WL	<C-W>L
an 70.360 &Window.Rotate\ &Up<Tab>^WR			<C-W>R
an 70.362 &Window.Rotate\ &Down<Tab>^Wr			<C-W>r
an 70.365 &Window.-SEP3-				<Nop>
an 70.370 &Window.&Equal\ Size<Tab>^W=			<C-W>=
an 70.380 &Window.&Max\ Height<Tab>^W_			<C-W>_
an 70.390 &Window.M&in\ Height<Tab>^W1_			<C-W>1_
an 70.400 &Window.Max\ &Width<Tab>^W\|			<C-W>\|
an 70.410 &Window.Min\ Widt&h<Tab>^W1\|			<C-W>1\|

" The popup menu
an 1.10 PopUp.&Undo			u
an 1.15 PopUp.-SEP1-			<Nop>
vnoremenu 1.20 PopUp.Cu&t		"+x
vnoremenu 1.30 PopUp.&Copy		"+y
cnoremenu 1.30 PopUp.&Copy		<C-Y>
nnoremenu 1.40 PopUp.&Paste		"+gP
cnoremenu 1.40 PopUp.&Paste		<C-R>+
exe 'vnoremenu <script> 1.40 PopUp.&Paste	' . paste#paste_cmd['v']
exe 'inoremenu <script> 1.40 PopUp.&Paste	' . paste#paste_cmd['i']
vnoremenu 1.50 PopUp.&Delete		x
an 1.55 PopUp.-SEP2-			<Nop>
vnoremenu 1.60 PopUp.Select\ Blockwise	<C-V>

nnoremenu 1.70 PopUp.Select\ &Word	vaw
onoremenu 1.70 PopUp.Select\ &Word	aw
vnoremenu 1.70 PopUp.Select\ &Word	<C-C>vaw
inoremenu 1.70 PopUp.Select\ &Word	<C-O>vaw
cnoremenu 1.70 PopUp.Select\ &Word	<C-C>vaw

nnoremenu 1.73 PopUp.Select\ &Sentence	vas
onoremenu 1.73 PopUp.Select\ &Sentence	as
vnoremenu 1.73 PopUp.Select\ &Sentence	<C-C>vas
inoremenu 1.73 PopUp.Select\ &Sentence	<C-O>vas
cnoremenu 1.73 PopUp.Select\ &Sentence	<C-C>vas

nnoremenu 1.77 PopUp.Select\ Pa&ragraph	vap
onoremenu 1.77 PopUp.Select\ Pa&ragraph	ap
vnoremenu 1.77 PopUp.Select\ Pa&ragraph	<C-C>vap
inoremenu 1.77 PopUp.Select\ Pa&ragraph	<C-O>vap
cnoremenu 1.77 PopUp.Select\ Pa&ragraph	<C-C>vap

nnoremenu 1.80 PopUp.Select\ &Line	V
onoremenu 1.80 PopUp.Select\ &Line	<C-C>V
vnoremenu 1.80 PopUp.Select\ &Line	<C-C>V
inoremenu 1.80 PopUp.Select\ &Line	<C-O>V
cnoremenu 1.80 PopUp.Select\ &Line	<C-C>V

nnoremenu 1.90 PopUp.Select\ &Block	<C-V>
onoremenu 1.90 PopUp.Select\ &Block	<C-C><C-V>
vnoremenu 1.90 PopUp.Select\ &Block	<C-C><C-V>
inoremenu 1.90 PopUp.Select\ &Block	<C-O><C-V>
cnoremenu 1.90 PopUp.Select\ &Block	<C-C><C-V>

noremenu  <script> <silent> 1.100 PopUp.Select\ &All	:<C-U>call <SID>SelectAll()<CR>
inoremenu <script> <silent> 1.100 PopUp.Select\ &All	<C-O>:call <SID>SelectAll()<CR>
cnoremenu <script> <silent> 1.100 PopUp.Select\ &All	<C-U>call <SID>SelectAll()<CR>

if has("spell")
  " Spell suggestions in the popup menu.  Note that this will slow down the
  " appearance of the menu!
  func! <SID>SpellPopup()
    if exists("s:changeitem") && s:changeitem != ''
      call <SID>SpellDel()
    endif

    " Return quickly if spell checking is not enabled.
    if !&spell || &spelllang == ''
      return
    endif

    let curcol = col('.')
    let [w, a] = spellbadword()
    if col('.') > curcol		" don't use word after the cursor
      let w = ''
    endif
    if w != ''
      if a == 'caps'
	let s:suglist = [substitute(w, '.*', '\u&', '')]
      else
	let s:suglist = spellsuggest(w, 10)
      endif
      if len(s:suglist) > 0
	if !exists("g:menutrans_spell_change_ARG_to")
	  let g:menutrans_spell_change_ARG_to = 'Change\ "%s"\ to'
	endif
	let s:changeitem = printf(g:menutrans_spell_change_ARG_to, escape(w, ' .'))
	let s:fromword = w
	let pri = 1
	" set 'cpo' to include the <CR>
	let cpo_save = &cpo
	set cpo&vim
	for sug in s:suglist
	  exe 'anoremenu 1.5.' . pri . ' PopUp.' . s:changeitem . '.' . escape(sug, ' .')
		\ . ' :call <SID>SpellReplace(' . pri . ')<CR>'
	  let pri += 1
	endfor

	if !exists("g:menutrans_spell_add_ARG_to_word_list")
	  let g:menutrans_spell_add_ARG_to_word_list = 'Add\ "%s"\ to\ Word\ List'
	endif
	let s:additem = printf(g:menutrans_spell_add_ARG_to_word_list, escape(w, ' .'))
	exe 'anoremenu 1.6 PopUp.' . s:additem . ' :spellgood ' . w . '<CR>'

	if !exists("g:menutrans_spell_ignore_ARG")
	  let g:menutrans_spell_ignore_ARG = 'Ignore\ "%s"'
	endif
	let s:ignoreitem = printf(g:menutrans_spell_ignore_ARG, escape(w, ' .'))
	exe 'anoremenu 1.7 PopUp.' . s:ignoreitem . ' :spellgood! ' . w . '<CR>'

	anoremenu 1.8 PopUp.-SpellSep- :
	let &cpo = cpo_save
      endif
    endif
    call cursor(0, curcol)	" put the cursor back where it was
  endfunc

  func! <SID>SpellReplace(n)
    let l = getline('.')
    " Move the cursor to the start of the word.
    call spellbadword()
    call setline('.', strpart(l, 0, col('.') - 1) . s:suglist[a:n - 1]
	  \ . strpart(l, col('.') + len(s:fromword) - 1))
  endfunc

  func! <SID>SpellDel()
    exe "aunmenu PopUp." . s:changeitem
    exe "aunmenu PopUp." . s:additem
    exe "aunmenu PopUp." . s:ignoreitem
    aunmenu PopUp.-SpellSep-
    let s:changeitem = ''
  endfun

  augroup SpellPopupMenu
    au! MenuPopup * call <SID>SpellPopup()
  augroup END
endif

" The GUI toolbar (for MS-Windows and GTK)
if has("toolbar")
  an 1.10 ToolBar.Open			:browse confirm e<CR>
  an <silent> 1.20 ToolBar.Save		:if expand("%") == ""<Bar>browse confirm w<Bar>else<Bar>confirm w<Bar>endif<CR>
  an 1.30 ToolBar.SaveAll		:browse confirm wa<CR>

  if has("printer")
    an 1.40   ToolBar.Print		:hardcopy<CR>
    vunmenu   ToolBar.Print
    vnoremenu ToolBar.Print		:hardcopy<CR>
  elseif has("unix")
    an 1.40   ToolBar.Print		:w !lpr<CR>
    vunmenu   ToolBar.Print
    vnoremenu ToolBar.Print		:w !lpr<CR>
  endif

  an 1.45 ToolBar.-sep1-		<Nop>
  an 1.50 ToolBar.Undo			u
  an 1.60 ToolBar.Redo			<C-R>

  an 1.65 ToolBar.-sep2-		<Nop>
  vnoremenu 1.70 ToolBar.Cut		"+x
  vnoremenu 1.80 ToolBar.Copy		"+y
  cnoremenu 1.80 ToolBar.Copy		<C-Y>
  nnoremenu 1.90 ToolBar.Paste		"+gP
  cnoremenu	 ToolBar.Paste		<C-R>+
  exe 'vnoremenu <script>	 ToolBar.Paste	' . paste#paste_cmd['v']
  exe 'inoremenu <script>	 ToolBar.Paste	' . paste#paste_cmd['i']

  if !has("gui_athena")
    an 1.95   ToolBar.-sep3-		<Nop>
    an 1.100  ToolBar.Replace		:promptrepl<CR>
    vunmenu   ToolBar.Replace
    vnoremenu ToolBar.Replace		y:promptrepl <C-R>=<SID>FixFText()<CR><CR>
    an 1.110  ToolBar.FindNext		n
    an 1.120  ToolBar.FindPrev		N
  endif

  an 1.215 ToolBar.-sep5-		<Nop>
  an <silent> 1.220 ToolBar.LoadSesn	:call <SID>LoadVimSesn()<CR>
  an <silent> 1.230 ToolBar.SaveSesn	:call <SID>SaveVimSesn()<CR>
  an 1.240 ToolBar.RunScript		:browse so<CR>

  an 1.245 ToolBar.-sep6-		<Nop>
  an 1.250 ToolBar.Make			:make<CR>
  an 1.270 ToolBar.RunCtags		:exe "!" . g:ctags_command<CR>
  an 1.280 ToolBar.TagJump		g<C-]>

  an 1.295 ToolBar.-sep7-		<Nop>
  an 1.300 ToolBar.Help			:help<CR>
  an <silent> 1.310 ToolBar.FindHelp	:call <SID>Helpfind()<CR>

" Only set the tooltips here if not done in a language menu file
if exists("*Do_toolbar_tmenu")
  call Do_toolbar_tmenu()
else
  let did_toolbar_tmenu = 1
  tmenu ToolBar.Open		Open file
  tmenu ToolBar.Save		Save current file
  tmenu ToolBar.SaveAll		Save all files
  tmenu ToolBar.Print		Print
  tmenu ToolBar.Undo		Undo
  tmenu ToolBar.Redo		Redo
  tmenu ToolBar.Cut		Cut to clipboard
  tmenu ToolBar.Copy		Copy to clipboard
  tmenu ToolBar.Paste		Paste from Clipboard
  if !has("gui_athena")
    tmenu ToolBar.Replace	Find / Replace...
    tmenu ToolBar.FindNext	Find Next
    tmenu ToolBar.FindPrev	Find Previous
  endif
  tmenu ToolBar.LoadSesn	Choose a session to load
  tmenu ToolBar.SaveSesn	Save current session
  tmenu ToolBar.RunScript	Choose a Vim Script to run
  tmenu ToolBar.Make		Make current project (:make)
  tmenu ToolBar.RunCtags	Build tags in current directory tree (!ctags -R .)
  tmenu ToolBar.TagJump		Jump to tag under cursor
  tmenu ToolBar.Help		Vim Help
  tmenu ToolBar.FindHelp	Search Vim Help
endif

" Select a session to load; default to current session name if present
fun! s:LoadVimSesn()
  if strlen(v:this_session) > 0
    let name = s:FnameEscape(v:this_session)
  else
    let name = "Session.vim"
  endif
  execute "browse so " . name
endfun

" Select a session to save; default to current session name if present
fun! s:SaveVimSesn()
  if strlen(v:this_session) == 0
    let v:this_session = "Session.vim"
  endif
  execute "browse mksession! " . s:FnameEscape(v:this_session)
endfun

endif

endif " !exists("did_install_default_menus")

" Define these items always, so that syntax can be switched on when it wasn't.
" But skip them when the Syntax menu was disabled by the user.
if !exists("did_install_syntax_menu")
  an 50.212 &Syntax.&Manual		:syn manual<CR>
  an 50.214 &Syntax.A&utomatic		:syn on<CR>
  an <silent> 50.216 &Syntax.On/Off\ for\ &This\ File :call <SID>SynOnOff()<CR>
  if !exists("*s:SynOnOff")
    fun s:SynOnOff()
      if has("syntax_items")
	syn clear
      else
	if !exists("g:syntax_on")
	  syn manual
	endif
	set syn=ON
      endif
    endfun
  endif
endif


" Install the Syntax menu only when filetype.vim has been loaded or when
" manual syntax highlighting is enabled.
" Avoid installing the Syntax menu twice.
if (exists("did_load_filetypes") || exists("syntax_on"))
	\ && !exists("did_install_syntax_menu")
  let did_install_syntax_menu = 1

" Skip setting up the individual syntax selection menus unless
" do_syntax_sel_menu is defined (it takes quite a bit of time).
if exists("do_syntax_sel_menu")
  runtime! synmenu.vim
else
  an <silent> 50.10 &Syntax.&Show\ File\ Types\ in\ Menu	:let do_syntax_sel_menu = 1<Bar>runtime! synmenu.vim<Bar>aunmenu &Syntax.&Show\ File\ Types\ in\ Menu<CR>
  an 50.195 &Syntax.-SEP1-		<Nop>
endif

an 50.210 &Syntax.&Off			:syn off<CR>
an 50.700 &Syntax.-SEP3-		<Nop>
an 50.710 &Syntax.Co&lor\ Test		:sp $VIMRUNTIME/syntax/colortest.vim<Bar>so %<CR>
an 50.720 &Syntax.&Highlight\ Test	:runtime syntax/hitest.vim<CR>
an 50.730 &Syntax.&Convert\ to\ HTML	:runtime syntax/2html.vim<CR>

endif " !exists("did_install_syntax_menu")

" Restore the previous value of 'cpoptions'.
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sw=2 :
