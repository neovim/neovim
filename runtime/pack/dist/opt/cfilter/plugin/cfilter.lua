---@param bufnr integer
---@param lnum integer
---@return string?
local function get_line(bufnr, lnum)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
  if not line then
    return nil
  end
  return line
end

---@param searchpat string
---@return string
local function get_search_pat(searchpat)
  local firstchar = searchpat:sub(1, 1)
  local lastchar = searchpat:sub(-1)
  local pat = searchpat
  if firstchar == lastchar and (firstchar == '/' or firstchar == '"' or firstchar == "'") then
    pat = searchpat:sub(2, -2)
    if pat == '' then
      -- Use the last search pattern
      pat = vim.fn.getreg('/')
    end
  end
  return pat
end

---@param items table[]
---@param searchpat string
---@param bang boolean
---@return table[]?
local function get_matched_items(items, searchpat, bang)
  local pat = get_search_pat(searchpat)

  for i, item in ipairs(items) do
    item.nvim_cfilter = {
      lnum = i - 1,
    }
  end

  local regex = vim.regex(pat)
  local bufname = vim.api.nvim_buf_get_name
  if bang then
    ---@param val table
    ---@return boolean
    return vim.tbl_filter(function(val)
      local text_match = regex:match_str(val.text) ~= nil
      local bufname_match = regex:match_str(bufname(val.bufnr)) ~= nil
      return not (text_match or bufname_match)
    end, items)
  else
    ---@param val table
    ---@return boolean
    return vim.tbl_filter(function(val)
      local text_match = regex:match_str(val.text) ~= nil
      local bufname_match = regex:match_str(bufname(val.bufnr)) ~= nil
      return text_match or bufname_match
    end, items)
  end
end

---@param is_qf boolean
---@param searchpat string
---@param bang boolean
local function cmd_cb(is_qf, searchpat, bang)
  local get_list, set_list ---@type function, function
  local cmd_name ---@type string

  if is_qf then
    get_list = vim.fn.getqflist
    set_list = vim.fn.setqflist
    cmd_name = ':Cfilter' .. (bang and '!' or '')
  else
    get_list = function()
      return vim.fn.getloclist(0)
    end
    set_list = function(...)
      return vim.fn.setloclist(0, ...)
    end
    cmd_name = ':Lfilter' .. (bang and '!' or '')
  end

  local title = cmd_name .. ' /' .. searchpat .. '/'
  set_list({}, ' ', {
    title = title,
    items = get_matched_items(get_list(), searchpat, bang),
  })
end

---@param opts vim.api.keyset.create_user_command.command_args
---@param ns integer
---@param preview_buf integer
---@return 0|1|2
local function cmd_preview(opts, ns, preview_buf)
  local bang = opts.bang
  local searchpat = opts.args
  local is_qf = opts.name == 'Cfilter'
  local get_list ---@type function
  if is_qf then
    get_list = vim.fn.getqflist
  else
    get_list = function(...)
      return vim.fn.getloclist(0, ...)
    end
  end
  local qfbufnr = get_list({ qfbufnr = true }).qfbufnr
  local lines = {}
  local items = get_matched_items(get_list(), searchpat, bang)
  if not items then
    return 0
  end
  for _, item in ipairs(get_matched_items(get_list(), searchpat, bang) or {}) do
    local lnum = item.nvim_cfilter.lnum
    table.insert(lines, get_line(qfbufnr, lnum))
  end
  vim.bo[qfbufnr].modifiable = true
  local return_value = preview_buf and 2 or 1
  vim.api.nvim_buf_set_lines(preview_buf or qfbufnr, 0, -1, false, lines)

  if not bang then
    for lnum = 0, vim.api.nvim_buf_line_count(qfbufnr) - 1, 1 do
      local line = get_line(qfbufnr, lnum)
      if line then
        local match_start, match_end = vim.regex(searchpat):match_str(line)
        if match_start and match_end then
          for _, buf in ipairs { qfbufnr, preview_buf } do
            vim.hl.range(buf, ns, 'IncSearch', { lnum, match_start }, { lnum, match_end })
          end
        end
      end
    end
  end
  return return_value
end

vim.api.nvim_create_user_command('Cfilter', function(opts)
  cmd_cb(true, opts.args, opts.bang)
end, {
  nargs = '+',
  bang = true,
  desc = 'Filter quickfix list',
  preview = cmd_preview,
})

vim.api.nvim_create_user_command('Lfilter', function(opts)
  cmd_cb(false, opts.args, opts.bang)
end, {
  nargs = '+',
  bang = true,
  desc = 'Filter location list',
  preview = cmd_preview,
})
