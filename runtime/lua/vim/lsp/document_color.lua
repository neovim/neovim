--- @brief This module provides LSP support for highlighting color references in a document.
--- Highlighting is enabled by default.

local api = vim.api
local lsp = vim.lsp
local util = lsp.util
local Capability = require('vim.lsp._capability')

local M = {}

--- @class (private) vim.lsp.document_color.HighlightInfo
--- @field lsp_info lsp.ColorInformation Unprocessed LSP color information
--- @field hex_code string Resolved HEX color
--- @field range vim.Range Range of the highlight
--- @field hl_group? string Highlight group name. Won't be present if the style is a custom function.

--- @class (private) vim.lsp.document_color.ClientState
--- @field namespace integer Extmark namespace for this client
--- @field hl_info vim.lsp.document_color.HighlightInfo[] Processed highlight information
--- @field processed_version? integer Buffer version for which the color ranges correspond to
--- @field applied_version? integer Last buffer version for which we applied color ranges

--- @inlinedoc
--- @class vim.lsp.document_color.Opts
---
--- Highlight style. It can be one of the pre-defined styles, a string to be used as virtual text, or a
--- function that receives the buffer handle, the range (start line, start col, end line, end col) and
--- the resolved hex color. (default: `'background'`)
--- @field style? 'background'|'foreground'|'virtual'|string|fun(bufnr: integer, range: vim.Range, hex_code: string)

-- Default options.
--- @type vim.lsp.document_color.Opts
local document_color_opts = { style = 'background' }

--- @param color string
local function get_contrast_color(color)
  local r_s, g_s, b_s = color:match('^#(%x%x)(%x%x)(%x%x)$')
  if not (r_s and g_s and b_s) then
    error('Invalid color format: ' .. color)
  end
  local r = vim._assert_integer(r_s, 16)
  local g = vim._assert_integer(g_s, 16)
  local b = vim._assert_integer(b_s, 16)

  -- Source: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
  -- Using power 2.2 is a close approximation to full piecewise transform
  local R, G, B = (r / 255) ^ 2.2, (g / 255) ^ 2.2, (b / 255) ^ 2.2
  local is_bright = (0.2126 * R + 0.7152 * G + 0.0722 * B) > 0.5
  return is_bright and '#000000' or '#ffffff'
end

--- Returns the hex string representing the given LSP color.
--- @param color lsp.Color
--- @return string
local function get_hex_code(color)
  -- The RGB values in lsp.Color are in the [0-1] range, but we want them to be in the [0-255] range instead.
  --- @param n number
  color = vim.tbl_map(function(n)
    return math.floor((n * 255) + 0.5)
  end, color)

  return ('#%02x%02x%02x'):format(color.red, color.green, color.blue):lower()
end

--- Cache of the highlight groups that we've already created.
--- @type table<string, true>
local color_cache = {}

--- Gets or creates the highlight group for the given LSP color information.
---
--- @param hex_code string
--- @param style string
--- @return string
local function get_hl_group(hex_code, style)
  if style ~= 'background' then
    style = 'foreground'
  end

  local hl_name = ('LspDocumentColor_%s_%s'):format(hex_code:sub(2), style)

  if not color_cache[hl_name] then
    if style == 'background' then
      api.nvim_set_hl(0, hl_name, { bg = hex_code, fg = get_contrast_color(hex_code) })
    else
      api.nvim_set_hl(0, hl_name, { fg = hex_code })
    end

    color_cache[hl_name] = true
  end

  return hl_name
end

--- @class (private) vim.lsp.document_color.Provider : vim.lsp.Capability
--- @field active table<integer, vim.lsp.document_color.Provider?>
--- @field client_state table<integer, vim.lsp.document_color.ClientState?>
local Provider = {
  name = 'document_color',
  method = 'textDocument/documentColor',
  active = {},
}
Provider.__index = Provider
setmetatable(Provider, Capability)
Capability.all[Provider.name] = Provider

--- @package
--- @param bufnr integer
--- @return vim.lsp.document_color.Provider
function Provider:new(bufnr)
  --- @type vim.lsp.document_color.Provider
  self = Capability.new(self, bufnr)

  api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      local provider = Provider.active[buf]
      if not provider then
        return true
      end
      provider:request()
    end,
    on_reload = function(_, buf)
      local provider = Provider.active[buf]
      if provider then
        provider:clear()
        provider:request()
      end
    end,
    on_detach = function(_, buf)
      local provider = Provider.active[buf]
      if provider then
        provider:destroy()
      end
    end,
  })

  api.nvim_create_autocmd('ColorScheme', {
    group = self.augroup,
    desc = 'Refresh document_color',
    callback = function()
      color_cache = {}
      local provider = Provider.active[bufnr]
      if provider then
        provider:clear()
        provider:request()
      end
    end,
  })

  return self
end

--- @package
--- @param client_id integer
function Provider:on_attach(client_id)
  self.client_state[client_id] = {
    namespace = api.nvim_create_namespace('nvim.lsp.document_color:' .. client_id),
    hl_info = {},
  }
  self:request(client_id)
end

--- @package
--- @param client_id integer
function Provider:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
    self.client_state[client_id] = nil
  end
  api.nvim__redraw({ buf = self.bufnr, valid = true, flush = false })
end

--- |lsp-handler| for the `textDocument/documentColor` method.
---
--- @package
--- @param err? lsp.ResponseError
--- @param result? lsp.ColorInformation[]
--- @param ctx lsp.HandlerContext
function Provider:handler(err, result, ctx)
  if err then
    lsp.log.error('document_color', err)
    return
  end

  local state = self.client_state[ctx.client_id]
  if not state then
    return
  end

  if
    util.buf_versions[self.bufnr] ~= ctx.version
    or not result
    or not api.nvim_buf_is_loaded(self.bufnr)
  then
    return
  end

  local hl_infos = {} --- @type vim.lsp.document_color.HighlightInfo[]
  local style = document_color_opts.style
  local position_encoding = assert(lsp.get_client_by_id(ctx.client_id)).offset_encoding
  for _, res in ipairs(result) do
    local range = vim.range.lsp(self.bufnr, res.range, position_encoding)
    local hex_code = get_hex_code(res.color)
    --- @type vim.lsp.document_color.HighlightInfo
    local hl_info = { range = range, hex_code = hex_code, lsp_info = res }

    if type(style) == 'string' then
      hl_info.hl_group = get_hl_group(hex_code, style)
    end

    table.insert(hl_infos, hl_info)
  end

  state.hl_info = hl_infos
  state.processed_version = ctx.version

  api.nvim__redraw({ buf = self.bufnr, valid = true, flush = false })
end

--- @package
--- @param client_id? integer
function Provider:request(client_id)
  for id in pairs(self.client_state) do
    if not client_id or client_id == id then
      local client = assert(lsp.get_client_by_id(id))
      ---@type lsp.DocumentColorParams
      local params = { textDocument = util.make_text_document_params(self.bufnr) }
      client:request('textDocument/documentColor', params, function(...)
        self:handler(...)
      end, self.bufnr)
    end
  end
end

--- @package
function Provider:clear()
  for _, state in pairs(self.client_state) do
    state.hl_info = {}
    state.applied_version = nil
    api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
  end
  api.nvim__redraw({ buf = self.bufnr, valid = true, flush = false })
end

local document_color_ns = api.nvim_create_namespace('nvim.lsp.document_color')
api.nvim_set_decoration_provider(document_color_ns, {
  on_win = function(_, _, bufnr)
    local provider = Provider.active[bufnr]
    if not provider then
      return
    end

    local style = document_color_opts.style

    for _, state in pairs(provider.client_state) do
      if
        state.processed_version == util.buf_versions[bufnr]
        and state.processed_version ~= state.applied_version
      then
        api.nvim_buf_clear_namespace(bufnr, state.namespace, 0, -1)

        for _, hl in ipairs(state.hl_info) do
          if type(style) == 'function' then
            style(bufnr, hl.range, hl.hex_code)
          elseif style == 'foreground' or style == 'background' then
            api.nvim_buf_set_extmark(
              bufnr,
              state.namespace,
              hl.range.start.row,
              hl.range.start.col,
              {
                end_row = hl.range.end_.row,
                end_col = hl.range.end_.col,
                hl_group = hl.hl_group,
                strict = false,
              }
            )
          else
            -- Default swatch: \uf0c8
            local swatch = style == 'virtual' and ' ' or style
            api.nvim_buf_set_extmark(
              bufnr,
              state.namespace,
              hl.range.start.row,
              hl.range.start.col,
              {
                virt_text = { { swatch, hl.hl_group } },
                virt_text_pos = 'inline',
              }
            )
          end
        end

        state.applied_version = state.processed_version
      end
    end
  end,
})

--- @param provider vim.lsp.document_color.Provider
--- @return vim.lsp.document_color.HighlightInfo?, integer?
local function get_hl_info_under_cursor(provider)
  local cursor_row, cursor_col = unpack(api.nvim_win_get_cursor(0)) --- @type integer, integer
  cursor_row = cursor_row - 1 -- Convert to 0-based index
  local cursor_pos = vim.pos(cursor_row, cursor_col)

  for client_id, state in pairs(provider.client_state) do
    for _, hl in ipairs(state.hl_info) do
      if hl.range:has(cursor_pos) then
        return hl, client_id
      end
    end
  end
end

--- Select from a list of presentations for the color under the cursor.
function M.color_presentation()
  local bufnr = api.nvim_get_current_buf()
  local provider = Provider.active[bufnr]
  if not provider then
    vim.notify('documentColor is not enabled for this buffer.', vim.log.levels.WARN)
    return
  end

  local hl_info, client_id = get_hl_info_under_cursor(provider)
  if not hl_info or not client_id then
    vim.notify('No color information under cursor.', vim.log.levels.WARN)
    return
  end

  local uri = vim.uri_from_bufnr(bufnr)
  local client = assert(lsp.get_client_by_id(client_id))

  --- @type lsp.ColorPresentationParams
  local params = {
    textDocument = { uri = uri },
    color = hl_info.lsp_info.color,
    range = hl_info.range:to_lsp(client.offset_encoding),
  }

  --- @param result lsp.ColorPresentation[]
  client:request('textDocument/colorPresentation', params, function(err, result, ctx)
    if err then
      lsp.log.error('color_presentation', err)
      return
    end

    if
      util.buf_versions[bufnr] ~= ctx.version
      or not next(result)
      or not api.nvim_buf_is_loaded(bufnr)
      or not Provider.active[bufnr]
    then
      return
    end

    vim.ui.select(result, {
      kind = 'color_presentation',
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice then
        return
      end

      local text_edits = {} --- @type lsp.TextEdit[]
      if choice.textEdit then
        text_edits[#text_edits + 1] = choice.textEdit
      else
        -- If there's no textEdit, we should insert the label.
        text_edits[#text_edits + 1] = { range = params.range, newText = choice.label }
      end
      vim.list_extend(text_edits, choice.additionalTextEdits or {})

      util.apply_text_edits(text_edits, bufnr, client.offset_encoding)
    end)
  end, bufnr)
end

--- Query whether document colors are enabled in the {filter}ed scope.
---
---@param filter? vim.lsp.capability.enable.Filter
---@return boolean
function M.is_enabled(filter)
  return Capability.is_enabled('document_color', filter)
end

--- Enables or disables document color highlighting for the {filter}ed scope.
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
--- ```
---
---@param enable? boolean True to enable, false to disable. (default: `true`)
---@param filter? vim.lsp.capability.enable.Filter
---@param opts? vim.lsp.document_color.Opts
function M.enable(enable, filter, opts)
  vim.validate('opts', opts, 'table', true)

  if opts then
    document_color_opts = vim.tbl_extend('keep', opts, document_color_opts)
    -- Re-process highlights with new style and refresh active providers.
    for _, provider in pairs(Provider.active) do
      provider:clear()
      provider:request()
    end
  end

  Capability.enable('document_color', enable, filter)
end

Capability.enable('document_color', true)

return M
