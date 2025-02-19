" Maintainer: Luca Saccarola <github.e41mv@aleeas.com>
" Former Maintainer: Charles E Campbell
" Upstream: <https://github.com/saccarosium/netrw.vim>
" Language: Netrw Listing Syntax

if exists("b:current_syntax")
    finish
endif

let b:current_syntax = "netrwlist"

" Directory List Syntax Highlighting: {{{

syn cluster NetrwGroup contains=netrwHide,netrwSortBy,netrwSortSeq,netrwQuickHelp,netrwVersion,netrwCopyTgt
syn cluster NetrwTreeGroup contains=netrwDir,netrwSymLink,netrwExe

syn match netrwPlain "\(\S\+ \)*\S\+" contains=netrwLink,@NoSpell
syn match netrwSpecial "\%(\S\+ \)*\S\+[*|=]\ze\%(\s\{2,}\|$\)" contains=netrwClassify,@NoSpell
syn match netrwDir "\.\{1,2}/" contains=netrwClassify,@NoSpell
syn match netrwDir "\%(\S\+ \)*\S\+/\ze\%(\s\{2,}\|$\)" contains=netrwClassify,@NoSpell
syn match netrwSizeDate "\<\d\+\s\d\{1,2}/\d\{1,2}/\d\{4}\s" skipwhite contains=netrwDateSep,@NoSpell nextgroup=netrwTime
syn match netrwSymLink "\%(\S\+ \)*\S\+@\ze\%(\s\{2,}\|$\)" contains=netrwClassify,@NoSpell
syn match netrwExe "\%(\S\+ \)*\S*[^~]\*\ze\%(\s\{2,}\|$\)" contains=netrwClassify,@NoSpell
if has("gui_running") && (&enc == 'utf-8' || &enc == 'utf-16' || &enc == 'ucs-4')
    syn match netrwTreeBar "^\%([-+|│] \)\+" contains=netrwTreeBarSpace nextgroup=@netrwTreeGroup
else
    syn match netrwTreeBar "^\%([-+|] \)\+" contains=netrwTreeBarSpace nextgroup=@netrwTreeGroup
endif
syn match netrwTreeBarSpace " " contained

syn match netrwClassify "[*=|@/]\ze\%(\s\{2,}\|$\)" contained
syn match netrwDateSep "/" contained
syn match netrwTime "\d\{1,2}:\d\{2}:\d\{2}" contained contains=netrwTimeSep
syn match netrwTimeSep ":"

syn match netrwComment '".*\%(\t\|$\)' contains=@NetrwGroup,@NoSpell
syn match netrwHide '^"\s*\(Hid\|Show\)ing:' skipwhite contains=@NoSpell nextgroup=netrwHidePat
syn match netrwSlash "/" contained
syn match netrwHidePat "[^,]\+" contained skipwhite contains=@NoSpell nextgroup=netrwHideSep
syn match netrwHideSep "," contained skipwhite nextgroup=netrwHidePat
syn match netrwSortBy "Sorted by" contained transparent skipwhite nextgroup=netrwList
syn match netrwSortSeq "Sort sequence:" contained transparent skipwhite nextgroup=netrwList
syn match netrwCopyTgt "Copy/Move Tgt:" contained transparent skipwhite nextgroup=netrwList
syn match netrwList ".*$" contained contains=netrwComma,@NoSpell
syn match netrwComma "," contained
syn region netrwQuickHelp matchgroup=Comment start="Quick Help:\s\+" end="$" contains=netrwHelpCmd,netrwQHTopic,@NoSpell keepend contained
syn match netrwHelpCmd "\S\+\ze:" contained skipwhite contains=@NoSpell nextgroup=netrwCmdSep
syn match netrwQHTopic "([a-zA-Z &]\+)" contained skipwhite
syn match netrwCmdSep ":" contained nextgroup=netrwCmdNote
syn match netrwCmdNote ".\{-}\ze " contained contains=@NoSpell
syn match netrwVersion "(netrw.*)" contained contains=@NoSpell
syn match netrwLink "-->" contained skipwhite

" }}}
" Special filetype highlighting {{{

if exists("g:netrw_special_syntax") && g:netrw_special_syntax
    if exists("+suffixes") && &suffixes != ""
        let suflist= join(split(&suffixes,','))
        let suflist= escape(substitute(suflist," ",'\\|','g'),'.~')
        exe "syn match netrwSpecFile '\\(\\S\\+ \\)*\\S*\\(".suflist."\\)\\>' contains=netrwTreeBar,@NoSpell"
    endif
    syn match netrwBak "\(\S\+ \)*\S\+\.bak\>" contains=netrwTreeBar,@NoSpell
    syn match netrwCompress "\(\S\+ \)*\S\+\.\%(gz\|bz2\|Z\|zip\)\>" contains=netrwTreeBar,@NoSpell
    if has("unix")
        syn match netrwCoreDump "\<core\%(\.\d\+\)\=\>" contains=netrwTreeBar,@NoSpell
    endif
    syn match netrwLex "\(\S\+ \)*\S\+\.\%(l\|lex\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwYacc "\(\S\+ \)*\S\+\.y\>" contains=netrwTreeBar,@NoSpell
    syn match netrwData "\(\S\+ \)*\S\+\.dat\>" contains=netrwTreeBar,@NoSpell
    syn match netrwDoc "\(\S\+ \)*\S\+\.\%(doc\|txt\|pdf\|ps\|docx\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwHdr "\(\S\+ \)*\S\+\.\%(h\|hpp\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwLib "\(\S\+ \)*\S*\.\%(a\|so\|lib\|dll\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwMakeFile "\<[mM]akefile\>\|\(\S\+ \)*\S\+\.mak\>" contains=netrwTreeBar,@NoSpell
    syn match netrwObj "\(\S\+ \)*\S*\.\%(o\|obj\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwPix "\c\(\S\+ \)*\S*\.\%(bmp\|fits\=\|gif\|je\=pg\|pcx\|ppc\|pgm\|png\|ppm\|psd\|rgb\|tif\|xbm\|xcf\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwTags "\<\(ANmenu\|ANtags\)\>" contains=netrwTreeBar,@NoSpell
    syn match netrwTags "\<tags\>" contains=netrwTreeBar,@NoSpell
    syn match netrwTilde "\(\S\+ \)*\S\+\~\*\=\>" contains=netrwTreeBar,@NoSpell
    syn match netrwTmp "\<tmp\(\S\+ \)*\S\+\>\|\(\S\+ \)*\S*tmp\>" contains=netrwTreeBar,@NoSpell
endif

" }}}
" Highlighting Links: {{{

if !exists("did_drchip_netrwlist_syntax")
    let did_drchip_netrwlist_syntax= 1
    hi default link netrwClassify Function
    hi default link netrwCmdSep Delimiter
    hi default link netrwComment Comment
    hi default link netrwDir Directory
    hi default link netrwHelpCmd Function
    hi default link netrwQHTopic Number
    hi default link netrwHidePat Statement
    hi default link netrwHideSep netrwComment
    hi default link netrwList Statement
    hi default link netrwVersion Identifier
    hi default link netrwSymLink Question
    hi default link netrwExe PreProc
    hi default link netrwDateSep Delimiter

    hi default link netrwTreeBar Special
    hi default link netrwTimeSep netrwDateSep
    hi default link netrwComma netrwComment
    hi default link netrwHide netrwComment
    hi default link netrwMarkFile TabLineSel
    hi default link netrwLink Special

    " special syntax highlighting (see :he g:netrw_special_syntax)
    hi default link netrwCoreDump WarningMsg
    hi default link netrwData Folded
    hi default link netrwHdr netrwPlain
    hi default link netrwLex netrwPlain
    hi default link netrwLib DiffChange
    hi default link netrwMakefile DiffChange
    hi default link netrwYacc netrwPlain
    hi default link netrwPix Special

    hi default link netrwBak netrwGray
    hi default link netrwCompress netrwGray
    hi default link netrwSpecFile netrwGray
    hi default link netrwObj netrwGray
    hi default link netrwTags netrwGray
    hi default link netrwTilde netrwGray
    hi default link netrwTmp netrwGray
endif

" set up netrwGray to be understated (but not Ignore'd or Conceal'd, as those
" can be hard/impossible to read). Users may override this in a colorscheme by
" specifying netrwGray highlighting.
redir => s:netrwgray
sil hi netrwGray
redir END

if s:netrwgray !~ 'guifg'
    if has("gui") && has("gui_running")
        if &bg == "dark"
            exe "hi netrwGray gui=NONE guifg=gray30"
        else
            exe "hi netrwGray gui=NONE guifg=gray70"
        endif
    else
        hi link netrwGray Folded
    endif
endif

" }}}

" vim:ts=8 sts=4 sw=4 et fdm=marker
