local glob = vim.glob

--- @class lsp.DynamicCapabilities
--- @field capabilities table<string, lsp.Registration[]>
--- @field client_id number
local M = {}

--- @param client_id number
function M.new(client_id)
  return setmetatable({
    capabilities = {},
    client_id = client_id,
  }, { __index = M })
end

function M:supports_registration(method)
  local client = vim.lsp.get_client_by_id(self.client_id)
  if not client then
    return false
  end
  local capability = vim.tbl_get(client.config.capabilities, unpack(vim.split(method, '/')))
  return type(capability) == 'table' and capability.dynamicRegistration
end

--- @param registrations lsp.Registration[]
--- @private
function M:register(registrations)
  -- remove duplicates
  self:unregister(registrations)
  for _, reg in ipairs(registrations) do
    local method = reg.method
    if not self.capabilities[method] then
      self.capabilities[method] = {}
    end
    table.insert(self.capabilities[method], reg)
  end
end

--- @param unregisterations lsp.Unregistration[]
--- @private
function M:unregister(unregisterations)
  for _, unreg in ipairs(unregisterations) do
    local method = unreg.method
    if not self.capabilities[method] then
      return
    end
    local id = unreg.id
    for i, reg in ipairs(self.capabilities[method]) do
      if reg.id == id then
        table.remove(self.capabilities[method], i)
        break
      end
    end
  end
end

--- @param method string
--- @param opts? {bufnr: integer?}
--- @return lsp.Registration? (table|nil) the registration if found
--- @private
function M:get(method, opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  for _, reg in ipairs(self.capabilities[method] or {}) do
    if not reg.registerOptions then
      return reg
    end
    local documentSelector = reg.registerOptions.documentSelector
    if not documentSelector then
      return reg
    end
    if self:match(opts.bufnr, documentSelector) then
      return reg
    end
  end
end

--- @param method string
--- @param opts? {bufnr: integer?}
--- @private
function M:supports(method, opts)
  return self:get(method, opts) ~= nil
end

--- @param bufnr number
--- @param documentSelector lsp.DocumentSelector
--- @private
function M:match(bufnr, documentSelector)
  local client = vim.lsp.get_client_by_id(self.client_id)
  if not client then
    return false
  end
  local language = client.config.get_language_id(bufnr, vim.bo[bufnr].filetype)
  local uri = vim.uri_from_bufnr(bufnr)
  local fname = vim.uri_to_fname(uri)
  for _, filter in ipairs(documentSelector) do
    local matches = true
    if filter.language and language ~= filter.language then
      matches = false
    end
    if matches and filter.scheme and not vim.startswith(uri, filter.scheme .. ':') then
      matches = false
    end
    if matches and filter.pattern and not glob.to_lpeg(filter.pattern):match(fname) then
      matches = false
    end
    if matches then
      return true
    end
  end
end

return M
