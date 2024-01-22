---@diagnostic disable: invisible
local api = vim.api
local nvim_err_writeln, nvim_buf_get_lines, nvim_command, nvim_exec_autocmds =
  api.nvim_err_writeln, api.nvim_buf_get_lines, api.nvim_command, api.nvim_exec_autocmds
local uv = vim.uv
local tbl_isempty, tbl_extend = vim.tbl_isempty, vim.tbl_extend
local validate = vim.validate
local if_nil = vim.F.if_nil

local lsp = vim._defer_require('vim.lsp', {
  _changetracking = ..., --- @module 'vim.lsp._changetracking'
  _completion = ..., --- @module 'vim.lsp._completion'
  _dynamic = ..., --- @module 'vim.lsp._dynamic'
  _snippet_grammar = ..., --- @module 'vim.lsp._snippet_grammar'
  _watchfiles = ..., --- @module 'vim.lsp._watchfiles'
  buf = ..., --- @module 'vim.lsp.buf'
  codelens = ..., --- @module 'vim.lsp.codelens'
  diagnostic = ..., --- @module 'vim.lsp.diagnostic'
  handlers = ..., --- @module 'vim.lsp.handlers'
  inlay_hint = ..., --- @module 'vim.lsp.inlay_hint'
  log = ..., --- @module 'vim.lsp.log'
  protocol = ..., --- @module 'vim.lsp.protocol'
  rpc = ..., --- @module 'vim.lsp.rpc'
  semantic_tokens = ..., --- @module 'vim.lsp.semantic_tokens'
  tagfunc = ..., --- @module 'vim.lsp.tagfunc'
  util = ..., --- @module 'vim.lsp.util'
})

local log = lsp.log
local protocol = lsp.protocol
local ms = protocol.Methods
local util = lsp.util
local changetracking = lsp._changetracking

-- Export these directly from rpc.
---@nodoc
lsp.rpc_response_error = lsp.rpc.rpc_response_error

-- maps request name to the required server_capability in the client.
lsp._request_name_to_capability = {
  [ms.textDocument_hover] = { 'hoverProvider' },
  [ms.textDocument_signatureHelp] = { 'signatureHelpProvider' },
  [ms.textDocument_definition] = { 'definitionProvider' },
  [ms.textDocument_implementation] = { 'implementationProvider' },
  [ms.textDocument_declaration] = { 'declarationProvider' },
  [ms.textDocument_typeDefinition] = { 'typeDefinitionProvider' },
  [ms.textDocument_documentSymbol] = { 'documentSymbolProvider' },
  [ms.textDocument_prepareCallHierarchy] = { 'callHierarchyProvider' },
  [ms.callHierarchy_incomingCalls] = { 'callHierarchyProvider' },
  [ms.callHierarchy_outgoingCalls] = { 'callHierarchyProvider' },
  [ms.textDocument_rename] = { 'renameProvider' },
  [ms.textDocument_prepareRename] = { 'renameProvider', 'prepareProvider' },
  [ms.textDocument_codeAction] = { 'codeActionProvider' },
  [ms.textDocument_codeLens] = { 'codeLensProvider' },
  [ms.codeLens_resolve] = { 'codeLensProvider', 'resolveProvider' },
  [ms.codeAction_resolve] = { 'codeActionProvider', 'resolveProvider' },
  [ms.workspace_executeCommand] = { 'executeCommandProvider' },
  [ms.workspace_symbol] = { 'workspaceSymbolProvider' },
  [ms.textDocument_references] = { 'referencesProvider' },
  [ms.textDocument_rangeFormatting] = { 'documentRangeFormattingProvider' },
  [ms.textDocument_formatting] = { 'documentFormattingProvider' },
  [ms.textDocument_completion] = { 'completionProvider' },
  [ms.textDocument_documentHighlight] = { 'documentHighlightProvider' },
  [ms.textDocument_semanticTokens_full] = { 'semanticTokensProvider' },
  [ms.textDocument_semanticTokens_full_delta] = { 'semanticTokensProvider' },
  [ms.textDocument_inlayHint] = { 'inlayHintProvider' },
  [ms.textDocument_diagnostic] = { 'diagnosticProvider' },
  [ms.inlayHint_resolve] = { 'inlayHintProvider', 'resolveProvider' },
}

-- TODO improve handling of scratch buffers with LSP attached.

--- Concatenates and writes a list of strings to the Vim error buffer.
---
---@param ... string List to write to the buffer
local function err_message(...)
  nvim_err_writeln(table.concat(vim.tbl_flatten({ ... })))
  nvim_command('redraw')
end

--- Returns the buffer number for the given {bufnr}.
---
---@param bufnr (integer|nil) Buffer number to resolve. Defaults to current buffer
---@return integer bufnr
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

--- Checks whether a given path is a directory.
---
---@param filename (string) path to check
---@return boolean # true if {filename} exists and is a directory, false otherwise
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
---@return string
function lsp._buf_get_line_ending(bufnr)
  return format_line_ending[vim.bo[bufnr].fileformat] or '\n'
end

local client_index = 0
--- Returns a new, unused client id.
---
---@return integer client_id
local function next_client_id()
  client_index = client_index + 1
  return client_index
end
-- Tracks all clients created via lsp.start_client
local active_clients = {} --- @type table<integer,lsp.Client>
local all_buffer_active_clients = {} --- @type table<integer,table<integer,true>>
local uninitialized_clients = {} --- @type table<integer,lsp.Client>

---@param bufnr? integer
---@param fn fun(client: lsp.Client, client_id: integer, bufnr: integer)
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
    local filtered_client_ids = {} --- @type table<integer,true>
    for client_id in pairs(client_ids) do
      if vim.list_contains(restrict_client_ids, client_id) then
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

--- Error codes to be used with `on_error` from |vim.lsp.start_client|.
--- Can be used to look up the string from a the number or the number
--- from the string.
--- @nodoc
lsp.client_errors = tbl_extend(
  'error',
  lsp.rpc.client_errors,
  vim.tbl_add_reverse_lookup({
    BEFORE_INIT_CALLBACK_ERROR = table.maxn(lsp.rpc.client_errors) + 1,
    ON_INIT_CALLBACK_ERROR = table.maxn(lsp.rpc.client_errors) + 2,
    ON_ATTACH_ERROR = table.maxn(lsp.rpc.client_errors) + 3,
  })
)

--- Normalizes {encoding} to valid LSP encoding names.
---
---@param encoding (string) Encoding to normalize
---@return string # normalized encoding name
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
---@param input string[]
---@return string command, string[] args #the command and arguments
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

--- Augments a validator function with support for optional (nil) values.
---
---@param fn (fun(v): boolean) The original validator function; should return a
---bool.
---@return fun(v): boolean # The augmented function. Also returns true if {v} is
---`nil`.
local function optional_validator(fn)
  return function(v)
    return v == nil or fn(v)
  end
end

--- Validates a client configuration as given to |vim.lsp.start_client()|.
---
---@param config (lsp.ClientConfig)
---@return (string|fun(dispatchers:vim.rpc.Dispatchers):vim.lsp.rpc.PublicClient?) Command
---@return string[] Arguments
---@return string Encoding.
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

  local cmd, cmd_args --- @type (string|fun(dispatchers:vim.rpc.Dispatchers):vim.lsp.rpc.PublicClient), string[]
  local config_cmd = config.cmd
  if type(config_cmd) == 'function' then
    cmd = config_cmd
  else
    cmd, cmd_args = lsp._cmd_parts(config_cmd)
  end
  local offset_encoding = valid_encodings.UTF16
  if config.offset_encoding then
    offset_encoding = validate_encoding(config.offset_encoding)
  end

  return cmd, cmd_args, offset_encoding
end

---@private
--- Returns full text of buffer {bufnr} as a string.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@return string # Buffer text as string.
function lsp._buf_get_full_text(bufnr)
  local line_ending = lsp._buf_get_line_ending(bufnr)
  local text = table.concat(nvim_buf_get_lines(bufnr, 0, -1, true), line_ending)
  if vim.bo[bufnr].eol then
    text = text .. line_ending
  end
  return text
end

--- Memoizes a function. On first run, the function return value is saved and
--- immediately returned on subsequent runs. If the function returns a multival,
--- only the first returned value will be memoized and returned. The function will only be run once,
--- even if it has side effects.
---
---@generic T: function
---@param fn (T) Function to run
---@return T
local function once(fn)
  local value --- @type function
  local ran = false
  return function(...)
    if not ran then
      value = fn(...) --- @type function
      ran = true
    end
    return value
  end
end

--- Default handler for the 'textDocument/didOpen' LSP notification.
---
---@param bufnr integer Number of the buffer, or 0 for current
---@param client lsp.Client Client object
local function text_document_did_open_handler(bufnr, client)
  changetracking.init(client, bufnr)
  if not vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
    return
  end
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local filetype = vim.bo[bufnr].filetype

  local params = {
    textDocument = {
      version = 0,
      uri = vim.uri_from_bufnr(bufnr),
      languageId = client.config.get_language_id(bufnr, filetype),
      text = lsp._buf_get_full_text(bufnr),
    },
  }
  client.notify(ms.textDocument_didOpen, params)
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
--- |vim.lsp.get_client_by_id()| or |vim.lsp.get_clients()|.
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
---  - supports_method(method, [opts]): boolean
---     Checks if a client supports a given method.
---     Always returns true for unknown off-spec methods.
---     [opts] is a optional `{bufnr?: integer}` table.
---     Some language server capabilities can be file specific.
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
---    for an active request, or "cancel" for a cancel request. It will
---    be "complete" ephemerally while executing |LspRequest| autocmds
---    when replies are received from the server.
---
---  - {config} (table): copy of the table that was passed by the user
---    to |vim.lsp.start_client()|.
---
---  - {server_capabilities} (table): Response from the server sent on
---    `initialize` describing the server's capabilities.
---
---  - {progress} A ring buffer (|vim.ringbuf()|) containing progress messages
---    sent by the server.
function lsp.client()
  error()
end

--- @class lsp.StartOpts
--- @field reuse_client fun(client: lsp.Client, config: table): boolean
--- @field bufnr integer

--- Create a new LSP client and start a language server or reuses an already
--- running client if one is found matching `name` and `root_dir`.
--- Attaches the current buffer to the client.
---
--- Example:
---
--- ```lua
--- vim.lsp.start({
---    name = 'my-server-name',
---    cmd = {'name-of-language-server-executable'},
---    root_dir = vim.fs.dirname(vim.fs.find({'pyproject.toml', 'setup.py'}, { upward = true })[1]),
--- })
--- ```
---
--- See |vim.lsp.start_client()| for all available options. The most important are:
---
--- - `name` arbitrary name for the LSP client. Should be unique per language server.
--- - `cmd` command string[] or function, described at |vim.lsp.start_client()|.
--- - `root_dir` path to the project root. By default this is used to decide if an existing client
---   should be re-used. The example above uses |vim.fs.find()| and |vim.fs.dirname()| to detect the
---   root by traversing the file system upwards starting from the current directory until either
---   a `pyproject.toml` or `setup.py` file is found.
--- - `workspace_folders` list of `{ uri:string, name: string }` tables specifying the project root
---   folders used by the language server. If `nil` the property is derived from `root_dir` for
---   convenience.
---
--- Language servers use this information to discover metadata like the
--- dependencies of your project and they tend to index the contents within the
--- project folder.
---
---
--- To ensure a language server is only started for languages it can handle,
--- make sure to call |vim.lsp.start()| within a |FileType| autocmd.
--- Either use |:au|, |nvim_create_autocmd()| or put the call in a
--- `ftplugin/<filetype_name>.lua` (See |ftplugin-name|)
---
---@param config table Same configuration as documented in |vim.lsp.start_client()|
---@param opts (nil|lsp.StartOpts) Optional keyword arguments:
---             - reuse_client (fun(client: client, config: table): boolean)
---                            Predicate used to decide if a client should be re-used.
---                            Used on all running clients.
---                            The default implementation re-uses a client if name
---                            and root_dir matches.
---             - bufnr (number)
---                     Buffer handle to attach to if starting or re-using a
---                     client (0 for current).
---@return integer|nil client_id
function lsp.start(config, opts)
  opts = opts or {}
  local reuse_client = opts.reuse_client
    or function(client, conf)
      return client.config.root_dir == conf.root_dir and client.name == conf.name
    end
  if not config.name and type(config.cmd) == 'table' then
    config.name = config.cmd[1] and vim.fs.basename(config.cmd[1]) or nil
  end
  local bufnr = opts.bufnr
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  for _, clients in ipairs({ uninitialized_clients, lsp.get_clients() }) do
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

--- Consumes the latest progress messages from all clients and formats them as a string.
--- Empty if there are no clients or if no new messages
---
---@return string
function lsp.status()
  local percentage = nil
  local messages = {} --- @type string[]
  for _, client in ipairs(vim.lsp.get_clients()) do
    for progress in client.progress do
      local value = progress.value
      if type(value) == 'table' and value.kind then
        local message = value.message and (value.title .. ': ' .. value.message) or value.title
        messages[#messages + 1] = message
        if value.percentage then
          percentage = math.max(percentage or 0, value.percentage)
        end
      end
      -- else: Doesn't look like work done progress and can be in any format
      -- Just ignore it as there is no sensible way to display it
    end
  end
  local message = table.concat(messages, ', ')
  if percentage then
    return string.format('%3d%%: %s', percentage, message)
  end
  return message
end

-- Determines whether the given option can be set by `set_defaults`.
---@param bufnr integer
---@param option string
---@return boolean
local function is_empty_or_default(bufnr, option)
  if vim.bo[bufnr][option] == '' then
    return true
  end

  local info = api.nvim_get_option_info2(option, { buf = bufnr })
  local scriptinfo = vim.tbl_filter(function(e)
    return e.sid == info.last_set_sid
  end, vim.fn.getscriptinfo())

  if #scriptinfo ~= 1 then
    return false
  end

  return vim.startswith(scriptinfo[1].name, vim.fn.expand('$VIMRUNTIME'))
end

---@private
---@param client lsp.Client
---@param bufnr integer
function lsp._set_defaults(client, bufnr)
  if
    client.supports_method(ms.textDocument_definition) and is_empty_or_default(bufnr, 'tagfunc')
  then
    vim.bo[bufnr].tagfunc = 'v:lua.vim.lsp.tagfunc'
  end
  if
    client.supports_method(ms.textDocument_completion) and is_empty_or_default(bufnr, 'omnifunc')
  then
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
  end
  if
    client.supports_method(ms.textDocument_rangeFormatting)
    and is_empty_or_default(bufnr, 'formatprg')
    and is_empty_or_default(bufnr, 'formatexpr')
  then
    vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr()'
  end
  api.nvim_buf_call(bufnr, function()
    if
      client.supports_method(ms.textDocument_hover)
      and is_empty_or_default(bufnr, 'keywordprg')
      and vim.fn.maparg('K', 'n', false, false) == ''
    then
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr })
    end
  end)
  if client.supports_method(ms.textDocument_diagnostic) then
    lsp.diagnostic._enable(bufnr)
  end
end

--- @class lsp.ClientConfig
--- @field cmd (string[]|fun(dispatchers: table):table)
--- @field cmd_cwd string
--- @field cmd_env (table)
--- @field detached boolean
--- @field workspace_folders (table)
--- @field capabilities lsp.ClientCapabilities
--- @field handlers table<string,function>
--- @field settings table
--- @field commands table
--- @field init_options table
--- @field name string
--- @field get_language_id fun(bufnr: integer, filetype: string): string
--- @field offset_encoding string
--- @field on_error fun(code: integer)
--- @field before_init function
--- @field on_init function
--- @field on_exit fun(code: integer, signal: integer, client_id: integer)
--- @field on_attach fun(client: lsp.Client, bufnr: integer)
--- @field trace 'off'|'messages'|'verbose'|nil
--- @field flags table
--- @field root_dir string

-- FIXME: DOC: Currently all methods on the `vim.lsp.client` object are
-- documented twice: Here, and on the methods themselves (e.g.
-- `client.request()`). This is a workaround for the vimdoc generator script
-- not handling method names correctly. If you change the documentation on
-- either, please make sure to update the other as well.
--
--- Starts and initializes a client with the given configuration.
---
--- Field `cmd` in {config} is required.
---
---@param config (lsp.ClientConfig) Configuration for the server:
--- - cmd: (string[]|fun(dispatchers: table):table) command string[] that launches the language
---       server (treated as in |jobstart()|, must be absolute or on `$PATH`, shell constructs like
---       "~" are not expanded), or function that creates an RPC client. Function receives
---       a `dispatchers` table and returns a table with member functions `request`, `notify`,
---       `is_closing` and `terminate`.
---       See |vim.lsp.rpc.request()|, |vim.lsp.rpc.notify()|.
---       For TCP there is a builtin RPC client factory: |vim.lsp.rpc.connect()|
---
--- - cmd_cwd: (string, default=|getcwd()|) Directory to launch
---       the `cmd` process. Not related to `root_dir`.
---
--- - cmd_env: (table) Environment flags to pass to the LSP on
---       spawn.  Must be specified using a table.
---       Non-string values are coerced to string.
---       Example:
---       <pre>
---                   { PORT = 8080; HOST = "0.0.0.0"; }
---       </pre>
---
--- - detached: (boolean, default true) Daemonize the server process so that it runs in a
---       separate process group from Nvim. Nvim will shutdown the process on exit, but if Nvim fails to
---       exit cleanly this could leave behind orphaned server processes.
---
--- - workspace_folders: (table) List of workspace folders passed to the
---       language server. For backwards compatibility rootUri and rootPath will be
---       derived from the first workspace folder in this list. See `workspaceFolders` in
---       the LSP spec.
---
--- - capabilities: Map overriding the default capabilities defined by
---       \|vim.lsp.protocol.make_client_capabilities()|, passed to the language
---       server on initialization. Hint: use make_client_capabilities() and modify
---       its result.
---       - Note: To send an empty dictionary use |vim.empty_dict()|, else it will be encoded as an
---         array.
---
--- - handlers: Map of language server method names to |lsp-handler|
---
--- - settings: Map with language server specific settings. These are
---       returned to the language server if requested via `workspace/configuration`.
---       Keys are case-sensitive.
---
--- - commands: table Table that maps string of clientside commands to user-defined functions.
---       Commands passed to start_client take precedence over the global command registry. Each key
---       must be a unique command name, and the value is a function which is called if any LSP action
---       (code action, code lenses, ...) triggers the command.
---
--- - init_options Values to pass in the initialization request
---       as `initializationOptions`. See `initialize` in the LSP spec.
---
--- - name: (string, default=client-id) Name in log messages.
---
--- - get_language_id: function(bufnr, filetype) -> language ID as string.
---       Defaults to the filetype.
---
--- - offset_encoding: (default="utf-16") One of "utf-8", "utf-16",
---       or "utf-32" which is the encoding that the LSP server expects. Client does
---       not verify this is correct.
---
--- - on_error: Callback with parameters (code, ...), invoked
---       when the client operation throws an error. `code` is a number describing
---       the error. Other arguments may be passed depending on the error kind.  See
---       `vim.lsp.rpc.client_errors` for possible errors.
---       Use `vim.lsp.rpc.client_errors[code]` to get human-friendly name.
---
--- - before_init: Callback with parameters (initialize_params, config)
---       invoked before the LSP "initialize" phase, where `params` contains the
---       parameters being sent to the server and `config` is the config that was
---       passed to |vim.lsp.start_client()|. You can use this to modify parameters before
---       they are sent.
---
--- - on_init: Callback (client, initialize_result) invoked after LSP
---       "initialize", where `result` is a table of `capabilities` and anything else
---       the server may send. For example, clangd sends
---       `initialize_result.offsetEncoding` if `capabilities.offsetEncoding` was
---       sent to it. You can only modify the `client.offset_encoding` here before
---       any notifications are sent. Most language servers expect to be sent client specified settings after
---       initialization. Nvim does not make this assumption. A
---       `workspace/didChangeConfiguration` notification should be sent
---        to the server during on_init.
---
--- - on_exit Callback (code, signal, client_id) invoked on client
--- exit.
---       - code: exit code of the process
---       - signal: number describing the signal used to terminate (if any)
---       - client_id: client handle
---
--- - on_attach: Callback (client, bufnr) invoked when client
---       attaches to a buffer.
---
--- - trace: ("off" | "messages" | "verbose" | nil) passed directly to the language
---       server in the initialize request. Invalid/empty values will default to "off"
---
--- - flags: A table with flags for the client. The current (experimental) flags are:
---       - allow_incremental_sync (bool, default true): Allow using incremental sync for buffer edits
---       - debounce_text_changes (number, default 150): Debounce didChange
---             notifications to the server by the given number in milliseconds. No debounce
---             occurs if nil
---       - exit_timeout (number|boolean, default false): Milliseconds to wait for server to
---             exit cleanly after sending the "shutdown" request before sending kill -15.
---             If set to false, nvim exits immediately after sending the "shutdown" request to the server.
---
--- - root_dir: (string) Directory where the LSP
---       server will base its workspaceFolders, rootUri, and rootPath
---       on initialization.
---
---@return integer|nil client_id. |vim.lsp.get_client_by_id()| Note: client may not be
--- fully initialized. Use `on_init` to do any actions once
--- the client has been initialized.
function lsp.start_client(config)
  local cmd, cmd_args, offset_encoding = validate_client_config(config)

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

  --- Returns the handler associated with an LSP method.
  --- Returns the default handler if the user hasn't set a custom one.
  ---
  ---@param method (string) LSP method name
  ---@return lsp.Handler|nil handler for the given method, if defined, or the default from |vim.lsp.handlers|
  local function resolve_handler(method)
    return handlers[method] or lsp.handlers[method]
  end

  ---@private
  --- Handles a notification sent by an LSP server by invoking the
  --- corresponding handler.
  ---
  ---@param method (string) LSP method name
  ---@param params (table) The parameters for that method.
  function dispatch.notification(method, params)
    if log.trace() then
      log.trace('notification', method, params)
    end
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
  ---@return any result
  ---@return lsp.ResponseError error code and message set in case an exception happens during the request.
  function dispatch.server_request(method, params)
    if log.trace() then
      log.trace('server_request', method, params)
    end
    local handler = resolve_handler(method)
    if handler then
      if log.trace() then
        log.trace('server_request: found handler for', method)
      end
      return handler(nil, params, { method = method, client_id = client_id })
    end
    if log.warn() then
      log.warn('server_request: no handler found for', method)
    end
    return nil, lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  --- Logs the given error to the LSP log and to the error buffer.
  --- @param code integer Error code
  --- @param err any Error arguments
  local function write_error(code, err)
    if log.error() then
      log.error(log_prefix, 'on_error', { code = lsp.client_errors[code], err = err })
    end
    err_message(log_prefix, ': Error ', lsp.client_errors[code], ': ', vim.inspect(err))
  end

  ---@private
  --- Invoked when the client operation throws an error.
  ---
  ---@param code (integer) Error code
  ---@param err any Other arguments may be passed depending on the error kind
  ---@see vim.lsp.rpc.client_errors for possible errors. Use
  ---`vim.lsp.rpc.client_errors[code]` to get a human-friendly name.
  function dispatch.on_error(code, err)
    write_error(code, err)
    if config.on_error then
      local status, usererr = pcall(config.on_error, code, err)
      if not status then
        if log.error() then
          log.error(log_prefix, 'user on_error failed', { err = usererr })
        end
        err_message(log_prefix, ' user on_error failed: ', tostring(usererr))
      end
    end
  end

  --- Reset defaults set by `set_defaults`.
  --- Must only be called if the last client attached to a buffer exits.
  local function reset_defaults(bufnr)
    if vim.bo[bufnr].tagfunc == 'v:lua.vim.lsp.tagfunc' then
      vim.bo[bufnr].tagfunc = nil
    end
    if vim.bo[bufnr].omnifunc == 'v:lua.vim.lsp.omnifunc' then
      vim.bo[bufnr].omnifunc = nil
    end
    if vim.bo[bufnr].formatexpr == 'v:lua.vim.lsp.formatexpr()' then
      vim.bo[bufnr].formatexpr = nil
    end
    api.nvim_buf_call(bufnr, function()
      local keymap = vim.fn.maparg('K', 'n', false, true)
      if keymap and keymap.callback == vim.lsp.buf.hover then
        vim.keymap.del('n', 'K', { buffer = bufnr })
      end
    end)
  end

  ---@private
  --- Invoked on client exit.
  ---
  ---@param code (integer) exit code of the process
  ---@param signal (integer) the signal used to terminate (if any)
  function dispatch.on_exit(code, signal)
    if config.on_exit then
      pcall(config.on_exit, code, signal, client_id)
    end

    local client = active_clients[client_id] and active_clients[client_id]
      or uninitialized_clients[client_id]

    for bufnr, client_ids in pairs(all_buffer_active_clients) do
      if client_ids[client_id] then
        vim.schedule(function()
          if client and client.attached_buffers[bufnr] then
            nvim_exec_autocmds('LspDetach', {
              buffer = bufnr,
              modeline = false,
              data = { client_id = client_id },
            })
          end

          local namespace = vim.lsp.diagnostic.get_namespace(client_id)
          vim.diagnostic.reset(namespace, bufnr)

          client_ids[client_id] = nil
          if vim.tbl_isempty(client_ids) then
            reset_defaults(bufnr)
          end
        end)
      end
    end

    -- Schedule the deletion of the client object so that it exists in the execution of LspDetach
    -- autocommands
    vim.schedule(function()
      active_clients[client_id] = nil
      uninitialized_clients[client_id] = nil

      -- Client can be absent if executable starts, but initialize fails
      -- init/attach won't have happened
      if client then
        changetracking.reset(client)
      end
      if code ~= 0 or (signal ~= 0 and signal ~= 15) then
        local msg = string.format(
          'Client %s quit with exit code %s and signal %s. Check log for errors: %s',
          name,
          code,
          signal,
          lsp.get_log_path()
        )
        vim.notify(msg, vim.log.levels.WARN)
      end
    end)
  end

  -- Start the RPC client.
  local rpc --- @type vim.lsp.rpc.PublicClient?
  if type(cmd) == 'function' then
    rpc = cmd(dispatch)
  else
    rpc = lsp.rpc.start(cmd, cmd_args, dispatch, {
      cwd = config.cmd_cwd,
      env = config.cmd_env,
      detached = config.detached,
    })
  end

  -- Return nil if client fails to start
  if not rpc then
    return
  end

  ---@class lsp.Client
  local client = {
    id = client_id,
    name = name,
    rpc = rpc,
    offset_encoding = offset_encoding,
    config = config,
    attached_buffers = {}, --- @type table<integer,true>

    handlers = handlers,
    --- @type table<string,function>
    commands = config.commands or {},

    --- @type table<integer,{ type: string, bufnr: integer, method: string}>
    requests = {},

    --- Contains $/progress report messages.
    --- They have the format {token: integer|string, value: any}
    --- For "work done progress", value will be one of:
    --- - lsp.WorkDoneProgressBegin,
    --- - lsp.WorkDoneProgressReport (extended with title from Begin)
    --- - lsp.WorkDoneProgressEnd    (extended with title from Begin)
    progress = vim.ringbuf(50),

    --- @type lsp.ServerCapabilities
    server_capabilities = {},

    ---@deprecated use client.progress instead
    messages = { name = name, messages = {}, progress = {}, status = {} },
    dynamic_capabilities = vim.lsp._dynamic.new(client_id),
  }

  ---@type table<string|integer, string> title of unfinished progress sequences by token
  client.progress.pending = {}

  --- @type lsp.ClientCapabilities
  client.config.capabilities = config.capabilities or protocol.make_client_capabilities()

  -- Store the uninitialized_clients for cleanup in case we exit before initialize finishes.
  uninitialized_clients[client_id] = client

  local function initialize()
    local valid_traces = {
      off = 'off',
      messages = 'messages',
      verbose = 'verbose',
    }

    local workspace_folders --- @type lsp.WorkspaceFolder[]?
    local root_uri --- @type string?
    local root_path --- @type string?
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
      processId = uv.os_getpid(),
      -- Information about the client
      -- since 3.15.0
      clientInfo = {
        name = 'Neovim',
        version = tostring(vim.version()),
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
      capabilities = config.capabilities,
      -- The initial trace setting. If omitted trace is disabled ("off").
      -- trace = "off" | "messages" | "verbose";
      trace = valid_traces[config.trace] or 'off',
    }
    if config.before_init then
      local status, err = pcall(config.before_init, initialize_params, config)
      if not status then
        write_error(lsp.client_errors.BEFORE_INIT_CALLBACK_ERROR, err)
      end
    end

    --- @param method string
    --- @param opts? {bufnr: integer?}
    client.supports_method = function(method, opts)
      opts = opts or {}
      local required_capability = lsp._request_name_to_capability[method]
      -- if we don't know about the method, assume that the client supports it.
      if not required_capability then
        return true
      end
      if vim.tbl_get(client.server_capabilities, unpack(required_capability)) then
        return true
      else
        if client.dynamic_capabilities:supports_registration(method) then
          return client.dynamic_capabilities:supports(method, opts)
        end
        return false
      end
    end

    if log.trace() then
      log.trace(log_prefix, 'initialize_params', initialize_params)
    end
    rpc.request('initialize', initialize_params, function(init_err, result)
      assert(not init_err, tostring(init_err))
      assert(result, 'server sent empty result')
      rpc.notify('initialized', vim.empty_dict())
      client.initialized = true
      uninitialized_clients[client_id] = nil
      client.workspace_folders = workspace_folders

      -- These are the cleaned up capabilities we use for dynamically deciding
      -- when to send certain events to clients.
      client.server_capabilities =
        assert(result.capabilities, "initialize result doesn't contain capabilities")
      client.server_capabilities = assert(protocol.resolve_capabilities(client.server_capabilities))

      if client.server_capabilities.positionEncoding then
        client.offset_encoding = client.server_capabilities.positionEncoding
      end

      if next(config.settings) then
        client.notify(ms.workspace_didChangeConfiguration, { settings = config.settings })
      end

      if config.on_init then
        local status, err = pcall(config.on_init, client, result)
        if not status then
          write_error(lsp.client_errors.ON_INIT_CALLBACK_ERROR, err)
        end
      end
      if log.info() then
        log.info(
          log_prefix,
          'server_capabilities',
          { server_capabilities = client.server_capabilities }
        )
      end

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

  ---@nodoc
  --- Sends a request to the server.
  ---
  --- This is a thin wrapper around {client.rpc.request} with some additional
  --- checks for capabilities and handler availability.
  ---
  ---@param method string LSP method name.
  ---@param params table|nil LSP request params.
  ---@param handler lsp.Handler|nil Response |lsp-handler| for this method.
  ---@param bufnr integer Buffer handle (0 for current).
  ---@return boolean status, integer|nil request_id {status} is a bool indicating
  ---whether the request was successful. If it is `false`, then it will
  ---always be `false` (the client has shutdown). If it was
  ---successful, then it will return {request_id} as the
  ---second result. You can use this with `client.cancel_request(request_id)`
  ---to cancel the-request.
  ---@see |vim.lsp.buf_request_all()|
  function client.request(method, params, handler, bufnr)
    if not handler then
      handler = assert(
        resolve_handler(method),
        string.format('not found: %q request handler for client %q.', method, client.name)
      )
    end
    -- Ensure pending didChange notifications are sent so that the server doesn't operate on a stale state
    changetracking.flush(client, bufnr)
    local version = util.buf_versions[bufnr]
    bufnr = resolve_bufnr(bufnr)
    if log.debug() then
      log.debug(log_prefix, 'client.request', client_id, method, params, handler, bufnr)
    end
    local success, request_id = rpc.request(method, params, function(err, result)
      local context = {
        method = method,
        client_id = client_id,
        bufnr = bufnr,
        params = params,
        version = version,
      }
      handler(err, result, context)
    end, function(request_id)
      local request = client.requests[request_id]
      request.type = 'complete'
      nvim_exec_autocmds('LspRequest', {
        buffer = api.nvim_buf_is_valid(bufnr) and bufnr or nil,
        modeline = false,
        data = { client_id = client_id, request_id = request_id, request = request },
      })
      client.requests[request_id] = nil
    end)

    if success and request_id then
      local request = { type = 'pending', bufnr = bufnr, method = method }
      client.requests[request_id] = request
      nvim_exec_autocmds('LspRequest', {
        buffer = bufnr,
        modeline = false,
        data = { client_id = client_id, request_id = request_id, request = request },
      })
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
  ---@param timeout_ms (integer|nil) Maximum time in milliseconds to wait for
  ---                               a result. Defaults to 1000
  ---@param bufnr (integer) Buffer handle (0 for current).
  ---@return {err: lsp.ResponseError|nil, result:any}|nil, string|nil err # a dictionary, where
  --- `err` and `result` come from the |lsp-handler|.
  --- On timeout, cancel or error, returns `(nil, err)` where `err` is a
  --- string describing the failure reason. If the request was unsuccessful
  --- returns `nil`.
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
      if request_id then
        client.cancel_request(request_id)
      end
      return nil, wait_result_reason[reason]
    end
    return request_result
  end

  ---@nodoc
  --- Sends a notification to an LSP server.
  ---
  ---@param method string LSP method name.
  ---@param params table|nil LSP request params.
  ---@return boolean status true if the notification was successful.
  ---If it is false, then it will always be false
  ---(the client has shutdown).
  function client.notify(method, params)
    if method ~= ms.textDocument_didChange then
      changetracking.flush(client)
    end

    local client_active = rpc.notify(method, params)

    if client_active then
      vim.schedule(function()
        nvim_exec_autocmds('LspNotify', {
          modeline = false,
          data = {
            client_id = client.id,
            method = method,
            params = params,
          },
        })
      end)
    end

    return client_active
  end

  ---@nodoc
  --- Cancels a request with a given request id.
  ---
  ---@param id (integer) id of request to cancel
  ---@return boolean status true if notification was successful. false otherwise
  ---@see |vim.lsp.client.notify()|
  function client.cancel_request(id)
    validate({ id = { id, 'n' } })
    local request = client.requests[id]
    if request and request.type == 'pending' then
      request.type = 'cancel'
      nvim_exec_autocmds('LspRequest', {
        buffer = request.bufnr,
        modeline = false,
        data = { client_id = client_id, request_id = id, request = request },
      })
    end
    return rpc.notify(ms.dollar_cancelRequest, { id = id })
  end

  -- Track this so that we can escalate automatically if we've already tried a
  -- graceful shutdown
  local graceful_shutdown_failed = false

  ---@nodoc
  --- Stops a client, optionally with force.
  ---
  ---By default, it will just ask the - server to shutdown without force. If
  --- you request to stop a client which has previously been requested to
  --- shutdown, it will automatically escalate and force shutdown.
  ---
  ---@param force boolean|nil
  function client.stop(force)
    if rpc.is_closing() then
      return
    end
    if force or not client.initialized or graceful_shutdown_failed then
      rpc.terminate()
      return
    end
    -- Sending a signal after a process has exited is acceptable.
    rpc.request(ms.shutdown, nil, function(err, _)
      if err == nil then
        rpc.notify(ms.exit)
      else
        -- If there was an error in the shutdown request, then term to be safe.
        rpc.terminate()
        graceful_shutdown_failed = true
      end
    end)
  end

  ---@private
  --- Checks whether a client is stopped.
  ---
  ---@return boolean # true if client is stopped or in the process of being
  ---stopped; false otherwise
  function client.is_stopped()
    return rpc.is_closing()
  end

  ---@private
  --- Execute a lsp command, either via client command function (if available)
  --- or via workspace/executeCommand (if supported by the server)
  ---
  ---@param command lsp.Command
  ---@param context? {bufnr: integer}
  ---@param handler? lsp.Handler only called if a server command
  function client._exec_cmd(command, context, handler)
    context = vim.deepcopy(context or {}, true) --[[@as lsp.HandlerContext]]
    context.bufnr = context.bufnr or api.nvim_get_current_buf()
    context.client_id = client.id
    local cmdname = command.command
    local fn = client.commands[cmdname] or lsp.commands[cmdname]
    if fn then
      fn(command, context)
      return
    end

    local command_provider = client.server_capabilities.executeCommandProvider
    local commands = type(command_provider) == 'table' and command_provider.commands or {}
    if not vim.list_contains(commands, cmdname) then
      vim.notify_once(
        string.format(
          'Language server `%s` does not support command `%s`. This command may require a client extension.',
          client.name,
          cmdname
        ),
        vim.log.levels.WARN
      )
      return
    end
    -- Not using command directly to exclude extra properties,
    -- see https://github.com/python-lsp/python-lsp-server/issues/146
    local params = {
      command = command.command,
      arguments = command.arguments,
    }
    client.request(ms.workspace_executeCommand, params, handler, context.bufnr)
  end

  ---@private
  --- Runs the on_attach function from the client's config if it was defined.
  ---@param bufnr integer Buffer number
  function client._on_attach(bufnr)
    text_document_did_open_handler(bufnr, client)

    lsp._set_defaults(client, bufnr)

    nvim_exec_autocmds('LspAttach', {
      buffer = bufnr,
      modeline = false,
      data = { client_id = client.id },
    })

    if config.on_attach then
      local status, err = pcall(config.on_attach, client, bufnr)
      if not status then
        write_error(lsp.client_errors.ON_ATTACH_ERROR, err)
      end
    end

    -- schedule the initialization of semantic tokens to give the above
    -- on_attach and LspAttach callbacks the ability to schedule wrap the
    -- opt-out (deleting the semanticTokensProvider from capabilities)
    vim.schedule(function()
      if vim.tbl_get(client.server_capabilities, 'semanticTokensProvider', 'full') then
        lsp.semantic_tokens.start(bufnr, client.id)
      end
    end)

    client.attached_buffers[bufnr] = true
  end

  initialize()

  return client_id
end

--- Notify all attached clients that a buffer has changed.
---@param _ integer
---@param bufnr integer
---@param changedtick integer
---@param firstline integer
---@param lastline integer
---@param new_lastline integer
---@return true?
local function text_document_did_change_handler(
  _,
  bufnr,
  changedtick,
  firstline,
  lastline,
  new_lastline
)
  -- Detach (nvim_buf_attach) via returning True to on_lines if no clients are attached
  if tbl_isempty(all_buffer_active_clients[bufnr] or {}) then
    return true
  end
  util.buf_versions[bufnr] = changedtick
  changetracking.send_changes(bufnr, firstline, lastline, new_lastline)
end

---Buffer lifecycle handler for textDocument/didSave
--- @param bufnr integer
local function text_document_did_save_handler(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local text = once(lsp._buf_get_full_text)
  for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
    local name = api.nvim_buf_get_name(bufnr)
    local old_name = changetracking._get_and_set_name(client, bufnr, name)
    if old_name and name ~= old_name then
      client.notify(ms.textDocument_didClose, {
        textDocument = {
          uri = vim.uri_from_fname(old_name),
        },
      })
      client.notify(ms.textDocument_didOpen, {
        textDocument = {
          version = 0,
          uri = uri,
          languageId = client.config.get_language_id(bufnr, vim.bo[bufnr].filetype),
          text = lsp._buf_get_full_text(bufnr),
        },
      })
      util.buf_versions[bufnr] = 0
    end
    local save_capability = vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'save')
    if save_capability then
      local included_text --- @type string?
      if type(save_capability) == 'table' and save_capability.includeText then
        included_text = text(bufnr)
      end
      client.notify(ms.textDocument_didSave, {
        textDocument = {
          uri = uri,
        },
        text = included_text,
      })
    end
  end
end

--- Implements the `textDocument/did…` notifications required to track a buffer
--- for any language server.
---
--- Without calling this, the server won't be notified of changes to a buffer.
---
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id (integer) Client id
---@return boolean success `true` if client was attached successfully; `false` otherwise
function lsp.buf_attach_client(bufnr, client_id)
  validate({
    bufnr = { bufnr, 'n', true },
    client_id = { client_id, 'n' },
  })
  bufnr = resolve_bufnr(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then
    if log.warn() then
      log.warn(string.format('buf_attach_client called on unloaded buffer (id: %d): ', bufnr))
    end
    return false
  end
  local buffer_client_ids = all_buffer_active_clients[bufnr]
  -- This is our first time attaching to this buffer.
  if not buffer_client_ids then
    buffer_client_ids = {}
    all_buffer_active_clients[bufnr] = buffer_client_ids

    local uri = vim.uri_from_bufnr(bufnr)
    local augroup = ('lsp_c_%d_b_%d_save'):format(client_id, bufnr)
    local group = api.nvim_create_augroup(augroup, { clear = true })
    api.nvim_create_autocmd('BufWritePre', {
      group = group,
      buffer = bufnr,
      desc = 'vim.lsp: textDocument/willSave',
      callback = function(ctx)
        for _, client in ipairs(lsp.get_clients({ bufnr = ctx.buf })) do
          local params = {
            textDocument = {
              uri = uri,
            },
            reason = protocol.TextDocumentSaveReason.Manual,
          }
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'willSave') then
            client.notify(ms.textDocument_willSave, params)
          end
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'willSaveWaitUntil') then
            local result, err =
              client.request_sync(ms.textDocument_willSaveWaitUntil, params, 1000, ctx.buf)
            if result and result.result then
              util.apply_text_edits(result.result, ctx.buf, client.offset_encoding)
            elseif err then
              log.error(vim.inspect(err))
            end
          end
        end
      end,
    })
    api.nvim_create_autocmd('BufWritePost', {
      group = group,
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
        for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
          changetracking.reset_buf(client, bufnr)
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
            client.notify(ms.textDocument_didClose, params)
          end
          text_document_did_open_handler(bufnr, client)
        end
      end,
      on_detach = function()
        local params = { textDocument = { uri = uri } }
        for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
          changetracking.reset_buf(client, bufnr)
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
            client.notify(ms.textDocument_didClose, params)
          end
          client.attached_buffers[bufnr] = nil
        end
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
    return true
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
---@param bufnr integer Buffer handle, or 0 for current
---@param client_id integer Client id
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
        bufnr,
        client_id
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
    client.notify(ms.textDocument_didClose, params)
  end

  client.attached_buffers[bufnr] = nil
  util.buf_versions[bufnr] = nil

  all_buffer_active_clients[bufnr][client_id] = nil
  if #vim.tbl_keys(all_buffer_active_clients[bufnr]) == 0 then
    all_buffer_active_clients[bufnr] = nil
  end

  local namespace = lsp.diagnostic.get_namespace(client_id)
  vim.diagnostic.reset(namespace, bufnr)
end

--- Checks if a buffer is attached for a particular client.
---
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id (integer) the client id
function lsp.buf_is_attached(bufnr, client_id)
  return (all_buffer_active_clients[resolve_bufnr(bufnr)] or {})[client_id] == true
end

--- Gets a client by id, or nil if the id is invalid.
--- The returned client may not yet be fully initialized.
---
---@param client_id integer client id
---
---@return (nil|lsp.Client) client rpc object
function lsp.get_client_by_id(client_id)
  return active_clients[client_id] or uninitialized_clients[client_id]
end

--- Returns list of buffers attached to client_id.
---
---@param client_id integer client id
---@return integer[] buffers list of buffer ids
function lsp.get_buffers_by_client_id(client_id)
  local client = lsp.get_client_by_id(client_id)
  return client and vim.tbl_keys(client.attached_buffers) or {}
end

--- Stops a client(s).
---
--- You can also use the `stop()` function on a |vim.lsp.client| object.
--- To stop all clients:
---
--- ```lua
--- vim.lsp.stop_client(vim.lsp.get_clients())
--- ```
---
--- By default asks the server to shutdown, unless stop was requested
--- already for this client, then force-shutdown is attempted.
---
---@param client_id integer|table id or |vim.lsp.client| object, or list thereof
---@param force boolean|nil shutdown forcefully
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

---@class vim.lsp.get_clients.filter
---@field id integer|nil Match clients by id
---@field bufnr integer|nil match clients attached to the given buffer
---@field name string|nil match clients by name
---@field method string|nil match client by supported method name

--- Get active clients.
---
---@param filter vim.lsp.get_clients.filter|nil (table|nil) A table with
---              key-value pairs used to filter the returned clients.
---              The available keys are:
---               - id (number): Only return clients with the given id
---               - bufnr (number): Only return clients attached to this buffer
---               - name (string): Only return clients with the given name
---               - method (string): Only return clients supporting the given method
---@return lsp.Client[]: List of |vim.lsp.client| objects
function lsp.get_clients(filter)
  validate({ filter = { filter, 't', true } })

  filter = filter or {}

  local clients = {} --- @type lsp.Client[]

  local t = filter.bufnr and (all_buffer_active_clients[resolve_bufnr(filter.bufnr)] or {})
    or active_clients
  for client_id in pairs(t) do
    local client = active_clients[client_id]
    if
      client
      and (filter.id == nil or client.id == filter.id)
      and (filter.name == nil or client.name == filter.name)
      and (filter.method == nil or client.supports_method(filter.method, { bufnr = filter.bufnr }))
    then
      clients[#clients + 1] = client
    end
  end
  return clients
end

---@private
---@deprecated
function lsp.get_active_clients(filter)
  vim.deprecate('vim.lsp.get_active_clients()', 'vim.lsp.get_clients()', '0.12')
  return lsp.get_clients(filter)
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

    local timeouts = {} --- @type table<integer,integer>
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

---@private
--- Sends an async request for all active clients attached to the
--- buffer.
---
---@param bufnr (integer) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params table|nil Parameters to send to the server
---@param handler? lsp.Handler See |lsp-handler|
---       If nil, follows resolution strategy defined in |lsp-handler-configuration|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
---cancel all the requests. You could instead
---iterate all clients and call their `cancel_request()` methods.
function lsp.buf_request(bufnr, method, params, handler)
  validate({
    bufnr = { bufnr, 'n', true },
    method = { method, 's' },
    handler = { handler, 'f', true },
  })

  bufnr = resolve_bufnr(bufnr)
  local method_supported = false
  local clients = lsp.get_clients({ bufnr = bufnr })
  local client_request_ids = {} --- @type table<integer,integer>
  for _, client in ipairs(clients) do
    if client.supports_method(method, { bufnr = bufnr }) then
      method_supported = true

      local request_success, request_id = client.request(method, params, handler, bufnr)
      -- This could only fail if the client shut down in the time since we looked
      -- it up and we did the request, which should be rare.
      if request_success then
        client_request_ids[client.id] = request_id
      end
    end
  end

  -- if has client but no clients support the given method, notify the user
  if next(clients) and not method_supported then
    vim.notify(lsp._unsupported_method(method), vim.log.levels.ERROR)
    nvim_command('redraw')
    return {}, function() end
  end

  local function _cancel_all_requests()
    for client_id, request_id in pairs(client_request_ids) do
      local client = active_clients[client_id]
      client.cancel_request(request_id)
    end
  end

  return client_request_ids, _cancel_all_requests
end

--- Sends an async request for all active clients attached to the buffer and executes the `handler`
--- callback with the combined result.
---
---@param bufnr (integer) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param handler fun(results: table<integer, {error: lsp.ResponseError, result: any}>) (function)
--- Handler called after all requests are completed. Server results are passed as
--- a `client_id:result` map.
---@return function cancel Function that cancels all requests.
function lsp.buf_request_all(bufnr, method, params, handler)
  local results = {} --- @type table<integer,{error:string, result:any}>
  local result_count = 0
  local expected_result_count = 0

  local set_expected_result_count = once(function()
    for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
      if client.supports_method(method, { bufnr = bufnr }) then
        expected_result_count = expected_result_count + 1
      end
    end
  end)

  local function _sync_handler(err, result, ctx)
    results[ctx.client_id] = { error = err, result = result }
    result_count = result_count + 1
    set_expected_result_count()

    if result_count >= expected_result_count then
      handler(results)
    end
  end

  local _, cancel = lsp.buf_request(bufnr, method, params, _sync_handler)

  return cancel
end

--- Sends a request to all server and waits for the response of all of them.
---
--- Calls |vim.lsp.buf_request_all()| but blocks Nvim while awaiting the result.
--- Parameters are the same as |vim.lsp.buf_request_all()| but the result is
--- different. Waits a maximum of {timeout_ms} (default 1000) ms.
---
---@param bufnr (integer) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param timeout_ms (integer|nil) Maximum time in milliseconds to wait for a
---                               result. Defaults to 1000
---
---@return table<integer, {err: lsp.ResponseError, result: any}>|nil (table) result Map of client_id:request_result.
---@return string|nil err On timeout, cancel, or error, `err` is a string describing the failure reason, and `result` is nil.
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
---@param bufnr (integer|nil) The number of the buffer
---@param method (string) Name of the request method
---@param params (any) Arguments to send to the server
---
---@return boolean success true if any client returns true; false otherwise
function lsp.buf_notify(bufnr, method, params)
  validate({
    bufnr = { bufnr, 'n', true },
    method = { method, 's' },
  })
  local resp = false
  for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
    if client.rpc.notify(method, params) then
      resp = true
    end
  end
  return resp
end

--- Implements 'omnifunc' compatible LSP completion.
---
---@see |complete-functions|
---@see |complete-items|
---@see |CompleteDone|
---
---@param findstart integer 0 or 1, decides behavior
---@param base integer findstart=0, text to match against
---
---@return integer|table Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function lsp.omnifunc(findstart, base)
  if log.debug() then
    log.debug('omnifunc.findstart', { findstart = findstart, base = base })
  end
  return vim.lsp._completion.omnifunc(findstart, base)
end

--- Provides an interface between the built-in client and a `formatexpr` function.
---
--- Currently only supports a single client. This can be set via
--- `setlocal formatexpr=v:lua.vim.lsp.formatexpr()` but will typically or in `on_attach`
--- via ``vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr(#{timeout_ms:250})'``.
---
---@param opts table options for customizing the formatting expression which takes the
---                   following optional keys:
---                   * timeout_ms (default 500ms). The timeout period for the formatting request.
function lsp.formatexpr(opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 500

  if vim.list_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
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
  for _, client in pairs(lsp.get_clients({ bufnr = bufnr })) do
    if client.supports_method(ms.textDocument_rangeFormatting) then
      local params = util.make_formatting_params()
      local end_line = vim.fn.getline(end_lnum) --[[@as string]]
      local end_col = util._str_utfindex_enc(end_line, nil, client.offset_encoding)
      --- @cast params +lsp.DocumentRangeFormattingParams
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
        client.request_sync(ms.textDocument_rangeFormatting, params, timeout_ms, bufnr)
      if response and response.result then
        lsp.util.apply_text_edits(response.result, 0, client.offset_encoding)
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
---@param pattern string Pattern used to find a workspace symbol
---@param flags string See |tag-function|
---
---@return table[] tags A list of matching tags
function lsp.tagfunc(pattern, flags)
  return vim.lsp.tagfunc(pattern, flags)
end

---Checks whether a client is stopped.
---
---@param client_id (integer)
---@return boolean stopped true if client is stopped, false otherwise.
function lsp.client_is_stopped(client_id)
  assert(client_id, 'missing client_id param')
  return active_clients[client_id] == nil and not uninitialized_clients[client_id]
end

--- Gets a map of client_id:client pairs for the given buffer, where each value
--- is a |vim.lsp.client| object.
---
---@param bufnr (integer|nil): Buffer handle, or 0 for current
---@return table result is table of (client_id, client) pairs
---@deprecated Use |vim.lsp.get_clients()| instead.
function lsp.buf_get_clients(bufnr)
  vim.deprecate('vim.lsp.buf_get_clients()', 'vim.lsp.get_clients()', '0.12')
  local result = {} --- @type table<integer,lsp.Client>
  for _, client in ipairs(lsp.get_clients({ bufnr = resolve_bufnr(bufnr) })) do
    result[client.id] = client
  end
  return result
end

--- Log level dictionary with reverse lookup as well.
---
--- Can be used to lookup the number from the name or the
--- name from the number.
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
--- Level numbers begin with "TRACE" at 0
--- @nodoc
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
---@param level (integer|string) the case insensitive level name or number
function lsp.set_log_level(level)
  if type(level) == 'string' or type(level) == 'number' then
    log.set_level(level)
  else
    error(string.format('Invalid log level: %q', level))
  end
end

--- Gets the path of the logfile used by the LSP client.
---@return string path to log file
function lsp.get_log_path()
  return log.get_filename()
end

---@private
--- Invokes a function for each LSP client attached to a buffer.
---
---@param bufnr integer Buffer number
---@param fn function Function to run on each client attached to buffer
---                   {bufnr}. The function takes the client, client ID, and
---                   buffer number as arguments.
---@deprecated use lsp.get_clients({ bufnr = bufnr }) with regular loop
function lsp.for_each_buffer_client(bufnr, fn)
  vim.deprecate(
    'vim.lsp.for_each_buffer_client()',
    'lsp.get_clients({ bufnr = bufnr }) with regular loop',
    '0.12'
  )
  return for_each_buffer_client(bufnr, fn)
end

--- Function to manage overriding defaults for LSP handlers.
---@param handler (lsp.Handler) See |lsp-handler|
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
--- @param name string
--- @param options table<string,any>
--- @param user_config table<string,any>
function lsp._with_extend(name, options, user_config)
  user_config = user_config or {}

  local resulting_config = {} --- @type table<string,any>
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
--- @type table<string,function>
lsp.commands = setmetatable({}, {
  __newindex = function(tbl, key, value)
    assert(type(key) == 'string', 'The key for commands in `vim.lsp.commands` must be a string')
    assert(type(value) == 'function', 'Command added to `vim.lsp.commands` must be a function')
    rawset(tbl, key, value)
  end,
})

return lsp
