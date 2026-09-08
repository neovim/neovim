local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local tableclear = require('vim._core.table').clear
local nvim_on = require('vim._core.util').nvim_on
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
--- treesitter language of the buffer, used for foldtext highlights.
---@field lang? string
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
---
--- Index in the form of start_row -> [text, highlight[]?][]
---@field row_virt_text table<integer, [string, string[]?][]>
---
--- Whether folding updates are deferred until editing settles.
---@field defer_refresh? boolean
---
--- Whether `client_state` has accepted ranges not yet reflected in the row indexes.
---@field pending_evaluate? boolean
---
--- Whether a deferred settle check is already scheduled.
---@field settle_scheduled? boolean
local State = {
  name = 'folding_range',
  method = 'textDocument/foldingRange',
  active = {},
}
State.__index = State
setmetatable(State, Capability)
Capability.all[State.name] = State

--- Re-evaluate the cached foldinfo in the buffer.
function State:evaluate()
  local row_level, row_kinds, row_text, row_virt_text =
    self.row_level, self.row_kinds, self.row_text, self.row_virt_text

  tableclear(row_level)
  tableclear(row_kinds)
  tableclear(row_text)
  tableclear(row_virt_text)

  -- Whether at least one range starts on the row.
  local row_starts = {} ---@type table<integer, true>
  -- Number of ranges ending on the row.
  local row_ends = {} ---@type table<integer, integer>

  for client_id, ranges in pairs(self.client_state) do
    for _, range in ipairs(ranges) do
      local start_row = range.startLine
      local end_row = range.endLine
      -- Ignore zero-length or invalid folds
      if start_row < end_row then
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
        row_starts[start_row] = true
        row_ends[end_row] = (row_ends[end_row] or 0) + 1
      end
    end
  end
  for row, level in pairs(row_level) do
    -- A start takes precedence when ranges start and end on the same row,
    -- otherwise the new fold is ignored.
    if row_starts[row] then
      level[2] = '>'
    elseif row_ends[row] then
      level[2] = '<'
      -- Use the outermost level when nested ranges end on the same row,
      -- otherwise the end of the outer fold is ignored.
      level[1] = level[1] - row_ends[row] + 1
    end
  end
end

--- Force `foldexpr()` to be re-evaluated, without opening folds.
---@param bufnr integer
local function foldupdate(bufnr)
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    local wininfo = vim.fn.getwininfo(winid)[1]
    if wininfo and wininfo.tabnr == vim.fn.tabpagenr() then
      if vim.wo[winid].foldmethod == 'expr' then
        vim._foldupdate(winid, 0, api.nvim_buf_line_count(bufnr))
      end
    end
  end
end

--- Find windows whose cursors are visible before a deferred fold update.
---@param bufnr integer
---@return integer[]
local function visible_cursor_windows(bufnr)
  local windows = {} ---@type integer[]
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    local wininfo = vim.fn.getwininfo(winid)[1]
    if
      wininfo
      and wininfo.tabnr == vim.fn.tabpagenr()
      and vim.wo[winid].foldmethod == 'expr'
      and vim._with({ win = winid }, function()
        return vim.fn.foldclosed('.') == -1
      end)
    then
      windows[#windows + 1] = winid
    end
  end
  return windows
end

--- Open folds that newly hide a previously visible cursor.
---@param bufnr integer
---@param windows integer[]
local function restore_cursor_visibility(bufnr, windows)
  for _, winid in ipairs(windows) do
    if
      api.nvim_win_is_valid(winid)
      and api.nvim_win_get_buf(winid) == bufnr
      and vim._with({ win = winid }, function()
        return vim.fn.foldclosed('.') ~= -1
      end)
    then
      vim._foldopen_cursor(winid)
    end
  end
end

--- Whether the current buffer is in a mode that can actively change its text.
---@param bufnr integer
---@return boolean
local function is_editing(bufnr)
  if api.nvim_get_current_buf() ~= bufnr then
    return false
  end

  local mode = api.nvim_get_mode().mode:sub(1, 1)
  return mode == 'i' or mode == 'R' or mode == 'r' or mode == 's' or mode == 'S' or mode == '\19'
end

--- Apply the latest accepted folding ranges once.
---@param restore_visibility? boolean
function State:apply_pending(restore_visibility)
  if not self.pending_evaluate then
    return
  end

  local visible_windows = restore_visibility and visible_cursor_windows(self.bufnr) or {}
  self.defer_refresh = nil
  self.pending_evaluate = nil
  self:evaluate()
  foldupdate(self.bufnr)
  restore_cursor_visibility(self.bufnr, visible_windows)
end

--- Recheck the mode after queued mode transitions have settled.
---@param state vim.lsp.folding_range.State
local function schedule_settle(state)
  if state.settle_scheduled then
    return
  end

  local bufnr = state.bufnr
  state.settle_scheduled = true
  vim.schedule(function()
    state.settle_scheduled = nil
    if State.active[bufnr] ~= state or not api.nvim_buf_is_valid(bufnr) then
      return
    end
    if is_editing(bufnr) then
      return
    end

    state:apply_pending(true)
  end)
end

---@param results table<integer,{err: lsp.ResponseError?, result: lsp.FoldingRange[]?}>
---@param ctx lsp.HandlerContext
---@param force? boolean
function State:multi_handler(results, ctx, force)
  -- Handling responses from outdated buffer only causes performance overhead.
  if util.buf_versions[self.bufnr] ~= ctx.version then
    return
  end

  for client_id, result in pairs(results) do
    if result.err then
      log.error('folding_range', result.err)
    else
      self.client_state[client_id] = result.result
    end
  end
  self.version = ctx.version
  self.pending_evaluate = true

  local snippet_active = api.nvim_get_current_buf() == self.bufnr
    and vim.snippet
    and vim.snippet.active()
  if not force and (self.defer_refresh or is_editing(self.bufnr) or snippet_active) then
    self.defer_refresh = true
    schedule_settle(self)
    return
  end

  self:apply_pending()
end

---@param err lsp.ResponseError?
---@param result lsp.FoldingRange[]?
---@param ctx lsp.HandlerContext, config?: table
function State:handler(err, result, ctx)
  self:multi_handler({ [ctx.client_id] = { err = err, result = result } }, ctx)
end

--- Request `textDocument/foldingRange` from the server.
--- Accepted ranges are applied once after the request is completed or editing settles.
---@param client_id integer
function State:refresh(client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if client then
    ---@type lsp.FoldingRangeParams
    local params = { textDocument = util.make_text_document_params(self.bufnr) }

    client:request('textDocument/foldingRange', params, function(...)
      self:handler(...)
    end, self.bufnr)
    return
  end
end

function State:reset()
  self.lang = vim.treesitter.language.get_lang(vim.bo[self.bufnr].filetype)
  tableclear(self.row_level)
  tableclear(self.row_kinds)
  tableclear(self.row_text)
  tableclear(self.row_virt_text)
  self.defer_refresh = nil
  self.pending_evaluate = nil
end

--- Initialize `state` and event hooks, then request folding ranges.
---@param bufnr integer
---@return vim.lsp.folding_range.State
function State:new(bufnr)
  self = Capability.new(self, bufnr)
  self.lang = vim.treesitter.language.get_lang(vim.bo[self.bufnr].filetype)
  self.row_level = {}
  self.row_kinds = {}
  self.row_text = {}
  self.row_virt_text = {}

  api.nvim_buf_attach(bufnr, false, {
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
  nvim_on('OptionSet', self.augroup, { pattern = 'foldexpr' }, function()
    if vim.v.option_type == 'global' or api.nvim_get_current_buf() == bufnr then
      vim.lsp._capability.enable('folding_range', false, { bufnr = bufnr })
    end
  end)
  nvim_on('FileType', self.augroup, { buf = bufnr }, function()
    self:reset()
  end)
  nvim_on('ModeChanged', self.augroup, { buf = bufnr }, function()
    if self.defer_refresh then
      schedule_settle(self)
    end
  end)

  return self
end

---@param client_id integer
function State:on_attach(client_id)
  self.client_state[client_id] = {}
  self:refresh(client_id)
end

---@params client_id integer
function State:on_detach(client_id)
  self.client_state[client_id] = nil
  self.pending_evaluate = true
  self:apply_pending()
end

---@private
function State:on_close(client_id)
  self.client_state[client_id] = {}
  self.pending_evaluate = true
  self:apply_pending()
end

---@private
function State:on_change(client_id)
  if is_editing(self.bufnr) then
    self.defer_refresh = true
  end
  self:refresh(client_id)
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
  local provider = State.active[bufnr]
  if not provider then
    return
  end

  -- Schedule `foldclose()` if the buffer is not up-to-date.
  if provider.version == util.buf_versions[bufnr] then
    provider:apply_pending()
    provider:foldclose(kind, winid)
    return
  end

  if not next(vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/foldingRange' })) then
    return
  end
  ---@type lsp.FoldingRangeParams
  local params = { textDocument = util.make_text_document_params(bufnr) }
  vim.lsp.buf_request_all(bufnr, 'textDocument/foldingRange', params, function(results, ctx)
    provider:multi_handler(results, ctx, true)
    -- Ensure this window is still valid and buffer stays as the current buffer
    -- after the async request.
    if api.nvim_win_is_valid(winid) and api.nvim_win_get_buf(winid) == bufnr then
      provider:foldclose(kind, winid)
    end
  end)
end

--- Split `line` into highlighted virt_text chunks from `spans`.
---
---@param line string
---@param spans [integer, integer, string][] [start_col, end_col, highlight]
---@return [string, string[]?][] [text, highlight[]?][]
local function spans_to_virt_text(line, spans)
  local boundaries = { 0, #line }
  for _, span in ipairs(spans) do
    boundaries[#boundaries + 1] = span[1]
    boundaries[#boundaries + 1] = span[2]
  end
  table.sort(boundaries)

  local virt_text = {} ---@type [string, string[]][]
  local last_b = -1
  for _, b in ipairs(boundaries) do
    if b > last_b then
      if last_b >= 0 then
        local start_col = last_b
        local end_col = b
        local text = line:sub(start_col + 1, end_col)
        local highlight = {} ---@type string[]
        for _, span in ipairs(spans) do
          if span[1] <= start_col and end_col <= span[2] then
            if highlight[#highlight] ~= span[3] then
              highlight[#highlight + 1] = span[3]
            end
          end
        end
        if #highlight == 0 then
          virt_text[#virt_text + 1] = { text }
        else
          virt_text[#virt_text + 1] = { text, highlight }
        end
      end
      last_b = b
    end
  end

  return virt_text
end

--- Return foldtext highlighted via treesitter, if available.
---
---@return string|[string, string[]?][]
---@param lnum? integer
function M.foldtext(lnum)
  lnum = lnum or vim.v.foldstart
  local bufnr = api.nvim_get_current_buf()
  local row = lnum - 1
  local state = State.active[bufnr]
  local lang = state and state.lang
  local line = vim.fn.getline(lnum)
  if not lang then
    return line
  end ---@cast state -nil

  local virt_text = state.row_virt_text[row]
  if virt_text then
    return virt_text
  end

  line = state.row_text[row] or line
  local ok, parser = pcall(function()
    local parser = vim.treesitter.get_string_parser(line, lang)
    parser:parse(true)
    return parser
  end)
  if not ok then
    return line
  end

  --- Collect treesitter highlight spans for the foldtext.
  --- [start_col, end_col, highlight]
  ---@type [integer, integer, string][]
  local spans = {}
  parser:for_each_tree(function(tstree, tree)
    local query = vim.treesitter.query.get(tree:lang(), 'highlights')
    if query then
      for capture, node in query:iter_captures(tstree:root(), line) do
        local name = query.captures[capture]
        local _, start_col, _, end_col = node:range()
        if name:match('^[^_]') then
          spans[#spans + 1] = {
            start_col,
            end_col,
            ('@%s.%s'):format(name, tree:lang()),
          }
        end
      end
    end
  end)

  virt_text = spans_to_virt_text(line, spans)
  state.row_virt_text[row] = virt_text

  return virt_text
end

---@param lnum? integer
---@return string level
function M.foldexpr(lnum)
  local bufnr = api.nvim_get_current_buf()
  if not vim.lsp._capability.is_enabled('folding_range', { bufnr = bufnr }) then
    -- `foldexpr` lead to a textlock, so any further operations need to be scheduled.
    vim.schedule(function()
      if api.nvim_buf_is_valid(bufnr) then
        vim.lsp._capability.enable('folding_range', true, { bufnr = bufnr })
      end
    end)
  end

  local state = State.active[bufnr]
  if not state then
    return '0'
  end
  local row = (lnum or vim.v.lnum) - 1
  local level = state.row_level[row]
  return level and (level[2] or '') .. (level[1] or '0') or '0'
end

return M
