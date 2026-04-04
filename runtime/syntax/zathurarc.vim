" Vim syntax file
" Language:             Zathurarc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Documentation:        https://pwmt.org/projects/zathura/documentation/
" Upstream:             https://github.com/Freed-Wu/zathurarc.vim
" Latest Revision:      2024-09-16
" 2026 Apr 04 by Vim project: add page-v-padding and page-h-padding

if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'zathurarc'

syntax case match
syntax iskeyword @,48-57,_,192-255,-

syntax region zathurarcComment start="\%([ \t]*\&\([^\\]\zs\|^\)\)#" end="$"
syntax match zathurarcBracket /[<>]/ contained
syntax match zathurarcNotation `<[A-Z][a-z0-9]\+>` contains=zathurarcBracket
syntax match zathurarcNumber `\<[0-9.]\>`
syntax region zathurarcString start=`"` skip=`\\"` end=`"`
syntax region zathurarcString start=`'` skip=`\\'` end=`'`
syntax keyword zathurarcMode normal fullscreen presentation index
syntax keyword zathurarcBoolean true false
syntax keyword zathurarcCommand include map set unmap
syntax keyword zathurarcOption abort-clear-search adjust-open advance-pages-per-row
syntax keyword zathurarcOption completion-bg completion-fg completion-group-bg
syntax keyword zathurarcOption completion-group-fg completion-highlight-bg
syntax keyword zathurarcOption completion-highlight-fg continuous-hist-save database
syntax keyword zathurarcOption dbus-raise-window dbus-service default-bg default-fg
syntax keyword zathurarcOption double-click-follow exec-command filemonitor
syntax keyword zathurarcOption first-page-column font guioptions highlight-active-color
syntax keyword zathurarcOption highlight-color highlight-fg highlight-transparency
syntax keyword zathurarcOption incremental-search index-active-bg index-active-fg index-bg
syntax keyword zathurarcOption index-fg inputbar-bg inputbar-fg link-hadjust link-zoom
syntax keyword zathurarcOption n-completion-items notification-bg notification-error-bg
syntax keyword zathurarcOption notification-error-fg notification-fg
syntax keyword zathurarcOption notification-warning-bg notification-warning-fg
syntax keyword zathurarcOption page-cache-size page-h-padding page-v-padding
syntax keyword zathurarcOption page-right-to-left page-thumbnail-size pages-per-row recolor
syntax keyword zathurarcOption recolor-darkcolor recolor-keephue recolor-lightcolor
syntax keyword zathurarcOption recolor-reverse-video render-loading render-loading-bg
syntax keyword zathurarcOption render-loading-fg sandbox scroll-full-overlap scroll-hstep
syntax keyword zathurarcOption scroll-page-aware scroll-step scroll-wrap search-hadjust
syntax keyword zathurarcOption selection-clipboard selection-notification show-directories
syntax keyword zathurarcOption show-hidden show-recent statusbar-basename statusbar-bg
syntax keyword zathurarcOption statusbar-fg statusbar-h-padding statusbar-home-tilde
syntax keyword zathurarcOption statusbar-page-percent statusbar-v-padding synctex
syntax keyword zathurarcOption synctex-editor-command vertical-center window-height
syntax keyword zathurarcOption window-icon window-icon-document window-title-basename
syntax keyword zathurarcOption window-title-home-tilde window-title-page window-width
syntax keyword zathurarcOption zoom-center zoom-max zoom-min zoom-step

highlight default link zathurarcComment Comment
highlight default link zathurarcNumber Number
highlight default link zathurarcMode Macro
highlight default link zathurarcString String
highlight default link zathurarcBoolean Boolean
" same as vim
highlight default link zathurarcBracket Delimiter
highlight default link zathurarcNotation Special
highlight default link zathurarcCommand Statement
highlight default link zathurarcOption PreProc
" ex: nowrap
