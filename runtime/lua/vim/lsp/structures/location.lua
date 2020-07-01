local highlight = require('vim.highlight')
local util = require('vim.lsp.util')

local Position = require('vim.lsp.structures.position')

local api = vim.api

local get_first_or_only = function(item)
  if item == nil or type(item) ~= 'table' then
    return item
  end

  if not vim.tbl_islist(item) then
    return item
  else
    return item[1]
  end
end

--- Set of functions for working with `Location` objects.
--- This set of functions also handles working with `LocationLink` for convenience.
---
--@ref https://microsoft.github.io/language-server-protocol/specifications/specification-current/#location
--@ref https://microsoft.github.io/language-server-protocol/specifications/specification-current/#locationLink
local Location = {}

Location.to_uri_and_range = function(location)
  local uri = location.targetUri or location.uri
  local range = location.targetSelectionRange or location.range

  assert(uri and range, string.format("Locations must have `uri` and `range`: %s", vim.inspect(location)))
  return uri, range
end

--[[

local cbs = { Location.jump, Location.highlight, ... }

jump(), highlight(), ...
if jump() == false then stop doing stuff end

--]]

Location.jump = function(location)
  location = get_first_or_only(location)

  if location == nil then
    return false, "Location not found"
  end

  local uri, range = Location.to_uri_and_range(location)
  if uri == nil then return end

  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  -- Save position in jumplist
  vim.cmd "normal! m'"

  -- Push a new item into tagstack
  local from = {vim.fn.bufnr('%'), vim.fn.line('.'), vim.fn.col('.'), 0}
  local items = {{tagname=vim.fn.expand('<cword>'), from=from}}
  vim.fn.settagstack(vim.fn.win_getid(), {items=items}, 't')

  --- Jump to new location (adjusting for UTF-16 encoding of characters)
  api.nvim_set_current_buf(bufnr)
  api.nvim_buf_set_option(bufnr, 'buflisted', true)

  local row, col = unpack(Position.to_pos(range.start, bufnr))

  api.nvim_win_set_cursor(0, {row + 1, col})
end

Location.preview = function(location, lines_above, lines_below)
  location = get_first_or_only(location)
  if not location then
    return false
  end

  lines_above = lines_above or 0
  lines_below = lines_below or 0

  local uri, range = Location.to_uri_and_range(location)
  if uri == nil then return end

  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  local contents = api.nvim_buf_get_lines(
    bufnr,
    math.max(0, range.start.line - lines_above),
    range["end"].line + 1 + lines_below,
    false
  )
  local filetype = api.nvim_buf_get_option(bufnr, 'filetype')

  return util.open_floating_preview(contents, filetype)
end

Location.highlight = function(location, higroup, timeout)
  location = get_first_or_only(location)
  if not location then
    return false
  end

  higroup = higroup or "IncSearch"
  timeout = timeout or 250

  local uri, range = Location.to_uri_and_range(location)
  if uri == nil then return end

  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  local highlight_ns = api.nvim_create_namespace('')

  highlight.range(
    bufnr,
    highlight_ns,
    higroup,
    Position.to_pos(range["start"]),
    Position.to_pos(range["end"])
  )

  vim.defer_fn(function() api.nvim_buf_clear_namespace(bufnr, highlight_ns, 0, -1) end, timeout)
end


Location.set_qflist = function(location, open_list)
  local items = util.locations_to_items(location)
  if vim.tbl_isempty(items) then
    return false
  end

  util.set_qflist(items)

  if open_list then
    api.nvim_command("copen")
    api.nvim_command("wincmd p")
  end
end

Location.set_loclist = function(location, open_list)
  local items = util.locations_to_items(location)
  if vim.tbl_isempty(items) then
    return false
  end

  util.set_loclist(items)

  if open_list then
    api.nvim_command("lopen")
    api.nvim_command("wincmd p")
  end
end

return Location
