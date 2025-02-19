" Vim syntax file
" Language: lf file manager configuration file (lfrc)
" Maintainer: Andis Sprinkis <andis@sprinkis.com>
" Former Maintainer: Cameron Wright
" Former URL: https://github.com/andis-sprinkis/lf-vim
" Last Change: 13 October 2024
"
" The shell syntax highlighting is configurable. See $VIMRUNTIME/doc/syntax.txt
" lf version: 32

if exists("b:current_syntax")
    finish
endif

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
    \ quit
    \ up
    \ half-up
    \ page-up
    \ scroll-up
    \ down
    \ half-down
    \ page-down
    \ scroll-down
    \ updir
    \ open
    \ jump-next
    \ jump-prev
    \ top
    \ bottom
    \ high
    \ middle
    \ low
    \ toggle
    \ invert
    \ invert-below
    \ unselect
    \ glob-select
    \ glob-unselect
    \ calcdirsize
    \ clearmaps
    \ copy
    \ cut
    \ paste
    \ clear
    \ sync
    \ draw
    \ redraw
    \ load
    \ reload
    \ echo
    \ echomsg
    \ echoerr
    \ cd
    \ select
    \ delete
    \ rename
    \ source
    \ push
    \ read
    \ shell
    \ shell-pipe
    \ shell-wait
    \ shell-async
    \ find
    \ find-back
    \ find-next
    \ find-prev
    \ search
    \ search-back
    \ search-next
    \ search-prev
    \ filter
    \ setfilter
    \ mark-save
    \ mark-load
    \ mark-remove
    \ tag
    \ tag-toggle
    \ cmd-escape
    \ cmd-complete
    \ cmd-menu-complete
    \ cmd-menu-complete-back
    \ cmd-menu-accept
    \ cmd-enter
    \ cmd-interrupt
    \ cmd-history-next
    \ cmd-history-prev
    \ cmd-left
    \ cmd-right
    \ cmd-home
    \ cmd-end
    \ cmd-delete
    \ cmd-delete-back
    \ cmd-delete-home
    \ cmd-delete-end
    \ cmd-delete-unix-word
    \ cmd-yank
    \ cmd-transpose
    \ cmd-transpose-word
    \ cmd-word
    \ cmd-word-back
    \ cmd-delete-word
    \ cmd-delete-word-back
    \ cmd-capitalize-word
    \ cmd-uppercase-word
    \ cmd-lowercase-word
    \ anchorfind
    \ autoquit
    \ borderfmt
    \ cleaner
    \ copyfmt
    \ cursoractivefmt
    \ cursorparentfmt
    \ cursorpreviewfmt
    \ cutfmt
    \ dircache
    \ dircounts
    \ dirfirst
    \ dironly
    \ dirpreviews
    \ drawbox
    \ dupfilefmt
    \ errorfmt
    \ filesep
    \ findlen
    \ globfilter
    \ globsearch
    \ hidden
    \ hiddenfiles
    \ hidecursorinactive
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
    \ mouse
    \ number
    \ numberfmt
    \ period
    \ preserve
    \ preview
    \ previewer
    \ promptfmt
    \ ratios
    \ relativenumber
    \ reverse
    \ roundbox
    \ ruler
    \ rulerfmt
    \ scrolloff
    \ selectfmt
    \ selmode
    \ shell
    \ shellflag
    \ shellopts
    \ sixel
    \ smartcase
    \ smartdia
    \ sortby
    \ statfmt
    \ tabstop
    \ tagfmt
    \ tempmarks
    \ timefmt
    \ truncatechar
    \ truncatepct
    \ waitmsg
    \ wrapscan
    \ wrapscroll
    \ pre-cd
    \ on-cd
    \ on-select
    \ on-redraw
    \ on-quit
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
