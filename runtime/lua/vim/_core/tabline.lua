local api = vim.api

local M = {}

--- @param win integer
--- @param name string
--- @return string
local function tab_hl(win, name)
  local ns = api.nvim_get_hl_ns({ winid = win })
  local hl = ns >= 0 and api.nvim_get_hl(ns, { name = name }) or {}
  return hl.link or name
end

--- Format a tab item like the built-in tabline.
--- @param info table
--- @return string
--- @return integer wincount
function M.default_item(info)
  local wincount = 0
  local modified = false
  for _, win in ipairs(api.nvim_tabpage_list_wins(info.tabpage)) do
    local config = api.nvim_win_get_config(win)
    if config.focusable ~= false and config.hide ~= true then
      wincount = wincount + 1
      modified = modified or vim.fn.getbufvar(api.nvim_win_get_buf(win), '&modified') == 1
    end
  end

  local prefix = (wincount > 1 and wincount or '') .. (modified and '+' or '')
  prefix = prefix ~= '' and prefix .. ' ' or ''
  local bufname = api.nvim_eval_statusline('%f', { winid = info.winid, maxwidth = 9999 }).str
  return prefix .. vim.fn.pathshorten(bufname), wincount
end

--- Generate the default 'tabline' expression.
--- @param itemfunc? fun(info: table): string, integer?
--- @return string
function M.default(itemfunc)
  itemfunc = itemfunc or M.default_item
  local tabs = api.nvim_list_tabpages()
  local current = api.nvim_get_current_tabpage()
  local items = {} --- @type string[]
  local current_index, current_end = 1, 0
  local width = 0

  for tabnr, tab in ipairs(tabs) do
    local win = api.nvim_tabpage_get_win(tab)
    local current_item = tab == current
    local hl = tab_hl(win, current_item and 'TabLineSel' or 'TabLine')
    local name, wincount = itemfunc({
      current = current_item,
      tabnr = tabnr,
      tabpage = tab,
      winid = win,
    }) --- @type string, integer?
    local label = string.gsub(name, '%%', '%%%%')
    local display = label
    if itemfunc == M.default_item and wincount and wincount > 1 then
      local count = tostring(wincount)
      local title = tab_hl(win, 'Title')
      display = '%$' .. title .. '$' .. count .. '%#' .. hl .. '#' .. label:sub(#count + 1)
    end
    items[#items + 1] = ('%%%dT%%#%s# %s %%T'):format(tabnr, hl, display)
    width = width + vim.fn.strdisplaywidth(name) + 2
    if current_item then
      current_index = #items
      current_end = width
    end
  end

  local showcmd = vim.o.showcmd
      and vim.o.showcmdloc == 'tabline'
      and '%-10.(%#TabLine#%S%#TabLineFill#%)'
    or ''
  local close = #items > 1 and ((showcmd ~= '' and ' ' or '') .. '%#TabLine#%999XX') or ''
  local content = table.concat(items)
  local reserved = api.nvim_eval_statusline(showcmd .. close, { use_tabline = true }).width
  if width - current_end + reserved >= vim.o.columns then
    content = table.concat(items, '', 1, current_index)
  end
  return '%<' .. content .. '%#TabLineFill#%0T%=' .. showcmd .. close
end

return M
