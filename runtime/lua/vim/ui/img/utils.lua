local M = {}

---@alias vim.ui.img.utils.Unit 'cell'|'pixel'

---Move the terminal cursor to cell x, y.
---NOTE: This is relative to the editor, so can be placed outside of normal region.
---@param x integer column position in terminal
---@param y integer row position in terminal
---@param write? fun(...:string) function to use to write bytes, otherwise io.stdout:write(...)
function M.move_cursor(x, y, write)
  write = write or function(...)
    io.stdout:write(...)
  end

  write(string.format(
    '\027[%s;%sH',
    math.floor(y),
    math.floor(x)
  ))
end

---Performs `ESC 7` to save the cursor position.
---@param write? fun(...:string)
function M.save_cursor(write)
  write = write or function(...)
    io.stdout:write(...)
  end

  write('\0277')
end

---Performs `ESC 8` to restore the cursor position.
---@param write? fun(...:string)
function M.restore_cursor(write)
  write = write or function(...)
    io.stdout:write(...)
  end

  write('\0278')
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
---@param opts? {use_chan_send?:boolean, write?:fun(...:string)}
---@return vim.ui.img.utils.BatchWriter
function M.new_batch_writer(opts)
  opts = opts or {}

  ---@class vim.ui.img.utils.BatchWriter
  ---@field private __queue string[]
  ---@overload fun(...:string)
  local writer = setmetatable({
    __queue = {},
  }, {
    ---@param t vim.ui.img.utils.BatchWriter
    ---@param ... string
    __call = function(t, ...)
      t.write(...)
    end,
  })

  ---Queues up bytes to be written later.
  ---@param ... string
  function writer.write(...)
    vim.list_extend(writer.__queue, { ... })
  end

  ---Writes immediately skipping queue.
  ---@param ... string
  function writer.write_fast(...)
    local bytes = table.concat({ ... })

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

  ---Flushes the bytes, sending them all together.
  function writer.flush()
    local queue = writer.__queue
    writer.__queue = {}

    writer.write_fast(table.concat(queue))
  end

  ---@cast writer -function
  return writer
end

---Enables or disables sync mode for terminal.
---@param enable boolean
---@param write? fun(...:string) function to use to write bytes, otherwise io.stdout:write(...)
function M.enable_sync_mode(enable, write)
  write = write or function(...)
    io.stdout:write(...)
  end

  -- TODO: Offer ability to check if synchronous mode exists:
  -- https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
  --
  -- Send ESC[?2026p
  -- Get back ESC[?2026;2$y
  if enable then
    write('\027[?2026h')
  else
    write('\027[?2026l')
  end
end

---Shows or hides the cursor in the terminal.
---@param show boolean
---@param write? fun(...:string) function to use to write bytes, otherwise io.stdout:write(...)
function M.show_cursor(show, write)
  write = write or function(...)
    io.stdout:write(...)
  end

  if show then
    write('\027[?25h')
  else
    write('\027[?25l')
  end
end

return M
