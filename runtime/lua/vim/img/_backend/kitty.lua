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
  local terminal = require("vim.img._terminal")

  terminal.write(terminal.code.ESC .. "_G") -- Begin sequence
  terminal.write(data)                      -- Primary data
  terminal.write(terminal.code.ESC .. "\\") -- End sequence
end

---@param image vim.img.Image
---@param opts? vim.img.Backend.RenderOpts
function M.render(image, opts)
  local terminal = require("vim.img._terminal")

  if not image:is_loaded() then
    return
  end

  opts = opts or {}
  if opts.pos then
    terminal.cursor.move(opts.pos.col, opts.pos.row, true)
  end

  image:for_each_chunk(function(chunk, pos, has_more)
    local data = {}

    -- If at the beginning of our image, mark as a PNG to be
    -- transmitted and displayed immediately
    if pos == 1 then
      table.insert(data, "a=T,f=100,")

      local crop = opts.crop
      local size = opts.size

      if crop then
        table.insert(data, string.format(
          "x=%s,y=%s,w=%s,h=%s,",
          crop.x,
          crop.y,
          crop.width,
          crop.height
        ))
      end

      if size then
        table.insert(data, string.format(
          "c=%s,r=%s,",
          size.width,
          size.height
        ))
      end
    end

    -- If we are still sending chunks and not at the end
    if has_more then
      table.insert(data, "m=1")
    else
      table.insert(data, "m=0")
    end

    -- If we have a chunk available, write it
    if string.len(chunk) > 0 then
      table.insert(data, ";")
      table.insert(data, chunk)
    end

    write_seq(table.concat(data))
  end)

  if opts.pos then
    terminal.cursor.restore()
  end
end

return M
