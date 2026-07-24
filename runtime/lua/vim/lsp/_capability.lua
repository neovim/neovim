local api = vim.api
local nvim_on = require('vim._core.util').nvim_on

---@alias vim.lsp.capability.Name
---| 'codelens'
---| 'diagnostics'
---| 'document_color'
---| 'folding_range'
---| 'inlay_hint'
---| 'inline_completion'
---| 'linked_editing_range'
---| 'semantic_tokens'

--- Tracks all supported capabilities, all of which derive from `vim.lsp.Capability`.
--- Returns capability *prototypes*, not their instances.
---@type table<vim.lsp.capability.Name, vim.lsp.Capability>
local all_capabilities = {}

--- Track each capability instance created per buffer
---@type table<integer, vim.lsp.Capability[]> buffer -> list of active capability instances
local buf_capabilities = {}

-- Abstract base class (not instantiable directly).
-- For each buffer that has at least one supported client attached,
-- exactly one instance of each concrete subclass is created.
-- That instance is destroyed once all supporting clients detach from the buffer.
---@class vim.lsp.Capability
---
--- Static field as the identifier of the LSP capability it supports.
---@field name vim.lsp.capability.Name
---
--- Static field records the method this capability requires.
---@field method vim.lsp.protocol.Method.ClientToServer | vim.lsp.protocol.Method.Registration
---
--- Static field for retrieving the instance associated with a specific `bufnr`.
---
--- Index in the form of `bufnr` -> `capability`
---@field active table<integer, vim.lsp.Capability?>
---
--- Buffer number the capability instance is associated with.
---@field bufnr integer
---
--- The augroup owned by this instance, which will be cleared upon destruction.
---@field augroup integer
---
--- Per-client state data, scoped to the lifetime of the attached client.
---@field client_state table<integer, table>
local M = {}
M.__index = M

---@generic T : vim.lsp.Capability
---@param self T
---@param bufnr integer
---@return T
function M:new(bufnr)
  -- `self` in the `new()` function refers to the concrete type (i.e., the metatable).
  -- `Class` may be a subtype of `Capability`, as it supports inheritance.
  ---@type vim.lsp.Capability
  local Class = self
  if M == Class then
    error('Do not instantiate the abstract class')
  elseif all_capabilities[Class.name] and all_capabilities[Class.name] ~= Class then
    error('Duplicated capability name')
  else
    all_capabilities[Class.name] = Class
  end

  ---@type vim.lsp.Capability
  self = setmetatable({}, Class)
  self.bufnr = bufnr
  self.augroup = api.nvim_create_augroup(string.format('nvim.lsp.%s:%s', self.name, bufnr), {
    clear = true,
  })
  self.client_state = {}

  if not buf_capabilities[bufnr] then
    buf_capabilities[bufnr] = {}
  end

  table.insert(buf_capabilities[bufnr], self)

  Class.active[bufnr] = self
  return self
end

function M:destroy()
  -- In case the function is called before all the clients detached.
  for client_id, _ in pairs(self.client_state) do
    self:on_detach(client_id)
  end

  api.nvim_del_augroup_by_id(self.augroup)
  self.active[self.bufnr] = nil

  buf_capabilities[self.bufnr] = vim.tbl_filter(function(cap) ---@param cap vim.lsp.Capability
    return cap ~= self
  end, buf_capabilities[self.bufnr])

  if not next(buf_capabilities[self.bufnr]) then
    buf_capabilities[self.bufnr] = nil
  end
end

--- Callback invoked when an LSP client attaches.
--- Use it to initialize per-client state (empty table, new namespaces, etc.),
--- or issue requests as needed.
---@param client_id integer
function M:on_attach(client_id)
  self.client_state[client_id] = {}
end

--- Callback invoked when an LSP client detaches.
--- Use it to clear per-client state (cached data, extmarks, etc.).
---@param client_id integer
function M:on_detach(client_id)
  self.client_state[client_id] = nil
end

--- Callback invoked when textDocument/didClose is sent for a client.
---@param client_id integer
---@diagnostic disable-next-line: unused-local
function M:on_close(client_id) end

--- Callback invoked when textDocument/didChange or textDocument/didOpen is sent for a client.
---@param client_id integer
---@diagnostic disable-next-line: unused-local
function M:on_change(client_id) end

--- Callback invoked on every redraw.
---@param topline integer
---@param botline integer
---@diagnostic disable-next-line: unused-local
function M:on_win(topline, botline) end

---@param name vim.lsp.capability.Name
local function make_enable_var(name)
  return ('_lsp_enabled_%s'):format(name)
end

--- Optional filters |kwargs|,
---@class vim.lsp.capability.enable.Filter
---@inlinedoc
---
--- Buffer number, or 0 for current buffer, or nil for all.
--- (default: all)
---@field bufnr? integer
---
--- Client ID, or nil for all.
--- (default: all)
---@field client_id? integer

---@param name vim.lsp.capability.Name
---@param enable? boolean
---@param filter? vim.lsp.capability.enable.Filter
function M.enable(name, enable, filter)
  vim.validate('name', name, 'string')
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)

  enable = enable == nil or enable
  filter = filter or {}
  local client_id = filter.client_id
  local bufnr = filter.bufnr and vim._resolve_bufnr(filter.bufnr)

  local var = make_enable_var(name)
  local client = client_id and vim.lsp.get_client_by_id(client_id)
  local Capability = all_capabilities[name]

  if client and bufnr then
    client._buf_enabled_capabilities[bufnr][name] = enable
  elseif client then
    client._enabled_capabilities[name] = enable
  elseif bufnr then
    vim.b[bufnr][var] = enable
  else
    vim.g[var] = enable
  end

  -- Attach or detach the client and its capability
  for _, it_client in ipairs(client_id and { client } or vim.lsp.get_clients()) do
    if it_client:supports_method(Capability.method) then
      local affected_buffers = bufnr and { it_client.attached_buffers[bufnr] and bufnr }
        or vim.tbl_keys(it_client.attached_buffers)

      for _, it_bufnr in ipairs(affected_buffers) do
        if M.is_enabled(name, { bufnr = it_bufnr, client_id = it_client.id }) then
          local capability = Capability.active[it_bufnr] or Capability:new(it_bufnr)
          if not capability.client_state[it_client.id] then
            capability:on_attach(it_client.id)
          end
        else
          local capability = Capability.active[it_bufnr]
          if capability then
            capability:on_detach(it_client.id)
            if not next(capability.client_state) then
              capability:destroy()
            end
          end
        end
      end
    end
  end
end

---@param name vim.lsp.capability.Name
---@param filter? vim.lsp.capability.enable.Filter
---@return boolean
function M.is_enabled(name, filter)
  vim.validate('name', name, 'string')
  vim.validate('filter', filter, 'table', true)

  filter = filter or {}
  local var = make_enable_var(name)
  local enabled_globally = vim.g[var] or false ---@type boolean

  local client_id = filter.client_id
  local client = client_id and vim.lsp.get_client_by_id(client_id)
  local enabled_per_client = client and client._enabled_capabilities[name]

  local buf = filter.bufnr and vim._resolve_bufnr(filter.bufnr)
  local enabled_per_buf = buf and vim.b[buf][var] --[[@as boolean?]]

  if buf and client_id then
    if client and client._buf_enabled_capabilities[buf][name] ~= nil then
      return client._buf_enabled_capabilities[buf][name]
    else
      enabled_per_client = vim.nonnil(enabled_per_client, enabled_globally) --[[@as boolean]]
      enabled_per_buf = vim.nonnil(enabled_per_buf, true) --[[@as boolean]]
      return enabled_per_client and enabled_per_buf
    end
  elseif filter.bufnr then
    return vim.nonnil(enabled_per_buf, enabled_globally) --[[@as boolean]]
  elseif client_id then
    return vim.nonnil(enabled_per_client, enabled_globally) --[[@as boolean]]
  end

  return enabled_globally
end

M.all = all_capabilities

local augroup = api.nvim_create_augroup('nvim.lsp.capability', {
  clear = true,
})

nvim_on('LspNotify', augroup, function(ev)
  local client_id = ev.data.client_id ---@type integer
  local bufnr = ev.buf

  if not buf_capabilities[bufnr] then
    return
  end

  for _, provider in ipairs(buf_capabilities[bufnr]) do
    if provider.client_state[client_id] then
      if ev.data.method == 'textDocument/didClose' then
        provider:on_close(client_id)
      end

      if ev.data.method == 'textDocument/didChange' or ev.data.method == 'textDocument/didOpen' then
        provider:on_change(client_id)
      end
    end
  end
end)

local namespace = api.nvim_create_namespace('nvim.lsp.capability')
api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    if not buf_capabilities[bufnr] then
      return
    end

    for _, provider in ipairs(buf_capabilities[bufnr]) do
      provider:on_win(topline, botline)
    end
  end,
})

return M
