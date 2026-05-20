local api = vim.api
local fn = vim.fn
local nvim_on = require('vim._core.util').nvim_on

local M = {}

local skip_names = { 'string', 'character', 'singlequote', 'escape', 'symbol', 'comment' }

---@param text string
---@param byte_col integer
---@return string
local function char_at(text, byte_col)
  if byte_col > #text then
    return ''
  end
  return text:sub(byte_col, byte_col + vim.str_utf_end(text, byte_col))
end

---@param text string
---@param byte_col integer
---@return string
local function char_before(text, byte_col)
  local end_col = math.min(byte_col - 1, #text)
  if end_col < 1 then
    return ''
  end
  return text:sub(end_col + vim.str_utf_start(text, end_col), end_col)
end

function M.enable()
  vim.g.loaded_matchparen = 1

  if vim.g.matchparen_timeout == nil then
    vim.g.matchparen_timeout = 300
  end
  if vim.g.matchparen_insert_timeout == nil then
    vim.g.matchparen_insert_timeout = 60
  end
  if vim.g.matchparen_disable_cursor_hl == nil then
    vim.g.matchparen_disable_cursor_hl = 0
  end

  local group = api.nvim_create_augroup('matchparen', { clear = true })

  -- Replace all matchparen autocommands
  nvim_on(
    { 'CursorMoved', 'CursorMovedI', 'WinEnter', 'WinScrolled', 'TextChanged', 'TextChangedI' },
    group,
    function()
      M.highlight_matching_pair()
    end
  )
  nvim_on('BufWinEnter', group, function()
    nvim_on('SafeState', group, { once = true }, function()
      M.highlight_matching_pair()
    end)
  end)
  nvim_on({ 'WinLeave', 'BufLeave', 'TextChangedP' }, group, function()
    M.remove_matches()
  end)

  -- Define commands that will disable and enable the plugin.
  api.nvim_create_user_command('DoMatchParen', function()
    M.do_matchparen()
  end, { force = true })
  api.nvim_create_user_command('NoMatchParen', function()
    M.no_matchparen()
  end, { force = true })
end

--- The function that is invoked (very often) to define a ":match" highlighting
--- for any matching paren.
---@param win? integer
function M.highlight_matching_pair(win)
  win = win or api.nvim_get_current_win()
  local buf = api.nvim_win_get_buf(win)

  if vim.w[win].matchparen_ids == nil then
    vim.w[win].matchparen_ids = {}
  end
  -- Remove any previous match.
  M.remove_matches(win)

  -- Avoid that we remove the popup menu.
  if fn.pumvisible() ~= 0 then
    return
  end

  -- Get the character under the cursor and check if it's in 'matchpairs'.
  local cursor = api.nvim_win_get_cursor(win)
  local c_lnum = cursor[1]
  local c_col = cursor[2] + 1
  local before = 0

  local text = api.nvim_buf_get_lines(buf, c_lnum - 1, c_lnum, false)[1] or ''
  -- Cursor columns are byte indexes,
  -- while 'matchpairs' entries may be multibyte characters.
  -- Use UTF-8 boundaries to extract the whole character around the byte column.
  local c_before = char_before(text, c_col)
  local c = char_at(text, c_col)
  ---@type string[]
  local plist = vim.split(vim.bo[buf].matchpairs, '[:,]', { trimempty = true })
  ---@type integer?
  local i = vim.iter(ipairs(plist)):find(function(_, item)
    return item == c
  end)
  if i == nil then
    -- not found, in Insert mode try character before the cursor
    local mode = api.nvim_get_mode().mode
    if c_col > 1 and (mode == 'i' or mode == 'R') then
      before = #c_before
      c = c_before
      i = vim.iter(ipairs(plist)):find(function(_, item)
        return item == c
      end)
    end
    if i == nil then
      -- not found, nothing to do
      return
    end
  end

  -- Figure out the arguments for searchpairpos().
  local flags ---@type string
  local c2 ---@type string
  if i % 2 == 1 then
    flags = 'nW'
    c2 = plist[i + 1]
  else
    flags = 'nbW'
    c2 = c
    c = plist[i - 1]
  end
  if c == '[' then
    c = [=[\[]=]
    c2 = [=[\]]=]
  end

  -- Find the match.  When it was just before the cursor move it there for a
  -- moment.
  local save_cursor ---@type [integer, integer, integer, integer, integer]?
  if before > 0 then
    save_cursor = fn.getcurpos(win)
    api.nvim_win_set_cursor(win, { c_lnum, c_col - before - 1 })
  end

  local skip ---@type fun(): boolean
  if vim.g.syntax_on == nil then
    skip = function()
      return false
    end
  elseif vim.b[buf].ts_highlight ~= nil and vim.bo[buf].syntax ~= 'on' then
    skip = function()
      for _, capture in ipairs(vim.treesitter.get_captures_at_cursor(win)) do
        for _, skip_name in ipairs(skip_names) do
          if capture:find(skip_name, 1, true) ~= nil then
            return true
          end
        end
      end
      return false
    end
  else
    -- do not attempt to match when the syntax item where the cursor is
    -- indicates there does not exist a matching parenthesis, e.g. for shells
    -- case statement: "case $var in foobar)"
    --
    -- add the check behind a filetype check, so it only needs to be
    -- evaluated for certain filetypes
    if vim.bo[buf].filetype == 'sh' then
      local pos = api.nvim_win_get_cursor(win)
      ---@type integer[]
      local stack = api.nvim_win_call(win, function()
        return fn.synstack(pos[1], pos[2] + 1)
      end)
      for _, id in ipairs(stack) do
        if fn.synIDattr(id, 'name'):lower():find('shsnglcase') ~= nil then
          if save_cursor ~= nil then
            api.nvim_win_call(win, function()
              fn.setpos('.', save_cursor)
            end)
          end
          return
        end
      end
    end
    -- Build an expression that detects whether the current cursor position is
    -- in certain syntax types (string, comment, etc.), for use as
    -- searchpairpos()'s skip argument.
    -- We match "escape" for special items, such as lispEscapeSpecial, and
    -- match "symbol" for lispBarSymbol.
    skip = function()
      local pos = api.nvim_win_get_cursor(win)
      for _, id in ipairs(fn.synstack(pos[1], pos[2] + 1)) do
        local name = fn.synIDattr(id, 'name'):lower()
        for _, skip_name in ipairs(skip_names) do
          if name:find(skip_name, 1, true) ~= nil then
            return true
          end
        end
      end
      return false
    end
    -- If executing the expression determines that the cursor is currently in
    -- one of the syntax types, then we want searchpairpos() to find the pair
    -- within those syntax types (i.e., not skip).  Otherwise, the cursor is
    -- outside of the syntax types and skip should keep its value so we skip
    -- any matching pair inside the syntax types.
    if api.nvim_win_call(win, skip) then
      skip = function()
        return false
      end
    end
  end

  -- Limit the search to lines visible in the window.
  ---@type integer, integer
  local stoplinetop, stoplinebottom = unpack(api.nvim_win_call(win, function()
    return { fn.line('w0'), fn.line('w$') }
  end))
  local stopline ---@type integer
  if i % 2 == 1 then
    stopline = stoplinebottom
  else
    stopline = stoplinetop
  end

  -- Limit the search time to 300 msec to avoid a hang on very long lines.
  local timeout ---@type integer
  local mode = api.nvim_get_mode().mode
  if mode == 'i' or mode == 'R' then
    timeout = vim.b[buf].matchparen_insert_timeout or vim.g.matchparen_insert_timeout
  else
    timeout = vim.b[buf].matchparen_timeout or vim.g.matchparen_timeout
  end

  ---@type boolean, [integer, integer]|string
  local ok, match = pcall(api.nvim_win_call, win, function()
    return fn.searchpairpos(c, '', c2, flags, skip, stopline, timeout)
  end)
  if not ok then ---@cast match string
    if save_cursor ~= nil then
      api.nvim_win_call(win, function()
        fn.setpos('.', save_cursor)
      end)
    end
    error(match)
  end ---@cast match [integer, integer]
  if save_cursor ~= nil then
    api.nvim_win_call(win, function()
      fn.setpos('.', save_cursor)
    end)
  end

  local m_lnum = match[1]
  local m_col = match[2]

  -- If a match is found setup match highlighting.
  if m_lnum > 0 and m_lnum >= stoplinetop and m_lnum <= stoplinebottom then
    local ids = vim.w[win].matchparen_ids
    if tonumber(vim.g.matchparen_disable_cursor_hl) == 0 then
      table.insert(
        ids,
        fn.matchaddpos(
          'MatchParen',
          { { c_lnum, c_col - before }, { m_lnum, m_col } },
          10,
          -1,
          { window = win }
        )
      )
    else
      table.insert(
        ids,
        fn.matchaddpos('MatchParen', { { m_lnum, m_col } }, 10, -1, { window = win })
      )
    end
    vim.w[win].matchparen_ids = ids
    vim.w[win].paren_hl_on = 1
  end
end

---@param win? integer
function M.remove_matches(win)
  win = win or api.nvim_get_current_win()

  if vim.w[win].paren_hl_on ~= nil and vim.w[win].paren_hl_on ~= 0 then
    local ids = vim.w[win].matchparen_ids or {}
    while #ids > 0 do
      pcall(fn.matchdelete, table.remove(ids, 1), win)
    end
    vim.w[win].matchparen_ids = ids
    vim.w[win].paren_hl_on = 0
  end
end

---@param tab? integer
function M.no_matchparen(tab)
  tab = tab or api.nvim_get_current_tabpage()
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    M.remove_matches(win)
  end
  vim.g.loaded_matchparen = nil
  pcall(api.nvim_clear_autocmds, { group = 'matchparen' })
end

---@param tab? integer
function M.do_matchparen(tab)
  if vim.g.loaded_matchparen == nil then
    M.enable()
  end
  tab = tab or api.nvim_get_current_tabpage()
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    M.highlight_matching_pair(win)
  end
end

return M
