local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local Range = require('vim.treesitter._range')
local api = vim.api
local M = {}

---@class (private) vim.lsp.linked_editing_range.state Global state for linked editing ranges
---@field enabled boolean Whether linked editing ranges are enabled
---An optional word pattern (regular expression) that describes valid contents for the given ranges.
---@field word_pattern string
---@field range_index? integer The index of the range that the cursor is on.
---@type vim.lsp.linked_editing_range.state
local state = {
  enabled = false,
  word_pattern = '^[%w%-_]*$',
}

local augroup = api.nvim_create_augroup('nvim.lsp.linked_editing_range', {})
local ns = api.nvim_create_namespace('nvim.lsp.linked_editing_range')

--- |lsp-handler| for the method `textDocument/linkedEditingRange`. Stores ranges globally in the
--- state variable.
---@param err lsp.ResponseError?
---@param result lsp.LinkedEditingRanges?
---@param ctx lsp.HandlerContext
local function on_linked_editing_range(err, result, ctx)
  if err then
    log.error('linkededitingrange', err)
    return
  end
  local bufnr = assert(ctx.bufnr)
  if
    not state.enabled
    or not api.nvim_buf_is_loaded(bufnr)
    or util.buf_versions[bufnr] ~= ctx.version
  then
    return
  end

  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  state.range_index = nil

  if not result then
    return
  end

  local client_id = ctx.client_id
  local client = assert(vim.lsp.get_client_by_id(client_id))

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local curpos = api.nvim_win_get_cursor(0)
  local cursor_range = { curpos[1] - 1, curpos[2], curpos[1] - 1, curpos[2] }
  for i, range in ipairs(result.ranges) do
    local start_line = range.start.line
    local line = lines and lines[start_line + 1] or ''
    range.start.character =
      vim.str_byteindex(line, client.offset_encoding, range.start.character, false)
    local end_line = range['end'].line
    line = lines and lines[end_line + 1] or ''
    range['end'].character =
      vim.str_byteindex(line, client.offset_encoding, range['end'].character, false)

    api.nvim_buf_set_extmark(bufnr, ns, start_line, range.start.character, {
      end_line = end_line,
      end_col = range['end'].character,
      hl_group = 'LspReferenceTarget',
      right_gravity = false,
      end_right_gravity = true,
    })

    local range_tuple =
      { range.start.line, range.start.character, range['end'].line, range['end'].character }
    if Range.contains(range_tuple, cursor_range) then
      state.range_index = i
    end
  end

  -- TODO: Apply the server's own word pattern, if it exists
end

--- Refresh linked editing ranges, only if we have attached clients that support it
---@param bufnr (integer) Buffer handle, or 0 for current
local function refresh(bufnr)
  local win = api.nvim_get_current_win()
  local method = ms.textDocument_linkedEditingRange
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })

  if not next(clients) then
    return
  end
  util._cancel_requests({
    bufnr = bufnr,
    clients = clients,
    method = method,
    type = 'pending',
  })
  -- TODO: Merge results from multiple clients
  local client = clients[1]
  client:request(
    method,
    vim.lsp.util.make_position_params(win, client.offset_encoding),
    on_linked_editing_range,
    bufnr
  )
end

local function setup_autocmds()
  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    callback = function(args)
      if not state.range_index then
        return
      end

      local buf = args.buf
      local ranges = api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
      if not next(ranges) then
        return
      end

      local r = ranges[state.range_index]
      local replacement = api.nvim_buf_get_text(buf, r[2], r[3], r[4].end_row, r[4].end_col, {})

      if not string.match(table.concat(replacement, '\n'), state.word_pattern) then
        api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        state.range_index = nil
        return
      end

      for i, range in ipairs(ranges) do
        if i ~= state.range_index then
          vim.cmd.undojoin()
          api.nvim_buf_set_text(
            buf,
            range[2],
            range[3],
            range[4].end_row,
            range[4].end_col,
            replacement
          )
        end
      end

      refresh(buf)
    end,
  })
  api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    callback = function(args)
      refresh(args.buf)
    end,
  })
  api.nvim_create_autocmd('LspDetach', {
    group = augroup,
    callback = function(args)
      local clients =
        vim.lsp.get_clients({ bufnr = args.buf, method = ms.textDocument_linkedEditingRange })

      if
        not vim.iter(clients):any(function(c)
          return c.id ~= args.data.client_id
        end)
      then
        M.enable(false)
      end
    end,
  })
end

--- Enables or disables linked editing ranges. Ranges are highlighted using the
--- |hl-LspReferenceTarget| group.
--- @param enable (boolean|nil) true/nil to enable, false to disable
function M.enable(enable)
  vim.validate('enable', enable, 'boolean', true)
  enable = enable ~= false
  if enable then
    if state.enabled then
      return
    end
    state.enabled = true
    setup_autocmds()

    refresh(0)
  else
    state.enabled = false
    api.nvim_clear_autocmds({ group = augroup })
  end
end

return M
