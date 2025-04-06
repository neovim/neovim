" Vim syntax file
" Language: lf file manager configuration file (lfrc)
" Maintainer: Andis Sprinkis <andis@sprinkis.com>
" Former Maintainer: Cameron Wright
" URL: https://github.com/andis-sprinkis/lf-vim
" Last Change: 28 March 2025
" 29 Mar 2025 by Vim Project (save and restore 'cpo' setting)
"
" The shell syntax highlighting is configurable. See $VIMRUNTIME/doc/syntax.txt
" lf version: 34

if exists("b:current_syntax")
    finish
endif
let s:cpo = &cpo
set cpo&vim

let b:current_syntax = "lf"

"{{{ Comment Matching
syn match    lfComment        '#.*$'
"}}}

"{{{ String Matching
syn match    lfString         "'.*'"
syn match    lfString         '".*"' contains=lfVar,lfSpecial
"}}}

"{{{ Match lf Variables
syn match    lfVar            '\$f\|\$fx\|\$fs\|\$id'
"}}}

"{{{ Keywords
syn keyword  lfKeyword        set setlocal cmd map cmap skipwhite
"}}}

"{{{ Options Keywords
syn keyword  lfOptions
    \ anchorfind
    \ autoquit
    \ borderfmt
    \ bottom
    \ calcdirsize
    \ cd
    \ cleaner
    \ clear
    \ clearmaps
    \ cmd-capitalize-word
    \ cmd-complete
    \ cmd-delete
    \ cmd-delete-back
    \ cmd-delete-end
    \ cmd-delete-home
    \ cmd-delete-unix-word
    \ cmd-delete-word
    \ cmd-delete-word-back
    \ cmd-end
    \ cmd-enter
    \ cmd-escape
    \ cmd-history-next
    \ cmd-history-prev
    \ cmd-home
    \ cmd-interrupt
    \ cmd-left
    \ cmd-lowercase-word
    \ cmd-menu-accept
    \ cmd-menu-complete
    \ cmd-menu-complete-back
    \ cmd-right
    \ cmd-transpose
    \ cmd-transpose-word
    \ cmd-uppercase-word
    \ cmd-word
    \ cmd-word-back
    \ cmd-yank
    \ copy
    \ copyfmt
    \ cursoractivefmt
    \ cursorparentfmt
    \ cursorpreviewfmt
    \ cut
    \ cutfmt
    \ delete
    \ dircache
    \ dircounts
    \ dirfirst
    \ dironly
    \ dirpreviews
    \ down
    \ draw
    \ drawbox
    \ dupfilefmt
    \ echo
    \ echoerr
    \ echomsg
    \ errorfmt
    \ filesep
    \ filter
    \ find
    \ find-back
    \ find-next
    \ find-prev
    \ findlen
    \ glob-select
    \ glob-unselect
    \ globfilter
    \ globsearch
    \ half-down
    \ half-up
    \ hidden
    \ hiddenfiles
    \ high
    \ history
    \ icons
    \ ifs
    \ ignorecase
    \ ignoredia
    \ incfilter
    \ incsearch
    \ info
    \ infotimefmtnew
    \ infotimefmtold
    \ invert
    \ invert-below
    \ jump-next
    \ jump-prev
    \ load
    \ locale
    \ low
    \ mark-load
    \ mark-remove
    \ mark-save
    \ middle
    \ mouse
    \ number
    \ numberfmt
    \ on-cd
    \ on-focus-gained
    \ on-focus-lost
    \ on-init
    \ on-quit
    \ on-redraw
    \ on-select
    \ open
    \ page-down
    \ page-up
    \ paste
    \ period
    \ pre-cd
    \ preserve
    \ preview
    \ previewer
    \ promptfmt
    \ push
    \ quit
    \ ratios
    \ read
    \ redraw
    \ relativenumber
    \ reload
    \ rename
    \ reverse
    \ roundbox
    \ rulerfmt
    \ scroll-down
    \ scroll-up
    \ scrolloff
    \ search
    \ search-back
    \ search-next
    \ search-prev
    \ select
    \ selectfmt
    \ selmode
    \ setfilter
    \ shell
    \ shell-async
    \ shell-pipe
    \ shell-wait
    \ shellflag
    \ shellopts
    \ showbinds
    \ sixel
    \ smartcase
    \ smartdia
    \ sortby
    \ source
    \ statfmt
    \ sync
    \ tabstop
    \ tag
    \ tag-toggle
    \ tagfmt
    \ tempmarks
    \ timefmt
    \ toggle
    \ top
    \ truncatechar
    \ truncatepct
    \ unselect
    \ up
    \ updir
    \ waitmsg
    \ watch
    \ wrapscan
    \ wrapscroll
"}}}

"{{{ Special Matching
syn match    lfSpecial        '<.*>\|\\.'
"}}}

"{{{ Shell Script Matching for cmd
let s:shell_syntax = get(g:, 'lf_shell_syntax', "syntax/sh.vim")
let s:shell_syntax = get(b:, 'lf_shell_syntax', s:shell_syntax)
unlet b:current_syntax
exe 'syn include @Shell '.s:shell_syntax
let b:current_syntax = "lf"
syn region   lfIgnore         start=".{{\n" end="^}}"
    \ keepend contains=lfExternalShell,lfExternalPatch
syn match    lfShell          '\$[a-zA-Z].*$
    \\|:[a-zA-Z].*$
    \\|%[a-zA-Z].*$
    \\|![a-zA-Z].*$
    \\|&[a-zA-Z].*$'
    \ transparent contains=@Shell,lfExternalPatch
syn match    lfExternalShell  "^.*$" transparent contained contains=@Shell
syn match    lfExternalPatch  "^\s*cmd\ .*\ .{{$\|^}}$" contained
"}}}

"{{{ Link Highlighting
hi def link  lfComment        Comment
hi def link  lfVar            Type
hi def link  lfSpecial        Special
hi def link  lfString         String
hi def link  lfKeyword        Statement
hi def link  lfOptions        Constant
hi def link  lfConstant       Constant
hi def link  lfExternalShell  Normal
hi def link  lfExternalPatch  Special
hi def link  lfIgnore         Special
"}}}
let &cpo = s:cpo
unlet s:cpo
