local api = vim.api

---@class vim.lsp.Capability
---@field name string
---@field active table<integer, vim.lsp.Capability?>
---@field bufnr integer
---@field augroup integer
---@field client_state table<integer, table>
local M = {}
M.__index = M

---@generic T : vim.lsp.Capability
---@param self T
---@param bufnr integer
---@return T
function M:new(bufnr)
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
  for client_id, _ in pairs(self.client_state) do
    self:on_detach(client_id)
  end

  api.nvim_del_augroup_by_id(self.augroup)
  self.active[self.bufnr] = nil
end

---@param client_id integer
---@diagnostic disable-next-line: unused-local
function M:on_detach(client_id)
  self.client_state[client_id] = nil
end

return M
