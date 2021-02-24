local color = require 'vim.color'
local highlight = require 'vim.highlight'
local validate = vim.validate
local api = vim.api

local client_ns = {}

local M = {}

--- Returns the namespace for the given client_id
---
--@param client_id number client id
--@return number
local function get_client_ns(client_id)
  if client_ns[client_id] == nil then
    client_ns[client_id] = api.nvim_create_namespace('vim_lsp_documentColor_'..client_id)
  end
  return client_ns[client_id]
end

--- Changes the guibg to @rgb for the text in @range. Also changes the guifg to
--- either #ffffff or #000000 based on which makes the text easier to read for
--- the given guibg
---
--@param client_id number client id
--@param bufnr (number) buffer handle
--@param range (table) with the structure:
--       {start={line=<number>,character=<number>}, end={line=<number>,character=<number>}}
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
local function color_background(client_id, bufnr, range, rgb)
  local hex = color.rgb_to_hex(rgb)
  local fghex = color.perceived_lightness(rgb) < 50 and 'ffffff' or '000000'

  local hlname = string.format('LspDocumentColorBackground%s', hex)
  api.nvim_command(string.format('highlight %s guibg=#%s guifg=#%s', hlname, hex, fghex))

  local start_pos = {range["start"]["line"], range["start"]["character"]}
  local end_pos = {range["end"]["line"], range["end"]["character"]}
  highlight.range(bufnr, get_client_ns(client_id), hlname, start_pos, end_pos)
end

--- Changes the guifg to @rgb for the text in @range.
---
--@param client_id number client id
--@param bufnr (number) buffer handle
--@param range (table) with the structure:
--       {start={line=<number>,character=<number>}, end={line=<number>,character=<number>}}
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
local function color_foreground(client_id, bufnr, range, rgb)
  local hex = color.rgb_to_hex(rgb)

  local hlname = string.format('LspDocumentColorForeground%s', hex)
  api.nvim_command(string.format('highlight %s guifg=#%s', hlname, hex))

  local start_pos = {range["start"]["line"], range["start"]["character"]}
  local end_pos = {range["end"]["line"], range["end"]["character"]}
  highlight.range(bufnr, get_client_ns(client_id), hlname, start_pos, end_pos)
end

--- Adds virtual text with the color @rgb and the text @virtual_text_str on
--- the last line of the @range.
---
--@param client_id number client id
--@param bufnr (number) buffer handle
--@param range (table) with the structure:
--       {start={line=<number>,character=<number>}, end={line=<number>,character=<number>}}
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
--@param virtual_text_str (string) to display as virtual text and color
local function color_virtual_text(client_id, bufnr, range, rgb, virtual_text_str)
  local hex = color.rgb_to_hex(rgb)

  local hlname = string.format('LspDocumentColorVirtualText%s', hex)
  api.nvim_command(string.format('highlight %s guifg=#%s', hlname, hex))

  local line = range['end']['line']
  api.nvim_buf_set_virtual_text(bufnr, get_client_ns(client_id), line, {{virtual_text_str, hlname}}, {})
end

--- Clears the previous document colors and adds the new document colors from @result.
--- Follows the same signature as :h lsp-handler
function M.on_document_color(_, _, result, client_id, bufnr, config)
  if not bufnr or not client_id then return end
  M.buf_clear_color(client_id, bufnr)
  if not result then return end
  M.buf_color(client_id, bufnr, result, config)
end

--- Shows a list of document colors for a certain buffer.
---
--@param client_id number client id
--@param bufnr buffer id
--@param color_infos Table of `ColorInformation` objects to highlight.
--       See https://microsoft.github.io/language-server-protocol/specification#textDocument_documentColor
function M.buf_color(client_id, bufnr, color_infos, config)
  validate {
    bufnr = {bufnr, 'n', false},
    color_infos = {color_infos, 't', false},
    config = {config, 't', true},
  }
  if not color_infos or not bufnr then return end

  config = vim.lsp._with_extend('vim.lsp.color.on_document_color', {
      background = false,
      foreground = false,
      virtual_text = false,
      virtual_text_str = '■',
      background_color = vim.color.decode_24bit_rgb(vim.api.nvim_get_hl_by_name('Normal', true)['background']),
    }, config)

  for _, color_info in ipairs(color_infos) do
    local rgba, range = color_info.color, color_info.range
    local r, g, b, a = rgba.red*255, rgba.green*255, rgba.blue*255, rgba.alpha
    local rgb = color.rgba_to_rgb({r=r, g=g, b=b, a=a}, config.background_color)

    if config.background then
      color_background(client_id, bufnr, range, rgb)
    end

    if config.foreground then
      color_foreground(client_id, bufnr, range, rgb)
    end

    if config.virtual_text then
      color_virtual_text(client_id, bufnr, range, rgb, config.virtual_text_str)
    end
  end
end

--- Removes document color highlights from a buffer.
---
--@param client_id number client id
--@param bufnr buffer id
function M.buf_clear_color(client_id, bufnr)
  validate {
    client_id = {client_id, 'n', true},
    bufnr = {bufnr, 'n', true}
  }
  api.nvim_buf_clear_namespace(bufnr, get_client_ns(client_id), 0, -1)
end

return M
