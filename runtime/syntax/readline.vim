" Vim syntax file
" Language:         readline(3) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2012-04-25
"   readline_has_bash - if defined add support for bash specific
"                       settings/functions

if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn match   readlineKey         contained
                              \ '\S'
                              \ nextgroup=readlineKeyTerminator

syn match   readlineBegin       display '^'
                              \ nextgroup=readlineComment,
                              \           readlineConditional,
                              \           readlineInclude,
                              \           readlineKeyName,
                              \           readlineKey,
                              \           readlineKeySeq,
                              \           readlineKeyword
                              \ skipwhite

syn region  readlineComment     contained display oneline
                                \ start='#'
                                \ end='$'
                                \ contains=readlineTodo,
                                \          @Spell

syn keyword readlineTodo        contained
                              \ TODO
                              \ FIXME
                              \ XXX
                              \ NOTE

syn match   readlineConditional contained
                              \ '$if\>'
                              \ nextgroup=readlineTest,
                              \           readlineTestApp
                              \ skipwhite

syn keyword readlineTest        contained
                              \ mode
                              \ nextgroup=readlineTestModeEq

syn match   readlineTestModeEq  contained
                              \ '='
                              \ nextgroup=readlineEditingMode

syn keyword readlineTest        contained
                              \ term
                              \ nextgroup=readlineTestTermEq

syn match   readlineTestTermEq  contained
                              \ '='
                              \ nextgroup=readlineTestTerm

syn match   readlineTestTerm    contained
                              \ '\S\+'

syn match   readlineTestApp     contained
                              \ '\S\+'

syn match   readlineConditional contained display
                              \ '$\%(else\|endif\)\>'

syn match   readlineInclude     contained display
                              \ '$include\>'
                              \ nextgroup=readlinePath

syn match   readlinePath        contained display
                              \ '.\+'

syn case ignore
syn match   readlineKeyName     contained display
                              \ nextgroup=readlineKeySeparator,
                              \           readlineKeyTerminator
                              \ '\%(Control\|Del\|Esc\|Escape\|LFD\|Meta\|Newline\|Ret\|Return\|Rubout\|Space\|Spc\|Tab\)'
syn case match

syn match   readlineKeySeparator  contained
                                \ '-'
                                \ nextgroup=readlineKeyName,
                                \           readlineKey

syn match   readlineKeyTerminator contained
                                \ ':'
                                \ nextgroup=readlineFunction
                                \ skipwhite

syn region  readlineKeySeq     contained display oneline
                              \ start=+"+
                              \ skip=+\\\\\|\\"+
                              \ end=+"+
                              \ contains=readlineKeyEscape
                              \ nextgroup=readlineKeyTerminator

syn match   readlineKeyEscape   contained display
                              \ +\\\([CM]-\|[e\\"'abdfnrtv]\|\o\{3}\|x\x\{2}\)+

syn keyword readlineKeyword     contained
                              \ set
                              \ nextgroup=readlineVariable
                              \ skipwhite

syn keyword readlineVariable    contained 
                              \ nextgroup=readlineBellStyle
                              \ skipwhite
                              \ bell-style

syn keyword readlineVariable    contained
                              \ nextgroup=readlineBoolean
                              \ skipwhite
                              \ bind-tty-special-chars
                              \ completion-ignore-case
                              \ completion-map-case
                              \ convert-meta
                              \ disable-completion
                              \ echo-control-characters
                              \ enable-keypad
                              \ enable-meta-key
                              \ expand-tilde
                              \ history-preserve-point
                              \ horizontal-scroll-mode
                              \ input-meta
                              \ meta-flag
                              \ mark-directories
                              \ mark-modified-lines
                              \ mark-symlinked-directories
                              \ match-hidden-files
                              \ menu-complete-display-prefix
                              \ output-meta
                              \ page-completions
                              \ print-completions-horizontally
                              \ revert-all-at-newline
                              \ show-all-if-ambiguous
                              \ show-all-if-unmodified
                              \ skip-completed-text
                              \ visible-stats

syn keyword readlineVariable    contained
                              \ nextgroup=readlineString
                              \ skipwhite
                              \ comment-begin
                              \ isearch-terminators

syn keyword readlineVariable    contained
                              \ nextgroup=readlineNumber
                              \ skipwhite
                              \ completion-display-width
                              \ completion-prefix-display-length
                              \ completion-query-items
                              \ history-size

syn keyword readlineVariable    contained
                              \ nextgroup=readlineEditingMode
                              \ skipwhite
                              \ editing-mode

syn keyword readlineVariable    contained
                              \ nextgroup=readlineKeymap
                              \ skipwhite
                              \ keymap

syn keyword readlineBellStyle   contained
                              \ audible
                              \ visible
                              \ none

syn case ignore
syn keyword readlineBoolean     contained
                              \ on
                              \ off
syn case match

syn region  readlineString      contained display oneline
                              \ matchgroup=readlineStringDelimiter
                              \ start=+"+
                              \ skip=+\\\\\|\\"+
                              \ end=+"+

syn match   readlineNumber      contained display
                              \ '[+-]\d\+\>'

syn keyword readlineEditingMode contained
                              \ emacs
                              \ vi

syn match   readlineKeymap      contained display
                              \ 'emacs\%(-\%(standard\|meta\|ctlx\)\)\=\|vi\%(-\%(move\|command\|insert\)\)\='

syn keyword readlineFunction    contained
                              \ beginning-of-line
                              \ end-of-line
                              \ forward-char
                              \ backward-char
                              \ forward-word
                              \ backward-word
                              \ clear-screen
                              \ redraw-current-line
                              \
                              \ accept-line
                              \ previous-history
                              \ next-history
                              \ beginning-of-history
                              \ end-of-history
                              \ reverse-search-history
                              \ forward-search-history
                              \ non-incremental-reverse-search-history
                              \ non-incremental-forward-search-history
                              \ history-search-forward
                              \ history-search-backward
                              \ yank-nth-arg
                              \ yank-last-arg
                              \
                              \ delete-char
                              \ backward-delete-char
                              \ forward-backward-delete-char
                              \ quoted-insert
                              \ tab-insert
                              \ self-insert
                              \ transpose-chars
                              \ transpose-words
                              \ upcase-word
                              \ downcase-word
                              \ capitalize-word
                              \ overwrite-mode
                              \
                              \ kill-line
                              \ backward-kill-line
                              \ unix-line-discard
                              \ kill-whole-line
                              \ kill-word
                              \ backward-kill-word
                              \ unix-word-rubout
                              \ unix-filename-rubout
                              \ delete-horizontal-space
                              \ kill-region
                              \ copy-region-as-kill
                              \ copy-backward-word
                              \ copy-forward-word
                              \ yank
                              \ yank-pop
                              \
                              \ digit-argument
                              \ universal-argument
                              \
                              \ complete
                              \ possible-completions
                              \ insert-completions
                              \ menu-complete
                              \ menu-complete-backward
                              \ delete-char-or-list
                              \
                              \ start-kbd-macro
                              \ end-kbd-macro
                              \ call-last-kbd-macro
                              \
                              \ re-read-init-file
                              \ abort
                              \ do-uppercase-version
                              \ prefix-meta
                              \ undo
                              \ revert-line
                              \ tilde-expand
                              \ set-mark
                              \ exchange-point-and-mark
                              \ character-search
                              \ character-search-backward
                              \ skip-csi-sequence
                              \ insert-comment
                              \ dump-functions
                              \ dump-variables
                              \ dump-macros
                              \ emacs-editing-mode
                              \ vi-editing-mode
                              \
                              \ vi-eof-maybe
                              \ vi-movement-mode
                              \ vi-undo
                              \ vi-match
                              \ vi-tilde-expand
                              \ vi-complete
                              \ vi-char-search
                              \ vi-redo
                              \ vi-search
                              \ vi-arg-digit
                              \ vi-append-eol
                              \ vi-prev-word
                              \ vi-change-to
                              \ vi-delete-to
                              \ vi-end-word
                              \ vi-char-search
                              \ vi-fetch-history
                              \ vi-insert-beg
                              \ vi-search-again
                              \ vi-put
                              \ vi-replace
                              \ vi-subst
                              \ vi-char-search
                              \ vi-next-word
                              \ vi-yank-to
                              \ vi-first-print
                              \ vi-yank-arg
                              \ vi-goto-mark
                              \ vi-append-mode
                              \ vi-prev-word
                              \ vi-change-to
                              \ vi-delete-to
                              \ vi-end-word
                              \ vi-char-search
                              \ vi-insert-mode
                              \ vi-set-mark
                              \ vi-search-again
                              \ vi-put
                              \ vi-change-char
                              \ vi-subst
                              \ vi-char-search
                              \ vi-undo
                              \ vi-next-word
                              \ vi-delete
                              \ vi-yank-to
                              \ vi-column
                              \ vi-change-case

if exists("readline_has_bash")
  syn keyword readlineFunction  contained
                              \ shell-expand-line
                              \ history-expand-line
                              \ magic-space
                              \ alias-expand-line
                              \ history-and-alias-expand-line
                              \ insert-last-argument
                              \ operate-and-get-next
                              \ forward-backward-delete-char
                              \ delete-char-or-list
                              \ complete-filename
                              \ possible-filename-completions
                              \ complete-username
                              \ possible-username-completions
                              \ complete-variable
                              \ possible-variable-completions
                              \ complete-hostname
                              \ possible-hostname-completions
                              \ complete-command
                              \ possible-command-completions
                              \ dynamic-complete-history
                              \ complete-into-braces
                              \ glob-expand-word
                              \ glob-list-expansions
                              \ display-shell-version
                              \ glob-complete-word
                              \ edit-and-execute-command
endif

hi def link readlineKey           readlineKeySeq
hi def link readlineComment       Comment
hi def link readlineTodo          Todo
hi def link readlineConditional   Conditional
hi def link readlineTest          Type
hi def link readlineDelimiter     Delimiter
hi def link readlineTestModeEq    readlineEq
hi def link readlineTestTermEq    readlineEq
hi def link readlineTestTerm      readlineString
hi def link readlineTestAppEq     readlineEq
hi def link readlineTestApp       readlineString
hi def link readlineInclude       Include
hi def link readlinePath          String
hi def link readlineKeyName       SpecialChar
hi def link readlineKeySeparator  readlineKeySeq
hi def link readlineKeyTerminator readlineDelimiter
hi def link readlineKeySeq        String
hi def link readlineKeyEscape     SpecialChar
hi def link readlineKeyword       Keyword
hi def link readlineVariable      Identifier
hi def link readlineBellStyle     Constant
hi def link readlineBoolean       Boolean
hi def link readlineString        String
hi def link readlineStringDelimiter readlineString
hi def link readlineNumber        Number
hi def link readlineEditingMode   Constant
hi def link readlineKeymap        Constant
hi def link readlineFunction      Function

let b:current_syntax = 'readline'

let &cpo = s:cpo_save
unlet s:cpo_save
