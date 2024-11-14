---@meta
-- luacheck: no unused args

error('Cannot require a meta file')

--- @brief <pre>help
--- vim.api.{func}({...})                                                    *vim.api*
---     Invokes Nvim |API| function {func} with arguments {...}.
---     Example: call the "nvim_get_current_line()" API function: >lua
---         print(tostring(vim.api.nvim_get_current_line()))
---
--- vim.NIL                                                                  *vim.NIL*
---     Special value representing NIL in |RPC| and |v:null| in Vimscript
---     conversion, and similar cases. Lua `nil` cannot be used as part of a Lua
---     table representing a Dictionary or Array, because it is treated as
---     missing: `{"foo", nil}` is the same as `{"foo"}`.
---
--- vim.type_idx                                                        *vim.type_idx*
---     Type index for use in |lua-special-tbl|. Specifying one of the values from
---     |vim.types| allows typing the empty table (it is unclear whether empty Lua
---     table represents empty list or empty array) and forcing integral numbers
---     to be |Float|. See |lua-special-tbl| for more details.
---
--- vim.val_idx                                                          *vim.val_idx*
---     Value index for tables representing |Float|s. A table representing
---     floating-point value 1.0 looks like this: >lua
---         {
---           [vim.type_idx] = vim.types.float,
---           [vim.val_idx] = 1.0,
---         }
--- <    See also |vim.type_idx| and |lua-special-tbl|.
---
--- vim.types                                                              *vim.types*
---     Table with possible values for |vim.type_idx|. Contains two sets of
---     key-value pairs: first maps possible values for |vim.type_idx| to
---     human-readable strings, second maps human-readable type names to values
---     for |vim.type_idx|. Currently contains pairs for `float`, `array` and
---         `dictionary` types.
---
---     Note: One must expect that values corresponding to `vim.types.float`,
---     `vim.types.array` and `vim.types.dictionary` fall under only two following
---     assumptions:
---     1. Value may serve both as a key and as a value in a table. Given the
---        properties of Lua tables this basically means “value is not `nil`”.
---     2. For each value in `vim.types` table `vim.types[vim.types[value]]` is the
---        same as `value`.
---     No other restrictions are put on types, and it is not guaranteed that
---     values corresponding to `vim.types.float`, `vim.types.array` and
---     `vim.types.dictionary` will not change or that `vim.types` table will only
---     contain values for these three types.
---
---                                                    *log_levels* *vim.log.levels*
--- Log levels are one of the values defined in `vim.log.levels`:
---
---     vim.log.levels.DEBUG
---     vim.log.levels.ERROR
---     vim.log.levels.INFO
---     vim.log.levels.TRACE
---     vim.log.levels.WARN
---     vim.log.levels.OFF
---
--- </pre>

---@nodoc
---@class vim.NIL

---@type vim.NIL
---@nodoc
vim.NIL = ...

--- Returns true if the code is executing as part of a "fast" event handler,
--- where most of the API is disabled. These are low-level events (e.g.
--- |lua-loop-callbacks|) which can be invoked whenever Nvim polls for input.
--- When this is `false` most API functions are callable (but may be subject
--- to other restrictions such as |textlock|).
function vim.in_fast_event() end

--- Creates a special empty table (marked with a metatable), which Nvim
--- converts to an empty dictionary when translating Lua values to Vimscript
--- or API types. Nvim by default converts an empty table `{}` without this
--- metatable to an list/array.
---
--- Note: If numeric keys are present in the table, Nvim ignores the metatable
--- marker and converts the dict to a list/array anyway.
--- @return table
function vim.empty_dict() end

--- Sends {event} to {channel} via |RPC| and returns immediately. If {channel}
--- is 0, the event is broadcast to all channels.
---
--- This function also works in a fast callback |lua-loop-callbacks|.
--- @param channel integer
--- @param method string
--- @param ...? any
function vim.rpcnotify(channel, method, ...) end

--- Sends a request to {channel} to invoke {method} via |RPC| and blocks until
--- a response is received.
---
--- Note: NIL values as part of the return value is represented as |vim.NIL|
--- special value
--- @param channel integer
--- @param method string
--- @param ...? any
function vim.rpcrequest(channel, method, ...) end

--- Compares strings case-insensitively.
--- @param a string
--- @param b string
--- @return 0|1|-1
--- if strings are
--- equal, {a} is greater than {b} or {a} is lesser than {b}, respectively.
function vim.stricmp(a, b) end

--- Gets a list of the starting byte positions of each UTF-8 codepoint in the given string.
---
--- Embedded NUL bytes are treated as terminating the string.
--- @param str string
--- @return integer[]
function vim.str_utf_pos(str) end

--- Gets the distance (in bytes) from the starting byte of the codepoint (character) that {index}
--- points to.
---
--- The result can be added to {index} to get the starting byte of a character.
---
--- Examples:
---
--- ```lua
--- -- The character 'æ' is stored as the bytes '\xc3\xa6' (using UTF-8)
---
--- -- Returns 0 because the index is pointing at the first byte of a character
--- vim.str_utf_start('æ', 1)
---
--- -- Returns -1 because the index is pointing at the second byte of a character
--- vim.str_utf_start('æ', 2)
--- ```
---
--- @param str string
--- @param index integer
--- @return integer
function vim.str_utf_start(str, index) end

--- Gets the distance (in bytes) from the last byte of the codepoint (character) that {index} points
--- to.
---
--- Examples:
---
--- ```lua
--- -- The character 'æ' is stored as the bytes '\xc3\xa6' (using UTF-8)
---
--- -- Returns 0 because the index is pointing at the last byte of a character
--- vim.str_utf_end('æ', 2)
---
--- -- Returns 1 because the index is pointing at the penultimate byte of a character
--- vim.str_utf_end('æ', 1)
--- ```
---
--- @param str string
--- @param index integer
--- @return integer
function vim.str_utf_end(str, index) end

--- The result is a String, which is the text {str} converted from
--- encoding {from} to encoding {to}. When the conversion fails `nil` is
--- returned.  When some characters could not be converted they
--- are replaced with "?".
--- The encoding names are whatever the iconv() library function
--- can accept, see ":Man 3 iconv".
---
--- @param str string Text to convert
--- @param from string Encoding of {str}
--- @param to string Target encoding
--- @return string? : Converted string if conversion succeeds, `nil` otherwise.
function vim.iconv(str, from, to, opts) end

--- Schedules {fn} to be invoked soon by the main event-loop. Useful
--- to avoid |textlock| or other temporary restrictions.
--- @param fn fun()
function vim.schedule(fn) end

--- Wait for {time} in milliseconds until {callback} returns `true`.
---
--- Executes {callback} immediately and at approximately {interval}
--- milliseconds (default 200). Nvim still processes other events during
--- this time.
---
--- Cannot be called while in an |api-fast| event.
---
--- Examples:
---
--- ```lua
--- ---
--- -- Wait for 100 ms, allowing other events to process
--- vim.wait(100, function() end)
---
--- ---
--- -- Wait for 100 ms or until global variable set.
--- vim.wait(100, function() return vim.g.waiting_for_var end)
---
--- ---
--- -- Wait for 1 second or until global variable set, checking every ~500 ms
--- vim.wait(1000, function() return vim.g.waiting_for_var end, 500)
---
--- ---
--- -- Schedule a function to set a value in 100ms
--- vim.defer_fn(function() vim.g.timer_result = true end, 100)
---
--- -- Would wait ten seconds if results blocked. Actually only waits  100 ms
--- if vim.wait(10000, function() return vim.g.timer_result end) then
---   print('Only waiting a little bit of time!')
--- end
--- ```
---
--- @param time integer Number of milliseconds to wait
--- @param callback? fun(): boolean Optional callback. Waits until {callback} returns true
--- @param interval? integer (Approximate) number of milliseconds to wait between polls
--- @param fast_only? boolean If true, only |api-fast| events will be processed.
--- @return boolean, nil|-1|-2
---     - If {callback} returns `true` during the {time}: `true, nil`
---     - If {callback} never returns `true` during the {time}: `false, -1`
---     - If {callback} is interrupted during the {time}: `false, -2`
---     - If {callback} errors, the error is raised.
function vim.wait(time, callback, interval, fast_only) end

--- Attach to |ui-events|, similar to |nvim_ui_attach()| but receive events
--- as Lua callback. Can be used to implement screen elements like
--- popupmenu or message handling in Lua.
---
--- {options} should be a dictionary-like table, where `ext_...` options should
--- be set to true to receive events for the respective external element.
---
--- {callback} receives event name plus additional parameters. See |ui-popupmenu|
--- and the sections below for event format for respective events.
---
--- Callbacks for `msg_show` events are executed in |api-fast| context.
---
--- Excessive errors inside the callback will result in forced detachment.
---
--- WARNING: This api is considered experimental.  Usability will vary for
--- different screen elements. In particular `ext_messages` behavior is subject
--- to further changes and usability improvements.  This is expected to be
--- used to handle messages when setting 'cmdheight' to zero (which is
--- likewise experimental).
---
--- Example (stub for a |ui-popupmenu| implementation):
---
--- ```lua
--- ns = vim.api.nvim_create_namespace('my_fancy_pum')
---
--- vim.ui_attach(ns, {ext_popupmenu=true}, function(event, ...)
---   if event == "popupmenu_show" then
---     local items, selected, row, col, grid = ...
---     print("display pum ", #items)
---   elseif event == "popupmenu_select" then
---     local selected = ...
---     print("selected", selected)
---   elseif event == "popupmenu_hide" then
---     print("FIN")
---   end
--- end)
--- ```
---
--- @since 0
---
--- @param ns integer
--- @param options table<string, any>
--- @param callback fun()
function vim.ui_attach(ns, options, callback) end

--- Detach a callback previously attached with |vim.ui_attach()| for the
--- given namespace {ns}.
--- @param ns integer
function vim.ui_detach(ns) end
