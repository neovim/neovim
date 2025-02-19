return {
  --- @type [string, string[], boolean][] List of [eventname, aliases, window-local event] tuples.
  events = {
    { 'BufAdd', { 'BufCreate' }, true }, -- after adding a buffer to the buffer list
    { 'BufDelete', {}, true }, -- deleting a buffer from the buffer list
    { 'BufEnter', {}, true }, -- after entering a buffer
    { 'BufFilePost', {}, true }, -- after renaming a buffer
    { 'BufFilePre', {}, true }, -- before renaming a buffer
    { 'BufHidden', {}, true }, -- just after buffer becomes hidden
    { 'BufLeave', {}, true }, -- before leaving a buffer
    { 'BufModifiedSet', {}, true }, -- after the 'modified' state of a buffer changes
    { 'BufNew', {}, true }, -- after creating any buffer
    { 'BufNewFile', {}, true }, -- when creating a buffer for a new file
    { 'BufReadCmd', {}, true }, -- read buffer using command
    { 'BufReadPost', { 'BufRead' }, true }, -- after reading a buffer
    { 'BufReadPre', {}, true }, -- before reading a buffer
    { 'BufUnload', {}, true }, -- just before unloading a buffer
    { 'BufWinEnter', {}, true }, -- after showing a buffer in a window
    { 'BufWinLeave', {}, true }, -- just after buffer removed from window
    { 'BufWipeout', {}, true }, -- just before really deleting a buffer
    { 'BufWriteCmd', {}, true }, -- write buffer using command
    { 'BufWritePost', {}, true }, -- after writing a buffer
    { 'BufWritePre', { 'BufWrite' }, true }, -- before writing a buffer
    { 'ChanInfo', {}, false }, -- info was received about channel
    { 'ChanOpen', {}, false }, -- channel was opened
    { 'CmdUndefined', {}, false }, -- command undefined
    { 'CmdWinEnter', {}, false }, -- after entering the cmdline window
    { 'CmdWinLeave', {}, false }, -- before leaving the cmdline window
    { 'CmdlineChanged', {}, false }, -- command line was modified
    { 'CmdlineEnter', {}, false }, -- after entering cmdline mode
    { 'CmdlineLeave', {}, false }, -- before leaving cmdline mode
    { 'ColorScheme', {}, false }, -- after loading a colorscheme
    { 'ColorSchemePre', {}, false }, -- before loading a colorscheme
    { 'CompleteChanged', {}, false }, -- after popup menu changed
    { 'CompleteDone', {}, false }, -- after finishing insert complete
    { 'CompleteDonePre', {}, false }, -- idem, before clearing info
    { 'CursorHold', {}, true }, -- cursor in same position for a while
    { 'CursorHoldI', {}, true }, -- idem, in Insert mode
    { 'CursorMoved', {}, true }, -- cursor was moved
    { 'CursorMovedC', {}, true }, -- cursor was moved in Cmdline mode
    { 'CursorMovedI', {}, true }, -- cursor was moved in Insert mode
    { 'DiagnosticChanged', {}, false }, -- diagnostics in a buffer were modified
    { 'DiffUpdated', {}, false }, -- diffs have been updated
    { 'DirChanged', {}, false }, -- directory changed
    { 'DirChangedPre', {}, false }, -- directory is going to change
    { 'EncodingChanged', { 'FileEncoding' }, false }, -- after changing the 'encoding' option
    { 'ExitPre', {}, false }, -- before exiting
    { 'FileAppendCmd', {}, true }, -- append to a file using command
    { 'FileAppendPost', {}, true }, -- after appending to a file
    { 'FileAppendPre', {}, true }, -- before appending to a file
    { 'FileChangedRO', {}, true }, -- before first change to read-only file
    { 'FileChangedShell', {}, true }, -- after shell command that changed file
    { 'FileChangedShellPost', {}, true }, -- after (not) reloading changed file
    { 'FileReadCmd', {}, true }, -- read from a file using command
    { 'FileReadPost', {}, true }, -- after reading a file
    { 'FileReadPre', {}, true }, -- before reading a file
    { 'FileType', {}, true }, -- new file type detected (user defined)
    { 'FileWriteCmd', {}, true }, -- write to a file using command
    { 'FileWritePost', {}, true }, -- after writing a file
    { 'FileWritePre', {}, true }, -- before writing a file
    { 'FilterReadPost', {}, true }, -- after reading from a filter
    { 'FilterReadPre', {}, true }, -- before reading from a filter
    { 'FilterWritePost', {}, true }, -- after writing to a filter
    { 'FilterWritePre', {}, true }, -- before writing to a filter
    { 'FocusGained', {}, false }, -- got the focus
    { 'FocusLost', {}, false }, -- lost the focus to another app
    { 'FuncUndefined', {}, false }, -- if calling a function which doesn't exist
    { 'GUIEnter', {}, false }, -- after starting the GUI
    { 'GUIFailed', {}, false }, -- after starting the GUI failed
    { 'InsertChange', {}, true }, -- when changing Insert/Replace mode
    { 'InsertCharPre', {}, true }, -- before inserting a char
    { 'InsertEnter', {}, true }, -- when entering Insert mode
    { 'InsertLeave', {}, true }, -- just after leaving Insert mode
    { 'InsertLeavePre', {}, true }, -- just before leaving Insert mode
    { 'LspAttach', {}, false }, -- after an LSP client attaches to a buffer
    { 'LspDetach', {}, false }, -- after an LSP client detaches from a buffer
    { 'LspNotify', {}, false }, -- after an LSP notice has been sent to the server
    { 'LspProgress', {}, false }, -- after a LSP progress update
    { 'LspRequest', {}, false }, -- after an LSP request is started, canceled, or completed
    { 'LspTokenUpdate', {}, false }, -- after a visible LSP token is updated
    { 'MenuPopup', {}, false }, -- just before popup menu is displayed
    { 'ModeChanged', {}, false }, -- after changing the mode
    { 'OptionSet', {}, false }, -- after setting any option
    { 'QuickFixCmdPost', {}, false }, -- after :make, :grep etc.
    { 'QuickFixCmdPre', {}, false }, -- before :make, :grep etc.
    { 'QuitPre', {}, false }, -- before :quit
    { 'RecordingEnter', {}, true }, -- when starting to record a macro
    { 'RecordingLeave', {}, true }, -- just before a macro stops recording
    { 'RemoteReply', {}, false }, -- upon string reception from a remote vim
    { 'SafeState', {}, false }, -- going to wait for a character
    { 'SearchWrapped', {}, true }, -- after the search wrapped around
    { 'SessionLoadPost', {}, false }, -- after loading a session file
    { 'SessionWritePost', {}, false }, -- after writing a session file
    { 'ShellCmdPost', {}, false }, -- after ":!cmd"
    { 'ShellFilterPost', {}, true }, -- after ":1,2!cmd", ":w !cmd", ":r !cmd".
    { 'Signal', {}, false }, -- after nvim process received a signal
    { 'SourceCmd', {}, false }, -- sourcing a Vim script using command
    { 'SourcePost', {}, false }, -- after sourcing a Vim script
    { 'SourcePre', {}, false }, -- before sourcing a Vim script
    { 'SpellFileMissing', {}, false }, -- spell file missing
    { 'StdinReadPost', {}, false }, -- after reading from stdin
    { 'StdinReadPre', {}, false }, -- before reading from stdin
    { 'SwapExists', {}, false }, -- found existing swap file
    { 'Syntax', {}, false }, -- syntax selected
    { 'TabClosed', {}, false }, -- a tab has closed
    { 'TabEnter', {}, false }, -- after entering a tab page
    { 'TabLeave', {}, false }, -- before leaving a tab page
    { 'TabNew', {}, false }, -- when creating a new tab
    { 'TabNewEntered', {}, false }, -- after entering a new tab
    { 'TermChanged', {}, false }, -- after changing 'term'
    { 'TermClose', {}, false }, -- after the process exits
    { 'TermEnter', {}, false }, -- after entering Terminal mode
    { 'TermLeave', {}, false }, -- after leaving Terminal mode
    { 'TermOpen', {}, false }, -- after opening a terminal buffer
    { 'TermRequest', {}, false }, -- after an unhandled OSC sequence is emitted
    { 'TermResponse', {}, false }, -- after setting "v:termresponse"
    { 'TextChanged', {}, true }, -- text was modified
    { 'TextChangedI', {}, true }, -- text was modified in Insert mode(no popup)
    { 'TextChangedP', {}, true }, -- text was modified in Insert mode(popup)
    { 'TextChangedT', {}, true }, -- text was modified in Terminal mode
    { 'TextYankPost', {}, true }, -- after a yank or delete was done (y, d, c)
    { 'UIEnter', {}, false }, -- after UI attaches
    { 'UILeave', {}, false }, -- after UI detaches
    { 'User', {}, false }, -- user defined autocommand
    { 'VimEnter', {}, false }, -- after starting Vim
    { 'VimLeave', {}, false }, -- before exiting Vim
    { 'VimLeavePre', {}, false }, -- before exiting Vim and writing ShaDa file
    { 'VimResized', {}, false }, -- after Vim window was resized
    { 'VimResume', {}, false }, -- after Nvim is resumed
    { 'VimSuspend', {}, false }, -- before Nvim is suspended
    { 'WinClosed', {}, true }, -- after closing a window
    { 'WinEnter', {}, true }, -- after entering a window
    { 'WinLeave', {}, true }, -- before leaving a window
    { 'WinNew', {}, false }, -- when entering a new window
    { 'WinResized', {}, true }, -- after a window was resized
    { 'WinScrolled', {}, true }, -- after a window was scrolled or resized
  },
  -- List of nvim-specific events or aliases for the purpose of generating
  -- syntax file
  nvim_specific = {
    BufModifiedSet = true,
    DiagnosticChanged = true,
    LspAttach = true,
    LspDetach = true,
    LspNotify = true,
    LspProgress = true,
    LspRequest = true,
    LspTokenUpdate = true,
    RecordingEnter = true,
    RecordingLeave = true,
    Signal = true,
    TabNewEntered = true,
    TermClose = true,
    TermOpen = true,
    TermRequest = true,
    UIEnter = true,
    UILeave = true,
  },
}
