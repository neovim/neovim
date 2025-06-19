local api = vim.api
local lsp = vim.lsp
local util = lsp.util
local method = lsp.protocol.Methods.textDocument_onTypeFormatting

local schedule = vim.schedule
local current_buf = api.nvim_get_current_buf
local mode = api.nvim_get_mode

local type_formatting_ns = api.nvim_create_namespace('nvim.lsp.on_type_formatting')

local M = {}

--- @alias vim.lsp.on_type_formatting.BufTriggers table<string, table<integer, vim.lsp.Client>>

--- A map from bufnr -> trigger character -> client ID -> client
--- @type table<integer, vim.lsp.on_type_formatting.BufTriggers>
local buf_handles = {}

---@param bufnr integer
---@return string
local function get_buf_augroup(bufnr)
  return string.format('nvim.lsp.on_type_formatting.buf:%d', bufnr)
end

---@param client_id integer
---@return string
local function get_client_augroup(client_id)
  return string.format('nvim.lsp.on_type_formatting.client:%d', client_id)
end

--- |lsp-handler| for the `textDocument/onTypeFormatting` method.
---
--- @param err? lsp.ResponseError
--- @param result? lsp.TextEdit[]
--- @param ctx lsp.HandlerContext
local function on_type_formatting(err, result, ctx)
  if err then
    lsp.log.error('on_type_formatting', err)
    return
  end

  local bufnr = assert(ctx.bufnr)

  if not result or not api.nvim_buf_is_loaded(bufnr) or util.buf_versions[bufnr] ~= ctx.version then
    return
  end

  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

---@param bufnr integer
---@param typed string
---@param triggered_clients vim.lsp.Client[]
---@param idx integer?
---@param client vim.lsp.Client?
local function format_iter(bufnr, typed, triggered_clients, idx, client)
  if not idx or not client then
    return
  end
  ---@type lsp.DocumentOnTypeFormattingParams
  local params = vim.tbl_extend(
    'keep',
    util.make_formatting_params(),
    util.make_position_params(0, client.offset_encoding),
    { ch = typed }
  )
  client:request(method, params, function(...)
    on_type_formatting(...)
    format_iter(bufnr, typed, triggered_clients, next(triggered_clients, idx))
  end, bufnr)
end

---@param typed string
local function on_key_cb(_, typed)
  if mode().mode ~= 'i' then
    return
  end

  local bufnr = current_buf()

  local buf_handle = buf_handles[bufnr]
  if not buf_handle then
    return
  end

  -- LSP expects '\n' for formatting on newline
  if typed == '\r' then
    typed = '\n'
  end

  local triggered_clients = buf_handle[typed]
  if not triggered_clients then
    return
  end

  -- Schedule the formatting to occur *after* the LSP is aware of the inserted character
  schedule(function()
    format_iter(bufnr, typed, triggered_clients, next(triggered_clients))
  end)
end

--- @param client vim.lsp.Client
--- @param bufnr integer
local function detach_otf(client, bufnr)
  local buf_handle = buf_handles[bufnr]
  if not buf_handle then
    return
  end

  local client_id = client.id

  -- Remove this client from its associated trigger characters
  for i, trigger in pairs(buf_handle) do
    trigger[client_id] = nil

    -- Remove the trigger character if we detached its last client.
    if not next(trigger) then
      buf_handle[i] = nil
    end
  end

  -- Remove the buf handle and its autocmds if we removed its last client.
  if not next(buf_handle) then
    buf_handles[bufnr] = nil
    api.nvim_clear_autocmds({ group = get_buf_augroup(bufnr) })

    -- Remove the on_key callback if we removed the last buf handle.
    if not next(buf_handles) then
      vim.on_key(nil, type_formatting_ns)
    end
  end
end

--- @param client vim.lsp.Client
--- @param bufnr integer
local function attach_otf(client, bufnr)
  local client_id = client.id
  ---@type lsp.DocumentOnTypeFormattingOptions?
  local otf_capabilities =
    vim.tbl_get(client.server_capabilities, 'documentOnTypeFormattingProvider')
  if not otf_capabilities then
    vim.notify(
      string.format(
        'Client with id %d does not support textDocument/onTypeFormatting requests',
        client_id
      ),
      vim.log.levels.WARN
    )
    return
  end

  -- Set on_key callback, clearing first in case it was already registered.
  vim.on_key(nil, type_formatting_ns)
  vim.on_key(on_key_cb, type_formatting_ns)

  -- Populate the buf handle data. We cannot use defaulttable here because then an empty table will
  -- be created for each unique keystroke
  local buf_handle = buf_handles[bufnr] or {}
  buf_handles[bufnr] = buf_handle

  local trigger = buf_handle[otf_capabilities.firstTriggerCharacter] or {}
  buf_handle[otf_capabilities.firstTriggerCharacter] = trigger
  trigger[client_id] = client

  for _, char in ipairs(otf_capabilities.moreTriggerCharacter or {}) do
    trigger = buf_handle[char] or {}
    buf_handle[char] = trigger
    trigger[client_id] = client
  end

  local group = api.nvim_create_augroup(get_buf_augroup(bufnr), { clear = true })
  api.nvim_create_autocmd('LspDetach', {
    buffer = bufnr,
    desc = 'Detach on-type formatting module when the client detaches',
    group = group,
    callback = function(args)
      detach_otf(args.data.client_id, bufnr)
    end,
  })
end

---@param enable boolean
---@param client vim.lsp.Client
local function toggle_otf_for_client(enable, client)
  local handler = enable and attach_otf or detach_otf
  local client_id = client.id

  -- Toggle for buffers already attached.
  for bufnr, _ in pairs(client.attached_buffers) do
    handler(client, bufnr)
  end

  -- If disabling, only clear the attachment autocmd. If enabling, create it.
  local group = api.nvim_create_augroup(get_client_augroup(client_id), { clear = true })
  if enable then
    api.nvim_create_autocmd('LspAttach', {
      group = group,
      desc = 'Enable on-type formatting for all buffers this client attaches to',
      callback = function(ev)
        if ev.data.client_id ~= client_id then
          return
        end

        attach_otf(client, ev.buf)
      end,
    })
  end
end

---@param enable boolean
local function toggle_otf_globally(enable)
  -- Toggle for clients that have already attached.
  local clients = lsp.get_clients({ method = method })
  for _, client in ipairs(clients) do
    toggle_otf_for_client(enable, client)
  end

  -- If disabling, only clear the attachment autocmd. If enabling, create it.
  local group = api.nvim_create_augroup('nvim.lsp.on_type_formatting', { clear = true })
  if enable then
    api.nvim_create_autocmd('LspAttach', {
      group = group,
      desc = 'Enable on-type formatting for all clients',
      callback = function(ev)
        local client = assert(lsp.get_client_by_id(ev.data.client_id))
        attach_otf(client, ev.buf)
      end,
    })
  end
end

--- Optional filters |kwargs|:
--- @inlinedoc
--- @class vim.lsp.on_type_formatting.enable.Filter
--- @field client_id integer? Client ID, or `nil` for all.

--- Enables/disables on-type formatting globally or for the given language client. The following is
--- a practical usage example:
---
--- ```lua
--- vim.lsp.start({
---   name = 'ts_ls',
---   cmd = '…',
---   on_attach = function(client)
---     vim.lsp.on_type_formatting.enable(true, { client_id = client.id })
---   end,
--- })
--- ```
---
--- @param enable boolean True to enable, false to disable.
--- @param filter vim.lsp.on_type_formatting.enable.Filter?
function M.enable(enable, filter)
  vim.validate('enable', enable, 'boolean')
  vim.validate('filter', filter, 'table', true)

  filter = filter or {}

  if filter.client_id then
    local client =
      assert(lsp.get_client_by_id(filter.client_id), 'Client not found for id ' .. filter.client_id)
    toggle_otf_for_client(enable, client)
  else
    toggle_otf_globally(enable)
  end
end

return M
