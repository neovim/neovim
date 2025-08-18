local api = vim.api

---@alias vim.lsp.capability.Name
---| 'semantic_tokens'
---| 'folding_range'
---| 'linked_editing_range'

--- Tracks all supported capabilities, all of which derive from `vim.lsp.Capability`.
--- Returns capability *prototypes*, not their instances.
---@type table<vim.lsp.capability.Name, vim.lsp.Capability>
local all_capabilities = {}

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
---@field method vim.lsp.protocol.Method.ClientToServer
---
--- Static field for retrieving the instance associated with a specific `bufnr`.
---
--- Index in the form of `bufnr` -> `capability`
---@field active table<integer, vim.lsp.Capability?>
---
--- Buffer number it associated with.
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
  local bufnr = filter.bufnr and vim._resolve_bufnr(filter.bufnr)
  local client_id = filter.client_id
  assert(not (bufnr and client_id), '`bufnr` and `client_id` are mutually exclusive.')

  local var = make_enable_var(name)
  local client = client_id and vim.lsp.get_client_by_id(client_id)

  -- Attach or detach the client and its capability
  -- based on the user’s latest marker value.
  for _, it_client in ipairs(client and { client } or vim.lsp.get_clients()) do
    for _, it_bufnr in
      ipairs(
        bufnr and { it_client.attached_buffers[bufnr] and bufnr }
          or vim.lsp.get_buffers_by_client_id(it_client.id)
      )
    do
      if enable ~= M.is_enabled(name, { bufnr = it_bufnr, client_id = it_client.id }) then
        local Capability = all_capabilities[name]

        if enable then
          if it_client:supports_method(Capability.method) then
            local capability = Capability.active[bufnr] or Capability:new(it_bufnr)
            if not capability.client_state[it_client.id] then
              capability:on_attach(it_client.id)
            end
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

  -- Updates the marker value.
  -- If local marker matches the global marker, set it to nil
  -- so that `is_enable` falls back to the global marker.
  if client then
    if enable == vim.g[var] then
      client._enabled_capabilities[name] = nil
    else
      client._enabled_capabilities[name] = enable
    end
  elseif bufnr then
    if enable == vim.g[var] then
      vim.b[bufnr][var] = nil
    else
      vim.b[bufnr][var] = enable
    end
  else
    vim.g[var] = enable
    for _, it_bufnr in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(it_bufnr) and vim.b[it_bufnr][var] == enable then
        vim.b[it_bufnr][var] = nil
      end
    end
    for _, it_client in ipairs(vim.lsp.get_clients()) do
      if it_client._enabled_capabilities[name] == enable then
        it_client._enabled_capabilities[name] = nil
      end
    end
  end
end

---@param name vim.lsp.capability.Name
---@param filter? vim.lsp.capability.enable.Filter
function M.is_enabled(name, filter)
  vim.validate('name', name, 'string')
  vim.validate('filter', filter, 'table', true)

  filter = filter or {}
  local bufnr = filter.bufnr and vim._resolve_bufnr(filter.bufnr)
  local client_id = filter.client_id

  local var = make_enable_var(name)
  local client = client_id and vim.lsp.get_client_by_id(client_id)

  -- As a fallback when not explicitly enabled or disabled:
  -- Clients are treated as "enabled" since their capabilities can control behavior.
  -- Buffers are treated as "disabled" to allow users to enable them as needed.
  return vim.F.if_nil(client and client._enabled_capabilities[name], vim.g[var], true)
    and vim.F.if_nil(bufnr and vim.b[bufnr][var], vim.g[var], false)
end

M.all = all_capabilities

return M
