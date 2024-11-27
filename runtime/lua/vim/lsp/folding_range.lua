local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

local M = {}

---@class (private) vim.lsp.folding_range.BufState
---
---@field version? integer
---
--- Index in the form of row -> [foldlevel, mark]
---@field row_level table<integer, [integer, ">" | "<"?]?>
---
--- Index in the form of start_row -> kinds
---@field row_kinds table<integer, table<lsp.FoldingRangeKind, boolean>?>>

---@type table<integer, vim.lsp.folding_range.BufState?>
local bufstates = {}

--- Add `ranges` into the given `bufstate`.
---@param bufstate vim.lsp.folding_range.BufState
---@param ranges lsp.FoldingRange[]
local function rangeadd(bufstate, ranges)
  local row_level = bufstate.row_level
  local row_kinds = bufstate.row_kinds

  for _, range in ipairs(ranges) do
    local start_row = range.startLine
    local end_row = range.endLine
    -- Adding folds within a single line is not supported by Nvim.
    if start_row ~= end_row then
      local kind = range.kind
      if kind then
        local kinds = row_kinds[start_row] or {}
        kinds[kind] = true
        row_kinds[start_row] = kinds
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

---@param result lsp.FoldingRange[]?
---@type lsp.Handler
local function handler(err, result, ctx)
  if err then
    log.error(err)
    return
  end

  if not result then
    return
  end

  local bufnr = assert(ctx.bufnr)
  -- Handling responses from outdated buffer only causes performance overhead.
  if util.buf_versions[bufnr] ~= ctx.version then
    return
  end

  local bufstate = assert(bufstates[bufnr])
  bufstate.row_level = {}
  bufstate.row_kinds = {}

  rangeadd(bufstate, result)
  bufstate.version = ctx.version

  if api.nvim_get_mode().mode:match('^i') then
    -- `foldUpdate()` is guarded in insert mode.
    schedule_foldupdate(bufnr)
  else
    foldupdate(bufnr)
  end
end

--- Request `textDocument/foldingRange` from the server.
--- `foldupdate()` is scheduled once after the request is completed.
---@param bufnr integer
---@param client vim.lsp.Client The client whose server supports `foldingRange`.
---@return integer? request_id
local function request(bufnr, client)
  ---@type lsp.FoldingRangeParams
  local params = { textDocument = util.make_text_document_params(bufnr) }
  local _, request_id = client:request(ms.textDocument_foldingRange, params, handler, bufnr)
  return request_id
end

-- NOTE:
-- `bufstate` and event hooks are interdependent:
-- * `bufstate` needs event hooks for correctness.
-- * event hooks require the previous `bufstate` for updates.
-- Since they are manually created and destroyed,
-- we ensure their lifecycles are always synchronized.
--
-- TODO(ofseed):
-- 1. Implement clearing `bufstate` and event hooks
--    when no clients in the buffer support the corresponding method.
-- 2. Then generalize this state management to other LSP modules.
local augroup_setup = api.nvim_create_augroup('vim_lsp_folding_range/setup', {})

--- Initialize `bufstate` and event hooks, then request folding ranges.
--- Manage their lifecycle within this function.
---@param bufnr integer
---@return vim.lsp.folding_range.BufState?
local function setup(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  -- Register the new `bufstate`.
  bufstates[bufnr] = {
    row_level = {},
    row_kinds = {},
  }

  -- Event hooks from `buf_attach` can't be removed externally.
  -- Hooks and `bufstate` share the same lifecycle;
  -- they should self-destroy if `bufstate == nil`.
  api.nvim_buf_attach(bufnr, false, {
    -- `on_detach` also runs on buffer reload (`:e`).
    -- Ensure `bufstate` and hooks are cleared to avoid duplication or leftover states.
    on_detach = function()
      bufstates[bufnr] = nil
      api.nvim_clear_autocmds({ buffer = bufnr, group = augroup_setup })
    end,
    -- Reset `bufstate` and request folding ranges.
    on_reload = function()
      bufstates[bufnr] = {
        row_level = {},
        row_kinds = {},
      }
      for _, client in
        ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange }))
      do
        request(bufnr, client)
      end
    end,
    --- Sync changed rows with their previous foldlevels before applying new ones.
    on_bytes = function(_, _, _, start_row, _, _, old_row, _, _, new_row, _, _)
      if bufstates[bufnr] == nil then
        return true
      end
      local row_level = bufstates[bufnr].row_level
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
  api.nvim_create_autocmd('LspDetach', {
    group = augroup_setup,
    buffer = bufnr,
    callback = function(args)
      ---@type vim.lsp.Client[]
      local clients = vim
        .iter(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange }))
        ---@param client vim.lsp.Client
        :filter(function(client)
          return client.id ~= args.data.client_id
        end)
        :totable()
      if #clients == 0 then
        if api.nvim_buf_is_loaded(bufnr) then
          bufstates[bufnr] = {
            row_level = {},
            row_kinds = {},
          }
          foldupdate(bufnr)
        end
      else
        for _, client in ipairs(clients) do
          request(bufnr, client)
        end
      end
    end,
  })
  api.nvim_create_autocmd('LspAttach', {
    group = augroup_setup,
    buffer = bufnr,
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      request(bufnr, client)
    end,
  })
  api.nvim_create_autocmd('LspNotify', {
    group = augroup_setup,
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
        request(bufnr, client)
      end
    end,
  })

  for _, client in
    ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange }))
  do
    request(bufnr, client)
  end

  return bufstates[bufnr]
end

---@param kind lsp.FoldingRangeKind
---@param winid integer
local function foldclose(kind, winid)
  vim._with({ win = winid }, function()
    local bufnr = api.nvim_win_get_buf(winid)
    local row_kinds = bufstates[bufnr].row_kinds
    -- Reverse traverse to ensure that the smallest ranges are closed first.
    for row = api.nvim_buf_line_count(bufnr) - 1, 0, -1 do
      local kinds = row_kinds[row]
      if kinds and kinds[kind] then
        vim.cmd(row + 1 .. 'foldclose')
      end
    end
  end)
end

--- Close all {kind} of folds in the the window with {winid}.
---
--- To automatically fold imports when opening a file, you can use an autocmd:
---
--- ```lua
--- vim.api.nvim_create_autocmd('LspNotify', {
---   callback = function(args)
---     if args.data.method == 'textDocument/didOpen' then
---       vim.lsp.folding_range.foldclose('imports', vim.fn.bufwinid(args.buf))
---     end
---   end,
--- })
--- ```
---
---@param kind lsp.FoldingRangeKind Kind to close, one of "comment", "imports" or "region".
---@param winid? integer Defaults to the current window.
function M.foldclose(kind, winid)
  vim.validate('kind', kind, 'string')
  vim.validate('winid', winid, 'number', true)

  winid = winid or api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local bufstate = bufstates[bufnr]
  if not bufstate then
    return
  end

  if bufstate.version == util.buf_versions[bufnr] then
    foldclose(kind, winid)
    return
  end
  -- Schedule `foldclose()` if the buffer is not up-to-date.

  --- Index in the form of request_id -> true?
  ---@type table<integer, true?>
  local scheduled_request = {}
  for _, client in
    ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange }))
  do
    local request_id = request(bufnr, client)
    if request_id then
      scheduled_request[request_id] = true
    end
  end

  api.nvim_create_autocmd('LspRequest', {
    buffer = bufnr,
    callback = function(args)
      ---@type integer
      local request_id = args.data.request_id
      if scheduled_request[request_id] and args.data.request.type == 'complete' then
        scheduled_request[request_id] = nil
      end
      -- Do `foldclose()` if all the requests is completed.
      if next(scheduled_request) == nil then
        foldclose(kind, winid)
        return true
      end
    end,
  })
end

---@param lnum? integer
---@return string level
function M._foldexpr(lnum)
  local bufnr = api.nvim_get_current_buf()
  local bufstate = bufstates[bufnr] or setup(bufnr)
  if not bufstate then
    return '0'
  end

  local row = (lnum or vim.v.lnum) - 1
  local level = bufstate.row_level[row]
  return level and (level[2] or '') .. (level[1] or '0') or '0'
end

return M
