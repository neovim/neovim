local api = vim.api

---@alias vim.lsp.capability.Name
---| 'semantic_tokens'
---| 'folding_range'

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

  api.nvim_create_autocmd('LspDetach', {
    group = self.augroup,
    buffer = bufnr,
    callback = function(args)
      self:on_detach(args.data.client_id)
      if next(self.client_state) == nil then
        self:destroy()
      end
    end,
  })

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

M.all = all_capabilities

return M
