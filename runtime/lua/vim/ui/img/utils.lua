local M = {}

---@alias vim.ui.img.utils.Unit 'cell'|'pixel'

---@class vim.ui.img.utils.Codes
M.codes = {
  ---Hides the cursor from being shown in terminal.
  CURSOR_HIDE            = '\027[?25l',
  ---Restore cursor position based on last save.
  CURSOR_RESTORE         = '\0278',
  ---Save cursor position to be restored later.
  CURSOR_SAVE            = '\0277',
  ---Shows the cursor if it was hidden in terminal.
  CURSOR_SHOW            = '\027[?25h',
  ---Queries the terminal for its background color.
  QUERY_BACKGROUND_COLOR = '\027]11;?',
  ---Disables scrolling mode for sixel.
  SIXEL_SCROLL_DISABLE   = '\027[?80l',
  ---Disable synchronized output mode.
  SYNC_MODE_DISABLE      = '\027[?2026l',
  ---Enable synchronized output mode.
  SYNC_MODE_ENABLE       = '\027[?2026h',
}

---Generates the escape code to move the cursor.
---Rounds down the column and row values.
---@param opts {row:number, col:number}
---@return string
function M.codes.move_cursor(opts)
  return string.format(
    '\027[%s;%sH',
    math.floor(opts.row),
    math.floor(opts.col)
  )
end

---Wraps one or more escape sequences for use with tmux passthrough.
---@param s string
---@return string
function M.codes.escape_tmux_passthrough(s)
  return ('\027Ptmux;' .. string.gsub(s, '\027', '\027\027')) .. '\027\\'
end

---@class (exact) vim.ui.img.utils.Rgb
---@field bit 8|16 how many bits
---@field r integer
---@field g integer
---@field b integer

---Attempts to match the OSC 11 terminal response to get the RGB values.
---@param s string
---@return vim.ui.img.utils.Rgb|nil
function M.codes.match_osc_11_response(s)
  local r, g, b = string.match(s, '\027]11;rgb:(%x+)/(%x+)/(%x+)')
  if r and g and b then
    -- Some terminals return AA/BB/CC (8-bit color)
    -- and others return AAAA/BBBB/CCCC (16-bit color)
    local bit = 8
    if string.len(r) > 2 or string.len(g) > 2 or string.len(b) > 2 then
      bit = 16
    end

    -- Cast our hexidecimal values to integers
    local rn = tonumber("0x" .. r)
    local gn = tonumber("0x" .. g)
    local bn = tonumber("0x" .. b)

    if rn and gn and bn then
      return { bit = bit, r = rn, g = gn, b = bn }
    end
  end
end

---Queries the terminal for its background color using OSC 11.
---@param opts? {timeout?:integer, write?:fun(...:string)}
---@param on_color? fun(err:string|nil, color:vim.ui.img.utils.Rgb|nil)
---@return vim.ui.img.utils.Rgb|nil color, string|nil err
function M.query_term_background_color(opts, on_color)
  opts = opts or {}

  ---@type vim.ui.img.utils.Rgb|nil
  local color

  local timeout = opts.timeout or 1000
  local write = opts.write or function(...) io.stdout:write(...) end
  local timer = assert(vim.uv.new_timer())

  local id = vim.api.nvim_create_autocmd('TermResponse', {
    callback = function(args)
      local resp = args.data.sequence ---@type string
      local rgb = M.codes.match_osc_11_response(resp)
      if rgb then
        -- Cancel the timeout callback
        timer:stop()
        timer:close()

        vim.schedule(function()
          if on_color then
            on_color(nil, rgb)
          else
            color = rgb
          end
        end)
        return true
      end
    end
  })

  write(M.codes.QUERY_BACKGROUND_COLOR)

  if on_color then
    timer:start(timeout, 0, vim.schedule_wrap(function()
      pcall(vim.api.nvim_del_autocmd, id)
      on_color(string.format('terminal failed to respond after %sms', timeout))
    end))
  else
    local ok = vim.wait(timeout, function() return color ~= nil end)

    if not ok then
      pcall(vim.api.nvim_del_autocmd, id)
      return nil, string.format('terminal failed to respond after %sms', timeout)
    else
      return color
    end
  end
end

---Returns the hex string (e.g. #ABCDEF) representing the color of the background.
---
---Attempt to detect the background color in two ways:
---1. Check if our global Normal is available and use it
---2. Query the terminal for a background color
---
---If neither is available, we don't attempt to set
---the alpha pixels to a background color
---@param opts? {timeout?:integer, write?:fun(...:string)}
---@param on_color? fun(err:string|nil, color:string|nil)
---@return string|nil color, string|nil err
function M.query_bg_hex_str(opts, on_color)
  local bg = vim.api.nvim_get_hl(0, { name = 'Normal' }).bg
  local bg_color = bg and string.format('#%06x', bg)

  if bg_color and on_color then
    vim.schedule(function()
      on_color(nil, bg_color)
    end)
    return
  elseif bg_color then
    return bg_color
  end

  ---@param rgb vim.ui.img.utils.Rgb
  ---@return string
  local function convert_to_hex(rgb)
    local r = rgb.bit == 8 and rgb.r or ((rgb.r / 65535) * 255)
    local g = rgb.bit == 8 and rgb.g or ((rgb.g / 65535) * 255)
    local b = rgb.bit == 8 and rgb.b or ((rgb.b / 65535) * 255)
    return string.format('#%02x%02x%02x', r, g, b)
  end

  local rgb, err = M.query_term_background_color(opts, on_color and function(err, rgb)
    on_color(err, rgb and convert_to_hex(rgb))
  end)

  if rgb then
    return convert_to_hex(rgb)
  else
    return nil, err
  end
end

---Creates a writer that will wait to send all bytes together.
---@param opts? {use_chan_send?:boolean, map?:(fun(s:string):string), multi?:boolean, write?:fun(...:string)}
---@return vim.ui.img.utils.BatchWriter
function M.new_batch_writer(opts)
  opts = opts or {}

  ---@class vim.ui.img.utils.BatchWriter
  ---@field private __queue string[]
  local writer = {
    __queue = {},
  }

  ---Queues up bytes to be written later.
  ---@param ... string
  function writer.write(...)
    vim.list_extend(writer.__queue, { ... })
  end

  ---Queues up bytes to be written later, using a format string.
  ---@param s string|number
  ---@param ... any
  function writer.write_format(s, ...)
    writer.write(string.format(s, ...))
  end

  ---Writes immediately skipping queue.
  ---@param ... string
  function writer.write_fast(...)
    writer.__write(writer.__concat(...))
  end

  ---Clears any queued bytes without sending them.
  function writer.clear()
    writer.__queue = {}
  end

  ---Flushes the bytes, sending them all together.
  function writer.flush()
    -- If nothing in the queue, don't write anything at all
    if #writer.__queue == 0 then
      return
    end

    ---@type string
    local bytes

    -- If multi specified, instead of concatentating all of the
    -- bytes together, we instead map each individually
    --
    -- Otherwise, we combine all bytes together and then map
    if opts.multi then
      bytes = writer.__concat(unpack(writer.__queue))
    else
      bytes = writer.__concat(table.concat(writer.__queue))
    end

    writer.__queue = {}
    writer.__write(bytes)
  end

  ---Transforms multiple bytes into a single sequence, mapping
  ---each individual series of bytes if we have a map function.
  ---@param ... string
  ---@return string
  function writer.__concat(...)
    ---@param s string
    return table.concat(vim.tbl_map(function(s)
      return opts.map and opts.map(s) or s
    end, { ... }))
  end

  ---@private
  ---@param bytes string
  function writer.__write(bytes)
    -- Depending on the configuration, will write one of three ways:
    --
    -- 1. Writes bytes using `opts.write()`
    -- 2. Writes bytes to stdout using `vim.api.nvim_chan_send()` to ensure that
    --    larger messages properly make use of errno to EAGAIN as mentioned in #26688
    -- 3. Writes bytes using `io.stdout:write()`
    if opts.write then
      opts.write(bytes)
    elseif opts.use_chan_send then
      vim.api.nvim_chan_send(2, bytes)
    else
      io.stdout:write(bytes)
      io.stdout:flush()
    end
  end

  ---@cast writer -function
  return writer
end

return M
