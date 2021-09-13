" Language: tmux(1) configuration file
" Version: 3.0 (git-48cbbb87)
" URL: https://github.com/ericpruitt/tmux.vim/
" Maintainer: Eric Pruitt <eric.pruitt@gmail.com>
" License: 2-Clause BSD (http://opensource.org/licenses/BSD-2-Clause)

if exists("b:current_syntax")
    finish
endif

" Explicitly change compatibility options to Vim's defaults because this file
" uses line continuations.
let s:original_cpo = &cpo
set cpo&vim

let b:current_syntax = "tmux"
syntax iskeyword @,48-57,_,192-255,-
syntax case match

syn keyword tmuxAction  none any current other
syn keyword tmuxBoolean off on

syn keyword tmuxTodo FIXME NOTE TODO XXX contained

syn match tmuxColour            /\<colour[0-9]\+/      display
syn match tmuxKey               /\(C-\|M-\|\^\)\+\S\+/ display
syn match tmuxNumber            /\<\d\+\>/             display
syn match tmuxFlags             /\s-\a\+/              display
syn match tmuxVariable          /\w\+=/                display
syn match tmuxVariableExpansion /\${\=\w\+}\=/         display
syn match tmuxControl           /%\(if\|elif\|else\|endif\)/

syn region tmuxComment start=/#/ skip=/\\\@<!\\$/ end=/$/ contains=tmuxTodo

syn region tmuxString start=+"+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end='$' contains=tmuxFormatString
syn region tmuxString start=+'+ skip=+\\\\\|\\'\|\\$+ excludenl end=+'+ end='$' contains=tmuxFormatString

" TODO: Figure out how escaping works inside of #(...) and #{...} blocks.
syn region tmuxFormatString start=/#[#DFhHIPSTW]/ end=// contained keepend
syn region tmuxFormatString start=/#{/ skip=/#{.\{-}}/ end=/}/ contained keepend
syn region tmuxFormatString start=/#(/ skip=/#(.\{-})/ end=/)/ contained keepend

hi def link tmuxFormatString      Identifier
hi def link tmuxAction            Boolean
hi def link tmuxBoolean           Boolean
hi def link tmuxCommands          Keyword
hi def link tmuxControl           Keyword
hi def link tmuxComment           Comment
hi def link tmuxKey               Special
hi def link tmuxNumber            Number
hi def link tmuxFlags             Identifier
hi def link tmuxOptions           Function
hi def link tmuxString            String
hi def link tmuxTodo              Todo
hi def link tmuxVariable          Identifier
hi def link tmuxVariableExpansion Identifier

" Make the foreground of colourXXX keywords match the color they represent.
" Darker colors have their background set to white.
for s:i in range(0, 255)
    let s:bg = (!s:i || s:i == 16 || (s:i > 231 && s:i < 235)) ? 15 : "none"
    exec "syn match tmuxColour" . s:i . " /\\<colour" . s:i . "\\>/ display"
\     " | highlight tmuxColour" . s:i . " ctermfg=" . s:i . " ctermbg=" . s:bg
endfor

syn keyword tmuxOptions
\ backspace buffer-limit command-alias default-terminal escape-time
\ exit-empty activity-action assume-paste-time base-index bell-action
\ default-command default-shell default-size destroy-unattached
\ detach-on-destroy display-panes-active-colour display-panes-colour
\ display-panes-time display-time exit-unattached focus-events history-file
\ history-limit key-table lock-after-time lock-command message-command-style
\ message-limit message-style aggressive-resize allow-rename
\ alternate-screen automatic-rename automatic-rename-format
\ clock-mode-colour clock-mode-style main-pane-height main-pane-width
\ mode-keys mode-style monitor-activity monitor-bell monitor-silence mouse
\ other-pane-height other-pane-width pane-active-border-style
\ pane-base-index pane-border-format pane-border-status pane-border-style
\ prefix prefix2 remain-on-exit renumber-windows repeat-time set-clipboard
\ set-titles set-titles-string silence-action status status-bg status-fg
\ status-format status-interval status-justify status-keys status-left
\ status-left-length status-left-style status-position status-right
\ status-right-length status-right-style status-style synchronize-panes
\ terminal-overrides update-environment user-keys visual-activity
\ visual-bell visual-silence window-active-style window-size
\ window-status-activity-style window-status-bell-style
\ window-status-current-format window-status-current-style
\ window-status-format window-status-last-style window-status-separator
\ window-status-style window-style word-separators wrap-search xterm-keys

syn keyword tmuxCommands
\ attach attach-session bind bind-key break-pane breakp capture-pane
\ capturep choose-buffer choose-client choose-tree clear-history clearhist
\ clock-mode command-prompt confirm confirm-before copy-mode detach
\ detach-client display display-menu display-message display-panes displayp
\ find-window findw if if-shell join-pane joinp kill-pane kill-server
\ kill-session kill-window killp has-session has killw link-window linkw
\ list-buffers list-clients list-commands list-keys list-panes list-sessions
\ list-windows load-buffer loadb lock lock-client lock-server lock-session
\ lockc last-pane lastp locks ls last-window last lsb lsc delete-buffer
\ deleteb lscm lsk lsp lsw menu move-pane move-window movep movew new
\ new-session new-window neww next next-layout next-window nextl
\ paste-buffer pasteb pipe-pane pipep prev previous-layout previous-window
\ prevl refresh refresh-client rename rename-session rename-window renamew
\ resize-pane resize-window resizep resizew respawn-pane respawn-window
\ respawnp respawnw rotate-window rotatew run run-shell save-buffer saveb
\ select-layout select-pane select-window selectl selectp selectw send
\ send-keys send-prefix set set-buffer set-environment set-hook set-option
\ set-window-option setb setenv setw show show-buffer show-environment
\ show-hooks show-messages show-options show-window-options showb showenv
\ showmsgs showw source source-file split-window splitw start start-server
\ suspend-client suspendc swap-pane swap-window swapp swapw switch-client
\ switchc unbind unbind-key unlink-window unlinkw wait wait-for

let &cpo = s:original_cpo
unlet! s:original_cpo s:bg s:i
