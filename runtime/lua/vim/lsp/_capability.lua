local api = vim.api

--- `vim.lsp.Capability` is expected to be created one-to-one with a buffer
--- when there is at least one supported client attached to that buffer,
--- and will be destroyed when all supporting clients are detached.
---@class vim.lsp.Capability
---
--- Static field for retrieving the instance associated with a specific `bufnr`.
---
--- Index inthe form of `bufnr` -> `capability`
---@field active table<integer, vim.lsp.Capability?>
---
--- The LSP feature it supports.
---@field name string
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
  assert(Class.name and Class.active, 'Do not instantiate the abstract class')

  ---@type vim.lsp.Capability
  self = setmetatable({}, Class)
  self.bufnr = bufnr
  self.augroup = api.nvim_create_augroup(
    string.format('nvim.lsp.%s:%s', self.name:gsub('%s+', '_'):lower(), bufnr),
    { clear = true }
  )
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

---@param client_id integer
function M:on_detach(client_id)
  self.client_state[client_id] = nil
end

return M
