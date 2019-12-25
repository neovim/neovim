local vim = vim
local api = vim.api

-- config = {
--   buf_init(bufnr, ...) -> lookup_value: any
--   on_detach(bufnr, lookup_value)
--   on_lines
--   on_changedtick
--   utf_sizes
-- }
-- Returns: { attach(bufnr, ...), iter(), get(bufnr) }
--
-- Any arguments passed after bufnr to attach() are forwarded to buf_init()
-- on_lines, on_changedtick, utf_sizes are forwarded to nvim_buf_attach
local function buffer_manager(config)
  vim.validate{
    on_detach = {config.on_detach, 'f', true};
    buf_init = {config.buf_init, 'f'};
  }
  local lookup = {}
  local function on_detach(_, bufnr)
    if lookup[bufnr] then
      pcall(config.on_detach, bufnr, lookup[bufnr])
    end
    lookup[bufnr] = nil
  end

  local R = {}

  local function resolve_bufnr(bufnr)
    if bufnr == 0 or bufnr == nil then
      return api.nvim_get_current_buf()
    end
    return bufnr
  end

  function R.attach(bufnr, ...)
    bufnr = resolve_bufnr(bufnr)
    local buffer_lookup = lookup[bufnr]
    if not buffer_lookup then
      -- TODO(ashkan): pcall?
      -- TODO(ashkan): use `true` as a default or throw error?
      buffer_lookup = config.buf_init(bufnr, ...) or error("Failed to setup buffer "..bufnr)
      lookup[bufnr] = buffer_lookup
      api.nvim_buf_attach(bufnr, false, {
        on_detach = on_detach;

        -- Forward any extra attachments from the config.
        on_lines       = config.on_lines;
        on_changedtick = config.on_changedtick;
        utf_sizes      = config.utf_sizes;
      })
    end
    return buffer_lookup, bufnr
  end

  function R.iter()
    return pairs(lookup)
  end

  function R.get(bufnr)
    return lookup[resolve_bufnr(bufnr)]
  end

  function R.set(bufnr, value)
    assert(value ~= nil)
    lookup[resolve_bufnr(bufnr)] = value
  end

  return R
end

return buffer_manager
