local api = vim.api
local fn = vim.fn

---@alias nvim.matchit.Mode 'n'|'v'|'o'
---@alias nvim.matchit.Skip fun(): boolean
---@alias nvim.matchit.PatternGroup string[]

---@class nvim.matchit.MatchCandidate
---@field group nvim.matchit.PatternGroup
---@field detect nvim.matchit.PatternGroup
---@field group_index integer
---@field part_index integer
---@field start_col integer
---@field end_col integer
---@field text string
---@field contains boolean
---@field line? integer
---@field resolved? nvim.matchit.PatternGroup

local M = {}

local NOTSLASH = [[\\\@1<!\%(\\\\\)*]]
local DEFAULT_WORDS = [[\/\*:\*\/,#\s*if\%(n\=def\)\=:#\s*else\>:#\s*elif\%(n\=def\)\=\>:#\s*endif\>]]

---@param s string
---@param idx integer
---@return boolean
local function is_escaped(s, idx)
  local count = 0
  local i = idx - 1
  while i >= 1 and s:sub(i, i) == '\\' do
    count = count + 1
    i = i - 1
  end
  return count % 2 == 1
end

---@param s string
---@param sep string
---@return string[]
local function split_escaped(s, sep)
  local parts = {}
  local start = 1
  for i = 1, #s do
    if s:sub(i, i) == sep and not is_escaped(s, i) then
      local part = s:sub(start, i - 1)
      if part ~= '' then
        table.insert(parts, part)
      end
      start = i + 1
    end
  end
  local part = s:sub(start)
  if part ~= '' then
    table.insert(parts, part)
  end
  return parts
end

---@param s string
---@return string
local function unescape_delims(s)
  -- un-escape \, and \: to , and :
  return (s:gsub('\\([:,])', '%1'))
end

---@param s string
---@return string
local function noncapturing(s)
  -- searchpair() requires that these patterns avoid \(\) groups.
  return fn.substitute(s, NOTSLASH .. [[\zs\\(]], [[\\%(]], 'g')
end

---@param s string
---@return boolean
local function contains_backref(s)
  return s:find('\\1', 1, true) ~= nil
end

---@param s string
---@return string?
local function first_capture_pattern(s)
  local i = 1
  while i <= #s - 1 do
    if s:sub(i, i) == '\\' then
      local next_two = s:sub(i + 1, i + 2)
      if next_two == '%(' then
        i = i + 3
      elseif s:sub(i + 1, i + 1) == '(' then
        local depth = 1
        local j = i + 2
        while j <= #s - 1 do
          if s:sub(j, j) == '\\' then
            local pair = s:sub(j + 1, j + 2)
            if pair == '%(' then
              depth = depth + 1
              j = j + 3
            elseif s:sub(j + 1, j + 1) == '(' then
              depth = depth + 1
              j = j + 2
            elseif s:sub(j + 1, j + 1) == ')' then
              depth = depth - 1
              if depth == 0 then
                return s:sub(i, j + 1)
              end
              j = j + 2
            else
              j = j + 2
            end
          else
            j = j + 1
          end
        end
        return nil
      else
        i = i + 2
      end
    else
      i = i + 1
    end
  end
  return nil
end

---@param s string
---@param repl string
---@return string
local function replace_backref(s, repl)
  return (s:gsub('\\1', function()
    return repl
  end))
end

---@return nvim.matchit.PatternGroup[]
local function matchpair_groups()
  local groups = {} ---@type nvim.matchit.PatternGroup[]
  for _, pair in ipairs(vim.split(vim.bo.matchpairs, ',', { trimempty = true })) do
    local items = vim.split(pair, ':', { plain = true })
    if #items == 2 then
      table.insert(groups, {
        fn.escape(items[1], [=[[$^.*~\/?]=]),
        fn.escape(items[2], [=[[$^.*~\/?]=]),
      })
    end
  end
  return groups
end

---@return string
local function buffer_match_words()
  local words = vim.b.match_words
  if words == nil or words == '' then
    return ''
  end
  if words:find(':', 1, true) == nil then
    -- Allow b:match_words = "GetVimMatchWords()" .
    return api.nvim_eval(words)
  end
  return words
end

---@return nvim.matchit.PatternGroup[]
local function parse_groups()
  local groups = {} ---@type nvim.matchit.PatternGroup[]
  local words = buffer_match_words()
  for _, group in ipairs(split_escaped(words, ',')) do
    local parts = split_escaped(group, ':')
    if #parts > 1 then
      table.insert(groups, parts)
    end
  end
  -- quote the special chars in 'matchpairs'
  for _, group in ipairs(matchpair_groups()) do
    table.insert(groups, group)
  end
  -- append the builtin pairs (/*, */, #if, #ifdef, #ifndef, #else, #elif,
  -- #elifdef, #elifndef, #endif)
  for _, group in ipairs(split_escaped(DEFAULT_WORDS, ',')) do
    local parts = split_escaped(group, ':')
    if #parts > 1 then
      table.insert(groups, parts)
    end
  end
  return groups
end

---@param group nvim.matchit.PatternGroup
---@return nvim.matchit.PatternGroup
local function detect_parts(group)
  local replacement = first_capture_pattern(group[1]) or [[.\{-}]]
  local parts = {} ---@type nvim.matchit.PatternGroup
  for _, part in ipairs(group) do
    if contains_backref(part) then
      table.insert(parts, replace_backref(part, replacement))
    else
      table.insert(parts, part)
    end
  end
  return parts
end

---@param line string
---@param pat string
---@param start_col integer
---@return string[]
local function anchored_matchlist(line, pat, start_col)
  return fn.matchlist(line, ('\\%%%dc\\%%(%s\\)'):format(start_col + 1, pat))
end

---@param line string
---@param group nvim.matchit.PatternGroup
---@param detect nvim.matchit.PatternGroup
---@param part_index integer
---@param start_col integer
---@return string?
local function candidate_ref(line, group, detect, part_index, start_col)
  local found = anchored_matchlist(line, detect[part_index], start_col)
  if found[1] ~= '' and found[2] ~= nil then
    return found[2]
  end
  if detect[part_index] ~= group[part_index] then
    found = anchored_matchlist(line, group[part_index], start_col)
    if found[1] ~= '' and found[2] ~= nil then
      return found[2]
    end
  end
  if contains_backref(table.concat(group, ':')) then
    found = anchored_matchlist(line, detect[1], start_col)
    if found[1] ~= '' and found[2] ~= nil then
      return found[2]
    end
  end
  return nil
end

---@param line string
---@param group nvim.matchit.PatternGroup
---@param detect nvim.matchit.PatternGroup
---@param part_index integer
---@param start_col integer
---@return nvim.matchit.PatternGroup
local function resolved_group(line, group, detect, part_index, start_col)
  local ref = candidate_ref(line, group, detect, part_index, start_col)
  local parts = {} ---@type nvim.matchit.PatternGroup
  if ref == nil then
    for _, part in ipairs(detect) do
      table.insert(parts, unescape_delims(part))
    end
    return parts
  end
  -- escape magic pattern metacharacters and matchit special characters [,:]
  local escaped = fn.escape(ref, [[\.*[^$~,:]])
  for index, part in ipairs(group) do
    if index == 1 then
      local capture = first_capture_pattern(part)
      if capture ~= nil then
        part = part:gsub(vim.pesc(capture), escaped, 1)
      end
    end
    table.insert(parts, unescape_delims(replace_backref(part, escaped)))
  end
  return parts
end

---@param line string
---@param pat string
---@return fun(): integer?, integer?, string?
local function iter_matches(line, pat)
  local start = 0
  return function()
    while start <= #line do
      local item = fn.matchstrpos(line, pat, start)
      local text, from, to = item[1], item[2], item[3]
      if from < 0 then
        return nil
      end
      start = math.max(to, from + 1)
      if text ~= '' then
        return from, to, text
      end
    end
    return nil
  end
end

---@param candidate nvim.matchit.MatchCandidate
---@param best nvim.matchit.MatchCandidate?
---@param cursor_col integer
---@return boolean
local function better_candidate(candidate, best, cursor_col)
  if best == nil then
    return true
  end
  if candidate.contains ~= best.contains then
    return candidate.contains
  end
  local candidate_distance = math.abs(cursor_col - candidate.start_col)
  local best_distance = math.abs(cursor_col - best.start_col)
  if candidate_distance ~= best_distance then
    return candidate_distance < best_distance
  end
  if candidate.start_col ~= best.start_col then
    return candidate.start_col > best.start_col
  end
  if candidate.group_index ~= best.group_index then
    return candidate.group_index < best.group_index
  end
  if candidate.part_index ~= best.part_index then
    return candidate.part_index < best.part_index
  end
  local candidate_length = candidate.end_col - candidate.start_col
  local best_length = best.end_col - best.start_col
  return candidate_length > best_length
end

---@return nvim.matchit.MatchCandidate?
local function find_current()
  -- Require match to end on or after the cursor and prefer it to
  -- start on or before the cursor.
  local cursor = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local cursor_col = cursor[2]
  local best = nil ---@type nvim.matchit.MatchCandidate?
  for group_index, group in ipairs(parse_groups()) do
    local detect = detect_parts(group)
    for part_index, pat in ipairs(detect) do
      for start_col, end_col, text in iter_matches(line, pat) do
        if end_col > cursor_col then
          ---@type nvim.matchit.MatchCandidate
          local candidate = {
            group = group,
            detect = detect,
            group_index = group_index,
            part_index = part_index,
            start_col = start_col,
            end_col = end_col,
            text = text,
            contains = start_col <= cursor_col and cursor_col < end_col,
          }
          if better_candidate(candidate, best, cursor_col) then
            best = candidate
          end
        end
      end
    end
  end
  if best == nil then
    return nil
  end
  best.line = cursor[1]
  best.resolved = resolved_group(line, best.group, best.detect, best.part_index, best.start_col)
  return best
end

---@param pattern string
---@return boolean
local function captures_match(pattern)
  for _, capture in ipairs(vim.treesitter.get_captures_at_cursor()) do
    if fn.match(capture, pattern) ~= -1 then
      return true
    end
  end
  return false
end

---@param pattern string
---@return boolean
local function syntax_match(pattern)
  for _, id in ipairs(fn.synstack(fn.line('.'), fn.col('.'))) do
    if fn.match(fn.synIDattr(id, 'name'), [[\c]] .. pattern) ~= -1 then
      return true
    end
  end
  return false
end

-- Parse special strings as typical skip arguments for searchpair():
--   s:foo becomes (current syntax item) =~ foo
--   S:foo becomes (current syntax item) !~ foo
--   r:foo becomes (line before cursor) =~ foo
--   R:foo becomes (line before cursor) !~ foo
--   t:foo becomes (current treesitter captures) =~ foo
--   T:foo becomes (current treesitter captures) !~ foo
---@param expr? string
---@return nvim.matchit.Skip
local function parse_skip(expr)
  expr = expr or vim.b.match_skip or [[s:comment\|string]]
  if expr == '' then
    return function()
      return false
    end
  end
  if expr:sub(2, 2) == ':' then
    local kind = expr:sub(1, 1)
    local pattern = expr:sub(3)
    if kind == 't' then
      return function()
        return captures_match(pattern)
      end
    elseif kind == 'T' then
      return function()
        return not captures_match(pattern)
      end
    elseif kind == 's' then
      if vim.b.ts_highlight ~= nil and vim.bo.syntax ~= 'on' then
        return function()
          return captures_match(pattern)
        end
      end
      if vim.g.syntax_on == nil then
        return function()
          return false
        end
      end
      return function()
        return syntax_match(pattern)
      end
    elseif kind == 'S' then
      if vim.b.ts_highlight ~= nil and vim.bo.syntax ~= 'on' then
        return function()
          return not captures_match(pattern)
        end
      end
      if vim.g.syntax_on == nil then
        return function()
          return false
        end
      end
      return function()
        return not syntax_match(pattern)
      end
    elseif kind == 'r' then
      return function()
        return fn.match(fn.strpart(fn.getline('.'), 0, fn.col('.')), pattern) ~= -1
      end
    elseif kind == 'R' then
      return function()
        return fn.match(fn.strpart(fn.getline('.'), 0, fn.col('.')), pattern) == -1
      end
    end
  end
  return function()
    local ok, result = pcall(api.nvim_eval, expr)
    return ok and result ~= false and result ~= 0 and result ~= nil
  end
end

---@param fncall fun()
local function with_options(fncall)
  local save_ignorecase = vim.o.ignorecase
  local save_smartcase = vim.o.smartcase
  local save_virtualedit = vim.o.virtualedit
  if vim.b.match_ignorecase ~= nil then
    vim.o.ignorecase = vim.b.match_ignorecase ~= 0
  end
  vim.o.smartcase = false
  vim.o.virtualedit = ''
  local ok, result = pcall(fncall)
  vim.o.ignorecase = save_ignorecase
  vim.o.smartcase = save_smartcase
  vim.o.virtualedit = save_virtualedit
  if not ok then
    error(result)
  end
  return result
end

---@param group nvim.matchit.PatternGroup
---@return string open
---@return string middle
---@return string close
local function group_patterns(group)
  local open = noncapturing(group[1])
  local close = noncapturing(group[#group])
  local middle = {}
  for i = 2, #group - 1 do
    table.insert(middle, noncapturing(group[i]))
  end
  return open, table.concat(middle, [[\|]]), close
end

---@param match nvim.matchit.MatchCandidate
---@param forward boolean
---@return string open
---@return string middle
---@return string close
---@return string flags
local function search_patterns(match, forward)
  local resolved = assert(match.resolved)
  local open, middle, close = group_patterns(resolved)
  if forward and match.part_index == #resolved or not forward and match.part_index == 1 then
    middle = ''
  end
  local backward = forward and match.part_index == #resolved or not forward and match.part_index ~= 1
  return open, middle, close, backward and 'bW' or 'W'
end

---@param startpos [integer, integer]
---@param tail string
local function finish_operator(startpos, tail)
  -- In Operator-pending mode, we want to include the whole match
  -- (for example, d%).
  -- This is only a problem if we end up moving in the forward direction.
  if startpos[1] > fn.line('.') or startpos[1] == fn.line('.') and startpos[2] >= fn.col('.') then
    return
  end
  if tail == '' then
    return
  end
  local line = api.nvim_get_current_line()
  local col = fn.col('.') - 1
  -- Check whether the match is a single character.  If not, move to the
  -- end of the match.
  local item = fn.matchstrpos(line, [[\%]] .. fn.col('.') .. [[c\%(]] .. tail .. [[\)]])
  if item[3] > col + 1 then
    api.nvim_win_set_cursor(0, { fn.line('.'), item[3] })
  end
end

---@param forward? boolean
---@param mode? nvim.matchit.Mode
function M.jump(forward, mode)
  forward = forward ~= false
  mode = mode or 'n'
  -- if a count has been applied, use the default [count]% mode (see :h N%)
  if vim.v.count > 0 then
    vim.cmd('normal! ' .. vim.v.count .. '%')
    return
  end
  local startpos = { fn.line('.'), fn.col('.') }
  if mode == 'o' and not api.nvim_get_mode().mode:find('[vV\22]') then
    vim.cmd('normal! v')
  elseif mode == 'v' then
    -- If this function was called from Visual mode, make sure that the cursor
    -- is at the correct end of the Visual range:
    vim.cmd([[normal! gv\<Esc>]])
    startpos = { fn.line('.'), fn.col('.') }
  end

  -- Check for custom match function hook
  if fn.exists('b:match_function') ~= 0 then
    local ok, result = pcall(fn.eval, ('call(b:match_function, [%d])'):format(forward and 1 or 0))
    if ok and type(result) == 'table' and #result >= 2 then
      api.nvim_win_set_cursor(0, { result[1], result[2] - 1 })
      return
    elseif not ok then
      return
    end
    -- Empty result: fall through to regular matching
  end

  with_options(function()
    local match = find_current()
    if match == nil then
      return
    end
    -- Set the arguments for searchpair().
    local open, middle, close, flags = search_patterns(match, forward)
    -- Set skip.
    local skip = parse_skip()
    local view = fn.winsaveview()
    api.nvim_win_set_cursor(0, { assert(match.line), match.start_col })
    if skip() then
      skip = function()
        return false
      end
    end
    -- Invalid user patterns should not leave the cursor/view moved.
    local ok, found = pcall(fn.searchpair, open, middle, close, flags, skip)
    if not ok then
      fn.winrestview(view)
      return
    end
    local eolmark = false
    if found > 0 and mode == 'v' and vim.o.selection ~= 'inclusive' then
      -- Exclusive selections need one byte past the match when possible.
      if fn.col('.') >= fn.col('$') - 1 then
        -- At EOL, remember to put the selection mark after the last byte.
        eolmark = true
      end
      vim.cmd('normal! l')
    end
    local target = api.nvim_win_get_cursor(0)
    fn.winrestview(view)
    if found > 0 then
      api.nvim_win_set_cursor(0, target)
      if eolmark then
        fn.setpos("''", { 0, fn.line('.'), fn.col('$'), 0 })
      end
      if mode == 'o' then
        finish_operator(startpos, table.concat({ middle, close }, [[\|]]))
      elseif vim.o.foldopen:find('percent', 1, true) ~= nil then
        -- Open folds, if appropriate.
        vim.cmd('normal! zv')
      end
    end
  end)
end

---@return string opens
---@return string middles
---@return string closes
local function all_patterns()
  local opens = {}
  local middles = {}
  local closes = {}
  for _, group in ipairs(parse_groups()) do
    local detect = detect_parts(group)
    table.insert(opens, noncapturing(unescape_delims(detect[1])))
    table.insert(closes, noncapturing(unescape_delims(detect[#detect])))
    for i = 2, #detect - 1 do
      table.insert(middles, noncapturing(unescape_delims(detect[i])))
    end
  end
  return table.concat(opens, [[\|]]), table.concat(middles, [[\|]]), table.concat(closes, [[\|]])
end

-- Jump to the nearest unmatched "(" or "if" or "<tag>" if a:spflag == "bW"
-- or the nearest unmatched "</tag>" or "endif" or ")" if a:spflag == "W".
---@param flags string
---@param mode? nvim.matchit.Mode
function M.multi_match(flags, mode)
  mode = mode or 'n'
  local count = math.max(vim.v.count1, 1)
  if mode == 'o' and not api.nvim_get_mode().mode:find('[vV\22]') then
    vim.cmd('normal! v')
  elseif mode == 'v' then
    vim.cmd([[normal! gv\<Esc>]])
  end
  with_options(function()
    local open, middle, close = all_patterns()
    local skip = parse_skip()
    if skip() then
      skip = function()
        return false
      end
    end
    while count > 0 do
      -- Invalid user patterns stop the multi-match without moving further.
      local ok, found = pcall(fn.searchpair, open, middle, close, flags, skip)
      if not ok or found < 1 then
        return
      end
      count = count - 1
    end
  end)
end

return M
