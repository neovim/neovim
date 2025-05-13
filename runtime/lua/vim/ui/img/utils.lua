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

  ---Flushes the bytes, sending them all together.
  function writer.flush()
    local bytes = table.concat(writer.__queue)

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

---Enables or disables sync mode for terminal.
---@param enable boolean
---@param write? fun(...:string) function to use to write bytes, otherwise io.stdout:write(...)
function M.enable_sync_mode(enable, write)
  write = write or function(...)
    io.stdout:write(...)
  end

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

---@generic T
---@param fn T
---@param opts? {ms?:integer}
---@return T
function M.debounce(fn, opts)
  local timer = assert(vim.uv.new_timer())
  local ms = opts and opts.ms or 20
  return function()
    timer:start(ms, 0, vim.schedule_wrap(fn))
  end
end

return M
