local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api
local M = {}

---@class lsp.inlay_hint.bufstate
---@field version? integer
---@field client_hint? table<integer, table<integer, lsp.InlayHint[]>> client_id -> (lnum -> hints)
---@field applied table<integer, integer> Last version of hints applied to this line
---@field enabled boolean Whether inlay hints are enabled for this buffer
---@type table<integer, lsp.inlay_hint.bufstate>
local bufstates = {}

local namespace = api.nvim_create_namespace('vim_lsp_inlayhint')
local augroup = api.nvim_create_augroup('vim_lsp_inlayhint', {})

--- |lsp-handler| for the method `textDocument/inlayHint`
--- Store hints for a specific buffer and client
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
  local bufstate = bufstates[bufnr]
  if not bufstate or not bufstate.enabled then
    return
  end
  if not (bufstate.client_hint and bufstate.version) then
    bufstate.client_hint = vim.defaulttable()
    bufstate.version = ctx.version
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

--- |lsp-handler| for the method `textDocument/inlayHint/refresh`
---@private
function M.on_refresh(err, _, ctx, _)
  if err then
    return vim.NIL
  end
  for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(ctx.client_id)) do
    for _, winid in ipairs(api.nvim_list_wins()) do
      if api.nvim_win_get_buf(winid) == bufnr then
        local bufstate = bufstates[bufnr]
        if bufstate then
          util._refresh(ms.textDocument_inlayHint, { bufnr = bufnr })
          break
        end
      end
    end
  end

  return vim.NIL
end

--- Clear inlay hints
---@param bufnr (integer) Buffer handle, or 0 for current
local function clear(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  if not bufstates[bufnr] then
    return
  end
  local bufstate = bufstates[bufnr]
  local client_lens = (bufstate or {}).client_hint or {}
  local client_ids = vim.tbl_keys(client_lens)
  for _, iter_client_id in ipairs(client_ids) do
    if bufstate then
      bufstate.client_hint[iter_client_id] = {}
    end
  end
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  api.nvim__buf_redraw_range(bufnr, 0, -1)
end

--- Disable inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
local function disable(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  clear(bufnr)
  if bufstates[bufnr] then
    bufstates[bufnr] = { enabled = false, applied = {} }
  end
end

--- Enable inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
local function enable(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local bufstate = bufstates[bufnr]
  if not bufstate then
    bufstates[bufnr] = { applied = {}, enabled = true }
    api.nvim_create_autocmd('LspNotify', {
      buffer = bufnr,
      callback = function(opts)
        if
          opts.data.method ~= ms.textDocument_didChange
          and opts.data.method ~= ms.textDocument_didOpen
        then
          return
        end
        if bufstates[bufnr] and bufstates[bufnr].enabled then
          util._refresh(ms.textDocument_inlayHint, { bufnr = bufnr })
        end
      end,
      group = augroup,
    })
    util._refresh(ms.textDocument_inlayHint, { bufnr = bufnr })
    api.nvim_buf_attach(bufnr, false, {
      on_reload = function(_, cb_bufnr)
        clear(cb_bufnr)
        if bufstates[cb_bufnr] and bufstates[cb_bufnr].enabled then
          bufstates[cb_bufnr].applied = {}
          util._refresh(ms.textDocument_inlayHint, { bufnr = cb_bufnr })
        end
      end,
      on_detach = function(_, cb_bufnr)
        disable(cb_bufnr)
      end,
    })
    api.nvim_create_autocmd('LspDetach', {
      buffer = bufnr,
      callback = function()
        disable(bufnr)
      end,
      group = augroup,
    })
  else
    bufstate.enabled = true
    util._refresh(ms.textDocument_inlayHint, { bufnr = bufnr })
  end
end

--- Toggle inlay hints for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
local function toggle(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local bufstate = bufstates[bufnr]
  if bufstate and bufstate.enabled then
    disable(bufnr)
  else
    enable(bufnr)
  end
end

api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    local bufstate = bufstates[bufnr]
    if not bufstate then
      return
    end

    if bufstate.version ~= util.buf_versions[bufnr] then
      return
    end
    local hints_by_client = bufstate.client_hint

    for lnum = topline, botline do
      if bufstate.applied[lnum] ~= bufstate.version then
        api.nvim_buf_clear_namespace(bufnr, namespace, lnum, lnum + 1)
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
            local vt = {}
            if hint.paddingLeft then
              vt[#vt + 1] = { ' ' }
            end
            vt[#vt + 1] = { text, 'LspInlayHint' }
            if hint.paddingRight then
              vt[#vt + 1] = { ' ' }
            end
            api.nvim_buf_set_extmark(bufnr, namespace, lnum, hint.position.character, {
              virt_text_pos = 'inline',
              ephemeral = false,
              virt_text = vt,
            })
          end
        end
        bufstate.applied[lnum] = bufstate.version
      end
    end
  end,
})

return setmetatable(M, {
  __call = function(_, bufnr, enable_)
    vim.validate({ enable = { enable_, { 'boolean', 'nil' } }, bufnr = { bufnr, 'number' } })
    if enable_ then
      enable(bufnr)
    elseif enable_ == false then
      disable(bufnr)
    else
      toggle(bufnr)
    end
  end,
})
