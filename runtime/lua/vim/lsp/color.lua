local color = require 'vim.color'
local highlight = require 'vim.highlight'
local validate = vim.validate
local api = vim.api

local document_color_ns = api.nvim_create_namespace("vim_lsp_documentColor")

local M = {}

--- Changes the guibg to @rgb for the text in @range. Also changes the guifg to
--- either #ffffff or #000000 based on which makes the text easier to read for
--- the given guibg
---
--@param bufnr (number) buffer handle
--@param range (table) with the structure:
--       {start={line=<number>,character=<number>}, end={line=<number>,character=<number>}}
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
local function highlight_background(bufnr, range, rgb)
    local hex = color.rgb_to_hex(rgb)
    local fghex = color.perceived_lightness(rgb) < 50 and 'ffffff' or '000000'

    local hlname = string.format('LspDocumentColorBackground%s', hex)
    api.nvim_command(string.format('highlight %s guibg=#%s guifg=#%s', hlname, hex, fghex))

    local start_pos = {range["start"]["line"], range["start"]["character"]}
    local end_pos = {range["end"]["line"], range["end"]["character"]}
    highlight.range(bufnr, document_color_ns, hlname, start_pos, end_pos)
end

--- Changes the guifg to @rgb for the text in @range.
---
--@param bufnr (number) buffer handle
--@param range (table) with the structure:
--       {start={line=<number>,character=<number>}, end={line=<number>,character=<number>}}
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
local function highlight_foreground(bufnr, range, rgb)
    local hex = color.rgb_to_hex(rgb)

    local hlname = string.format('LspDocumentColorForeground%s', hex)
    api.nvim_command(string.format('highlight %s guifg=#%s', hlname, hex))

    local start_pos = {range["start"]["line"], range["start"]["character"]}
    local end_pos = {range["end"]["line"], range["end"]["character"]}
    highlight.range(bufnr, document_color_ns, hlname, start_pos, end_pos)
end

--- Adds virtual text with the color @rgb and the text @virtual_text_str on
--- the last line of the @range.
---
--@param bufnr (number) buffer handle
--@param range (table) with the structure:
--       {start={line=<number>,character=<number>}, end={line=<number>,character=<number>}}
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
--@param virtual_text_str (string) to display as virtual text and color
local function highlight_virtual_text(bufnr, range, rgb, virtual_text_str)
    local hex = color.rgb_to_hex(rgb)

    local hlname = string.format('LspDocumentColorVirtualText%s', hex)
    api.nvim_command(string.format('highlight %s guifg=#%s', hlname, hex))

    local line = range['end']['line']
    api.nvim_buf_set_virtual_text(bufnr, document_color_ns, line, {{virtual_text_str, hlname}}, {})
end

--- Clears the previous document colors and adds the new document colors from @result.
--- Follows the same signature as :h lsp-handler
function M.on_document_color(_, _, result, _, bufnr, config)
  -- TODO debounce it and document
  if not bufnr then return end
  M.buf_clear_highlights(bufnr)
  if not result then return end
  M.buf_highlight(bufnr, result, config)
end

--- Shows a list of document colors for a certain buffer.
---
--@param bufnr buffer id
--@param color_infos Table of `ColorInformation` objects to highlight.
--       See https://microsoft.github.io/language-server-protocol/specification#textDocument_documentColor
function M.buf_highlight(bufnr, color_infos, config)
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
      highlight_background(bufnr, range, rgb)
    end

    if config.foreground then
      highlight_foreground(bufnr, range, rgb)
    end

    if config.virtual_text then
      highlight_virtual_text(bufnr, range, rgb, config.virtual_text_str)
    end
  end
end

--- Removes document color highlights from a buffer.
---
--@param bufnr buffer id
function M.buf_clear_highlights(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    api.nvim_buf_clear_namespace(bufnr, document_color_ns, 0, -1)
end

return M
