---@class vim.img.KittyBackend: vim.img.Backend
local M = {}

---For kitty, we need to write an image in chunks
---
---Graphics codes are in this form:
---
---    <ESC>_G<control data>;<payload><ESC>\
---
---To stream data for a PNG, we specify the format `f=100`.
---
---To simultaneously transmit and display an image, we use `a=T`.
---
---Chunking data (such as from over a network) requires the
---specification of `m=0|1`, where all chunks must have a
---value of `1` except the very last chunk.
---@param data string
local function write_seq(data)
  local terminal = require('vim.img._terminal')

  terminal.write(terminal.code.ESC .. '_G') -- Begin sequence
  terminal.write(data) -- Primary data
  terminal.write(terminal.code.ESC .. '\\') -- End sequence
end

---Builds a header table of key value pairs.
---@param opts vim.img.Backend.RenderOpts
---@return table<string, string>
local function make_header(opts)
  ---@type table<string, string>
  local header = {}

  header['a'] = 'T'
  header['f'] = '100'

  local crop = opts.crop
  local size = opts.size

  if crop then
    header['x'] = tostring(crop.x)
    header['y'] = tostring(crop.y)
    header['w'] = tostring(crop.width)
    header['h'] = tostring(crop.height)
  end

  if size then
    header['c'] = tostring(size.width)
    header['r'] = tostring(size.height)
  end

  return header
end

---@param image vim.img.Image
---@param opts vim.img.Backend.RenderOpts
local function write_multipart_image(image, opts)
  image:for_each_chunk(function(chunk, pos, has_more)
    local data = {}

    -- If at the beginning of our image, mark as a PNG to be
    -- transmitted and displayed immediately
    if pos == 1 then
      -- Add an entry in our data to write out to the terminal
      -- that is "k=v," for the key-value entries from the header
      for key, value in pairs(make_header(opts)) do
        table.insert(data, key .. '=' .. value .. ',')
      end
    end

    -- If we are still sending chunks and not at the end
    if has_more then
      table.insert(data, 'm=1')
    else
      table.insert(data, 'm=0')
    end

    -- If we have a chunk available, write it
    if string.len(chunk) > 0 then
      table.insert(data, ';')
      table.insert(data, chunk)
    end

    write_seq(table.concat(data))
  end)
end

---@param image vim.img.Image
---@param opts? vim.img.Backend.RenderOpts
function M.render(image, opts)
  local terminal = require('vim.img._terminal')

  if not image:is_loaded() then
    return
  end

  opts = opts or {}
  if opts.pos then
    terminal.cursor.move(opts.pos.col, opts.pos.row, true)
  end

  write_multipart_image(image, opts)

  if opts.pos then
    terminal.cursor.restore()
  end
end

return M
