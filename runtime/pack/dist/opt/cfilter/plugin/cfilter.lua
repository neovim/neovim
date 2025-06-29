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
---@param regex vim.regex
---@param bang boolean
---@param opts? { max_matches: integer }
---@return table[]
local function get_matched_items(items, regex, bang, opts)
  if not opts then opts = {} end
  local bufname = vim.api.nvim_buf_get_name
  local cond ---@type fun(val: table): boolean
  local results = {}
  if bang then
    ---@param val table
    ---@return boolean
    cond = function(val)
      local text_match = regex:match_str(val.text) ~= nil
      local bufname_match = regex:match_str(bufname(val.bufnr)) ~= nil
      return not (text_match or bufname_match)
    end
  else
    ---@param val table
    ---@return boolean
    cond = function(val)
      local text_match = regex:match_str(val.text) ~= nil
      local bufname_match = regex:match_str(bufname(val.bufnr)) ~= nil
      return text_match or bufname_match
    end
  end

  local results_num = 0
  for i, item in ipairs(items) do
    if cond(item) then
      item.nvim_cfilter = {
        lnum = i - 1,
      }
      table.insert(results, item)
      if opts.max_matches then
        results_num = results_num + 1
        if results_num > opts.max_matches then
          break
        end
      end
    end
  end
  return results
end

---@param is_qf boolean
---@param pat string
---@param bang boolean
local function cmd_cb(is_qf, pat, bang)
  local get_list, set_list ---@type function, function
  local cmd_name ---@type string
  pat = get_search_pat(pat)
  if pat == '' then
    return
  end

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

  local regex = vim.regex(pat)

  local title = cmd_name .. ' /' .. pat .. '/'
  set_list({}, ' ', {
    title = title,
    items = get_matched_items(get_list(), regex, bang),
  })
end

---@param opts vim.api.keyset.create_user_command.command_args
---@param ns integer
---@param preview_buf integer
---@return 0|1|2
local function cmd_preview(opts, ns, preview_buf)
  local bang, pat = opts.bang, opts.args
  pat = get_search_pat(pat)
  if pat == '' then
    return 0
  end

  local get_list = opts.name == 'Cfilter' and vim.fn.getqflist or function(...)
    return vim.fn.getloclist(0, ...)
  end

  local qf_info = get_list({ qfbufnr = true, winid = true, items = true })
  local qfbufnr, qfwinid, items = qf_info.qfbufnr, qf_info.winid, qf_info.items

  local max_matches = vim.api.nvim_win_get_height(qfwinid)
  local lines = {}
  local regex = vim.regex(pat)
  items = get_matched_items(items, regex, bang, { max_matches = max_matches })
  for _, item in ipairs(items) do
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
        local match_start, match_end = regex:match_str(line)
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
