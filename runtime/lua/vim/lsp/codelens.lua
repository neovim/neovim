local api = vim.api
local log = require('vim.lsp.log')
local nvim_on = require('vim._core.util').nvim_on
local tableclear = require('vim._core.table').clear
local util = require('vim.lsp.util')

local M = {}

local Capability = require('vim.lsp._capability')

---@class (private) vim.lsp.codelens.RowLenses
---@field lenses lsp.CodeLens[]
---@field version? integer `TextDocument` version most recently applied to this row.
---
---@class (private) vim.lsp.codelens.ClientState
---@field row_lenses table<integer, vim.lsp.codelens.RowLenses>
---@field namespace integer
---@field version? integer `TextDocument` version current state corresponds to.
---
---@class (private) vim.lsp.codelens.Provider : vim.lsp.Capability
---@field active table<integer, vim.lsp.codelens.Provider>
---
--- Index In the form of client_id -> client_state
---@field client_state? table<integer, vim.lsp.codelens.ClientState?>
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

  nvim_on('LspNotify', self.augroup, { buf = self.bufnr }, function(ev)
    local client_id = ev.data.client_id ---@type integer

    if not self.client_state[client_id] then
      return
    end

    if ev.data.method == 'textDocument/didClose' then
      self:clear(client_id)
    end

    if ev.data.method == 'textDocument/didChange' or ev.data.method == 'textDocument/didOpen' then
      self:request(client_id)
    end
  end)

  return self
end

---@package
---@param client_id integer
function Provider:on_attach(client_id)
  if not self.client_state[client_id] then
    self.client_state[client_id] = {
      namespace = api.nvim_create_namespace('nvim.lsp.codelens:' .. client_id),
      row_lenses = {},
    }
  end
  self:request(client_id)
end

---@package
---@param client_id integer
function Provider:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    self:clear(client_id)
    self.client_state[client_id] = nil
  end
end

---@package
---@param client_id integer
function Provider:clear(client_id)
  local state = self.client_state[client_id]
  if state then
    state.version = nil
    tableclear(state.row_lenses)
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
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

  tableclear(state.row_lenses)

  -- Code lenses should only span a single line.
  for _, lens in ipairs(result or {}) do
    local row = lens.range.start.line
    local row_lenses = state.row_lenses[row] or { lenses = {} }
    table.insert(row_lenses.lenses, lens)
    state.row_lenses[row] = row_lenses
  end
  state.version = ctx.version

  api.nvim__redraw({ buf = self.bufnr, valid = true, flush = false })
end

---@package
---@param client_id integer
function Provider:request(client_id)
  ---@type lsp.CodeLensParams
  local params = { textDocument = util.make_text_document_params(self.bufnr) }
  local state = self.client_state[client_id]
  local client = vim.lsp.get_client_by_id(client_id)
  if state and client then
    client:request('textDocument/codeLens', params, function(...)
      self:handler(...)
    end, self.bufnr)
  end
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
    local row_lenses = state.row_lenses[row]
    -- A newer textDocument/codeLens response can replace row_lenses while resolve is in flight.
    if not row_lenses then
      return
    end

    for i, lens in ipairs(row_lenses.lenses) do
      -- Only apply if this exact unresolved lens still exists; otherwise response is stale.
      if lens == unresolved_lens then
        row_lenses.lenses[i] = resolved_lens
        row_lenses.version = nil
        api.nvim__redraw({
          buf = self.bufnr,
          range = { row, row + 1 },
          valid = true,
          flush = false,
        })
        return
      end
    end
  end, self.bufnr)
end

---@package
---@param toprow integer
---@param botrow integer
function Provider:on_win(toprow, botrow)
  for row = toprow, botrow do
    for client_id, state in pairs(self.client_state) do
      if state.version == util.buf_versions[self.bufnr] then
        local row_lenses = state.row_lenses[row]

        if not row_lenses then
          api.nvim_buf_clear_namespace(self.bufnr, state.namespace, row, row + 1)
        elseif row_lenses.version ~= state.version then
          row_lenses.version = state.version

          local bufnr = self.bufnr
          local namespace = state.namespace

          table.sort(row_lenses.lenses, function(a, b)
            return a.range.start.character < b.range.start.character
          end)

          local client = assert(vim.lsp.get_client_by_id(client_id))
          local range = vim.range.lsp(bufnr, row_lenses.lenses[1].range, client.offset_encoding)
          ---@type [string, string][]
          local virt_text = {
            { string.rep(' ', range.start_col), 'LspCodeLensSeparator' },
          }
          local has_unresolved = false

          for _, lens in ipairs(row_lenses.lenses) do
            -- A code lens is unresolved when no command is associated to it.
            if not lens.command then
              has_unresolved = true
              self:resolve(client, lens)
            else
              vim.list_extend(virt_text, {
                { lens.command.title, 'LspCodeLens' },
                { ' | ', 'LspCodeLensSeparator' },
              })
            end
          end

          local had_extmark = #api.nvim_buf_get_extmarks(
            bufnr,
            namespace,
            { row, 0 },
            { row, -1 },
            {}
          ) > 0

          if not has_unresolved or not had_extmark then
            -- Remove trailing separator.
            table.remove(virt_text)

            -- Use a placeholder to prevent flickering caused by layout shifts.
            if #virt_text == 1 then
              table.insert(virt_text, { '', 'LspCodeLens' })
            end

            api.nvim_buf_clear_namespace(bufnr, namespace, row, row + 1)
            api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
              virt_lines = { virt_text },
              virt_lines_above = true,
              virt_lines_overflow = 'scroll',
              hl_mode = 'combine',
            })

            -- Fix https://github.com/neovim/neovim/issues/16166
            -- Make sure the code lens on the first line is visible when updating.
            if row == 0 then
              vim.fn.winrestview({ topfill = 1 })
            end
          end
        end
      end
    end
  end

  -- Clear extmarks beyond the bottom of the buffer.
  if botrow == api.nvim_buf_line_count(self.bufnr) - 1 then
    for _, state in pairs(self.client_state) do
      api.nvim_buf_clear_namespace(self.bufnr, state.namespace, botrow + 1, -1)
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
      for _, row_lenses in pairs(state.row_lenses) do
        result = vim.list_extend(result, row_lenses.lenses)
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
      for _, row_lenses in pairs(state.row_lenses) do
        for _, lens in ipairs(row_lenses.lenses) do
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
  local pos = vim.pos.cursor(winid)
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

  for _, provider in pairs(Provider.active) do
    local state = provider.client_state[ctx.client_id]
    if state then
      provider:request(ctx.client_id)
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
