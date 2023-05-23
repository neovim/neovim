local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local M = {}

---@class lsp._inlay_hint.bufstate
---@field version integer
---@field client_hint table<integer, table<integer, lsp.InlayHint[]>> client_id -> (lnum -> hints)

---@type table<integer, lsp._inlay_hint.bufstate>
local hint_cache_by_buf = setmetatable({}, {
  __index = function(t, b)
    local key = b > 0 and b or api.nvim_get_current_buf()
    return rawget(t, key)
  end,
})

local namespace = api.nvim_create_namespace('vim_lsp_inlayhint')

M.__explicit_buffers = {}

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
--- Resolves unresolved hints
---@private
function M.on_inlayhint(err, result, ctx, _)
  if err then
    local _ = log.error() and log.error('inlayhint', err)
    return
  end
  local bufnr = ctx.bufnr
  if util.buf_versions[bufnr] ~= ctx.version then
    return
  end
  local client_id = ctx.client_id
  if not result then
    return
  end
  local bufstate = hint_cache_by_buf[bufnr]
  if not bufstate then
    bufstate = {
      client_hint = vim.defaulttable(),
      version = ctx.version,
    }
    hint_cache_by_buf[bufnr] = bufstate
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(_, b)
        api.nvim_buf_clear_namespace(b, namespace, 0, -1)
        hint_cache_by_buf[b] = nil
      end,
      on_reload = function(_, b)
        api.nvim_buf_clear_namespace(b, namespace, 0, -1)
        hint_cache_by_buf[b] = nil
      end,
    })
  end
  local hints_by_client = bufstate.client_hint
  local client = vim.lsp.get_client_by_id(client_id)

  local new_hints_by_lnum = vim.defaulttable()
  local num_unprocessed = #result
  if num_unprocessed == 0 then
    hints_by_client[client_id] = {}
    bufstate.version = ctx.version
    api.nvim__buf_redraw_range(bufnr, 0, -1)
    return
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  ---@private
  local function pos_to_byte(position)
    local col = position.character
    if col > 0 then
      local line = lines[position.line + 1] or ''
      local ok, convert_result
      ok, convert_result = pcall(util._str_byteindex_enc, line, col, client.offset_encoding)
      if ok then
        return convert_result
      end
      return math.min(#line, col)
    end
    return col
  end

  for _, hint in ipairs(result) do
    local lnum = hint.position.line
    hint.position.character = pos_to_byte(hint.position)
    table.insert(new_hints_by_lnum[lnum], hint)
  end

  hints_by_client[client_id] = new_hints_by_lnum
  bufstate.version = ctx.version
  api.nvim__buf_redraw_range(bufnr, 0, -1)
end

---@private
local function resolve_bufnr(bufnr)
  return bufnr == 0 and api.nvim_get_current_buf() or bufnr
end

--- Refresh inlay hints for a buffer
---
--- It is recommended to trigger this using an autocmd or via keymap.
---@param opts (nil|table) Optional arguments
---  - bufnr (integer, default: 0): Buffer whose hints to refresh
---  - only_visible (boolean, default: false): Whether to only refresh hints for the visible regions of the buffer
---
--- Example:
--- <pre>vim
---   autocmd BufEnter,InsertLeave,BufWritePost <buffer> lua vim.lsp._inlay_hint.refresh()
--- </pre>
---
---@private
function M.refresh(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0
  local only_visible = opts.only_visible or false
  bufnr = resolve_bufnr(bufnr)
  M.__explicit_buffers[bufnr] = true
  local buffer_windows = {}
  for _, winid in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(winid) == bufnr then
      table.insert(buffer_windows, winid)
    end
  end
  for _, window in ipairs(buffer_windows) do
    local first = vim.fn.line('w0', window)
    local last = vim.fn.line('w$', window)
    local params = {
      textDocument = util.make_text_document_params(bufnr),
      range = {
        start = { line = first - 1, character = 0 },
        ['end'] = { line = last, character = 0 },
      },
    }
    vim.lsp.buf_request(bufnr, 'textDocument/inlayHint', params)
  end
  if not only_visible then
    local params = {
      textDocument = util.make_text_document_params(bufnr),
      range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = api.nvim_buf_line_count(bufnr), character = 0 },
      },
    }
    vim.lsp.buf_request(bufnr, 'textDocument/inlayHint', params)
  end
end

--- Clear inlay hints
---
---@param client_id integer|nil filter by client_id. All clients if nil
---@param bufnr integer|nil filter by buffer. All buffers if nil
---@private
function M.clear(client_id, bufnr)
  local buffers = bufnr and { resolve_bufnr(bufnr) } or vim.tbl_keys(hint_cache_by_buf)
  for _, iter_bufnr in ipairs(buffers) do
    M.__explicit_buffers[iter_bufnr] = false
    local bufstate = hint_cache_by_buf[iter_bufnr]
    local client_lens = (bufstate or {}).client_hint or {}
    local client_ids = client_id and { client_id } or vim.tbl_keys(client_lens)
    for _, iter_client_id in ipairs(client_ids) do
      if bufstate then
        bufstate.client_hint[iter_client_id] = {}
      end
    end
    api.nvim_buf_clear_namespace(iter_bufnr, namespace, 0, -1)
  end
  vim.cmd('redraw!')
end

api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    local bufstate = hint_cache_by_buf[bufnr]
    if not bufstate then
      return
    end

    if bufstate.version ~= util.buf_versions[bufnr] then
      return
    end
    local hints_by_client = bufstate.client_hint
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    for lnum = topline, botline do
      for _, hints_by_lnum in pairs(hints_by_client) do
        local line_hints = hints_by_lnum[lnum] or {}
        for _, hint in pairs(line_hints) do
          local text = ''
          if type(hint.label) == 'string' then
            text = hint.label
          else
            for _, part in ipairs(hint.label) do
              text = text .. part.value
            end
          end
          if hint.paddingLeft then
            text = ' ' .. text
          end
          if hint.paddingRight then
            text = text .. ' '
          end
          api.nvim_buf_set_extmark(bufnr, namespace, lnum, hint.position.character, {
            virt_text_pos = 'inline',
            ephemeral = false,
            virt_text = {
              { text, 'LspInlayHint' },
            },
            hl_mode = 'combine',
          })
        end
      end
    end
  end,
})

return M
