local M = {}

---Creates a writer that will wait to send all bytes together.
---@param opts? {use_chan_send?:boolean, map?:(fun(s:string):string), multi?:boolean, write?:fun(...:string)}
---@return vim.ui.img._Writer
function M.new(opts)
  opts = opts or {}

  ---@class vim.ui.img._Writer
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
