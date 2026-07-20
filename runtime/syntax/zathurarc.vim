" Vim syntax file
" Language:             Zathurarc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Documentation:        https://pwmt.org/projects/zathura/documentation/
" Upstream:             https://github.com/Freed-Wu/zathurarc.vim
" Latest Revision:      2024-09-16
" 2026 Apr 04 by Vim project: add page-v-padding and page-h-padding
" 2026 Jul 20 by Vim project: syn options with latest zathura upstream repo

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
syntax keyword zathurarcOption highlight-color highlighter-modifier highlight-fg
syntax keyword zathurarcOption incremental-search index-active-bg index-active-fg index-bg
syntax keyword zathurarcOption index-fg inputbar-bg inputbar-fg jumplist-size link-hadjust
syntax keyword zathurarcOption link-zoom n-completion-items nohlsearch notification-bg
syntax keyword zathurarcOption notification-error-bg notification-error-fg notification-fg
syntax keyword zathurarcOption notification-warning-bg notification-warning-fg
syntax keyword zathurarcOption open-first-page open-link-confirm page-cache-size
syntax keyword zathurarcOption page-h-padding page-mode page-right-to-left pages-per-row
syntax keyword zathurarcOption page-thumbnail-size page-v-padding recolor
syntax keyword zathurarcOption recolor-adjust-lightness recolor-darkcolor recolor-keephue
syntax keyword zathurarcOption recolor-lightcolor recolor-reverse-video render-loading
syntax keyword zathurarcOption render-loading-bg render-loading-fg scrollbar-bg
syntax keyword zathurarcOption scrollbar-fg scroll-full-overlap scroll-hstep
syntax keyword zathurarcOption scroll-page-aware scroll-step scroll-wrap search-hadjust
syntax keyword zathurarcOption selection-clipboard selection-keep-highlight
syntax keyword zathurarcOption selection-notification show-directories show-hidden
syntax keyword zathurarcOption show-recent show-signature-information signature-error-color
syntax keyword zathurarcOption signature-success-color signature-warning-color
syntax keyword zathurarcOption single-page-mode statusbar-basename statusbar-bg
syntax keyword zathurarcOption statusbar-fg statusbar-home-tilde statusbar-h-padding
syntax keyword zathurarcOption statusbar-page-percent statusbar-v-padding synctex
syntax keyword zathurarcOption synctex-edit-modifier synctex-editor-command vertical-center
syntax keyword zathurarcOption window-height window-title-basename window-title-home-tilde
syntax keyword zathurarcOption window-title-page window-width word-separator zoom-center
syntax keyword zathurarcOption zoom-max zoom-min zoom-step

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
