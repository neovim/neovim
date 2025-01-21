local ts = vim.treesitter
local api = vim.api

local M = {}

local ns = api.nvim_create_namespace('nvim.matching')

---@alias Pos { [1]: integer, [2]: integer }

--- 0-based line and column position
--- @return Pos
local function norm_cursor_pos()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  return { row - 1, col }
end

--- Iterate over unnamed children of the node.
--- @param node TSNode
--- @return Iter
local function anonymous_children(node)
  return vim.iter(node:iter_children()):filter(function(child)
    return not child:named()
  end)
end

--- @param node TSNode
--- @param start? boolean start or end position of the node
--- @return Pos
local function node_pos(node, start)
  start = vim.F.if_nil(start, true)
  local row, col
  if start then
    row, col = node:start()
  else
    row, col = node:end_()
    col = col - 1
  end
  return { row, col }
end

--- TODO: pattern instead of startswith
--- @param pattern string capture group pattern (without '@')
--- @return boolean
local function on_capture(pattern)
  local captures = ts.get_captures_at_cursor(0)
  for _, capture in ipairs(captures) do
    if vim.startswith(capture, pattern) then
      return true
    end
  end
  return false
end

--- TODO: return all keywords as list for highlighting
--- Find matching keywords (e.g. if/then/end)
--- @param current TSNode
--- @param backward boolean?
--- @return Pos[]?
local function ts_match_keyword(current, backward)
  if not current then
    return
  end
  local keywords = anonymous_children(current)

  -- prev for backwards matching, first for wrapping last item
  local prev, first
  for keyword in keywords do
    -- cursor on keyword
    if ts.is_in_node_range(keyword, unpack(norm_cursor_pos())) then
      local match
      if backward then
        -- first item wraps to last item
        match = prev or keywords:last()
      else
        -- last item wraps to first item
        match = keywords:next() or first
      end
      if match then
        return { node_pos(match) }
      end
    end
    first = vim.F.if_nil(first, keyword)
    prev = keyword
  end
end

--- Find matching brackets
--- @param node TSNode
--- @return Pos[]?
local function ts_match_punc(node)
  if not node then
    return
  end

  local opening = anonymous_children(node):nth(1)
  local closing = anonymous_children(node):last()

  if opening and closing then
    local cursor = norm_cursor_pos()

    local open_pos = node_pos(opening)
    local close_pos = node_pos(closing, false)
    local cursor_on_open = vim.deep_equal(cursor, open_pos)

    if cursor_on_open then
      return { close_pos, open_pos }
    else
      return { open_pos, close_pos }
    end
  end
end

--- @param str string
--- @param sep string
--- @return fun(): string?
local function gsplit_escaped(str, sep)
  local start = 1
  return function()
    local end_ = start
    while end_ <= #str and str:sub(end_, end_) ~= sep do
      end_ = end_ + 1
      if str:sub(end_, end_) == '\\' then
        end_ = end_ + 2
      end
    end
    -- get part before sep
    local sub = str:sub(start, end_ - 1)
    -- update start for next group
    start = end_ + 1
    return sub ~= '' and sub or nil
  end
end

--- Substitute `\1` with the capture group found.
--- @param str string
--- @return string
local function resolve_backref(str)
  local first_capture = str:match([[\%(.-\%)]]) or [[\1]]
  local res, _ = str:gsub([[\1]], first_capture)
  return res
end

--- @return string[]?
local function find_match_group(words)
  for group in gsplit_escaped(words, ',') do
    group = resolve_backref(group)
    -- iterate through it because we want to return the group parts
    local split_groups = vim.iter(gsplit_escaped(group, ':')):totable()
    for _, pattern in ipairs(split_groups) do
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      local buf = vim.api.nvim_get_current_buf()
      local matches = vim.fn.matchbufline(buf, pattern, line, line)
      for _, match in ipairs(matches) do
        local match_end = match.byteidx + #match.text
        if match.byteidx <= col and col <= match_end then
          return split_groups
        end
      end
    end
  end
end

--- Check if matching bracket is in skipable syntax group
--- @return boolean
local function searchskip()
  if not vim.g.syntax_on then
    return false
  end
  local groups = vim.regex('string\\|character\\|singlequote\\|escape\\|symbol\\|comment')
  return vim.iter(vim.fn.synstack(vim.fn.line('.'), vim.fn.col('.'))):any(function(id)
    local name = vim.fn.synIDattr(id, 'name'):lower()
    return groups:match_str(name) ~= nil
  end)
end

--- Current character under cursor
--- @return string
local function cursor_char()
  local r, c = unpack(norm_cursor_pos())
  return api.nvim_buf_get_text(0, r, c, r, c + 1, {})[1]
end

--- TODO: jump to start if on end (wrap)
--- @param backward boolean?
--- @return Pos[]?
local function syntax_match(backward)
  local words = vim.b.match_words or ''

  -- Allow b:match_words = "GetVimMatchWords()"
  if #words > 0 and not words:find(':') then
    words = api.nvim_eval(words)
  end

  -- Combine 'matchpairs' and b:match_words
  words = ('%s,%s'):format(vim.bo.matchpairs, words)

  -- 1. Try to find a match
  local group = find_match_group(words)
  if not group then
    return
  end
  local start = group[1]
  local last = group[#group]
  local mid = #group > 2 and group[2] or ''

  -- 2. TODO: parse b:match_skip
  local skip = searchskip

  -- Determine search direction for brackets
  local char = cursor_char()
  if start == char or last == char then
    backward = last == char
  end

  local flags = backward and 'bnW' or 'nW'

  -- unescape : and ,
  start = start:gsub('\\([:,])', '%1')
  mid = mid:gsub('\\([:,])', '%1')
  last = last:gsub('\\([:,])', '%1')

  -- avoid \(\) groups
  local notslash = [[\\\@1<!\%(\\\\\)*]]
  start = vim.fn.substitute(start, notslash .. [[\zs\\(]], [[\\%(]], 'g')
  mid = vim.fn.substitute(mid, notslash .. [[\zs\\(]], [[\\%(]], 'g')
  last = vim.fn.substitute(last, notslash .. [[\zs\\(]], [[\\%(]], 'g')

  -- use |nomagic| with parentheses
  if start == '(' or start == '[' then
    start = '\\M' .. start
    last = '\\M' .. last
  end

  -- |search()| respects 'ignorecase'
  local prev_ignorecase = vim.o.ignorecase
  local ignorecase = vim.b.match_ignorecase or vim.o.ignorecase
  if ignorecase == 0 then
    ignorecase = false
  end
  vim.o.ignorecase = ignorecase

  local match = vim.fn.searchpairpos(start, mid, last, flags, skip)

  vim.o.ignorecase = prev_ignorecase

  if match[1] > 0 and match[2] > 0 then
    match[1] = match[1] - 1
    match[2] = match[2] - 1
    return { match, norm_cursor_pos() }
  end
end

--- Finds the first match group matching the element under the cursor. The
--- first element is the 'next' element and so on.
--- @param backward boolean? Search backwards
--- @return Pos[]?
local function find_matches(backward)
  local node = ts.get_node()

  if node and on_capture('punctuation.bracket') then
    return ts_match_punc(node)
  end
  if node and on_capture('keyword') then
    return ts_match_keyword(node, backward)
  end

  return syntax_match(backward)
end

function M.jump(opts)
  if vim.o.rtp:find('matchit') ~= nil then
    vim.cmd.unlet('g:loaded_matchit')
    vim.cmd.runtime('plugin/matchit.vim')
    -- doesn't allow both plugins to be used (even with different keymaps)
    return
  end

  -- [count]% goes to the percentage in a file |N%|
  if vim.v.count1 > 1 then
    vim.cmd(('normal! %s%%'):format(vim.v.count1))
    return
  end

  opts = vim.tbl_extend('keep', opts or {}, {
    backward = false,
  })

  local matches = find_matches(opts.backward)
  if matches then
    local row, col = unpack(matches[1])
    if vim.startswith(vim.fn.mode(1), 'no') then
      vim.cmd('normal! v')
    end
    api.nvim_win_set_cursor(0, { row + 1, col })
  end
end

function M.highlight()
  api.nvim_buf_clear_namespace(0, ns, 0, -1)

  -- self-destruct if matchparen is loaded
  if vim.o.rtp:find('matchparen') ~= nil then
    api.nvim_del_augroup_by_name('nvim.matching')
    return
  end

  local matches = find_matches()
  for _, match in ipairs(matches or {}) do
    local row, col = unpack(match)
    vim.hl.range(0, ns, 'MatchParen', { row, col }, { row, col + 1 })
  end
end

-- inform ftplugin's to set b:match_words / b:match_ignorecase / b:match_skip
vim.g.loaded_matchit = 1

return M
