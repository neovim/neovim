local default_handlers = require('vim.lsp.handlers')
local log = require('vim.lsp.log')
local lsp_rpc = require('vim.lsp.rpc')
local protocol = require('vim.lsp.protocol')
local util = require('vim.lsp.util')
local sync = require('vim.lsp.sync')

local vim = vim
local api = vim.api
local nvim_err_writeln, nvim_buf_get_lines, nvim_command, nvim_buf_get_option, nvim_exec_autocmds =
  api.nvim_err_writeln,
  api.nvim_buf_get_lines,
  api.nvim_command,
  api.nvim_buf_get_option,
  api.nvim_exec_autocmds
local uv = vim.loop
local tbl_isempty, tbl_extend = vim.tbl_isempty, vim.tbl_extend
local validate = vim.validate
local if_nil = vim.F.if_nil

local lsp = {
  protocol = protocol,

  handlers = default_handlers,

  buf = require('vim.lsp.buf'),
  diagnostic = require('vim.lsp.diagnostic'),
  codelens = require('vim.lsp.codelens'),
  util = util,

  -- Allow raw RPC access.
  rpc = lsp_rpc,

  -- Export these directly from rpc.
  rpc_response_error = lsp_rpc.rpc_response_error,
}

-- maps request name to the required server_capability in the client.
lsp._request_name_to_capability = {
  ['textDocument/hover'] = { 'hoverProvider' },
  ['textDocument/signatureHelp'] = { 'signatureHelpProvider' },
  ['textDocument/definition'] = { 'definitionProvider' },
  ['textDocument/implementation'] = { 'implementationProvider' },
  ['textDocument/declaration'] = { 'declarationProvider' },
  ['textDocument/typeDefinition'] = { 'typeDefinitionProvider' },
  ['textDocument/documentSymbol'] = { 'documentSymbolProvider' },
  ['textDocument/prepareCallHierarchy'] = { 'callHierarchyProvider' },
  ['textDocument/rename'] = { 'renameProvider' },
  ['textDocument/prepareRename'] = { 'renameProvider', 'prepareProvider' },
  ['textDocument/codeAction'] = { 'codeActionProvider' },
  ['textDocument/codeLens'] = { 'codeLensProvider' },
  ['codeLens/resolve'] = { 'codeLensProvider', 'resolveProvider' },
  ['workspace/executeCommand'] = { 'executeCommandProvider' },
  ['workspace/symbol'] = { 'workspaceSymbolProvider' },
  ['textDocument/references'] = { 'referencesProvider' },
  ['textDocument/rangeFormatting'] = { 'documentRangeFormattingProvider' },
  ['textDocument/formatting'] = { 'documentFormattingProvider' },
  ['textDocument/completion'] = { 'completionProvider' },
  ['textDocument/documentHighlight'] = { 'documentHighlightProvider' },
}

-- TODO improve handling of scratch buffers with LSP attached.

---@private
--- Concatenates and writes a list of strings to the Vim error buffer.
---
---@param {...} (List of strings) List to write to the buffer
local function err_message(...)
  nvim_err_writeln(table.concat(vim.tbl_flatten({ ... })))
  nvim_command('redraw')
end

---@private
--- Returns the buffer number for the given {bufnr}.
---
---@param bufnr (number) Buffer number to resolve. Defaults to the current
---buffer if not given.
---@returns bufnr (number) Number of requested buffer
local function resolve_bufnr(bufnr)
  validate({ bufnr = { bufnr, 'n', true } })
  if bufnr == nil or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

---@private
--- Called by the client when trying to call a method that's not
--- supported in any of the servers registered for the current buffer.
---@param method (string) name of the method
function lsp._unsupported_method(method)
  local msg = string.format(
    'method %s is not supported by any of the servers registered for the current buffer',
    method
  )
  log.warn(msg)
  return msg
end

---@private
--- Checks whether a given path is a directory.
---
---@param filename (string) path to check
---@returns true if {filename} exists and is a directory, false otherwise
local function is_dir(filename)
  validate({ filename = { filename, 's' } })
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

local wait_result_reason = { [-1] = 'timeout', [-2] = 'interrupted', [-3] = 'error' }

local valid_encodings = {
  ['utf-8'] = 'utf-8',
  ['utf-16'] = 'utf-16',
  ['utf-32'] = 'utf-32',
  ['utf8'] = 'utf-8',
  ['utf16'] = 'utf-16',
  ['utf32'] = 'utf-32',
  UTF8 = 'utf-8',
  UTF16 = 'utf-16',
  UTF32 = 'utf-32',
}

local format_line_ending = {
  ['unix'] = '\n',
  ['dos'] = '\r\n',
  ['mac'] = '\r',
}

---@private
---@param bufnr (number)
---@returns (string)
local function buf_get_line_ending(bufnr)
  return format_line_ending[nvim_buf_get_option(bufnr, 'fileformat')] or '\n'
end

local client_index = 0
---@private
--- Returns a new, unused client id.
---
---@returns (number) client id
local function next_client_id()
  client_index = client_index + 1
  return client_index
end
-- Tracks all clients created via lsp.start_client
local active_clients = {}
local all_buffer_active_clients = {}
local uninitialized_clients = {}

---@private
local function for_each_buffer_client(bufnr, fn, restrict_client_ids)
  validate({
    fn = { fn, 'f' },
    restrict_client_ids = { restrict_client_ids, 't', true },
  })
  bufnr = resolve_bufnr(bufnr)
  local client_ids = all_buffer_active_clients[bufnr]
  if not client_ids or tbl_isempty(client_ids) then
    return
  end

  if restrict_client_ids and #restrict_client_ids > 0 then
    local filtered_client_ids = {}
    for client_id in pairs(client_ids) do
      if vim.tbl_contains(restrict_client_ids, client_id) then
        filtered_client_ids[client_id] = true
      end
    end
    client_ids = filtered_client_ids
  end

  for client_id in pairs(client_ids) do
    local client = active_clients[client_id]
    if client then
      fn(client, client_id, bufnr)
    end
  end
end

-- Error codes to be used with `on_error` from |vim.lsp.start_client|.
-- Can be used to look up the string from a the number or the number
-- from the string.
lsp.client_errors = tbl_extend(
  'error',
  lsp_rpc.client_errors,
  vim.tbl_add_reverse_lookup({
    ON_INIT_CALLBACK_ERROR = table.maxn(lsp_rpc.client_errors) + 1,
  })
)

---@private
--- Normalizes {encoding} to valid LSP encoding names.
---
---@param encoding (string) Encoding to normalize
---@returns (string) normalized encoding name
local function validate_encoding(encoding)
  validate({
    encoding = { encoding, 's' },
  })
  return valid_encodings[encoding:lower()]
    or error(
      string.format(
        "Invalid offset encoding %q. Must be one of: 'utf-8', 'utf-16', 'utf-32'",
        encoding
      )
    )
end

---@internal
--- Parses a command invocation into the command itself and its args. If there
--- are no arguments, an empty table is returned as the second argument.
---
---@param input (List)
---@returns (string) the command
---@returns (list of strings) its arguments
function lsp._cmd_parts(input)
  validate({
    cmd = {
      input,
      function()
        return vim.tbl_islist(input)
      end,
      'list',
    },
  })

  local cmd = input[1]
  local cmd_args = {}
  -- Don't mutate our input.
  for i, v in ipairs(input) do
    validate({ ['cmd argument'] = { v, 's' } })
    if i > 1 then
      table.insert(cmd_args, v)
    end
  end
  return cmd, cmd_args
end

---@private
--- Augments a validator function with support for optional (nil) values.
---
---@param fn (function(v)) The original validator function; should return a
---bool.
---@returns (function(v)) The augmented function. Also returns true if {v} is
---`nil`.
local function optional_validator(fn)
  return function(v)
    return v == nil or fn(v)
  end
end

---@private
--- Validates a client configuration as given to |vim.lsp.start_client()|.
---
---@param config (table)
---@returns (table) "Cleaned" config, containing only the command, its
---arguments, and a valid encoding.
---
---@see |vim.lsp.start_client()|
local function validate_client_config(config)
  validate({
    config = { config, 't' },
  })
  validate({
    handlers = { config.handlers, 't', true },
    capabilities = { config.capabilities, 't', true },
    cmd_cwd = { config.cmd_cwd, optional_validator(is_dir), 'directory' },
    cmd_env = { config.cmd_env, 't', true },
    detached = { config.detached, 'b', true },
    name = { config.name, 's', true },
    on_error = { config.on_error, 'f', true },
    on_exit = { config.on_exit, 'f', true },
    on_init = { config.on_init, 'f', true },
    settings = { config.settings, 't', true },
    commands = { config.commands, 't', true },
    before_init = { config.before_init, 'f', true },
    offset_encoding = { config.offset_encoding, 's', true },
    flags = { config.flags, 't', true },
    get_language_id = { config.get_language_id, 'f', true },
  })
  assert(
    (
      not config.flags
      or not config.flags.debounce_text_changes
      or type(config.flags.debounce_text_changes) == 'number'
    ),
    'flags.debounce_text_changes must be a number with the debounce time in milliseconds'
  )

  local cmd, cmd_args = lsp._cmd_parts(config.cmd)
  local offset_encoding = valid_encodings.UTF16
  if config.offset_encoding then
    offset_encoding = validate_encoding(config.offset_encoding)
  end

  return {
    cmd = cmd,
    cmd_args = cmd_args,
    offset_encoding = offset_encoding,
  }
end

---@private
--- Returns full text of buffer {bufnr} as a string.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@returns Buffer text as string.
local function buf_get_full_text(bufnr)
  local line_ending = buf_get_line_ending(bufnr)
  local text = table.concat(nvim_buf_get_lines(bufnr, 0, -1, true), line_ending)
  if nvim_buf_get_option(bufnr, 'eol') then
    text = text .. line_ending
  end
  return text
end

---@private
--- Memoizes a function. On first run, the function return value is saved and
--- immediately returned on subsequent runs. If the function returns a multival,
--- only the first returned value will be memoized and returned. The function will only be run once,
--- even if it has side effects.
---
---@param fn (function) Function to run
---@returns (function) Memoized function
local function once(fn)
  local value
  local ran = false
  return function(...)
    if not ran then
      value = fn(...)
      ran = true
    end
    return value
  end
end

local changetracking = {}
do
  --@private
  --- client_id → state
  ---
  ---   state
  ---     use_incremental_sync: bool
  ---     buffers: bufnr -> buffer_state
  ---
  ---   buffer_state
  ---     pending_change?: function that the timer starts to trigger didChange
  ---     pending_changes: table (uri -> list of pending changeset tables));
  ---                      Only set if incremental_sync is used
  ---
  ---     timer?: uv_timer
  ---     lines: table
  local state_by_client = {}

  ---@private
  function changetracking.init(client, bufnr)
    local use_incremental_sync = (
      if_nil(client.config.flags.allow_incremental_sync, true)
      and vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'change')
        == protocol.TextDocumentSyncKind.Incremental
    )
    local state = state_by_client[client.id]
    if not state then
      state = {
        buffers = {},
        debounce = client.config.flags.debounce_text_changes or 150,
        use_incremental_sync = use_incremental_sync,
      }
      state_by_client[client.id] = state
    end
    if not state.buffers[bufnr] then
      local buf_state = {
        name = api.nvim_buf_get_name(bufnr),
      }
      state.buffers[bufnr] = buf_state
      if use_incremental_sync then
        buf_state.lines = nvim_buf_get_lines(bufnr, 0, -1, true)
        buf_state.lines_tmp = {}
        buf_state.pending_changes = {}
      end
    end
  end

  ---@private
  function changetracking._get_and_set_name(client, bufnr, name)
    local state = state_by_client[client.id] or {}
    local buf_state = (state.buffers or {})[bufnr]
    local old_name = buf_state.name
    buf_state.name = name
    return old_name
  end

  ---@private
  function changetracking.reset_buf(client, bufnr)
    changetracking.flush(client, bufnr)
    local state = state_by_client[client.id]
    if state and state.buffers then
      local buf_state = state.buffers[bufnr]
      state.buffers[bufnr] = nil
      if buf_state and buf_state.timer then
        buf_state.timer:stop()
        buf_state.timer:close()
        buf_state.timer = nil
      end
    end
  end

  ---@private
  function changetracking.reset(client_id)
    local state = state_by_client[client_id]
    if not state then
      return
    end
    for _, buf_state in pairs(state.buffers) do
      if buf_state.timer then
        buf_state.timer:stop()
        buf_state.timer:close()
        buf_state.timer = nil
      end
    end
    state.buffers = {}
  end

  ---@private
  --
  -- Adjust debounce time by taking time of last didChange notification into
  -- consideration. If the last didChange happened more than `debounce` time ago,
  -- debounce can be skipped and otherwise maybe reduced.
  --
  -- This turns the debounce into a kind of client rate limiting
  local function next_debounce(debounce, buf_state)
    if debounce == 0 then
      return 0
    end
    local ns_to_ms = 0.000001
    if not buf_state.last_flush then
      return debounce
    end
    local now = uv.hrtime()
    local ms_since_last_flush = (now - buf_state.last_flush) * ns_to_ms
    return math.max(debounce - ms_since_last_flush, 0)
  end

  ---@private
  function changetracking.prepare(bufnr, firstline, lastline, new_lastline)
    local incremental_changes = function(client, buf_state)
      local prev_lines = buf_state.lines
      local curr_lines = buf_state.lines_tmp

      local changed_lines = nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
      for i = 1, firstline do
        curr_lines[i] = prev_lines[i]
      end
      for i = firstline + 1, new_lastline do
        curr_lines[i] = changed_lines[i - firstline]
      end
      for i = lastline + 1, #prev_lines do
        curr_lines[i - lastline + new_lastline] = prev_lines[i]
      end
      if tbl_isempty(curr_lines) then
        -- Can happen when deleting the entire contents of a buffer, see https://github.com/neovim/neovim/issues/16259.
        curr_lines[1] = ''
      end

      local line_ending = buf_get_line_ending(bufnr)
      local incremental_change = sync.compute_diff(
        buf_state.lines,
        curr_lines,
        firstline,
        lastline,
        new_lastline,
        client.offset_encoding or 'utf-16',
        line_ending
      )

      -- Double-buffering of lines tables is used to reduce the load on the garbage collector.
      -- At this point the prev_lines table is useless, but its internal storage has already been allocated,
      -- so let's keep it around for the next didChange event, in which it will become the next
      -- curr_lines table. Note that setting elements to nil doesn't actually deallocate slots in the
      -- internal storage - it merely marks them as free, for the GC to deallocate them.
      for i in ipairs(prev_lines) do
        prev_lines[i] = nil
      end
      buf_state.lines = curr_lines
      buf_state.lines_tmp = prev_lines

      return incremental_change
    end
    local full_changes = once(function()
      return {
        text = buf_get_full_text(bufnr),
      }
    end)
    local uri = vim.uri_from_bufnr(bufnr)
    return function(client)
      if
        vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'change')
        == protocol.TextDocumentSyncKind.None
      then
        return
      end
      local state = state_by_client[client.id]
      local buf_state = state.buffers[bufnr]
      changetracking._reset_timer(buf_state)
      local debounce = next_debounce(state.debounce, buf_state)
      if state.use_incremental_sync then
        -- This must be done immediately and cannot be delayed
        -- The contents would further change and startline/endline may no longer fit
        table.insert(buf_state.pending_changes, incremental_changes(client, buf_state))
      end
      buf_state.pending_change = function()
        if buf_state.pending_change == nil then
          return
        end
        buf_state.pending_change = nil
        buf_state.last_flush = uv.hrtime()
        if client.is_stopped() or not api.nvim_buf_is_valid(bufnr) then
          return
        end
        local changes = state.use_incremental_sync and buf_state.pending_changes
          or { full_changes() }
        client.notify('textDocument/didChange', {
          textDocument = {
            uri = uri,
            version = util.buf_versions[bufnr],
          },
          contentChanges = changes,
        })
        buf_state.pending_changes = {}
      end
      if debounce == 0 then
        buf_state.pending_change()
      else
        local timer = uv.new_timer()
        buf_state.timer = timer
        -- Must use schedule_wrap because `full_changes()` calls nvim_buf_get_lines
        timer:start(debounce, 0, vim.schedule_wrap(buf_state.pending_change))
      end
    end
  end

  function changetracking._reset_timer(buf_state)
    if buf_state.timer then
      buf_state.timer:stop()
      buf_state.timer:close()
      buf_state.timer = nil
    end
  end

  --- Flushes any outstanding change notification.
  ---@private
  function changetracking.flush(client, bufnr)
    local state = state_by_client[client.id]
    if not state then
      return
    end
    if bufnr then
      local buf_state = state.buffers[bufnr] or {}
      changetracking._reset_timer(buf_state)
      if buf_state.pending_change then
        buf_state.pending_change()
      end
    else
      for _, buf_state in pairs(state.buffers) do
        changetracking._reset_timer(buf_state)
        if buf_state.pending_change then
          buf_state.pending_change()
        end
      end
    end
  end
end

---@private
--- Default handler for the 'textDocument/didOpen' LSP notification.
---
---@param bufnr number Number of the buffer, or 0 for current
---@param client Client object
local function text_document_did_open_handler(bufnr, client)
  changetracking.init(client, bufnr)
  if not vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
    return
  end
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local filetype = nvim_buf_get_option(bufnr, 'filetype')

  local params = {
    textDocument = {
      version = 0,
      uri = vim.uri_from_bufnr(bufnr),
      languageId = client.config.get_language_id(bufnr, filetype),
      text = buf_get_full_text(bufnr),
    },
  }
  client.notify('textDocument/didOpen', params)
  util.buf_versions[bufnr] = params.textDocument.version

  -- Next chance we get, we should re-do the diagnostics
  vim.schedule(function()
    -- Protect against a race where the buffer disappears
    -- between `did_open_handler` and the scheduled function firing.
    if api.nvim_buf_is_valid(bufnr) then
      local namespace = vim.lsp.diagnostic.get_namespace(client.id)
      vim.diagnostic.show(namespace, bufnr)
    end
  end)
end

-- FIXME: DOC: Shouldn't need to use a dummy function
--
--- LSP client object. You can get an active client object via
--- |vim.lsp.get_client_by_id()| or |vim.lsp.get_active_clients()|.
---
--- - Methods:
---
---  - request(method, params, [handler], bufnr)
---     Sends a request to the server.
---     This is a thin wrapper around {client.rpc.request} with some additional
---     checking.
---     If {handler} is not specified,  If one is not found there, then an error will occur.
---     Returns: {status}, {[client_id]}. {status} is a boolean indicating if
---     the notification was successful. If it is `false`, then it will always
---     be `false` (the client has shutdown).
---     If {status} is `true`, the function returns {request_id} as the second
---     result. You can use this with `client.cancel_request(request_id)`
---     to cancel the request.
---
---  - request_sync(method, params, timeout_ms, bufnr)
---     Sends a request to the server and synchronously waits for the response.
---     This is a wrapper around {client.request}
---     Returns: { err=err, result=result }, a dictionary, where `err` and `result` come from
---     the |lsp-handler|. On timeout, cancel or error, returns `(nil, err)` where `err` is a
---     string describing the failure reason. If the request was unsuccessful returns `nil`.
---
---  - notify(method, params)
---     Sends a notification to an LSP server.
---     Returns: a boolean to indicate if the notification was successful. If
---     it is false, then it will always be false (the client has shutdown).
---
---  - cancel_request(id)
---     Cancels a request with a given request id.
---     Returns: same as `notify()`.
---
---  - stop([force])
---     Stops a client, optionally with force.
---     By default, it will just ask the server to shutdown without force.
---     If you request to stop a client which has previously been requested to
---     shutdown, it will automatically escalate and force shutdown.
---
---  - is_stopped()
---     Checks whether a client is stopped.
---     Returns: true if the client is fully stopped.
---
---  - on_attach(client, bufnr)
---     Runs the on_attach function from the client's config if it was defined.
---     Useful for buffer-local setup.
---
--- - Members
---  - {id} (number): The id allocated to the client.
---
---  - {name} (string): If a name is specified on creation, that will be
---    used. Otherwise it is just the client id. This is used for
---    logs and messages.
---
---  - {rpc} (table): RPC client object, for low level interaction with the
---    client. See |vim.lsp.rpc.start()|.
---
---  - {offset_encoding} (string): The encoding used for communicating
---    with the server. You can modify this in the `config`'s `on_init` method
---    before text is sent to the server.
---
---  - {handlers} (table): The handlers used by the client as described in |lsp-handler|.
---
---  - {requests} (table): The current pending requests in flight
---    to the server. Entries are key-value pairs with the key
---    being the request ID while the value is a table with `type`,
---    `bufnr`, and `method` key-value pairs. `type` is either "pending"
---    for an active request, or "cancel" for a cancel request.
---
---  - {config} (table): copy of the table that was passed by the user
---    to |vim.lsp.start_client()|.
---
---  - {server_capabilities} (table): Response from the server sent on
---    `initialize` describing the server's capabilities.
function lsp.client()
  error()
end

--- Create a new LSP client and start a language server or reuses an already
--- running client if one is found matching `name` and `root_dir`.
--- Attaches the current buffer to the client.
---
--- Example:
---
--- <pre>
--- vim.lsp.start({
---    name = 'my-server-name',
---    cmd = {'name-of-language-server-executable'},
---    root_dir = vim.fs.dirname(vim.fs.find({'pyproject.toml', 'setup.py'}, { upward = true })[1]),
--- })
--- </pre>
---
--- See |lsp.start_client| for all available options. The most important are:
---
--- `name` is an arbitrary name for the LSP client. It should be unique per
--- language server.
---
--- `cmd` the command as list - used to start the language server.
--- The command must be present in the `$PATH` environment variable or an
--- absolute path to the executable. Shell constructs like `~` are *NOT* expanded.
---
--- `root_dir` path to the project root.
--- By default this is used to decide if an existing client should be re-used.
--- The example above uses |vim.fs.find| and |vim.fs.dirname| to detect the
--- root by traversing the file system upwards starting
--- from the current directory until either a `pyproject.toml` or `setup.py`
--- file is found.
---
--- `workspace_folders` a list of { uri:string, name: string } tables.
--- The project root folders used by the language server.
--- If `nil` the property is derived from the `root_dir` for convenience.
---
--- Language servers use this information to discover metadata like the
--- dependencies of your project and they tend to index the contents within the
--- project folder.
---
---
--- To ensure a language server is only started for languages it can handle,
--- make sure to call |vim.lsp.start| within a |FileType| autocmd.
--- Either use |:au|, |nvim_create_autocmd()| or put the call in a
--- `ftplugin/<filetype_name>.lua` (See |ftplugin-name|)
---
---@param config table Same configuration as documented in |lsp.start_client()|
---@param opts nil|table Optional keyword arguments:
---             - reuse_client (fun(client: client, config: table): boolean)
---                            Predicate used to decide if a client should be re-used.
---                            Used on all running clients.
---                            The default implementation re-uses a client if name
---                            and root_dir matches.
---@return number client_id
function lsp.start(config, opts)
  opts = opts or {}
  local reuse_client = opts.reuse_client
    or function(client, conf)
      return client.config.root_dir == conf.root_dir and client.name == conf.name
    end
  config.name = config.name or (config.cmd[1] and vim.fs.basename(config.cmd[1])) or nil
  local bufnr = api.nvim_get_current_buf()
  for _, clients in ipairs({ uninitialized_clients, lsp.get_active_clients() }) do
    for _, client in pairs(clients) do
      if reuse_client(client, config) then
        lsp.buf_attach_client(bufnr, client.id)
        return client.id
      end
    end
  end
  local client_id = lsp.start_client(config)
  if client_id == nil then
    return nil -- lsp.start_client will have printed an error
  end
  lsp.buf_attach_client(bufnr, client_id)
  return client_id
end

-- FIXME: DOC: Currently all methods on the `vim.lsp.client` object are
-- documented twice: Here, and on the methods themselves (e.g.
-- `client.request()`). This is a workaround for the vimdoc generator script
-- not handling method names correctly. If you change the documentation on
-- either, please make sure to update the other as well.
--
--- Starts and initializes a client with the given configuration.
---
--- Parameter `cmd` is required.
---
--- The following parameters describe fields in the {config} table.
---
---
---@param cmd: (required, string or list treated like |jobstart()|) Base command
--- that initiates the LSP client.
---
---@param cmd_cwd: (string, default=|getcwd()|) Directory to launch
--- the `cmd` process. Not related to `root_dir`.
---
---@param cmd_env: (table) Environment flags to pass to the LSP on
--- spawn.  Can be specified using keys like a map or as a list with `k=v`
--- pairs or both. Non-string values are coerced to string.
--- Example:
--- <pre>
--- { "PRODUCTION=true"; "TEST=123"; PORT = 8080; HOST = "0.0.0.0"; }
--- </pre>
---
---@param detached: (boolean, default true) Daemonize the server process so that it runs in a
--- separate process group from Nvim. Nvim will shutdown the process on exit, but if Nvim fails to
--- exit cleanly this could leave behind orphaned server processes.
---
---@param workspace_folders (table) List of workspace folders passed to the
--- language server. For backwards compatibility rootUri and rootPath will be
--- derived from the first workspace folder in this list. See `workspaceFolders` in
--- the LSP spec.
---
---@param capabilities Map overriding the default capabilities defined by
--- |vim.lsp.protocol.make_client_capabilities()|, passed to the language
--- server on initialization. Hint: use make_client_capabilities() and modify
--- its result.
--- - Note: To send an empty dictionary use
---   `{[vim.type_idx]=vim.types.dictionary}`, else it will be encoded as an
---   array.
---
---@param handlers Map of language server method names to |lsp-handler|
---
---@param settings Map with language server specific settings. These are
--- returned to the language server if requested via `workspace/configuration`.
--- Keys are case-sensitive.
---
---@param commands table Table that maps string of clientside commands to user-defined functions.
--- Commands passed to start_client take precedence over the global command registry. Each key
--- must be a unique command name, and the value is a function which is called if any LSP action
--- (code action, code lenses, ...) triggers the command.
---
---@param init_options Values to pass in the initialization request
--- as `initializationOptions`. See `initialize` in the LSP spec.
---
---@param name (string, default=client-id) Name in log messages.
---
---@param get_language_id function(bufnr, filetype) -> language ID as string.
--- Defaults to the filetype.
---
---@param offset_encoding (default="utf-16") One of "utf-8", "utf-16",
--- or "utf-32" which is the encoding that the LSP server expects. Client does
--- not verify this is correct.
---
---@param on_error Callback with parameters (code, ...), invoked
--- when the client operation throws an error. `code` is a number describing
--- the error. Other arguments may be passed depending on the error kind.  See
--- |vim.lsp.rpc.client_errors| for possible errors.
--- Use `vim.lsp.rpc.client_errors[code]` to get human-friendly name.
---
---@param before_init Callback with parameters (initialize_params, config)
--- invoked before the LSP "initialize" phase, where `params` contains the
--- parameters being sent to the server and `config` is the config that was
--- passed to |vim.lsp.start_client()|. You can use this to modify parameters before
--- they are sent.
---
---@param on_init Callback (client, initialize_result) invoked after LSP
--- "initialize", where `result` is a table of `capabilities` and anything else
--- the server may send. For example, clangd sends
--- `initialize_result.offsetEncoding` if `capabilities.offsetEncoding` was
--- sent to it. You can only modify the `client.offset_encoding` here before
--- any notifications are sent. Most language servers expect to be sent client specified settings after
--- initialization. Neovim does not make this assumption. A
--- `workspace/didChangeConfiguration` notification should be sent
---  to the server during on_init.
---
---@param on_exit Callback (code, signal, client_id) invoked on client
--- exit.
--- - code: exit code of the process
--- - signal: number describing the signal used to terminate (if any)
--- - client_id: client handle
---
---@param on_attach Callback (client, bufnr) invoked when client
--- attaches to a buffer.
---
---@param trace:  "off" | "messages" | "verbose" | nil passed directly to the language
--- server in the initialize request. Invalid/empty values will default to "off"
---@param flags: A table with flags for the client. The current (experimental) flags are:
--- - allow_incremental_sync (bool, default true): Allow using incremental sync for buffer edits
--- - debounce_text_changes (number, default 150): Debounce didChange
---       notifications to the server by the given number in milliseconds. No debounce
---       occurs if nil
--- - exit_timeout (number|boolean, default false): Milliseconds to wait for server to
---       exit cleanly after sending the 'shutdown' request before sending kill -15.
---       If set to false, nvim exits immediately after sending the 'shutdown' request to the server.
---
---@param root_dir string Directory where the LSP
--- server will base its workspaceFolders, rootUri, and rootPath
--- on initialization.
---
---@returns Client id. |vim.lsp.get_client_by_id()| Note: client may not be
--- fully initialized. Use `on_init` to do any actions once
--- the client has been initialized.
function lsp.start_client(config)
  local cleaned_config = validate_client_config(config)
  local cmd, cmd_args, offset_encoding =
    cleaned_config.cmd, cleaned_config.cmd_args, cleaned_config.offset_encoding

  config.flags = config.flags or {}
  config.settings = config.settings or {}

  -- By default, get_language_id just returns the exact filetype it is passed.
  --    It is possible to pass in something that will calculate a different filetype,
  --    to be sent by the client.
  config.get_language_id = config.get_language_id or function(_, filetype)
    return filetype
  end

  local client_id = next_client_id()

  local handlers = config.handlers or {}
  local name = config.name or tostring(client_id)
  local log_prefix = string.format('LSP[%s]', name)

  local dispatch = {}

  ---@private
  --- Returns the handler associated with an LSP method.
  --- Returns the default handler if the user hasn't set a custom one.
  ---
  ---@param method (string) LSP method name
  ---@returns (fn) The handler for the given method, if defined, or the default from |vim.lsp.handlers|
  local function resolve_handler(method)
    return handlers[method] or default_handlers[method]
  end

  ---@private
  --- Handles a notification sent by an LSP server by invoking the
  --- corresponding handler.
  ---
  ---@param method (string) LSP method name
  ---@param params (table) The parameters for that method.
  function dispatch.notification(method, params)
    local _ = log.trace() and log.trace('notification', method, params)
    local handler = resolve_handler(method)
    if handler then
      -- Method name is provided here for convenience.
      handler(nil, params, { method = method, client_id = client_id })
    end
  end

  ---@private
  --- Handles a request from an LSP server by invoking the corresponding handler.
  ---
  ---@param method (string) LSP method name
  ---@param params (table) The parameters for that method
  function dispatch.server_request(method, params)
    local _ = log.trace() and log.trace('server_request', method, params)
    local handler = resolve_handler(method)
    if handler then
      local _ = log.trace() and log.trace('server_request: found handler for', method)
      return handler(nil, params, { method = method, client_id = client_id })
    end
    local _ = log.warn() and log.warn('server_request: no handler found for', method)
    return nil, lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  ---@private
  --- Invoked when the client operation throws an error.
  ---
  ---@param code (number) Error code
  ---@param err (...) Other arguments may be passed depending on the error kind
  ---@see |vim.lsp.rpc.client_errors| for possible errors. Use
  ---`vim.lsp.rpc.client_errors[code]` to get a human-friendly name.
  function dispatch.on_error(code, err)
    local _ = log.error()
      and log.error(log_prefix, 'on_error', { code = lsp.client_errors[code], err = err })
    err_message(log_prefix, ': Error ', lsp.client_errors[code], ': ', vim.inspect(err))
    if config.on_error then
      local status, usererr = pcall(config.on_error, code, err)
      if not status then
        local _ = log.error() and log.error(log_prefix, 'user on_error failed', { err = usererr })
        err_message(log_prefix, ' user on_error failed: ', tostring(usererr))
      end
    end
  end

  ---@private
  local function set_defaults(client, bufnr)
    local capabilities = client.server_capabilities
    if capabilities.definitionProvider and vim.bo[bufnr].tagfunc == '' then
      vim.bo[bufnr].tagfunc = 'v:lua.vim.lsp.tagfunc'
    end
    if capabilities.completionProvider and vim.bo[bufnr].omnifunc == '' then
      vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
    end
    if
      capabilities.documentRangeFormattingProvider
      and vim.bo[bufnr].formatprg == ''
      and vim.bo[bufnr].formatexpr == ''
    then
      vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr()'
    end
  end

  ---@private
  --- Reset defaults set by `set_defaults`.
  --- Must only be called if the last client attached to a buffer exits.
  local function unset_defaults(bufnr)
    if vim.bo[bufnr].tagfunc == 'v:lua.vim.lsp.tagfunc' then
      vim.bo[bufnr].tagfunc = nil
    end
    if vim.bo[bufnr].omnifunc == 'v:lua.vim.lsp.omnifunc' then
      vim.bo[bufnr].omnifunc = nil
    end
    if vim.bo[bufnr].formatexpr == 'v:lua.vim.lsp.formatexpr()' then
      vim.bo[bufnr].formatexpr = nil
    end
  end

  ---@private
  --- Invoked on client exit.
  ---
  ---@param code (number) exit code of the process
  ---@param signal (number) the signal used to terminate (if any)
  function dispatch.on_exit(code, signal)
    if config.on_exit then
      pcall(config.on_exit, code, signal, client_id)
    end

    for bufnr, client_ids in pairs(all_buffer_active_clients) do
      if client_ids[client_id] then
        vim.schedule(function()
          nvim_exec_autocmds('LspDetach', {
            buffer = bufnr,
            modeline = false,
            data = { client_id = client_id },
          })

          local namespace = vim.lsp.diagnostic.get_namespace(client_id)
          vim.diagnostic.reset(namespace, bufnr)
        end)

        client_ids[client_id] = nil
      end
      if vim.tbl_isempty(client_ids) then
        vim.schedule(function()
          unset_defaults(bufnr)
        end)
      end
    end

    active_clients[client_id] = nil
    uninitialized_clients[client_id] = nil

    changetracking.reset(client_id)
    if code ~= 0 or (signal ~= 0 and signal ~= 15) then
      local msg =
        string.format('Client %s quit with exit code %s and signal %s', client_id, code, signal)
      vim.schedule(function()
        vim.notify(msg, vim.log.levels.WARN)
      end)
    end
  end

  -- Start the RPC client.
  local rpc = lsp_rpc.start(cmd, cmd_args, dispatch, {
    cwd = config.cmd_cwd,
    env = config.cmd_env,
    detached = config.detached,
  })

  -- Return nil if client fails to start
  if not rpc then
    return
  end

  local client = {
    id = client_id,
    name = name,
    rpc = rpc,
    offset_encoding = offset_encoding,
    config = config,
    attached_buffers = {},

    handlers = handlers,
    commands = config.commands or {},

    requests = {},
    -- for $/progress report
    messages = { name = name, messages = {}, progress = {}, status = {} },
  }

  -- Store the uninitialized_clients for cleanup in case we exit before initialize finishes.
  uninitialized_clients[client_id] = client

  ---@private
  local function initialize()
    local valid_traces = {
      off = 'off',
      messages = 'messages',
      verbose = 'verbose',
    }
    local version = vim.version()

    local workspace_folders
    local root_uri
    local root_path
    if config.workspace_folders or config.root_dir then
      if config.root_dir and not config.workspace_folders then
        workspace_folders = {
          {
            uri = vim.uri_from_fname(config.root_dir),
            name = string.format('%s', config.root_dir),
          },
        }
      else
        workspace_folders = config.workspace_folders
      end
      root_uri = workspace_folders[1].uri
      root_path = vim.uri_to_fname(root_uri)
    else
      workspace_folders = nil
      root_uri = nil
      root_path = nil
    end

    local initialize_params = {
      -- The process Id of the parent process that started the server. Is null if
      -- the process has not been started by another process.  If the parent
      -- process is not alive then the server should exit (see exit notification)
      -- its process.
      processId = uv.getpid(),
      -- Information about the client
      -- since 3.15.0
      clientInfo = {
        name = 'Neovim',
        version = string.format('%s.%s.%s', version.major, version.minor, version.patch),
      },
      -- The rootPath of the workspace. Is null if no folder is open.
      --
      -- @deprecated in favour of rootUri.
      rootPath = root_path or vim.NIL,
      -- The rootUri of the workspace. Is null if no folder is open. If both
      -- `rootPath` and `rootUri` are set `rootUri` wins.
      rootUri = root_uri or vim.NIL,
      -- The workspace folders configured in the client when the server starts.
      -- This property is only available if the client supports workspace folders.
      -- It can be `null` if the client supports workspace folders but none are
      -- configured.
      workspaceFolders = workspace_folders or vim.NIL,
      -- User provided initialization options.
      initializationOptions = config.init_options,
      -- The capabilities provided by the client (editor or tool)
      capabilities = config.capabilities or protocol.make_client_capabilities(),
      -- The initial trace setting. If omitted trace is disabled ("off").
      -- trace = "off" | "messages" | "verbose";
      trace = valid_traces[config.trace] or 'off',
    }
    if config.before_init then
      -- TODO(ashkan) handle errors here.
      pcall(config.before_init, initialize_params, config)
    end
    local _ = log.trace() and log.trace(log_prefix, 'initialize_params', initialize_params)
    rpc.request('initialize', initialize_params, function(init_err, result)
      assert(not init_err, tostring(init_err))
      assert(result, 'server sent empty result')
      rpc.notify('initialized', vim.empty_dict())
      client.initialized = true
      uninitialized_clients[client_id] = nil
      client.workspace_folders = workspace_folders
      -- TODO(mjlbach): Backwards compatibility, to be removed in 0.7
      client.workspaceFolders = client.workspace_folders

      -- These are the cleaned up capabilities we use for dynamically deciding
      -- when to send certain events to clients.
      client.server_capabilities =
        assert(result.capabilities, "initialize result doesn't contain capabilities")
      client.server_capabilities = protocol.resolve_capabilities(client.server_capabilities)

      -- Deprecation wrapper: this will be removed in 0.8
      local mt = {}
      mt.__index = function(table, key)
        if key == 'resolved_capabilities' then
          vim.notify_once(
            '[LSP] Accessing client.resolved_capabilities is deprecated, '
              .. 'update your plugins or configuration to access client.server_capabilities instead.'
              .. 'The new key/value pairs in server_capabilities directly match those '
              .. 'defined in the language server protocol',
            vim.log.levels.WARN
          )
          rawset(table, key, protocol._resolve_capabilities_compat(client.server_capabilities))
          return rawget(table, key)
        else
          return rawget(table, key)
        end
      end
      setmetatable(client, mt)

      client.supports_method = function(method)
        local required_capability = lsp._request_name_to_capability[method]
        -- if we don't know about the method, assume that the client supports it.
        if not required_capability then
          return true
        end
        if vim.tbl_get(client.server_capabilities, unpack(required_capability)) then
          return true
        else
          return false
        end
      end

      if next(config.settings) then
        client.notify('workspace/didChangeConfiguration', { settings = config.settings })
      end

      if config.on_init then
        local status, err = pcall(config.on_init, client, result)
        if not status then
          pcall(handlers.on_error, lsp.client_errors.ON_INIT_CALLBACK_ERROR, err)
        end
      end
      local _ = log.info()
        and log.info(
          log_prefix,
          'server_capabilities',
          { server_capabilities = client.server_capabilities }
        )

      -- Only assign after initialized.
      active_clients[client_id] = client
      -- If we had been registered before we start, then send didOpen This can
      -- happen if we attach to buffers before initialize finishes or if
      -- someone restarts a client.
      for bufnr, client_ids in pairs(all_buffer_active_clients) do
        if client_ids[client_id] then
          client._on_attach(bufnr)
        end
      end
    end)
  end

  ---@private
  --- Sends a request to the server.
  ---
  --- This is a thin wrapper around {client.rpc.request} with some additional
  --- checks for capabilities and handler availability.
  ---
  ---@param method (string) LSP method name.
  ---@param params (table) LSP request params.
  ---@param handler (function, optional) Response |lsp-handler| for this method.
  ---@param bufnr (number) Buffer handle (0 for current).
  ---@returns ({status}, [request_id]): {status} is a bool indicating
  ---whether the request was successful. If it is `false`, then it will
  ---always be `false` (the client has shutdown). If it was
  ---successful, then it will return {request_id} as the
  ---second result. You can use this with `client.cancel_request(request_id)`
  ---to cancel the-request.
  ---@see |vim.lsp.buf_request()|
  function client.request(method, params, handler, bufnr)
    if not handler then
      handler = resolve_handler(method)
        or error(string.format('not found: %q request handler for client %q.', method, client.name))
    end
    -- Ensure pending didChange notifications are sent so that the server doesn't operate on a stale state
    changetracking.flush(client, bufnr)
    bufnr = resolve_bufnr(bufnr)
    local _ = log.debug()
      and log.debug(log_prefix, 'client.request', client_id, method, params, handler, bufnr)
    local success, request_id = rpc.request(method, params, function(err, result)
      handler(
        err,
        result,
        { method = method, client_id = client_id, bufnr = bufnr, params = params }
      )
    end, function(request_id)
      client.requests[request_id] = nil
      nvim_exec_autocmds('User', { pattern = 'LspRequest', modeline = false })
    end)

    if success then
      client.requests[request_id] = { type = 'pending', bufnr = bufnr, method = method }
      nvim_exec_autocmds('User', { pattern = 'LspRequest', modeline = false })
    end

    return success, request_id
  end

  ---@private
  --- Sends a request to the server and synchronously waits for the response.
  ---
  --- This is a wrapper around {client.request}
  ---
  ---@param method (string) LSP method name.
  ---@param params (table) LSP request params.
  ---@param timeout_ms (number, optional, default=1000) Maximum time in
  ---milliseconds to wait for a result.
  ---@param bufnr (number) Buffer handle (0 for current).
  ---@returns { err=err, result=result }, a dictionary, where `err` and `result` come from the |lsp-handler|.
  ---On timeout, cancel or error, returns `(nil, err)` where `err` is a
  ---string describing the failure reason. If the request was unsuccessful
  ---returns `nil`.
  ---@see |vim.lsp.buf_request_sync()|
  function client.request_sync(method, params, timeout_ms, bufnr)
    local request_result = nil
    local function _sync_handler(err, result)
      request_result = { err = err, result = result }
    end

    local success, request_id = client.request(method, params, _sync_handler, bufnr)
    if not success then
      return nil
    end

    local wait_result, reason = vim.wait(timeout_ms or 1000, function()
      return request_result ~= nil
    end, 10)

    if not wait_result then
      client.cancel_request(request_id)
      return nil, wait_result_reason[reason]
    end
    return request_result
  end

  ---@private
  --- Sends a notification to an LSP server.
  ---
  ---@param method string LSP method name.
  ---@param params table|nil LSP request params.
  ---@returns {status} (bool) true if the notification was successful.
  ---If it is false, then it will always be false
  ---(the client has shutdown).
  function client.notify(method, params)
    if method ~= 'textDocument/didChange' then
      changetracking.flush(client)
    end
    return rpc.notify(method, params)
  end

  ---@private
  --- Cancels a request with a given request id.
  ---
  ---@param id (number) id of request to cancel
  ---@returns true if any client returns true; false otherwise
  ---@see |vim.lsp.client.notify()|
  function client.cancel_request(id)
    validate({ id = { id, 'n' } })
    local request = client.requests[id]
    if request and request.type == 'pending' then
      request.type = 'cancel'
      nvim_exec_autocmds('User', { pattern = 'LspRequest', modeline = false })
    end
    return rpc.notify('$/cancelRequest', { id = id })
  end

  -- Track this so that we can escalate automatically if we've already tried a
  -- graceful shutdown
  local graceful_shutdown_failed = false
  ---@private
  --- Stops a client, optionally with force.
  ---
  ---By default, it will just ask the - server to shutdown without force. If
  --- you request to stop a client which has previously been requested to
  --- shutdown, it will automatically escalate and force shutdown.
  ---
  ---@param force (bool, optional)
  function client.stop(force)
    local handle = rpc.handle
    if handle:is_closing() then
      return
    end
    if force or not client.initialized or graceful_shutdown_failed then
      handle:kill(15)
      return
    end
    -- Sending a signal after a process has exited is acceptable.
    rpc.request('shutdown', nil, function(err, _)
      if err == nil then
        rpc.notify('exit')
      else
        -- If there was an error in the shutdown request, then term to be safe.
        handle:kill(15)
        graceful_shutdown_failed = true
      end
    end)
  end

  ---@private
  --- Checks whether a client is stopped.
  ---
  ---@returns (bool) true if client is stopped or in the process of being
  ---stopped; false otherwise
  function client.is_stopped()
    return rpc.handle:is_closing()
  end

  ---@private
  --- Runs the on_attach function from the client's config if it was defined.
  ---@param bufnr (number) Buffer number
  function client._on_attach(bufnr)
    text_document_did_open_handler(bufnr, client)

    set_defaults(client, bufnr)

    nvim_exec_autocmds('LspAttach', {
      buffer = bufnr,
      modeline = false,
      data = { client_id = client.id },
    })

    if config.on_attach then
      -- TODO(ashkan) handle errors.
      pcall(config.on_attach, client, bufnr)
    end
    client.attached_buffers[bufnr] = true
  end

  initialize()

  return client_id
end

---@private
---@fn text_document_did_change_handler(_, bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
--- Notify all attached clients that a buffer has changed.
local text_document_did_change_handler
do
  text_document_did_change_handler =
    function(_, bufnr, changedtick, firstline, lastline, new_lastline)
      -- Detach (nvim_buf_attach) via returning True to on_lines if no clients are attached
      if tbl_isempty(all_buffer_active_clients[bufnr] or {}) then
        return true
      end
      util.buf_versions[bufnr] = changedtick
      local compute_change_and_notify =
        changetracking.prepare(bufnr, firstline, lastline, new_lastline)
      for_each_buffer_client(bufnr, compute_change_and_notify)
    end
end

---@private
---Buffer lifecycle handler for textDocument/didSave
local function text_document_did_save_handler(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local text = once(buf_get_full_text)
  for_each_buffer_client(bufnr, function(client)
    local name = api.nvim_buf_get_name(bufnr)
    local old_name = changetracking._get_and_set_name(client, bufnr, name)
    if old_name and name ~= old_name then
      client.notify('textDocument/didOpen', {
        textDocument = {
          version = 0,
          uri = uri,
          languageId = client.config.get_language_id(bufnr, vim.bo[bufnr].filetype),
          text = buf_get_full_text(bufnr),
        },
      })
      util.buf_versions[bufnr] = 0
    end
    local save_capability = vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'save')
    if save_capability then
      local included_text
      if type(save_capability) == 'table' and save_capability.includeText then
        included_text = text(bufnr)
      end
      client.notify('textDocument/didSave', {
        textDocument = {
          uri = uri,
        },
        text = included_text,
      })
    end
  end)
end

--- Implements the `textDocument/did…` notifications required to track a buffer
--- for any language server.
---
--- Without calling this, the server won't be notified of changes to a buffer.
---
---@param bufnr (number) Buffer handle, or 0 for current
---@param client_id (number) Client id
function lsp.buf_attach_client(bufnr, client_id)
  validate({
    bufnr = { bufnr, 'n', true },
    client_id = { client_id, 'n' },
  })
  bufnr = resolve_bufnr(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then
    local _ = log.warn()
      and log.warn(string.format('buf_attach_client called on unloaded buffer (id: %d): ', bufnr))
    return false
  end
  local buffer_client_ids = all_buffer_active_clients[bufnr]
  -- This is our first time attaching to this buffer.
  if not buffer_client_ids then
    buffer_client_ids = {}
    all_buffer_active_clients[bufnr] = buffer_client_ids

    local uri = vim.uri_from_bufnr(bufnr)
    local augroup = ('lsp_c_%d_b_%d_did_save'):format(client_id, bufnr)
    api.nvim_create_autocmd('BufWritePost', {
      group = api.nvim_create_augroup(augroup, { clear = true }),
      buffer = bufnr,
      desc = 'vim.lsp: textDocument/didSave handler',
      callback = function(ctx)
        text_document_did_save_handler(ctx.buf)
      end,
    })
    -- First time, so attach and set up stuff.
    api.nvim_buf_attach(bufnr, false, {
      on_lines = text_document_did_change_handler,
      on_reload = function()
        local params = { textDocument = { uri = uri } }
        for_each_buffer_client(bufnr, function(client, _)
          changetracking.reset_buf(client, bufnr)
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
            client.notify('textDocument/didClose', params)
          end
          text_document_did_open_handler(bufnr, client)
        end)
      end,
      on_detach = function()
        local params = { textDocument = { uri = uri } }
        for_each_buffer_client(bufnr, function(client, _)
          changetracking.reset_buf(client, bufnr)
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
            client.notify('textDocument/didClose', params)
          end
        end)
        util.buf_versions[bufnr] = nil
        all_buffer_active_clients[bufnr] = nil
      end,
      -- TODO if we know all of the potential clients ahead of time, then we
      -- could conditionally set this.
      --      utf_sizes = size_index > 1;
      utf_sizes = true,
    })
  end

  if buffer_client_ids[client_id] then
    return
  end
  -- This is our first time attaching this client to this buffer.
  buffer_client_ids[client_id] = true

  local client = active_clients[client_id]
  -- Send didOpen for the client if it is initialized. If it isn't initialized
  -- then it will send didOpen on initialize.
  if client then
    client._on_attach(bufnr)
  end
  return true
end

--- Detaches client from the specified buffer.
--- Note: While the server is notified that the text document (buffer)
--- was closed, it is still able to send notifications should it ignore this notification.
---
---@param bufnr number Buffer handle, or 0 for current
---@param client_id number Client id
function lsp.buf_detach_client(bufnr, client_id)
  validate({
    bufnr = { bufnr, 'n', true },
    client_id = { client_id, 'n' },
  })
  bufnr = resolve_bufnr(bufnr)

  local client = lsp.get_client_by_id(client_id)
  if not client or not client.attached_buffers[bufnr] then
    vim.notify(
      string.format(
        'Buffer (id: %d) is not attached to client (id: %d). Cannot detach.',
        client_id,
        bufnr
      )
    )
    return
  end

  nvim_exec_autocmds('LspDetach', {
    buffer = bufnr,
    modeline = false,
    data = { client_id = client_id },
  })

  changetracking.reset_buf(client, bufnr)

  if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
    local uri = vim.uri_from_bufnr(bufnr)
    local params = { textDocument = { uri = uri } }
    client.notify('textDocument/didClose', params)
  end

  client.attached_buffers[bufnr] = nil
  util.buf_versions[bufnr] = nil

  all_buffer_active_clients[bufnr][client_id] = nil
  if #vim.tbl_keys(all_buffer_active_clients[bufnr]) == 0 then
    all_buffer_active_clients[bufnr] = nil
  end

  local namespace = vim.lsp.diagnostic.get_namespace(client_id)
  vim.diagnostic.reset(namespace, bufnr)

  vim.notify(string.format('Detached buffer (id: %d) from client (id: %d)', bufnr, client_id))
end

--- Checks if a buffer is attached for a particular client.
---
---@param bufnr (number) Buffer handle, or 0 for current
---@param client_id (number) the client id
function lsp.buf_is_attached(bufnr, client_id)
  return (all_buffer_active_clients[resolve_bufnr(bufnr)] or {})[client_id] == true
end

--- Gets a client by id, or nil if the id is invalid.
--- The returned client may not yet be fully initialized.
---
---@param client_id number client id
---
---@returns |vim.lsp.client| object, or nil
function lsp.get_client_by_id(client_id)
  return active_clients[client_id] or uninitialized_clients[client_id]
end

--- Returns list of buffers attached to client_id.
---
---@param client_id number client id
---@returns list of buffer ids
function lsp.get_buffers_by_client_id(client_id)
  local client = lsp.get_client_by_id(client_id)
  return client and vim.tbl_keys(client.attached_buffers) or {}
end

--- Stops a client(s).
---
--- You can also use the `stop()` function on a |vim.lsp.client| object.
--- To stop all clients:
---
--- <pre>
--- vim.lsp.stop_client(vim.lsp.get_active_clients())
--- </pre>
---
--- By default asks the server to shutdown, unless stop was requested
--- already for this client, then force-shutdown is attempted.
---
---@param client_id client id or |vim.lsp.client| object, or list thereof
---@param force boolean (optional) shutdown forcefully
function lsp.stop_client(client_id, force)
  local ids = type(client_id) == 'table' and client_id or { client_id }
  for _, id in ipairs(ids) do
    if type(id) == 'table' and id.stop ~= nil then
      id.stop(force)
    elseif active_clients[id] then
      active_clients[id].stop(force)
    elseif uninitialized_clients[id] then
      uninitialized_clients[id].stop(true)
    end
  end
end

--- Get active clients.
---
---@param filter (table|nil) A table with key-value pairs used to filter the
---              returned clients. The available keys are:
---               - id (number): Only return clients with the given id
---               - bufnr (number): Only return clients attached to this buffer
---               - name (string): Only return clients with the given name
---@returns (table) List of |vim.lsp.client| objects
function lsp.get_active_clients(filter)
  validate({ filter = { filter, 't', true } })

  filter = filter or {}

  local clients = {}

  local t = filter.bufnr and (all_buffer_active_clients[resolve_bufnr(filter.bufnr)] or {})
    or active_clients
  for client_id in pairs(t) do
    local client = active_clients[client_id]
    if
      (filter.id == nil or client.id == filter.id)
      and (filter.name == nil or client.name == filter.name)
    then
      clients[#clients + 1] = client
    end
  end
  return clients
end

api.nvim_create_autocmd('VimLeavePre', {
  desc = 'vim.lsp: exit handler',
  callback = function()
    log.info('exit_handler', active_clients)
    for _, client in pairs(uninitialized_clients) do
      client.stop(true)
    end
    -- TODO handle v:dying differently?
    if tbl_isempty(active_clients) then
      return
    end
    for _, client in pairs(active_clients) do
      client.stop()
    end

    local timeouts = {}
    local max_timeout = 0
    local send_kill = false

    for client_id, client in pairs(active_clients) do
      local timeout = if_nil(client.config.flags.exit_timeout, false)
      if timeout then
        send_kill = true
        timeouts[client_id] = timeout
        max_timeout = math.max(timeout, max_timeout)
      end
    end

    local poll_time = 50

    ---@private
    local function check_clients_closed()
      for client_id, timeout in pairs(timeouts) do
        timeouts[client_id] = timeout - poll_time
      end

      for client_id, _ in pairs(active_clients) do
        if timeouts[client_id] ~= nil and timeouts[client_id] > 0 then
          return false
        end
      end
      return true
    end

    if send_kill then
      if not vim.wait(max_timeout, check_clients_closed, poll_time) then
        for client_id, client in pairs(active_clients) do
          if timeouts[client_id] ~= nil then
            client.stop(true)
          end
        end
      end
    end
  end,
})

--- Sends an async request for all active clients attached to the
--- buffer.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params (optional, table) Parameters to send to the server
---@param handler (optional, function) See |lsp-handler|
---       If nil, follows resolution strategy defined in |lsp-handler-configuration|
---
---@returns 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function lsp.buf_request(bufnr, method, params, handler)
  validate({
    bufnr = { bufnr, 'n', true },
    method = { method, 's' },
    handler = { handler, 'f', true },
  })

  local supported_clients = {}
  local method_supported = false
  for_each_buffer_client(bufnr, function(client, client_id)
    if client.supports_method(method) then
      method_supported = true
      table.insert(supported_clients, client_id)
    end
  end)

  -- if has client but no clients support the given method, notify the user
  if
    not tbl_isempty(all_buffer_active_clients[resolve_bufnr(bufnr)] or {}) and not method_supported
  then
    vim.notify(lsp._unsupported_method(method), vim.log.levels.ERROR)
    nvim_command('redraw')
    return {}, function() end
  end

  local client_request_ids = {}
  for_each_buffer_client(bufnr, function(client, client_id, resolved_bufnr)
    local request_success, request_id = client.request(method, params, handler, resolved_bufnr)
    -- This could only fail if the client shut down in the time since we looked
    -- it up and we did the request, which should be rare.
    if request_success then
      client_request_ids[client_id] = request_id
    end
  end, supported_clients)

  local function _cancel_all_requests()
    for client_id, request_id in pairs(client_request_ids) do
      local client = active_clients[client_id]
      client.cancel_request(request_id)
    end
  end

  return client_request_ids, _cancel_all_requests
end

---Sends an async request for all active clients attached to the buffer.
---Executes the callback on the combined result.
---Parameters are the same as |vim.lsp.buf_request()| but the return result and callback are
---different.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params (optional, table) Parameters to send to the server
---@param callback (function) The callback to call when all requests are finished.
--  Unlike `buf_request`, this will collect all the responses from each server instead of handling them.
--  A map of client_id:request_result will be provided to the callback
--
---@returns (function) A function that will cancel all requests which is the same as the one returned from `buf_request`.
function lsp.buf_request_all(bufnr, method, params, callback)
  local request_results = {}
  local result_count = 0
  local expected_result_count = 0

  local set_expected_result_count = once(function()
    for_each_buffer_client(bufnr, function(client)
      if client.supports_method(method) then
        expected_result_count = expected_result_count + 1
      end
    end)
  end)

  local function _sync_handler(err, result, ctx)
    request_results[ctx.client_id] = { error = err, result = result }
    result_count = result_count + 1
    set_expected_result_count()

    if result_count >= expected_result_count then
      callback(request_results)
    end
  end

  local _, cancel = lsp.buf_request(bufnr, method, params, _sync_handler)

  return cancel
end

--- Sends a request to all server and waits for the response of all of them.
---
--- Calls |vim.lsp.buf_request_all()| but blocks Nvim while awaiting the result.
--- Parameters are the same as |vim.lsp.buf_request()| but the return result is
--- different. Wait maximum of {timeout_ms} (default 1000) ms.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params (optional, table) Parameters to send to the server
---@param timeout_ms (optional, number, default=1000) Maximum time in
---      milliseconds to wait for a result.
---
---@returns Map of client_id:request_result. On timeout, cancel or error,
---        returns `(nil, err)` where `err` is a string describing the failure
---        reason.
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results

  local cancel = lsp.buf_request_all(bufnr, method, params, function(it)
    request_results = it
  end)

  local wait_result, reason = vim.wait(timeout_ms or 1000, function()
    return request_results ~= nil
  end, 10)

  if not wait_result then
    cancel()
    return nil, wait_result_reason[reason]
  end

  return request_results
end

--- Send a notification to a server
---@param bufnr [number] (optional): The number of the buffer
---@param method [string]: Name of the request method
---@param params [string]: Arguments to send to the server
---
---@returns true if any client returns true; false otherwise
function lsp.buf_notify(bufnr, method, params)
  validate({
    bufnr = { bufnr, 'n', true },
    method = { method, 's' },
  })
  local resp = false
  for_each_buffer_client(bufnr, function(client, _client_id, _resolved_bufnr)
    if client.rpc.notify(method, params) then
      resp = true
    end
  end)
  return resp
end

---@private
local function adjust_start_col(lnum, line, items, encoding)
  local min_start_char = nil
  for _, item in pairs(items) do
    if item.filterText == nil and item.textEdit and item.textEdit.range.start.line == lnum - 1 then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then
        return nil
      end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then
    return util._str_byteindex_enc(line, min_start_char, encoding)
  else
    return nil
  end
end

--- Implements 'omnifunc' compatible LSP completion.
---
---@see |complete-functions|
---@see |complete-items|
---@see |CompleteDone|
---
---@param findstart 0 or 1, decides behavior
---@param base If findstart=0, text to match against
---
---@returns (number) Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function lsp.omnifunc(findstart, base)
  local _ = log.debug() and log.debug('omnifunc.findstart', { findstart = findstart, base = base })

  local bufnr = resolve_bufnr()
  local has_buffer_clients = not tbl_isempty(all_buffer_active_clients[bufnr] or {})
  if not has_buffer_clients then
    if findstart == 1 then
      return -1
    else
      return {}
    end
  end

  -- Then, perform standard completion request
  local _ = log.info() and log.info('base ', base)

  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  local _ = log.trace() and log.trace('omnifunc.line', pos, line)

  -- Get the start position of the current keyword
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')

  local params = util.make_position_params()

  local items = {}
  lsp.buf_request(bufnr, 'textDocument/completion', params, function(err, result, ctx)
    if err or not result or vim.fn.mode() ~= 'i' then
      return
    end

    -- Completion response items may be relative to a position different than `textMatch`.
    -- Concrete example, with sumneko/lua-language-server:
    --
    -- require('plenary.asy|
    --         ▲       ▲   ▲
    --         │       │   └── cursor_pos: 20
    --         │       └────── textMatch: 17
    --         └────────────── textEdit.range.start.character: 9
    --                                 .newText = 'plenary.async'
    --                  ^^^
    --                  prefix (We'd remove everything not starting with `asy`,
    --                  so we'd eliminate the `plenary.async` result
    --
    -- `adjust_start_col` is used to prefer the language server boundary.
    --
    local client = lsp.get_client_by_id(ctx.client_id)
    local encoding = client and client.offset_encoding or 'utf-16'
    local candidates = util.extract_completion_items(result)
    local startbyte = adjust_start_col(pos[1], line, candidates, encoding) or textMatch
    local prefix = line:sub(startbyte + 1, pos[2])
    local matches = util.text_document_completion_list_to_complete_items(result, prefix)
    -- TODO(ashkan): is this the best way to do this?
    vim.list_extend(items, matches)
    vim.fn.complete(startbyte + 1, items)
  end)

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end

--- Provides an interface between the built-in client and a `formatexpr` function.
---
--- Currently only supports a single client. This can be set via
--- `setlocal formatexpr=v:lua.vim.lsp.formatexpr()` but will typically or in `on_attach`
--- via ``vim.api.nvim_buf_set_option(bufnr, 'formatexpr', 'v:lua.vim.lsp.formatexpr(#{timeout_ms:250})')``.
---
---@param opts table options for customizing the formatting expression which takes the
---                   following optional keys:
---                   * timeout_ms (default 500ms). The timeout period for the formatting request.
function lsp.formatexpr(opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 500

  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end

  local start_lnum = vim.v.lnum
  local end_lnum = start_lnum + vim.v.count - 1

  if start_lnum <= 0 or end_lnum <= 0 then
    return 0
  end
  local bufnr = api.nvim_get_current_buf()
  for _, client in pairs(lsp.get_active_clients({ bufnr = bufnr })) do
    if client.supports_method('textDocument/rangeFormatting') then
      local params = util.make_formatting_params()
      local end_line = vim.fn.getline(end_lnum)
      local end_col = util._str_utfindex_enc(end_line, nil, client.offset_encoding)
      params.range = {
        start = {
          line = start_lnum - 1,
          character = 0,
        },
        ['end'] = {
          line = end_lnum - 1,
          character = end_col,
        },
      }
      local response =
        client.request_sync('textDocument/rangeFormatting', params, timeout_ms, bufnr)
      if response.result then
        vim.lsp.util.apply_text_edits(response.result, 0, client.offset_encoding)
        return 0
      end
    end
  end

  -- do not run builtin formatter.
  return 0
end

--- Provides an interface between the built-in client and 'tagfunc'.
---
--- When used with normal mode commands (e.g. |CTRL-]|) this will invoke
--- the "textDocument/definition" LSP method to find the tag under the cursor.
--- Otherwise, uses "workspace/symbol". If no results are returned from
--- any LSP servers, falls back to using built-in tags.
---
---@param pattern Pattern used to find a workspace symbol
---@param flags See |tag-function|
---
---@returns A list of matching tags
function lsp.tagfunc(...)
  return require('vim.lsp.tagfunc')(...)
end

---Checks whether a client is stopped.
---
---@param client_id (Number)
---@returns true if client is stopped, false otherwise.
function lsp.client_is_stopped(client_id)
  return active_clients[client_id] == nil
end

--- Gets a map of client_id:client pairs for the given buffer, where each value
--- is a |vim.lsp.client| object.
---
---@param bufnr (optional, number): Buffer handle, or 0 for current
---@returns (table) Table of (client_id, client) pairs
---@deprecated Use |vim.lsp.get_active_clients()| instead.
function lsp.buf_get_clients(bufnr)
  local result = {}
  for _, client in ipairs(lsp.get_active_clients({ bufnr = resolve_bufnr(bufnr) })) do
    result[client.id] = client
  end
  return result
end

-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the
-- name from the number.
-- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
-- Level numbers begin with "TRACE" at 0
lsp.log_levels = log.levels

--- Sets the global log level for LSP logging.
---
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
---
--- Level numbers begin with "TRACE" at 0
---
--- Use `lsp.log_levels` for reverse lookup.
---
---@see |vim.lsp.log_levels|
---
---@param level [number|string] the case insensitive level name or number
function lsp.set_log_level(level)
  if type(level) == 'string' or type(level) == 'number' then
    log.set_level(level)
  else
    error(string.format('Invalid log level: %q', level))
  end
end

--- Gets the path of the logfile used by the LSP client.
---@returns (String) Path to logfile.
function lsp.get_log_path()
  return log.get_filename()
end

--- Invokes a function for each LSP client attached to a buffer.
---
---@param bufnr number Buffer number
---@param fn function Function to run on each client attached to buffer
---                   {bufnr}. The function takes the client, client ID, and
---                   buffer number as arguments. Example:
---             <pre>
---               vim.lsp.for_each_buffer_client(0, function(client, client_id, bufnr)
---                 print(vim.inspect(client))
---               end)
---             </pre>
function lsp.for_each_buffer_client(bufnr, fn)
  return for_each_buffer_client(bufnr, fn)
end

--- Function to manage overriding defaults for LSP handlers.
---@param handler (function) See |lsp-handler|
---@param override_config (table) Table containing the keys to override behavior of the {handler}
function lsp.with(handler, override_config)
  return function(err, result, ctx, config)
    return handler(err, result, ctx, vim.tbl_deep_extend('force', config or {}, override_config))
  end
end

--- Helper function to use when implementing a handler.
--- This will check that all of the keys in the user configuration
--- are valid keys and make sense to include for this handler.
---
--- Will error on invalid keys (i.e. keys that do not exist in the options)
function lsp._with_extend(name, options, user_config)
  user_config = user_config or {}

  local resulting_config = {}
  for k, v in pairs(user_config) do
    if options[k] == nil then
      error(
        debug.traceback(
          string.format(
            'Invalid option for `%s`: %s. Valid options are:\n%s',
            name,
            k,
            vim.inspect(vim.tbl_keys(options))
          )
        )
      )
    end

    resulting_config[k] = v
  end

  for k, v in pairs(options) do
    if resulting_config[k] == nil then
      resulting_config[k] = v
    end
  end

  return resulting_config
end

--- Registry for client side commands.
--- This is an extension point for plugins to handle custom commands which are
--- not part of the core language server protocol specification.
---
--- The registry is a table where the key is a unique command name,
--- and the value is a function which is called if any LSP action
--- (code action, code lenses, ...) triggers the command.
---
--- If a LSP response contains a command for which no matching entry is
--- available in this registry, the command will be executed via the LSP server
--- using `workspace/executeCommand`.
---
--- The first argument to the function will be the `Command`:
---   Command
---     title: String
---     command: String
---     arguments?: any[]
---
--- The second argument is the `ctx` of |lsp-handler|
lsp.commands = setmetatable({}, {
  __newindex = function(tbl, key, value)
    assert(type(key) == 'string', 'The key for commands in `vim.lsp.commands` must be a string')
    assert(type(value) == 'function', 'Command added to `vim.lsp.commands` must be a function')
    rawset(tbl, key, value)
  end,
})

return lsp
-- vim:sw=2 ts=2 et
