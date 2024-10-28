--- @meta _
-- THIS FILE IS GENERATED
-- DO NOT EDIT
error('Cannot require a meta file')

--- @class vim.v
vim.v = ...

--- The command line arguments Vim was invoked with.  This is a
--- list of strings.  The first item is the Vim command.
--- See `v:progpath` for the command with full path.
--- @type string[]
vim.v.argv = ...

--- Argument for evaluating 'formatexpr' and used for the typed
--- character when using <expr> in an abbreviation `:map-<expr>`.
--- It is also used by the `InsertCharPre` and `InsertEnter` events.
--- @type any
vim.v.char = ...

--- The name of the character encoding of a file to be converted.
--- Only valid while evaluating the 'charconvert' option.
--- @type string
vim.v.charconvert_from = ...

--- The name of the character encoding of a file after conversion.
--- Only valid while evaluating the 'charconvert' option.
--- @type string
vim.v.charconvert_to = ...

--- The extra arguments ("++p", "++enc=", "++ff=") given to a file
--- read/write command.  This is set before an autocommand event
--- for a file read/write command is triggered.  There is a
--- leading space to make it possible to append this variable
--- directly after the read/write command. Note: "+cmd" isn't
--- included here, because it will be executed anyway.
--- @type string
vim.v.cmdarg = ...

--- Set like v:cmdarg for a file read/write command.  When a "!"
--- was used the value is 1, otherwise it is 0.  Note that this
--- can only be used in autocommands.  For user commands `<bang>`
--- can be used.
--- @type integer
vim.v.cmdbang = ...

--- When evaluating 'findexpr': if 'findexpr' is used for cmdline
--- completion the value is `v:true`, otherwise it is `v:false`.
--- @type boolean
vim.v.cmdcomplete = ...

--- The current locale setting for collation order of the runtime
--- environment.  This allows Vim scripts to be aware of the
--- current locale encoding.  Technical: it's the value of
--- LC_COLLATE.  When not using a locale the value is "C".
--- This variable can not be set directly, use the `:language`
--- command.
--- See `multi-lang`.
--- @type string
vim.v.collate = ...

--- Dictionary containing the `complete-items` for the most
--- recently completed word after `CompleteDone`.  Empty if the
--- completion failed, or after leaving and re-entering insert
--- mode.
--- Note: Plugins can modify the value to emulate the builtin
--- `CompleteDone` event behavior.
--- @type any
vim.v.completed_item = ...

--- The count given for the last Normal mode command.  Can be used
--- to get the count before a mapping.  Read-only.  Example:
---
--- ```vim
---   :map _x :<C-U>echo "the count is " .. v:count<CR>
--- ```
---
--- Note: The <C-U> is required to remove the line range that you
--- get when typing ':' after a count.
--- When there are two counts, as in "3d2w", they are multiplied,
--- just like what happens in the command, "d6w" for the example.
--- Also used for evaluating the 'formatexpr' option.
--- @type integer
vim.v.count = ...

--- Just like "v:count", but defaults to one when no count is
--- used.
--- @type integer
vim.v.count1 = ...

--- The current locale setting for characters of the runtime
--- environment.  This allows Vim scripts to be aware of the
--- current locale encoding.  Technical: it's the value of
--- LC_CTYPE.  When not using a locale the value is "C".
--- This variable can not be set directly, use the `:language`
--- command.
--- See `multi-lang`.
--- @type any
vim.v.ctype = ...

--- Normally zero.  When a deadly signal is caught it's set to
--- one.  When multiple signals are caught the number increases.
--- Can be used in an autocommand to check if Vim didn't
--- terminate normally.
--- Example:
---
--- ```vim
---   :au VimLeave * if v:dying | echo "\nAAAAaaaarrrggghhhh!!!\n" | endif
--- ```
---
--- Note: if another deadly signal is caught when v:dying is one,
--- VimLeave autocommands will not be executed.
--- @type integer
vim.v.dying = ...

--- Number of screen cells that can be used for an `:echo` message
--- in the last screen line before causing the `hit-enter-prompt`.
--- Depends on 'showcmd', 'ruler' and 'columns'.  You need to
--- check 'cmdheight' for whether there are full-width lines
--- available above the last line.
--- @type integer
vim.v.echospace = ...

--- Last given error message.
--- Modifiable (can be set).
--- Example:
---
--- ```vim
---   let v:errmsg = ""
---   silent! next
---   if v:errmsg != ""
---     " ... handle error
--- ```
--- @type string
vim.v.errmsg = ...

--- Errors found by assert functions, such as `assert_true()`.
--- This is a list of strings.
--- The assert functions append an item when an assert fails.
--- The return value indicates this: a one is returned if an item
--- was added to v:errors, otherwise zero is returned.
--- To remove old results make it empty:
---
--- ```vim
---   let v:errors = []
--- ```
---
--- If v:errors is set to anything but a list it is made an empty
--- list by the assert function.
--- @type string[]
vim.v.errors = ...

--- Dictionary of event data for the current `autocommand`.  Valid
--- only during the event lifetime; storing or passing v:event is
--- invalid!  Copy it instead:
---
--- ```vim
---   au TextYankPost * let g:foo = deepcopy(v:event)
--- ```
---
--- Keys vary by event; see the documentation for the specific
--- event, e.g. `DirChanged` or `TextYankPost`.
---   KEY              DESCRIPTION ~
---   abort            Whether the event triggered during
---                    an aborting condition (e.g. `c_Esc` or
---                    `c_CTRL-C` for `CmdlineLeave`).
---   chan             `channel-id`
---   cmdlevel         Level of cmdline.
---   cmdtype          Type of cmdline, `cmdline-char`.
---   cwd              Current working directory.
---   inclusive        Motion is `inclusive`, else exclusive.
---   scope            Event-specific scope name.
---   operator         Current `operator`.  Also set for Ex
---   commands         (unlike `v:operator`). For
---                    example if `TextYankPost` is triggered
---                    by the `:yank` Ex command then
---                    `v:event.operator` is "y".
---   regcontents      Text stored in the register as a
---                    `readfile()`-style list of lines.
---   regname          Requested register (e.g "x" for "xyy)
---                    or the empty string for an unnamed
---                    operation.
---   regtype          Type of register as returned by
---                    `getregtype()`.
---   visual           Selection is visual (as opposed to,
---                    e.g., via motion).
---   completed_item   Current selected complete item on
---                    `CompleteChanged`, Is `{}` when no complete
---                    item selected.
---   height           Height of popup menu on `CompleteChanged`
---   width            Width of popup menu on `CompleteChanged`
---   row              Row count of popup menu on `CompleteChanged`,
---                    relative to screen.
---   col              Col count of popup menu on `CompleteChanged`,
---                    relative to screen.
---   size             Total number of completion items on
---                    `CompleteChanged`.
---   scrollbar        Is `v:true` if popup menu have scrollbar, or
---                    `v:false` if not.
---   changed_window   Is `v:true` if the event fired while
---                    changing window  (or tab) on `DirChanged`.
---   status           Job status or exit code, -1 means "unknown". `TermClose`
---   reason           Reason for completion being done. `CompleteDone`
--- @type any
vim.v.event = ...

--- The value of the exception most recently caught and not
--- finished.  See also `v:throwpoint` and `throw-variables`.
--- Example:
---
--- ```vim
---   try
---     throw "oops"
---   catch /.*/
---     echo "caught " .. v:exception
---   endtry
--- ```
---
--- Output: "caught oops".
--- @type string
vim.v.exception = ...

--- Exit code, or `v:null` before invoking the `VimLeavePre`
--- and `VimLeave` autocmds.  See `:q`, `:x` and `:cquit`.
--- Example:
---
--- ```vim
---   :au VimLeave * echo "Exit value is " .. v:exiting
--- ```
--- @type any
vim.v.exiting = ...

--- Special value used to put "false" in JSON and msgpack.  See
--- `json_encode()`.  This value is converted to "v:false" when used
--- as a String (e.g. in `expr5` with string concatenation
--- operator) and to zero when used as a Number (e.g. in `expr5`
--- or `expr7` when used with numeric operators). Read-only.
--- @type boolean
vim.v['false'] = ...

--- What should happen after a `FileChangedShell` event was
--- triggered.  Can be used in an autocommand to tell Vim what to
--- do with the affected buffer:
---   reload  Reload the buffer (does not work if
---           the file was deleted).
---   edit    Reload the buffer and detect the
---           values for options such as
---           'fileformat', 'fileencoding', 'binary'
---           (does not work if the file was
---           deleted).
---   ask     Ask the user what to do, as if there
---           was no autocommand.  Except that when
---           only the timestamp changed nothing
---           will happen.
---   <empty> Nothing, the autocommand should do
---           everything that needs to be done.
--- The default is empty.  If another (invalid) value is used then
--- Vim behaves like it is empty, there is no warning message.
--- @type string
vim.v.fcs_choice = ...

--- The reason why the `FileChangedShell` event was triggered.
--- Can be used in an autocommand to decide what to do and/or what
--- to set v:fcs_choice to.  Possible values:
---   deleted   file no longer exists
---   conflict  file contents, mode or timestamp was
---             changed and buffer is modified
---   changed   file contents has changed
---   mode      mode of file changed
---   time      only file timestamp changed
--- @type string
vim.v.fcs_reason = ...

--- When evaluating 'includeexpr': the file name that was
--- detected.  When evaluating 'findexpr': the argument passed to
--- the `:find` command.  Empty otherwise.
--- @type string
vim.v.fname = ...

--- The name of the diff (patch) file.  Only valid while
--- evaluating 'patchexpr'.
--- @type string
vim.v.fname_diff = ...

--- The name of the input file.  Valid while evaluating:
---   option         used for ~
---   'charconvert'  file to be converted
---   'diffexpr'     original file
---   'patchexpr'    original file
--- And set to the swap file name for `SwapExists`.
--- @type string
vim.v.fname_in = ...

--- The name of the new version of the file.  Only valid while
--- evaluating 'diffexpr'.
--- @type string
vim.v.fname_new = ...

--- The name of the output file.  Only valid while
--- evaluating:
---   option           used for ~
---   'charconvert'    resulting converted file [1]
---   'diffexpr'       output of diff
---   'patchexpr'      resulting patched file
--- [1] When doing conversion for a write command (e.g., ":w
--- file") it will be equal to v:fname_in.  When doing conversion
--- for a read command (e.g., ":e file") it will be a temporary
--- file and different from v:fname_in.
--- @type string
vim.v.fname_out = ...

--- Used for 'foldtext': dashes representing foldlevel of a closed
--- fold.
--- Read-only in the `sandbox`. `fold-foldtext`
--- @type string
vim.v.folddashes = ...

--- Used for 'foldtext': last line of closed fold.
--- Read-only in the `sandbox`. `fold-foldtext`
--- @type integer
vim.v.foldend = ...

--- Used for 'foldtext': foldlevel of closed fold.
--- Read-only in the `sandbox`. `fold-foldtext`
--- @type integer
vim.v.foldlevel = ...

--- Used for 'foldtext': first line of closed fold.
--- Read-only in the `sandbox`. `fold-foldtext`
--- @type integer
vim.v.foldstart = ...

--- Variable that indicates whether search highlighting is on.
--- Setting it makes sense only if 'hlsearch' is enabled. Setting
--- this variable to zero acts like the `:nohlsearch` command,
--- setting it to one acts like
---
--- ```vim
---   let &hlsearch = &hlsearch
--- ```
---
--- Note that the value is restored when returning from a
--- function. `function-search-undo`.
--- @type integer
vim.v.hlsearch = ...

--- Used for the `InsertEnter` and `InsertChange` autocommand
--- events.  Values:
---   i    Insert mode
---   r    Replace mode
---   v    Virtual Replace mode
--- @type string
vim.v.insertmode = ...

--- Key of the current item of a `Dictionary`.  Only valid while
--- evaluating the expression used with `map()` and `filter()`.
--- Read-only.
--- @type string
vim.v.key = ...

--- The current locale setting for messages of the runtime
--- environment.  This allows Vim scripts to be aware of the
--- current language.  Technical: it's the value of LC_MESSAGES.
--- The value is system dependent.
--- This variable can not be set directly, use the `:language`
--- command.
--- It can be different from `v:ctype` when messages are desired
--- in a different language than what is used for character
--- encoding.  See `multi-lang`.
--- @type string
vim.v.lang = ...

--- The current locale setting for time messages of the runtime
--- environment.  This allows Vim scripts to be aware of the
--- current language.  Technical: it's the value of LC_TIME.
--- This variable can not be set directly, use the `:language`
--- command.  See `multi-lang`.
--- @type string
vim.v.lc_time = ...

--- Line number for the 'foldexpr' `fold-expr`, 'formatexpr',
--- 'indentexpr' and 'statuscolumn' expressions, tab page number
--- for 'guitablabel' and 'guitabtooltip'.  Only valid while one of
--- these expressions is being evaluated.  Read-only when in the
--- `sandbox`.
--- @type integer
vim.v.lnum = ...

--- Prefix for calling Lua functions from expressions.
--- See `v:lua-call` for more information.
--- @type any
vim.v.lua = ...

--- Maximum line length.  Depending on where it is used it can be
--- screen columns, characters or bytes.  The value currently is
--- 2147483647 on all systems.
--- @type integer
vim.v.maxcol = ...

--- Column number for a mouse click obtained with `getchar()`.
--- This is the screen column number, like with `virtcol()`.  The
--- value is zero when there was no mouse button click.
--- @type integer
vim.v.mouse_col = ...

--- Line number for a mouse click obtained with `getchar()`.
--- This is the text line number, not the screen line number.  The
--- value is zero when there was no mouse button click.
--- @type integer
vim.v.mouse_lnum = ...

--- Window number for a mouse click obtained with `getchar()`.
--- First window has number 1, like with `winnr()`.  The value is
--- zero when there was no mouse button click.
--- @type integer
vim.v.mouse_win = ...

--- `window-ID` for a mouse click obtained with `getchar()`.
--- The value is zero when there was no mouse button click.
--- @type integer
vim.v.mouse_winid = ...

--- Dictionary containing msgpack types used by `msgpackparse()`
--- and `msgpackdump()`. All types inside dictionary are fixed
--- (not editable) empty lists. To check whether some list is one
--- of msgpack types, use `is` operator.
--- @type any
vim.v.msgpack_types = ...

--- Special value used to put "null" in JSON and NIL in msgpack.
--- See `json_encode()`.  This value is converted to "v:null" when
--- used as a String (e.g. in `expr5` with string concatenation
--- operator) and to zero when used as a Number (e.g. in `expr5`
--- or `expr7` when used with numeric operators). Read-only.
--- In some places `v:null` can be used for a List, Dict, etc.
--- that is not set.  That is slightly different than an empty
--- List, Dict, etc.
--- @type vim.NIL
vim.v.null = ...

--- Maximum value of a number.
--- @type integer
vim.v.numbermax = ...

--- Minimum value of a number (negative).
--- @type integer
vim.v.numbermin = ...

--- Number of bits in a Number.  This is normally 64, but on some
--- systems it may be 32.
--- @type integer
vim.v.numbersize = ...

--- List of file names that is loaded from the `shada` file on
--- startup.  These are the files that Vim remembers marks for.
--- The length of the List is limited by the ' argument of the
--- 'shada' option (default is 100).
--- When the `shada` file is not used the List is empty.
--- Also see `:oldfiles` and `c_#<`.
--- The List can be modified, but this has no effect on what is
--- stored in the `shada` file later.  If you use values other
--- than String this will cause trouble.
--- @type string[]
vim.v.oldfiles = ...

--- The last operator given in Normal mode.  This is a single
--- character except for commands starting with <g> or <z>,
--- in which case it is two characters.  Best used alongside
--- `v:prevcount` and `v:register`.  Useful if you want to cancel
--- Operator-pending mode and then use the operator, e.g.:
---
--- ```vim
---   :omap O <Esc>:call MyMotion(v:operator)<CR>
--- ```
---
--- The value remains set until another operator is entered, thus
--- don't expect it to be empty.
--- v:operator is not set for `:delete`, `:yank` or other Ex
--- commands.
--- Read-only.
--- @type string
vim.v.operator = ...

--- Command used to set the option. Valid while executing an
--- `OptionSet` autocommand.
---   value        option was set via ~
---   "setlocal"   `:setlocal` or `:let l:xxx`
---   "setglobal"  `:setglobal` or `:let g:xxx`
---   "set"        `:set` or `:let`
---   "modeline"   `modeline`
--- @type string
vim.v.option_command = ...

--- New value of the option. Valid while executing an `OptionSet`
--- autocommand.
--- @type any
vim.v.option_new = ...

--- Old value of the option. Valid while executing an `OptionSet`
--- autocommand. Depending on the command used for setting and the
--- kind of option this is either the local old value or the
--- global old value.
--- @type any
vim.v.option_old = ...

--- Old global value of the option. Valid while executing an
--- `OptionSet` autocommand.
--- @type any
vim.v.option_oldglobal = ...

--- Old local value of the option. Valid while executing an
--- `OptionSet` autocommand.
--- @type any
vim.v.option_oldlocal = ...

--- Scope of the set command. Valid while executing an
--- `OptionSet` autocommand. Can be either "global" or "local"
--- @type string
vim.v.option_type = ...

--- The count given for the last but one Normal mode command.
--- This is the v:count value of the previous command.  Useful if
--- you want to cancel Visual or Operator-pending mode and then
--- use the count, e.g.:
---
--- ```vim
---   :vmap % <Esc>:call MyFilter(v:prevcount)<CR>
--- ```
---
--- Read-only.
--- @type integer
vim.v.prevcount = ...

--- Normally zero.  Set to one after using ":profile start".
--- See `profiling`.
--- @type integer
vim.v.profiling = ...

--- The name by which Nvim was invoked (with path removed).
--- Read-only.
--- @type string
vim.v.progname = ...

--- Absolute path to the current running Nvim.
--- Read-only.
--- @type string
vim.v.progpath = ...

--- The name of the register in effect for the current normal mode
--- command (regardless of whether that command actually used a
--- register).  Or for the currently executing normal mode mapping
--- (use this in custom commands that take a register).
--- If none is supplied it is the default register '"', unless
--- 'clipboard' contains "unnamed" or "unnamedplus", then it is
--- "*" or '+'.
--- Also see `getreg()` and `setreg()`
--- @type string
vim.v.register = ...

--- Relative line number for the 'statuscolumn' expression.
--- Read-only.
--- @type integer
vim.v.relnum = ...

--- String describing the script or function that caused the
--- screen to scroll up.  It's only set when it is empty, thus the
--- first reason is remembered.  It is set to "Unknown" for a
--- typed command.
--- This can be used to find out why your script causes the
--- hit-enter prompt.
--- @type any
vim.v.scrollstart = ...

--- Search direction:  1 after a forward search, 0 after a
--- backward search.  It is reset to forward when directly setting
--- the last search pattern, see `quote/`.
--- Note that the value is restored when returning from a
--- function. `function-search-undo`.
--- Read-write.
--- @type integer
vim.v.searchforward = ...

--- Primary listen-address of Nvim, the first item returned by
--- `serverlist()`. Usually this is the named pipe created by Nvim
--- at `startup` or given by `--listen` (or the deprecated
--- `$NVIM_LISTEN_ADDRESS` env var).
---
--- See also `serverstart()` `serverstop()`.
--- Read-only.
---
---                                                      *$NVIM*
--- $NVIM is set by `terminal` and `jobstart()`, and is thus
--- a hint that the current environment is a subprocess of Nvim.
--- Example:
---
--- ```vim
---   if $NVIM
---     echo nvim_get_chan_info(v:parent)
---   endif
--- ```
---
--- Note the contents of $NVIM may change in the future.
--- @type string
vim.v.servername = ...

--- Result of the last shell command.  When non-zero, the last
--- shell command had an error.  When zero, there was no problem.
--- This only works when the shell returns the error code to Vim.
--- The value -1 is often used when the command could not be
--- executed.  Read-only.
--- Example:
---
--- ```vim
---   !mv foo bar
---   if v:shell_error
---     echo 'could not rename "foo" to "bar"!'
---   endif
--- ```
--- @type integer
vim.v.shell_error = ...

--- Last given status message.
--- Modifiable (can be set).
--- @type string
vim.v.statusmsg = ...

--- `channel-id` corresponding to stderr. The value is always 2;
--- use this variable to make your code more descriptive.
--- Unlike stdin and stdout (see `stdioopen()`), stderr is always
--- open for writing. Example:
---
--- ```vim
--- :call chansend(v:stderr, "error: toaster empty\n")
--- ```
--- @type integer
vim.v.stderr = ...

--- `SwapExists` autocommands can set this to the selected choice
--- for handling an existing swapfile:
---   'o'    Open read-only
---   'e'    Edit anyway
---   'r'    Recover
---   'd'    Delete swapfile
---   'q'    Quit
---   'a'    Abort
--- The value should be a single-character string.  An empty value
--- results in the user being asked, as would happen when there is
--- no SwapExists autocommand.  The default is empty.
--- @type string
vim.v.swapchoice = ...

--- Normal mode command to be executed after a file has been
--- opened.  Can be used for a `SwapExists` autocommand to have
--- another Vim open the file and jump to the right place.  For
--- example, when jumping to a tag the value is ":tag tagname\r".
--- For ":edit +cmd file" the value is ":cmd\r".
--- @type string
vim.v.swapcommand = ...

--- Name of the swapfile found.
--- Only valid during `SwapExists` event.
--- Read-only.
--- @type string
vim.v.swapname = ...

--- Value of `Blob` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_blob = ...

--- Value of `Boolean` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_bool = ...

--- Value of `Dictionary` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_dict = ...

--- Value of `Float` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_float = ...

--- Value of `Funcref` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_func = ...

--- Value of `List` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_list = ...

--- Value of `Number` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_number = ...

--- Value of `String` type.  Read-only.  See: `type()`
--- @type integer
vim.v.t_string = ...

--- The value of the most recent OSC or DCS control sequence
--- sent from a process running in the embedded `terminal`.
--- This can be read in a `TermRequest` event handler to respond
--- to queries from embedded applications.
--- @type string
vim.v.termrequest = ...

--- The value of the most recent OSC or DCS control sequence
--- received by Nvim from the terminal. This can be read in a
--- `TermResponse` event handler after querying the terminal using
--- another escape sequence.
--- @type string
vim.v.termresponse = ...

--- Must be set before using `test_garbagecollect_now()`.
--- @type any
vim.v.testing = ...

--- Full filename of the last loaded or saved session file.
--- Empty when no session file has been saved.  See `:mksession`.
--- Modifiable (can be set).
--- @type any
vim.v.this_session = ...

--- The point where the exception most recently caught and not
--- finished was thrown.  Not set when commands are typed.  See
--- also `v:exception` and `throw-variables`.
--- Example:
---
--- ```vim
---   try
---     throw "oops"
---   catch /.*/
---     echo "Exception from" v:throwpoint
---   endtry
--- ```
---
--- Output: "Exception from test.vim, line 2"
--- @type any
vim.v.throwpoint = ...

--- Special value used to put "true" in JSON and msgpack.  See
--- `json_encode()`.  This value is converted to "v:true" when used
--- as a String (e.g. in `expr5` with string concatenation
--- operator) and to one when used as a Number (e.g. in `expr5` or
--- `expr7` when used with numeric operators). Read-only.
--- @type boolean
vim.v['true'] = ...

--- Value of the current item of a `List` or `Dictionary`.  Only
--- valid while evaluating the expression used with `map()` and
--- `filter()`.  Read-only.
--- @type any
vim.v.val = ...

--- Vim version number: major version times 100 plus minor
--- version.  Vim 5.0 is 500, Vim 5.1 is 501.
--- Read-only.
--- Use `has()` to check the Nvim (not Vim) version:
---
--- ```vim
---   :if has("nvim-0.2.1")
--- ```
--- @type integer
vim.v.version = ...

--- 0 during startup, 1 just before `VimEnter`.
--- Read-only.
--- @type integer
vim.v.vim_did_enter = ...

--- Virtual line number for the 'statuscolumn' expression.
--- Negative when drawing the status column for virtual lines, zero
--- when drawing an actual buffer line, and positive when drawing
--- the wrapped part of a buffer line.
--- Read-only.
--- @type integer
vim.v.virtnum = ...

--- Last given warning message.
--- Modifiable (can be set).
--- @type string
vim.v.warningmsg = ...

--- Application-specific window "handle" which may be set by any
--- attached UI. Defaults to zero.
--- Note: For Nvim `windows` use `winnr()` or `win_getid()`, see
--- `window-ID`.
--- @type integer
vim.v.windowid = ...
