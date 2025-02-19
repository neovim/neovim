local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

local M = {}

---@class (private) vim.lsp.folding_range.BufState
---
---@field version? integer
---
--- Never use this directly, `renew()` the cached foldinfo
--- then use on demand via `row_*` fields.
---
--- Index In the form of client_id -> ranges
---@field client_ranges table<integer, lsp.FoldingRange[]?>
---
--- Index in the form of row -> [foldlevel, mark]
---@field row_level table<integer, [integer, ">" | "<"?]?>
---
--- Index in the form of start_row -> kinds
---@field row_kinds table<integer, table<lsp.FoldingRangeKind, true?>?>>
---
--- Index in the form of start_row -> collapsed_text
---@field row_text table<integer, string?>

---@type table<integer, vim.lsp.folding_range.BufState?>
local bufstates = {}

--- Renew the cached foldinfo in the buffer.
---@param bufnr integer
local function renew(bufnr)
  local bufstate = assert(bufstates[bufnr])

  ---@type table<integer, [integer, ">" | "<"?]?>
  local row_level = {}
  ---@type table<integer, table<lsp.FoldingRangeKind, true?>?>>
  local row_kinds = {}
  ---@type table<integer, string?>
  local row_text = {}

  for _, ranges in pairs(bufstate.client_ranges) do
    for _, range in ipairs(ranges) do
      local start_row = range.startLine
      local end_row = range.endLine
      -- Adding folds within a single line is not supported by Nvim.
      if start_row ~= end_row then
        row_text[start_row] = range.collapsedText

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

  bufstate.row_level = row_level
  bufstate.row_kinds = row_kinds
  bufstate.row_text = row_text
end

--- Renew the cached foldinfo then force `foldexpr()` to be re-evaluated,
--- without opening folds.
---@param bufnr integer
local function foldupdate(bufnr)
  renew(bufnr)
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
---@type lsp.MultiHandler
local function multi_handler(results, ctx)
  local bufnr = assert(ctx.bufnr)
  -- Handling responses from outdated buffer only causes performance overhead.
  if util.buf_versions[bufnr] ~= ctx.version then
    return
  end

  local bufstate = assert(bufstates[bufnr])
  for client_id, result in pairs(results) do
    if result.err then
      log.error(result.err)
    else
      bufstate.client_ranges[client_id] = result.result
    end
  end
  bufstate.version = ctx.version

  if api.nvim_get_mode().mode:match('^i') then
    -- `foldUpdate()` is guarded in insert mode.
    schedule_foldupdate(bufnr)
  else
    foldupdate(bufnr)
  end
end

---@param result lsp.FoldingRange[]?
---@type lsp.Handler
local function handler(err, result, ctx)
  multi_handler({ [ctx.client_id] = { err = err, result = result } }, ctx)
end

--- Request `textDocument/foldingRange` from the server.
--- `foldupdate()` is scheduled once after the request is completed.
---@param bufnr integer
---@param client? vim.lsp.Client The client whose server supports `foldingRange`.
local function request(bufnr, client)
  ---@type lsp.FoldingRangeParams
  local params = { textDocument = util.make_text_document_params(bufnr) }

  if client then
    client:request(ms.textDocument_foldingRange, params, handler, bufnr)
    return
  end

  if not next(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange })) then
    return
  end

  vim.lsp.buf_request_all(bufnr, ms.textDocument_foldingRange, params, multi_handler)
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
local augroup_setup = api.nvim_create_augroup('nvim.lsp.folding_range.setup', {})

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
    client_ranges = {},
    row_level = {},
    row_kinds = {},
    row_text = {},
  }

  -- Event hooks from `buf_attach` can't be removed externally.
  -- Hooks and `bufstate` share the same lifecycle;
  -- they should self-destroy if `bufstate == nil`.
  api.nvim_buf_attach(bufnr, false, {
    -- `on_detach` also runs on buffer reload (`:e`).
    -- Ensure `bufstate` and hooks are cleared to avoid duplication or leftover states.
    on_detach = function()
      util._cancel_requests({
        bufnr = bufnr,
        method = ms.textDocument_foldingRange,
        type = 'pending',
      })
      bufstates[bufnr] = nil
      api.nvim_clear_autocmds({ buffer = bufnr, group = augroup_setup })
    end,
    -- Reset `bufstate` and request folding ranges.
    on_reload = function()
      bufstates[bufnr] = {
        client_ranges = {},
        row_level = {},
        row_kinds = {},
        row_text = {},
      }
      request(bufnr)
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
      if not api.nvim_buf_is_loaded(bufnr) then
        return
      end

      ---@type integer
      local client_id = args.data.client_id
      bufstates[bufnr].client_ranges[client_id] = nil

      ---@type vim.lsp.Client[]
      local clients = vim
        .iter(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange }))
        ---@param client vim.lsp.Client
        :filter(function(client)
          return client.id ~= client_id
        end)
        :totable()
      if #clients == 0 then
        bufstates[bufnr] = {
          client_ranges = {},
          row_level = {},
          row_kinds = {},
          row_text = {},
        }
      end

      foldupdate(bufnr)
    end,
  })
  api.nvim_create_autocmd('LspAttach', {
    group = augroup_setup,
    buffer = bufnr,
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      if client:supports_method(vim.lsp.protocol.Methods.textDocument_foldingRange, bufnr) then
        request(bufnr, client)
      end
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

  request(bufnr)

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

---@param kind lsp.FoldingRangeKind
---@param winid? integer
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

  if not next(vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_foldingRange })) then
    return
  end
  ---@type lsp.FoldingRangeParams
  local params = { textDocument = util.make_text_document_params(bufnr) }
  vim.lsp.buf_request_all(bufnr, ms.textDocument_foldingRange, params, function(...)
    multi_handler(...)
    foldclose(kind, winid)
  end)
end

---@return string
function M.foldtext()
  local bufnr = api.nvim_get_current_buf()
  local lnum = vim.v.foldstart
  local row = lnum - 1
  local bufstate = bufstates[bufnr]
  if bufstate and bufstate.row_text[row] then
    return bufstate.row_text[row]
  end
  return vim.fn.getline(lnum)
end

---@param lnum? integer
---@return string level
function M.foldexpr(lnum)
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
