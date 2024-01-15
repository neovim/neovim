" Language: tmux(1) configuration file
" Version: 3.3a (git-e7c829fc)
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

" The values "yes" and "no" are synonyms for "on" and "off", so they do not
" appear in the option table file.
syn keyword tmuxEnums yes no

syn keyword tmuxTodo FIXME NOTE TODO XXX contained

syn match tmuxColour            /\<colou\?r[0-9]\+\>/  display
syn match tmuxKey               /\(C-\|M-\|\^\)\+\S\+/ display
syn match tmuxNumber            /\<\d\+\>/             display
syn match tmuxFlags             /\s-\a\+/              display
syn match tmuxVariableExpansion /\$\({[A-Za-z_]\w*}\|[A-Za-z_]\w*\)/ display
syn match tmuxControl           /\(^\|\s\)%\(if\|elif\|else\|endif\)\($\|\s\)/ display
syn match tmuxEscape            /\\\(u\x\{4\}\|U\x\{8\}\|\o\{3\}\|[\\ernt$]\)/ display

" Missing closing bracket.
syn match tmuxInvalidVariableExpansion /\${[^}]*$/ display
" Starts with invalid character.
syn match tmuxInvalidVariableExpansion /\${[^A-Za-z_][^}]*}/ display
syn match tmuxInvalidVariableExpansion /\$[^A-Za-z_{ \t]/ display
" Contains invalid character.
syn match tmuxInvalidVariableExpansion /\${[^}]*[^A-Za-z0-9_][^}]*}/ display

syn region tmuxComment start=/#/ skip=/\\\@<!\\$/ end=/$/ contains=tmuxTodo,@Spell

syn region tmuxString start=+"+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end='$' contains=tmuxFormatString,tmuxEscape,tmuxVariableExpansion,tmuxInvalidVariableExpansion,@Spell
syn region tmuxUninterpolatedString start=+'+ skip=+\\$+ excludenl end=+'+ end='$' contains=tmuxFormatString,@Spell

" TODO: Figure out how escaping works inside of #(...) and #{...} blocks.
syn region tmuxFormatString start=/#[#DFhHIPSTW]/ end=// contained keepend
syn region tmuxFormatString start=/#{/ skip=/#{.\{-}}/ end=/}/ keepend
syn region tmuxFormatString start=/#(/ skip=/#(.\{-})/ end=/)/ contained keepend

" At the time of this writing, the latest tmux release will parse a line
" reading "abc=xyz set-option ..." as an assignment followed by a command
" hence the presence of "\s" in the "end" argument.
syn region tmuxAssignment matchgroup=tmuxVariable start=/^\s*[A-Za-z_]\w*=\@=/ skip=/\\$\|\\\s/ end=/\s\|$/ contains=tmuxString,tmuxUninterpolatedString,tmuxVariableExpansion,tmuxControl,tmuxEscape,tmuxInvalidVariableExpansion

hi def link tmuxFormatString      Identifier
hi def link tmuxAction            Boolean
hi def link tmuxBoolean           Boolean
hi def link tmuxCommands          Keyword
hi def link tmuxControl           PreCondit
hi def link tmuxComment           Comment
hi def link tmuxEnums             Boolean
hi def link tmuxEscape            Special
hi def link tmuxEscapeUnquoted    Special
hi def link tmuxInvalidVariableExpansion
\                                 Error
hi def link tmuxKey               Special
hi def link tmuxNumber            Number
hi def link tmuxFlags             Identifier
hi def link tmuxOptions           Function
hi def link tmuxString            String
hi def link tmuxTodo              Todo
hi def link tmuxUninterpolatedString
\                                 String
hi def link tmuxVariable          Identifier
hi def link tmuxVariableExpansion Identifier

" Make the foreground of colourXXX keywords match the color they represent
" when g:tmux_syntax_colors is unset or set to a non-zero value.
" Darker colors have their background set to white.
if get(g:, "tmux_syntax_colors", 1)
    for s:i in range(0, 255)
        let s:bg = (!s:i || s:i == 16 || (s:i > 231 && s:i < 235)) ? 15 : "none"
        exec "syn match tmuxColour" . s:i . " /\\<colou\\?r" . s:i . "\\>/ display"
\         " | highlight tmuxColour" . s:i . " ctermfg=" . s:i . " ctermbg=" . s:bg
    endfor
endif

syn keyword tmuxOptions
\ activity-action after-bind-key after-capture-pane after-copy-mode
\ after-display-message after-display-panes after-kill-pane after-list-buffers
\ after-list-clients after-list-keys after-list-panes after-list-sessions
\ after-list-windows after-load-buffer after-lock-server after-new-session
\ after-new-window after-paste-buffer after-pipe-pane after-queue
\ after-refresh-client after-rename-session after-rename-window
\ after-resize-pane after-resize-window after-save-buffer after-select-layout
\ after-select-pane after-select-window after-send-keys after-set-buffer
\ after-set-environment after-set-hook after-set-option after-show-environment
\ after-show-messages after-show-options after-split-window after-unbind-key
\ aggressive-resize alert-activity alert-bell alert-silence allow-passthrough
\ allow-rename alternate-screen assume-paste-time automatic-rename
\ automatic-rename-format backspace base-index bell-action buffer-limit
\ client-active client-attached client-detached client-focus-in
\ client-focus-out client-resized client-session-changed clock-mode-color
\ clock-mode-colour clock-mode-style command-alias copy-command
\ copy-mode-current-match-style copy-mode-mark-style copy-mode-match-style
\ cursor-color cursor-colour cursor-style default-command default-shell
\ default-size default-terminal destroy-unattached detach-on-destroy
\ display-panes-active-color display-panes-active-colour display-panes-color
\ display-panes-colour display-panes-time display-time editor escape-time
\ exit-empty exit-unattached extended-keys fill-character focus-events
\ history-file history-limit key-table lock-after-time lock-command
\ main-pane-height main-pane-width menu-border-lines menu-border-style
\ menu-selected-style menu-style message-command-style message-limit
\ message-line message-style mode-keys mode-style monitor-activity monitor-bell
\ monitor-silence mouse other-pane-height other-pane-width
\ pane-active-border-style pane-base-index pane-border-format
\ pane-border-indicators pane-border-lines pane-border-status pane-border-style
\ pane-colors pane-colours pane-died pane-exited pane-focus-in pane-focus-out
\ pane-mode-changed pane-set-clipboard pane-title-changed popup-border-lines
\ popup-border-style popup-style prefix prefix2 prompt-history-limit
\ remain-on-exit remain-on-exit-format renumber-windows repeat-time
\ scroll-on-clear session-closed session-created session-renamed
\ session-window-changed set-clipboard set-titles set-titles-string
\ silence-action status status-bg status-fg status-format status-interval
\ status-justify status-keys status-left status-left-length status-left-style
\ status-position status-right status-right-length status-right-style
\ status-style synchronize-panes terminal-features terminal-overrides
\ update-environment user-keys visual-activity visual-bell visual-silence
\ window-active-style window-layout-changed window-linked window-pane-changed
\ window-renamed window-resized window-size window-status-activity-style
\ window-status-bell-style window-status-current-format
\ window-status-current-style window-status-format window-status-last-style
\ window-status-separator window-status-style window-style window-unlinked
\ word-separators wrap-search xterm-keys

syn keyword tmuxCommands
\ attach attach-session bind bind-key break-pane breakp capture-pane capturep
\ choose-buffer choose-client choose-session choose-tree choose-window
\ clear-history clear-prompt-history clearhist clearphist clock-mode
\ command-prompt confirm confirm-before copy-mode customize-mode delete-buffer
\ deleteb detach detach-client display display-menu display-message
\ display-panes display-popup displayp find-window findw has has-session if
\ if-shell info join-pane joinp kill-pane kill-server kill-session kill-window
\ killp killw last last-pane last-window lastp link-window linkw list-buffers
\ list-clients list-commands list-keys list-panes list-sessions list-windows
\ load-buffer loadb lock lock-client lock-server lock-session lockc locks ls
\ lsb lsc lscm lsk lsp lsw menu move-pane move-window movep movew new
\ new-session new-window neww next next-layout next-window nextl paste-buffer
\ pasteb pipe-pane pipep popup prev previous-layout previous-window prevl
\ refresh refresh-client rename rename-session rename-window renamew
\ resize-pane resize-window resizep resizew respawn-pane respawn-window
\ respawnp respawnw rotate-window rotatew run run-shell save-buffer saveb
\ select-layout select-pane select-window selectl selectp selectw send
\ send-keys send-prefix server-access server-info set set-buffer
\ set-environment set-hook set-option set-window-option setb setenv setw show
\ show-buffer show-environment show-hooks show-messages show-options
\ show-prompt-history show-window-options showb showenv showmsgs showphist
\ showw source source-file split-pane split-window splitp splitw start
\ start-server suspend-client suspendc swap-pane swap-window swapp swapw
\ switch-client switchc unbind unbind-key unlink-window unlinkw wait wait-for

syn keyword tmuxEnums
\ absolute-centre all always any arrows bar blinking-bar blinking-block
\ blinking-underline block both bottom centre color colour current default
\ double emacs external failed heavy largest latest left manual next
\ no-detached none number off on other padded previous right rounded simple
\ single smallest top underline vi

let &cpo = s:original_cpo
unlet! s:original_cpo s:bg s:i
