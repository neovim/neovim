local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local M = {}

local Capability = require('vim.lsp._capability')

---@class (private) vim.lsp.codelens.ClientState
---@field row_lenses table<integer, lsp.CodeLens[]?> row -> lens
---@field namespace integer

---@class (private) vim.lsp.codelens.Provider : vim.lsp.Capability
---@field active table<integer, vim.lsp.codelens.Provider?>
---
--- `TextDocument` version current state corresponds to.
---@field version? integer
---
--- Last version of codelens applied to this line.
---
--- Index In the form of row -> true?
---@field row_version table<integer, integer?>
---
--- Index In the form of client_id -> client_state
---@field client_state? table<integer, vim.lsp.codelens.ClientState?>
---
--- Timer for debouncing automatic requests.
---
---@field timer? uv.uv_timer_t
local Provider = {
  name = 'codelens',
  method = 'textDocument/codeLens',
  active = {},
}
Provider.__index = Provider
setmetatable(Provider, Capability)
Capability.all[Provider.name] = Provider

---@package
---@param bufnr integer
---@return vim.lsp.codelens.Provider
function Provider:new(bufnr)
  ---@type vim.lsp.codelens.Provider
  self = Capability.new(self, bufnr)
  self.client_state = {}
  self.row_version = {}

  api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      local provider = Provider.active[buf]
      if not provider then
        return true
      end
      provider:automatic_request()
    end,
    on_reload = function(_, buf)
      local provider = Provider.active[buf]
      if provider then
        provider:automatic_request()
      end
    end,
  })

  return self
end

---@package
---@param client_id integer
function Provider:on_attach(client_id)
  local state = self.client_state[client_id]
  if not state then
    state = {
      namespace = api.nvim_create_namespace('nvim.lsp.codelens:' .. client_id),
      row_lenses = {},
    }
    self.client_state[client_id] = state
  end
  self:request(client_id)
end

---@package
---@param client_id integer
function Provider:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
    self.client_state[client_id] = nil
  end
end

--- `lsp.Handler` for `textDocument/codeLens`.
---
---@package
---@param err? lsp.ResponseError
---@param result? lsp.CodeLens[]
---@param ctx lsp.HandlerContext
function Provider:handler(err, result, ctx)
  local state = self.client_state[ctx.client_id]
  if not state then
    return
  end

  if err then
    log.error('codelens', err)
    return
  end

  if util.buf_versions[self.bufnr] ~= ctx.version then
    return
  end

  ---@type table<integer, lsp.CodeLens[]>
  local row_lenses = {}

  -- Code lenses should only span a single line.
  for _, lens in ipairs(result or {}) do
    local row = lens.range.start.line
    local lenses = row_lenses[row] or {}
    table.insert(lenses, lens)
    row_lenses[row] = lenses
  end

  state.row_lenses = row_lenses
  self.version = ctx.version
end

---@package
---@param client_id? integer
---@param on_response? function
function Provider:request(client_id, on_response)
  ---@type lsp.CodeLensParams
  local params = { textDocument = util.make_text_document_params(self.bufnr) }
  for id in pairs(self.client_state) do
    if not client_id or client_id == id then
      local client = assert(vim.lsp.get_client_by_id(id))
      client:request('textDocument/codeLens', params, function(...)
        self:handler(...)

        if on_response then
          on_response()
        end
      end, self.bufnr)
    end
  end
end

---@private
function Provider:reset_timer()
  local timer = self.timer
  if timer then
    self.timer = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

--- Automatically request with debouncing, used as callbacks in autocmd events.
---
---@package
function Provider:automatic_request()
  self:reset_timer()
  self.timer = vim.defer_fn(function()
    self:request()
  end, 200)
end

---@private
---@param client vim.lsp.Client
---@param unresolved_lens lsp.CodeLens
function Provider:resolve(client, unresolved_lens)
  ---@param resolved_lens lsp.CodeLens
  client:request('codeLens/resolve', unresolved_lens, function(err, resolved_lens, ctx)
    local state = self.client_state[client.id]
    if not state then
      return
    end

    if err then
      log.error('codelens/resolve', err)
      return
    end

    if util.buf_versions[self.bufnr] ~= ctx.version then
      return
    end

    local row = unresolved_lens.range.start.line
    local lenses = assert(state.row_lenses[row])
    for i, lens in ipairs(lenses) do
      if lens == unresolved_lens then
        lenses[i] = resolved_lens
      end
    end

    self.row_version[row] = nil
    api.nvim__redraw({
      buf = self.bufnr,
      range = { row, row + 1 },
      valid = true,
      flush = false,
    })
  end, self.bufnr)
end

---@package
---@param toprow integer
---@param botrow integer
function Provider:on_win(toprow, botrow)
  for row = toprow, botrow do
    if self.row_version[row] ~= self.version then
      for client_id, state in pairs(self.client_state) do
        local namespace = state.namespace

        api.nvim_buf_clear_namespace(self.bufnr, namespace, row, row + 1)

        local lenses = state.row_lenses[row]
        if lenses then
          table.sort(lenses, function(a, b)
            return a.range.start.character < b.range.start.character
          end)

          ---@type [string, string][]
          local virt_text = {}
          for _, lens in ipairs(lenses) do
            -- A code lens is unresolved when no command is associated to it.
            if not lens.command then
              local client = assert(vim.lsp.get_client_by_id(client_id))
              self:resolve(client, lens)
            else
              vim.list_extend(virt_text, {
                { lens.command.title, 'LspCodeLens' },
                { ' | ', 'LspCodeLensSeparator' },
              })
            end
          end
          -- Remove trailing separator.
          table.remove(virt_text)

          api.nvim_buf_set_extmark(self.bufnr, namespace, row, 0, {
            virt_text = virt_text,
            hl_mode = 'combine',
          })
        end
        self.row_version[row] = self.version
      end
    end
  end
end

local namespace = api.nvim_create_namespace('nvim.lsp.codelens')
api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, toprow, botrow)
    local provider = Provider.active[bufnr]
    if provider then
      provider:on_win(toprow, botrow)
    end
  end,
})

--- Query whether code lens is enabled in the {filter}ed scope
---
---@param filter? vim.lsp.capability.enable.Filter
---@return boolean whether code lens is enabled.
function M.is_enabled(filter)
  return vim.lsp._capability.is_enabled('codelens', filter)
end

--- Enables or disables code lens for the {filter}ed scope.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled())
--- ```
---
--- To run a code lens, see |vim.lsp.codelens.run()|.
---
---@param enable? boolean true/nil to enable, false to disable
---@param filter? vim.lsp.capability.enable.Filter
function M.enable(enable, filter)
  vim.lsp._capability.enable('codelens', enable, filter)
end

--- Optional filters |kwargs|:
---@class vim.lsp.codelens.get.Filter
---@inlinedoc
---
--- Buffer handle, or 0 for current.
--- (default: 0)
---@field bufnr? integer
---
--- Client ID, or nil for all.
--- (default: all)
---@field client_id? integer

---@class vim.lsp.codelens.get.Result
---@inlinedoc
---@field client_id integer
---@field lens lsp.CodeLens

--- Get all code lenses in the {filter}ed scope.
---
---@param filter? vim.lsp.codelens.get.Filter
---@return vim.lsp.codelens.get.Result[]
function M.get(filter)
  if type(filter) == 'number' then
    vim.deprecate(
      'vim.lsp.codelens.get(bufnr)',
      'vim.lsp.codelens.get({ bufnr = bufnr })',
      '0.13.0'
    )
    local bufnr = vim._resolve_bufnr(filter)
    local provider = Provider.active[bufnr]
    if not provider then
      return {}
    end
    ---@type lsp.CodeLens[]
    local result = {}
    for _, state in pairs(provider.client_state) do
      for _, lenses in pairs(state.row_lenses) do
        result = vim.list_extend(result, lenses)
      end
    end
    return result
  end

  vim.validate('filter', filter, 'table', true)
  filter = filter or {}

  local bufnr = vim._resolve_bufnr(filter.bufnr)
  local provider = Provider.active[bufnr]
  if not provider then
    return {}
  end

  local result = {}
  for client_id, state in pairs(provider.client_state) do
    if not filter.client_id or filter.client_id == client_id then
      for _, lenses in pairs(state.row_lenses) do
        for _, lens in ipairs(lenses) do
          table.insert(result, { client_id = client_id, lens = lens })
        end
      end
    end
  end
  return result
end

---@param lnum integer
---@param opts vim.lsp.codelens.run.Opts
---@param results table<integer, {err: lsp.ResponseError?, result: lsp.CodeLens[]?}>
---@param context lsp.HandlerContext
local function on_lenses_run(lnum, opts, results, context)
  local bufnr = context.bufnr or 0

  ---@type {client: vim.lsp.Client, lens: lsp.CodeLens}[]
  local candidates = {}
  local pending_resolve = 1
  local function on_resolved()
    pending_resolve = pending_resolve - 1
    if pending_resolve > 0 then
      return
    end
    if #candidates == 0 then
      vim.notify('No codelens at current line')
    elseif #candidates == 1 then
      local candidate = candidates[1]
      candidate.client:exec_cmd(candidate.lens.command, { bufnr = bufnr })
    else
      local selectopts = {
        prompt = 'Code lenses: ',
        kind = 'codelens',
        ---@param candidate {client: vim.lsp.Client, lens: lsp.CodeLens}
        format_item = function(candidate)
          return string.format('%s [%s]', candidate.lens.command.title, candidate.client.name)
        end,
      }
      vim.ui.select(candidates, selectopts, function(candidate)
        if candidate then
          candidate.client:exec_cmd(candidate.lens.command, { bufnr = bufnr })
        end
      end)
    end
  end
  for client_id, result in pairs(results) do
    if opts.client_id == nil or opts.client_id == client_id then
      local client = assert(vim.lsp.get_client_by_id(client_id))
      for _, lens in ipairs(result.result or {}) do
        if lens.range.start.line == lnum then
          if lens.command then
            table.insert(candidates, { client = client, lens = lens })
          else
            pending_resolve = pending_resolve + 1
            client:request('codeLens/resolve', lens, function(_, resolved_lens)
              if resolved_lens then
                table.insert(candidates, { client = client, lens = resolved_lens })
              end
              on_resolved()
            end, bufnr)
          end
        end
      end
    end
  end
  on_resolved()
end

--- Optional parameters |kwargs|:
---@class vim.lsp.codelens.run.Opts
---@inlinedoc
---
--- Client ID, or nil for all.
--- (default: all)
---@field client_id? integer

--- Run code lens at the current cursor position.
---
---@param opts? vim.lsp.codelens.run.Opts
function M.run(opts)
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}

  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local pos = vim.pos.cursor(api.nvim_win_get_cursor(winid))
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }
  vim.lsp.buf_request_all(bufnr, 'textDocument/codeLens', params, function(results, context)
    on_lenses_run(pos.row, opts, results, context)
  end)
end

--- |lsp-handler| for the method `workspace/codeLens/refresh`
---
---@private
---@type lsp.Handler
function M.on_refresh(err, _, ctx)
  if err then
    return vim.NIL
  end

  for bufnr, provider in pairs(Provider.active) do
    for client_id in pairs(provider.client_state) do
      if client_id == ctx.client_id then
        provider:request(client_id, function()
          provider.row_version = {}
          vim.api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
        end)
      end
    end
  end
  return vim.NIL
end

---@deprecated
---@param client_id? integer
---@param bufnr? integer
function M.clear(client_id, bufnr)
  vim.deprecate(
    'vim.lsp.codelens.clear(client_id, bufnr)',
    'vim.lsp.codelens.enable(false, { bufnr = bufnr, client_id = client_id })',
    '0.13.0'
  )
  M.enable(false, { bufnr = bufnr, client_id = client_id })
end

---@deprecated
---@param lenses? lsp.CodeLens[] lenses to display
---@param bufnr integer
---@param client_id integer
function M.display(lenses, bufnr, client_id)
  vim.deprecate('vim.lsp.codelens.display()', nil, '0.13.0')
  local _, _, _ = lenses, bufnr, client_id
end

---@deprecated
---@param lenses? lsp.CodeLens[] lenses to store
---@param bufnr integer
---@param client_id integer
function M.save(lenses, bufnr, client_id)
  vim.deprecate('vim.lsp.codelens.save()', nil, '0.13.0')
  local _, _, _ = lenses, bufnr, client_id
end

---@deprecated
---@param err? lsp.ResponseError
---@param result lsp.CodeLens[]
---@param ctx lsp.HandlerContext
function M.on_codelens(err, result, ctx)
  vim.deprecate('vim.lsp.codelens.on_codelens()', nil, '0.13.0')
  local _, _, _ = err, result, ctx
end

---@class vim.lsp.codelens.refresh.Opts
---@inlinedoc
---@field bufnr? integer

---@deprecated
---@param opts? vim.lsp.codelens.refresh.Opts Optional fields
function M.refresh(opts)
  vim.deprecate(
    'vim.lsp.codelens.refresh({ bufnr = bufnr})',
    'vim.lsp.codelens.enable(true, { bufnr = bufnr })',
    '0.13.0'
  )

  vim.validate('opts', opts, 'table', true)
  M.enable(true, { bufnr = opts and opts.bufnr })
end

return M
