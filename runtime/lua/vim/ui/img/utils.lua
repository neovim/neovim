local M = {}

---@alias vim.ui.img.utils.Unit 'cell'|'pixel'

---@class vim.ui.img.utils.Codes
M.codes = {
  ---Hides the cursor from being shown in terminal.
  CURSOR_HIDE          = '\027[?25l',
  ---Restore cursor position based on last save.
  CURSOR_RESTORE       = '\0278',
  ---Save cursor position to be restored later.
  CURSOR_SAVE          = '\0277',
  ---Shows the cursor if it was hidden in terminal.
  CURSOR_SHOW          = '\027[?25h',
  ---Disables scrolling mode for sixel.
  SIXEL_SCROLL_DISABLE = '\027[?80l',
  ---Disable synchronized output mode.
  SYNC_MODE_DISABLE    = '\027[?2026l',
  ---Enable synchronized output mode.
  SYNC_MODE_ENABLE     = '\027[?2026h',
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

---@param opts? {on_response?:fun(pos:vim.ui.img.utils.Position), timeout_ms?:number, no_error?:boolean, write?:fun(...:string)}
---@return vim.ui.img.utils.Position|nil
function M.get_cursor_position(opts)
  opts = opts or {}

  local on_response = opts.on_response
  local timeout = opts.timeout_ms or 1000
  local position = nil

  local id = vim.api.nvim_create_autocmd('TermResponse', {
    callback = function(args)
      local resp = args.data.sequence ---@type string
      local row, col = string.match(resp, '\027[(%d+);(%d+)R')

      local row_num = tonumber(row)
      local col_num = tonumber(col)

      if row_num and col_num then
        local pos = require('vim.ui.img.utils.position').new({
          x = col_num,
          y = row_num,
          unit = 'cell',
        })

        if on_response then
          vim.schedule(function()
            on_response(pos)
          end)
        else
          position = pos
        end

        -- Mark that we no longer need this autocmd
        return true
      end
    end
  })

  local write = opts.write or function(...)
    io.stdout:write(...)
  end

  -- Send request to get cursor position
  write('\027[6n')

  -- Asynchronous, so we're done at this point
  if on_response then
    return
  end

  -- Wait for the position to be retrieved
  vim.wait(timeout, function()
    return position ~= nil
  end)

  -- Delete the autocmd, ignoring errors if already gone
  pcall(vim.api.nvim_del_autocmd, id)

  if opts.no_error then
    return position
  end

  return assert(
    position,
    string.format('unable to retrieve a response in %sms', timeout)
  )
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
