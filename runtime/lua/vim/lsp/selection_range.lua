local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

local M = {}

local augroup = api.nvim_create_augroup('vim_lsp_selection_range', {})

---@param winid integer
---@param count integer
local function select(winid, count)
  local bufnr = api.nvim_win_get_buf(winid)
  ---@type lsp.Range[]
  local ranges = vim.b[bufnr].lsp_selection_ranges
  if not ranges then
    return false
  end

  ---@type integer
  local selected = vim.b[bufnr].lsp_selection_index
  ---@type integer
  local index

  if selected then
    index = selected + count
  else
    index = count

    if api.nvim_get_mode().mode:match('^[in]$') then
      vim.cmd.normal({ 'v', bang = true })
    end
    api.nvim_create_autocmd('ModeChanged', {
      group = augroup,
      once = true,
      pattern = '*:[in]',
      callback = function()
        vim.b[bufnr].lsp_selection_ranges = nil
        vim.b[bufnr].lsp_selection_index = nil
      end,
    })
  end

  index = math.min(math.max(1, index), #ranges)
  local range = ranges[index]
  api.nvim_win_set_cursor(winid, {
    range['start'].line + 1,
    range['start'].character,
  })
  vim.cmd.normal({ 'o', bang = true })
  api.nvim_win_set_cursor(winid, {
    range['end'].line + 1,
    range['end'].character,
  })
  vim.b[bufnr].lsp_selection_index = index

  return true
end

---@param selection lsp.SelectionRange
---@return fun(): lsp.Range?
local function parent(selection)
  ---@diagnostic disable-next-line: missing-fields
  selection = { parent = selection }
  return function()
    selection = selection.parent
    return selection and selection.range
  end
end

---@param bufnr integer
---@param selections lsp.SelectionRange[]
---@param encodings "utf-8" | "utf-16" | "utf-32"[]
local function merge(bufnr, selections, encodings)
  ---@type lsp.Range[]
  local ranges = {}

  --TODO: multi-client support
  for i = 1, #selections do
    local selection = selections[i]
    local encoding = encodings[i]

    for range in parent(selection) do
      local start_row = range['start'].line
      local start_col = range['start'].character
      local end_row = range['end'].line
      local end_col = range['end'].character

      if not (start_row == end_row and start_col == end_col) then
        range['start'].character = vim.str_byteindex(
          api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, true)[1],
          encoding,
          start_col,
          false
        )

        if end_col == 0 then
          end_row = end_row - 1
          end_col = #api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, true)[1]
          range['end'] = {
            line = end_row,
            character = end_col,
          }
        else
          end_col = end_col - 1
          range['end'].character = vim.str_byteindex(
            api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, true)[1],
            encoding,
            end_col,
            false
          )
        end

        ranges[#ranges + 1] = range
      end
    end
  end

  return ranges
end

---@class vim.lsp.selection_range.ExpandOpts
---@inlinedoc
---
--- Window ID
--- (default: current window)
---@field winid? integer
---
--- Cursor position as a `(row, col)` tuple.
--- See |nvim_win_get_cursor()|.
--- (default: current cursor position)
---@field pos? [integer, integer]
---
--- Number of times to expand the selection.
--- (default: 1)
---@field count? integer

--- Create or expand a selection.
---@param opts? vim.lsp.selection_range.ExpandOpts
function M.expand(opts)
  opts = opts or {}
  local winid = opts.winid or api.nvim_get_current_win()
  local pos = opts.pos or api.nvim_win_get_cursor(winid)
  local count = opts.count or 1
  if select(winid, count) then
    return
  end

  local bufnr = api.nvim_win_get_buf(winid)
  local row, col = unpack(pos) ---@type integer, integer
  row = row - 1

  vim.lsp.buf_request_all(
    bufnr,
    ms.textDocument_selectionRange,
    function(client)
      local line = row
      local character = vim.str_utfindex(
        api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1],
        client.offset_encoding,
        col,
        false
      )

      ---@type lsp.SelectionRangeParams
      return {
        textDocument = util.make_text_document_params(bufnr),
        positions = { { line = line, character = character } },
      }
    end,

    ---@param results
    ---|table<integer, { err?: lsp.ResponseError, result?: lsp.SelectionRange[] }>
    ---@type lsp.MultiHandler
    function(results)
      ---@type lsp.SelectionRange[]
      local selections = {}
      ---@type "utf-8"|"utf-16"|"utf-32"[]
      local encodings = {}

      for client_id, result in pairs(results) do
        if result.err then
          log.error(result.err)
        elseif result.result then
          local client = assert(vim.lsp.get_client_by_id(client_id))
          selections[#selections + 1] = result.result[1]
          encodings[#encodings + 1] = client.offset_encoding
        end
      end

      local ranges = merge(bufnr, selections, encodings)
      if #ranges ~= 0 then
        vim.b[bufnr].lsp_selection_ranges = ranges
      end

      select(winid, 1)
    end
  )
end

---@class vim.lsp.selection_range.ShrinkOpts
---@inlinedoc
---
--- Window ID
--- (default: current window)
---@field winid? integer
---
--- Number of times to shrink the selection.
--- (default: 1)
---@field count? integer

--- Shrink the previous selection.
---@param opts? vim.lsp.selection_range.ShrinkOpts
function M.shrink(opts)
  opts = opts or {}
  local winid = opts.winid or api.nvim_get_current_win()
  local count = opts.count or 1
  select(winid, -count)
end

return M
