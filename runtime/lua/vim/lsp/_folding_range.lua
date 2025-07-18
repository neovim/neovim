local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

---@type table<lsp.FoldingRangeKind, true>
local supported_fold_kinds = {
  ['comment'] = true,
  ['imports'] = true,
  ['region'] = true,
}

local M = {}

local Capability = require('vim.lsp._capability')

---@class (private) vim.lsp.folding_range.State : vim.lsp.Capability
---
---@field active table<integer, vim.lsp.folding_range.State?>
---
--- `TextDocument` version this `state` corresponds to.
---@field version? integer
---
--- Never use this directly, `evaluate()` the cached foldinfo
--- then use on demand via `row_*` fields.
---
--- Index In the form of client_id -> ranges
---@field client_state table<integer, lsp.FoldingRange[]?>
---
--- Index in the form of row -> [foldlevel, mark]
---@field row_level table<integer, [integer, ">" | "<"?]?>
---
--- Index in the form of start_row -> kinds
---@field row_kinds table<integer, table<lsp.FoldingRangeKind, true?>?>>
---
--- Index in the form of start_row -> collapsed_text
---@field row_text table<integer, string?>
local State = { name = 'Folding Range', active = {} }
State.__index = State
setmetatable(State, Capability)

--- Re-evaluate the cached foldinfo in the buffer.
function State:evaluate()
  ---@type table<integer, [integer, ">" | "<"?]?>
  local row_level = {}
  ---@type table<integer, table<lsp.FoldingRangeKind, true?>?>>
  local row_kinds = {}
  ---@type table<integer, string?>
  local row_text = {}

  for client_id, ranges in pairs(self.client_state) do
    for _, range in ipairs(ranges) do
      local start_row = range.startLine
      local end_row = range.endLine
      -- Adding folds within a single line is not supported by Nvim.
      if start_row ~= end_row then
        row_text[start_row] = range.collapsedText

        local kind = range.kind
        if kind then
          -- Ignore unsupported fold kinds.
          if supported_fold_kinds[kind] then
            local kinds = row_kinds[start_row] or {}
            kinds[kind] = true
            row_kinds[start_row] = kinds
          else
            log.info(('Unknown fold kind "%s" from client %d'):format(kind, client_id))
          end
        end

        for row = start_row, end_row do
          local level = row_level[row] or { 0 }
          level[1] = level[1] + 1
          row_level[row] = level
        end
        row_level[start_row][2] = '>'
        row_level[end_row][2] = '<'
      end
    end
  end

  self.row_level = row_level
  self.row_kinds = row_kinds
  self.row_text = row_text
end

--- Force `foldexpr()` to be re-evaluated, without opening folds.
---@param bufnr integer
local function foldupdate(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) or not vim.b[bufnr]._lsp_enable_folding_range then
    return
  end
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    local wininfo = vim.fn.getwininfo(winid)[1]
    if wininfo and wininfo.tabnr == vim.fn.tabpagenr() then
      if vim.wo[winid].foldmethod == 'expr' then
        vim._foldupdate(winid, 0, api.nvim_buf_line_count(bufnr))
      end
    end
  end
end

--- Whether `foldupdate()` is scheduled for the buffer with `bufnr`.
---
--- Index in the form of bufnr -> true?
---@type table<integer, true?>
local scheduled_foldupdate = {}

--- Schedule `foldupdate()` after leaving insert mode.
---@param bufnr integer
local function schedule_foldupdate(bufnr)
  if not scheduled_foldupdate[bufnr] then
    scheduled_foldupdate[bufnr] = true
    api.nvim_create_autocmd('InsertLeave', {
      buffer = bufnr,
      once = true,
      callback = function()
        foldupdate(bufnr)
        scheduled_foldupdate[bufnr] = nil
      end,
    })
  end
end

---@param results table<integer,{err: lsp.ResponseError?, result: lsp.FoldingRange[]?}>
---@param ctx lsp.HandlerContext
function State:multi_handler(results, ctx)
  -- Handling responses from outdated buffer only causes performance overhead.
  if util.buf_versions[self.bufnr] ~= ctx.version then
    return
  end

  for client_id, result in pairs(results) do
    if result.err then
      log.error(result.err)
    else
      self.client_state[client_id] = result.result
    end
  end
  self.version = ctx.version

  self:evaluate()
  if api.nvim_get_mode().mode:match('^i') then
    -- `foldUpdate()` is guarded in insert mode.
    schedule_foldupdate(self.bufnr)
  else
    foldupdate(self.bufnr)
  end
end

---@param err lsp.ResponseError?
---@param result lsp.FoldingRange[]?
---@param ctx lsp.HandlerContext, config?: table
function State:handler(err, result, ctx)
  self:multi_handler({ [ctx.client_id] = { err = err, result = result } }, ctx)
end

--- Request `textDocument/foldingRange` from the server.
--- `foldupdate()` is scheduled once after the request is completed.
---@param client? vim.lsp.Client The client whose server supports `foldingRange`.
function State:refresh(client)
  if not vim.b._lsp_enable_folding_range then
    return
  end

  ---@type lsp.FoldingRangeParams
  local params = { textDocument = util.make_text_document_params(self.bufnr) }

  if client then
    client:request(ms.textDocument_foldingRange, params, function(...)
      self:handler(...)
    end, self.bufnr)
    return
  end

  if
    not next(vim.lsp.get_clients({ bufnr = self.bufnr, method = ms.textDocument_foldingRange }))
  then
    return
  end

  vim.lsp.buf_request_all(self.bufnr, ms.textDocument_foldingRange, params, function(...)
    self:multi_handler(...)
  end)
end

function State:reset()
  self.row_level = {}
  self.row_kinds = {}
  self.row_text = {}
end

--- Initialize `state` and event hooks, then request folding ranges.
---@param bufnr integer
---@return vim.lsp.folding_range.State
function State:new(bufnr)
  self = Capability.new(self, bufnr)
  self:reset()

  api.nvim_buf_attach(bufnr, false, {
    -- Reset `bufstate` and request folding ranges.
    on_reload = function()
      local state = State.active[bufnr]
      if state then
        state:reset()
        state:refresh()
      end
    end,
    --- Sync changed rows with their previous foldlevels before applying new ones.
    on_bytes = function(_, _, _, start_row, _, _, old_row, _, _, new_row, _, _)
      local state = State.active[bufnr]
      if state == nil then
        return true
      end
      local row_level = state.row_level
      if next(row_level) == nil then
        return
      end
      local row = new_row - old_row
      if row > 0 then
        vim._list_insert(row_level, start_row, start_row + math.abs(row) - 1, { -1 })
        -- If the previous row ends a fold,
        -- Nvim treats the first row after consecutive `-1`s as a new fold start,
        -- which is not the desired behavior.
        local prev_level = row_level[start_row - 1]
        if prev_level and prev_level[2] == '<' then
          row_level[start_row] = { prev_level[1] - 1 }
        end
      elseif row < 0 then
        vim._list_remove(row_level, start_row, start_row + math.abs(row) - 1)
      end
    end,
  })
  api.nvim_create_autocmd('LspNotify', {
    group = self.augroup,
    buffer = bufnr,
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      if
        client:supports_method(ms.textDocument_foldingRange, bufnr)
        and (
          args.data.method == ms.textDocument_didChange
          or args.data.method == ms.textDocument_didOpen
        )
      then
        self:refresh(client)
      end
    end,
  })
  api.nvim_create_autocmd('OptionSet', {
    group = self.augroup,
    pattern = 'foldexpr',
    callback = function()
      if vim.v.option_type == 'global' or vim.api.nvim_get_current_buf() == bufnr then
        vim.b[bufnr]._lsp_enable_folding_range = nil
      end
    end,
  })

  return self
end

function State:destroy()
  api.nvim_del_augroup_by_id(self.augroup)
  State.active[self.bufnr] = nil
end

---@params client_id integer
function State:on_detach(client_id)
  self.client_state[client_id] = nil
  self:evaluate()
  foldupdate(self.bufnr)
end

---@param bufnr integer
---@param client_id? integer
function M._setup(bufnr, client_id)
  local state = State.active[bufnr]
  if not state then
    state = State:new(bufnr)
  end

  state:refresh(client_id and vim.lsp.get_client_by_id(client_id))
end

---@param kind lsp.FoldingRangeKind
---@param winid integer
function State:foldclose(kind, winid)
  vim._with({ win = winid }, function()
    local bufnr = api.nvim_win_get_buf(winid)
    local row_kinds = State.active[bufnr].row_kinds
    -- Reverse traverse to ensure that the smallest ranges are closed first.
    for row = api.nvim_buf_line_count(bufnr) - 1, 0, -1 do
      local kinds = row_kinds[row]
      if kinds and kinds[kind] then
        vim.cmd(row + 1 .. 'foldclose')
      end
    end
  end)
end

---@param kind lsp.FoldingRangeKind
---@param winid? integer
function M.foldclose(kind, winid)
  vim.validate('kind', kind, 'string')
  vim.validate('winid', winid, 'number', true)

  winid = winid or api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local state = State.active[bufnr]
  if not state then
    return
  end

  -- Schedule `foldclose()` if the buffer is not up-to-date.
  if state.version == util.buf_versions[bufnr] then
    state:foldclose(kind, winid)
    return
  end

  if not next(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange })) then
    return
  end
  ---@type lsp.FoldingRangeParams
  local params = { textDocument = util.make_text_document_params(bufnr) }
  vim.lsp.buf_request_all(bufnr, ms.textDocument_foldingRange, params, function(...)
    state:multi_handler(...)
    -- Ensure this buffer stays as the current buffer after the async request
    if api.nvim_win_get_buf(winid) == bufnr then
      state:foldclose(kind, winid)
    end
  end)
end

---@return string
function M.foldtext()
  local bufnr = api.nvim_get_current_buf()
  local lnum = vim.v.foldstart
  local row = lnum - 1
  local state = State.active[bufnr]
  if state and state.row_text[row] then
    return state.row_text[row]
  end
  return vim.fn.getline(lnum)
end

---@param lnum? integer
---@return string level
function M.foldexpr(lnum)
  local bufnr = api.nvim_get_current_buf()
  local state = State.active[bufnr]
  if not vim.b[bufnr]._lsp_enable_folding_range then
    vim.b[bufnr]._lsp_enable_folding_range = true
    if state then
      state:refresh()
    end
  end

  if not state then
    return '0'
  end
  local row = (lnum or vim.v.lnum) - 1
  local level = state.row_level[row]
  return level and (level[2] or '') .. (level[1] or '0') or '0'
end

M.__FoldEvaluator = State

return M
