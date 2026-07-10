-- matchit: Extended "%" matching

local fn = vim.fn

local M = {}

local last_mps = ''
local last_words = ':'
local patBR = ''

local notslash = [[\\\@1<!\%(\\\\\)*]]

local do_BR ---@type boolean
local pat ---@type string
local all ---@type string

local function restore_options()
  -- In clean_up(), :execute "set" restore_options.
  local restore_options = ''
  local match_ignorecase = vim.b.match_ignorecase
  if match_ignorecase == nil then
    match_ignorecase = vim.o.ignorecase
  else
    match_ignorecase = match_ignorecase ~= 0
  end
  if match_ignorecase ~= vim.o.ignorecase then
    restore_options = restore_options
      .. (vim.o.ignorecase and ' ' or ' no')
      .. 'ignorecase'
    vim.o.ignorecase = match_ignorecase
  end
  if vim.o.virtualedit ~= '' then
    restore_options = ' ve=' .. vim.o.virtualedit .. restore_options
    vim.o.virtualedit = ''
  end
  if vim.o.smartcase then
    restore_options = ' smartcase ' .. restore_options
    vim.o.smartcase = false
  end
  return restore_options
end

local clean_up
local append
local parse_words
local wholematch
local ref
local count
local resolve
local choose
local insert_refs
local parse_skip

function M.match_wrapper(word, forward, mode)
  local restore_options = restore_options()
  -- In clean_up(), we may need to check whether the cursor moved forward.
  local startpos = { fn.line('.'), fn.col('.') }
  -- if a count has been applied, use the default [count]% mode (see :h N%)
  if vim.v.count ~= 0 then
    vim.cmd('normal! ' .. vim.v.count .. '%')
    return clean_up(restore_options, mode, startpos)
  end
  if mode:find('v') and fn.mode(1):find('ni') then
    vim.cmd('normal! gv')
  elseif mode == 'o' and fn.match(fn.mode(1), '[\\x16vV]') == -1 then
    vim.cmd('normal! v')
    -- If this function was called from Visual mode, make sure that the cursor
    -- is at the correct end of the Visual range:
  elseif mode == 'v' then
    vim.cmd([[execute "normal! gv\<Esc>"]])
    startpos = { fn.line('.'), fn.col('.') }
  end

  -- Check for custom match function hook
  if vim.b.match_function ~= nil then
    local ok, result = pcall(fn.call, vim.b.match_function, { forward })
    if ok then
      if not vim.tbl_isempty(result) then
        fn.cursor(result)
        return clean_up(restore_options, mode, startpos)
      end
    else
      if vim.b.match_debug ~= nil then
        vim.api.nvim_echo({ { 'matchit: b:match_function error: ' .. result, 'WarningMsg' } }, true, {})
      end
      return clean_up(restore_options, mode, startpos)
    end
    -- Empty result: fall through to regular matching
  end

  -- First step:  if not already done, set the script variables
  --   do_BR   flag for whether there are backrefs
  --   pat     parsed version of b:match_words
  --   all     regexp based on pat and the default groups
  local match_words
  if vim.b.match_words == nil or vim.b.match_words == '' then
    match_words = ''
  elseif fn.match(vim.b.match_words, ':') ~= -1 then
    match_words = vim.b.match_words
  else
    -- Allow b:match_words = "GetVimMatchWords()" .
    match_words = fn.eval(vim.b.match_words)
  end
  -- Thanks to Preben "Peppe" Guldberg and Bram Moolenaar for this suggestion!
  if match_words ~= last_words or vim.o.matchpairs ~= last_mps or vim.b.match_debug ~= nil then
    last_mps = vim.o.matchpairs
    -- quote the special chars in 'matchpairs', replace [,:] with \| and then
    -- append the builtin pairs (/*, */, #if, #ifdef, #ifndef, #else, #elif,
    -- #elifdef, #elifndef, #endif)
    local default = fn.escape(vim.o.matchpairs, [=[[$^.*~\/?]]=])
      .. (#vim.o.matchpairs > 0 and ',' or '')
      .. [[\/\*:\*\/,#\s*if\%(n\=def\)\=:#\s*else\>:#\s*elif\%(n\=def\)\=\>:#\s*endif\>]]
    -- all = pattern with all the keywords
    match_words = append(match_words, default)
    last_words = match_words
    if fn.match(match_words, notslash .. [[\\\d]]) == -1 then
      do_BR = false
      pat = match_words
    else
      do_BR = true
      pat = parse_words(match_words)
    end
    all = fn.substitute(pat, notslash .. [[\zs[,:]\+]], [[\\|]], 'g')
    -- un-escape \, and \: to , and :
    all = fn.substitute(all, notslash .. [[\zs\\\(:\|,\)]], [[\1]], 'g')
    -- Just in case there are too many '\(...)' groups inside the pattern, make
    -- sure to use \%(...) groups, so that error E872 can be avoided
    all = fn.substitute(all, notslash .. [[\zs\\(]], [[\\%(]], 'g')
    all = [[\%(]] .. all .. [[\)]]
    if vim.b.match_debug ~= nil then
      vim.b.match_pat = pat
    end
    -- Reconstruct the version with unresolved backrefs.
    patBR = fn.substitute(match_words .. ',', notslash .. [[\zs[,:]*,[,:]*]], ',', 'g')
    patBR = fn.substitute(patBR, notslash .. [[\zs:\{2,}]], ':', 'g')
    -- un-escape \, to ,
    patBR = fn.substitute(patBR, [[\,]], ',', 'g')
  end

  -- Second step:  set the following local variables:
  --     matchline = line on which the cursor started
  --     curcol    = number of characters before match
  --     prefix    = regexp for start of line to start of match
  --     suffix    = regexp for end of match to end of line
  -- Require match to end on or after the cursor and prefer it to
  -- start on or before the cursor.
  local matchline = fn.getline(startpos[1])
  local curcol, prefix, suffix, regexp
  if word ~= '' then
    -- word given
    if fn.match(word, all) == -1 then
      vim.api.nvim_echo({ { 'Missing rule for word:"' .. word .. '"', 'WarningMsg' } }, false, {})
      return clean_up(restore_options, mode, startpos)
    end
    matchline = word
    curcol = 0
    prefix = [[^\%(]]
    suffix = [[\)$]]
    -- Now the case when "word" is not given
  else
    -- Find the match that ends on or after the cursor and set curcol.
    regexp = wholematch(matchline, all, startpos[2] - 1)
    curcol = fn.match(matchline, regexp)
    -- If there is no match, give up.
    if curcol == -1 then
      return clean_up(restore_options, mode, startpos)
    end
    local endcol = fn.matchend(matchline, regexp)
    local suf = #matchline - endcol
    prefix = curcol ~= 0 and ('^.*\\%' .. (curcol + 1) .. [[c\%(]]) or [[^\%(]]
    suffix = suf ~= 0 and ([[\)\%]] .. (endcol + 1) .. 'c.*$') or [[\)$]]
  end
  if vim.b.match_debug ~= nil then
    vim.b.match_match = fn.matchstr(matchline, regexp)
    vim.b.match_col = curcol + 1
  end

  -- Third step:  Find the group and single word that match, and the original
  -- (backref) versions of these.  Then, resolve the backrefs.
  -- Set the following local variable:
  -- group = colon-separated list of patterns, one of which matches
  --       = ini:mid:fin or ini:fin
  --
  -- Now, set group and groupBR to the matching group: 'if:endif' or
  -- 'while:endwhile' or whatever.  A bit of a kluge: choose() returns
  -- group . "," . groupBR, and we pick it apart.
  local group = choose(pat, matchline, ',', ':', prefix, suffix, patBR)
  local i = fn.matchend(group, notslash .. ',')
  local groupBR = fn.strpart(group, i)
  group = fn.strpart(group, 0, i - 1)
  -- Now, matchline =~ prefix . substitute(group,':','\|','g') . suffix
  if do_BR then -- Do the hard part:  resolve those backrefs!
    group = insert_refs(groupBR, prefix, group, suffix, matchline)
  end
  if vim.b.match_debug ~= nil then
    vim.b.match_wholeBR = groupBR
    i = fn.matchend(groupBR, notslash .. ':')
    vim.b.match_iniBR = fn.strpart(groupBR, 0, i - 1)
  end

  -- Fourth step:  Set the arguments for searchpair().
  i = fn.matchend(group, notslash .. ':')
  local j = fn.matchend(group, '.*' .. notslash .. ':')
  local ini = fn.strpart(group, 0, i - 1)
  local mid = fn.substitute(fn.strpart(group, i, j - i - 1), notslash .. [[\zs:]], [[\\|]], 'g')
  local fin = fn.strpart(group, j)
  -- Un-escape the remaining , and : characters.
  ini = fn.substitute(ini, notslash .. [[\zs\\\(:\|,\)]], [[\1]], 'g')
  mid = fn.substitute(mid, notslash .. [[\zs\\\(:\|,\)]], [[\1]], 'g')
  fin = fn.substitute(fin, notslash .. [[\zs\\\(:\|,\)]], [[\1]], 'g')
  -- searchpair() requires that these patterns avoid \(\) groups.
  ini = fn.substitute(ini, notslash .. [[\zs\\(]], [[\\%(]], 'g')
  mid = fn.substitute(mid, notslash .. [[\zs\\(]], [[\\%(]], 'g')
  fin = fn.substitute(fin, notslash .. [[\zs\\(]], [[\\%(]], 'g')
  -- Set mid.  This is optimized for readability, not micro-efficiency!
  if (forward and fn.match(matchline, prefix .. fin .. suffix) ~= -1)
    or (not forward and fn.match(matchline, prefix .. ini .. suffix) ~= -1)
  then
    mid = ''
  end
  -- Set flag.  This is optimized for readability, not micro-efficiency!
  local flag
  if (forward and fn.match(matchline, prefix .. fin .. suffix) ~= -1)
    or (not forward and fn.match(matchline, prefix .. ini .. suffix) == -1)
  then
    flag = 'bW'
  else
    flag = 'W'
  end
  -- Set skip.
  local skip
  if vim.b.match_skip ~= nil then
    skip = vim.b.match_skip
  elseif vim.b.match_comment ~= nil then -- backwards compatibility and testing!
    skip = 'r:' .. vim.b.match_comment
  else
    skip = [[s:comment\|string]]
  end
  skip = parse_skip(skip)
  if vim.b.match_debug ~= nil then
    vim.b.match_ini = ini
    vim.b.match_tail = (#mid > 0 and (mid .. [[\|]]) or '') .. fin
  end

  -- Fifth step:  actually start moving the cursor and call searchpair().
  -- Later, :execute restore_cursor to get to the original screen.
  local view = fn.winsaveview()
  fn.cursor(0, curcol + 1)
  if (skip:find('synID', 1, true) and not (vim.fn.has('syntax') == 1 and vim.g.syntax_on ~= nil))
    or (skip:find('v:lua.vim.treesitter', 1, true) and vim.b.ts_highlight == nil)
  then
    skip = '0'
  elseif fn.eval(skip) ~= 0 then
    skip = '0'
  end
  local sp_return = fn.searchpair(ini, mid, fin, flag, skip)
  local eolmark
  if vim.o.selection ~= 'inclusive' and mode == 'v' then
    -- move cursor one pos to the right, because selection is not inclusive
    -- add virtualedit=onemore, to make it work even when the match ends the
    -- line
    if not (fn.col('.') < fn.col('$') - 1) then
      eolmark = true -- flag to set a mark on eol (since we cannot move there)
    end
    vim.cmd('normal! l')
  end
  local final_position = { fn.line('.'), fn.col('.') }
  -- Restore cursor position and original screen.
  fn.winrestview(view)
  vim.cmd([[normal! m']])
  if sp_return > 0 then
    fn.cursor(final_position)
  end
  if eolmark then
    fn.setpos("''", { 0, fn.line('.'), fn.col('$'), 0 }) -- set mark on the eol
  end
  return clean_up(restore_options, mode, startpos, mid .. [[\|]] .. fin)
end

-- Restore options and do some special handling for Operator-pending mode.
-- The optional argument is the tail of the matching group.
clean_up = function(options, mode, startpos, ...)
  if #options > 0 then
    vim.cmd('set' .. options)
  end
  -- Open folds, if appropriate.
  if mode ~= 'o' then
    if vim.o.foldopen:find('percent', 1, true) then
      vim.cmd('normal! zv')
    end
    -- In Operator-pending mode, we want to include the whole match
    -- (for example, d%).
    -- This is only a problem if we end up moving in the forward direction.
  elseif startpos[1] < fn.line('.')
    or (startpos[1] == fn.line('.') and startpos[2] < fn.col('.'))
  then
    local args = { ... }
    if #args > 0 then
      -- Check whether the match is a single character.  If not, move to the
      -- end of the match.
      local matchline = fn.getline('.')
      local currcol = fn.col('.')
      local regexp = wholematch(matchline, args[1], currcol - 1)
      local endcol = fn.matchend(matchline, regexp)
      if endcol > currcol then -- This is NOT off by one!
        fn.cursor(0, endcol)
      end
    end
  end
  return 0
end

-- Example (simplified HTML patterns):  if
--   groupBR   = '<\(\k\+\)>:</\1>'
--   prefix    = '^.\{3}\('
--   group     = '<\(\k\+\)>:</\(\k\+\)>'
--   suffix    = '\).\{2}$'
--   matchline =  "123<tag>12" or "123</tag>12"
-- then extract "tag" from matchline and return "<tag>:</tag>" .
insert_refs = function(groupBR, prefix, group, suffix, matchline)
  if fn.match(matchline, prefix .. fn.substitute(group, notslash .. [[\zs:]], [[\\|]], 'g') .. suffix) == -1 then
    return group
  end
  local i = fn.matchend(groupBR, notslash .. ':')
  local ini = fn.strpart(groupBR, 0, i - 1)
  local tailBR = fn.strpart(groupBR, i)
  local word = choose(group, matchline, ':', '', prefix, suffix, groupBR)
  i = fn.matchend(word, notslash .. ':')
  local wordBR = fn.strpart(word, i)
  word = fn.strpart(word, 0, i - 1)
  -- Now, matchline =~ prefix . word . suffix
  local ref_table
  if wordBR ~= ini then
    ref_table = resolve(ini, wordBR, 'table')
  else
    ref_table = ''
    local d = 0
    while d < 10 do
      if fn.match(tailBR, notslash .. '\\\\' .. d) ~= -1 then
        ref_table = ref_table .. d
      else
        ref_table = ref_table .. '-'
      end
      d = d + 1
    end
  end
  local d = 9
  while d ~= 0 do
    if fn.strpart(ref_table, d, 1) ~= '-' then
      local backref = fn.substitute(matchline, prefix .. word .. suffix, '\\' .. fn.strpart(ref_table, d, 1), '')
      -- escape magic pattern metacharacters and matchit special characters [,:]
      backref = fn.escape(backref, [[\.*[^$~,:]])
      local start, len = ref(ini, d, 'start', 'len')
      ini = fn.strpart(ini, 0, start) .. backref .. fn.strpart(ini, start + len)
      tailBR = fn.substitute(tailBR, notslash .. [[\zs\\]] .. d, fn.escape(backref, [[\&]]), 'g')
    end
    d = d - 1
  end
  if vim.b.match_debug ~= nil then
    if do_BR then
      vim.b.match_table = ref_table
      vim.b.match_word = word
    else
      vim.b.match_table = ''
      vim.b.match_word = ''
    end
  end
  return ini .. ':' .. tailBR
end

-- String append item2 to item and add ',' in between items
append = function(item, item2)
  if item == '' then
    return item2
  end
  -- there is already a trailing comma, don't add another one
  if item:sub(-1) == ',' then
    return item .. item2
  end
  return item .. ',' .. item2
end

-- Input a comma-separated list of groups with backrefs, such as
--   groups = '\(foo\):end\1,\(bar\):end\1'
-- and return a comma-separated list of groups with backrefs replaced:
--   return '\(foo\):end\(foo\),\(bar\):end\(bar\)'
parse_words = function(groups)
  groups = fn.substitute(groups .. ',', notslash .. [[\zs[,:]*,[,:]*]], ',', 'g')
  groups = fn.substitute(groups, notslash .. [[\zs:\{2,}]], ':', 'g')
  local parsed = ''
  while fn.match(groups, '[^,:]') ~= -1 do
    local i = fn.matchend(groups, notslash .. ':')
    local j = fn.matchend(groups, notslash .. ',')
    local ini = fn.strpart(groups, 0, i - 1)
    local tail = fn.strpart(groups, i, j - i - 1) .. ':'
    groups = fn.strpart(groups, j)
    parsed = parsed .. ini
    i = fn.matchend(tail, notslash .. ':')
    while i ~= -1 do
      -- In 'if:else:endif', ini='if' and word='else' and then word='endif'.
      local word = fn.strpart(tail, 0, i - 1)
      tail = fn.strpart(tail, i)
      i = fn.matchend(tail, notslash .. ':')
      parsed = parsed .. ':' .. resolve(ini, word, 'word')
    end -- Now, tail has been used up.
    parsed = parsed .. ','
  end
  return fn.substitute(parsed, ',$', '', '')
end

-- TODO I think this can be simplified and/or made more efficient.
-- TODO What should I do if start is out of range?
-- Return a regexp that matches all of string, such that
-- matchstr(string, regexp) represents the match for pat that starts
-- as close to start as possible, before being preferred to after, and
-- ends after start .
wholematch = function(string, pattern, start)
  local group = [[\%(]] .. pattern .. [[\)]]
  local prefix = start ~= 0 and ([[\(^.*\%<]] .. (start + 2) .. [[c\)\zs]]) or '^'
  local len = #string
  local suffix = start + 1 < len and ([[\(\%>]] .. (start + 1) .. [[c.*$\)\@=]]) or '$'
  if fn.match(string, prefix .. group .. suffix) == -1 then
    prefix = ''
  end
  return prefix .. group .. suffix
end

-- No extra arguments: ref(string, d) will find the d'th occurrence of '\('
-- and return it, along with everything up to and including the matching '\)'.
ref = function(string, d, ...)
  local args = { ... }
  local len = #string
  local start
  if d == 0 then
    start = 0
  else
    local cnt = d
    local match = string
    while cnt ~= 0 do
      cnt = cnt - 1
      local index = fn.matchend(match, notslash .. [[\\(]])
      if index == -1 then
        return ''
      end
      match = fn.strpart(match, index)
    end
    start = len - #match
    if #args == 1 and args[1] == 'start' then
      return start - 2
    end
    cnt = 1
    while cnt ~= 0 do
      local index = fn.matchend(match, notslash .. [[\\(\|\\)]]) - 1
      if index == -2 then
        return ''
      end
      cnt = cnt + (fn.strpart(match, index, 1) == '(' and 1 or -1)
      match = fn.strpart(match, index + 1)
    end
    start = start - 2
    len = len - start - #match
  end
  if #args == 1 then
    return len
  elseif #args == 2 then
    return start, len
  else
    return fn.strpart(string, start, len)
  end
end

-- Count the number of disjoint copies of pattern in string.
count = function(string, pattern, ...)
  local args = { ... }
  local escaped_pattern = fn.escape(pattern, [[\]])
  if #args > 1 then
    local foo = fn.substitute(string, '[^' .. pattern .. ']', args[1], 'g')
    foo = fn.substitute(foo, escaped_pattern, args[2], 'g')
    foo = fn.substitute(foo, '[^' .. args[2] .. ']', '', 'g')
    return #foo
  end
  local result = 0
  local foo = string
  local index = fn.matchend(foo, escaped_pattern)
  while index ~= -1 do
    result = result + 1
    foo = fn.strpart(foo, index)
    index = fn.matchend(foo, escaped_pattern)
  end
  return result
end

-- resolve('\(a\)\(b\)', '\(c\)\2\1\1\2') should return table.word, where
-- word = '\(c\)\(b\)\(a\)\3\2' and table = '-32-------'.
resolve = function(source, target, output)
  local word = target
  local i = fn.matchend(word, notslash .. [[\\\d]]) - 1
  local ref_table = '----------'
  while i ~= -2 do -- There are back references to be replaced.
    local d = tonumber(fn.strpart(word, i, 1))
    local backref = ref(source, d)
    -- The idea is to replace '\d' with backref.  The hard part is dealing
    -- with nested groups and renumbering the inserted references.
    local w = count(fn.substitute(fn.strpart(word, 0, i - 1), [[\\\\]], '', 'g'), [[\(]], '1')
    local b = 1
    local s = d
    while b <= count(fn.substitute(backref, [[\\\\]], '', 'g'), [[\(]], '1') and s < 10 do
      if fn.strpart(ref_table, s, 1) == '-' then
        if w + b < 10 then
          ref_table = fn.strpart(ref_table, 0, s) .. (w + b) .. fn.strpart(ref_table, s + 1)
        end
        b = b + 1
        s = s + 1
      else
        local start, len = ref(backref, b, 'start', 'len')
        local nested_ref = fn.strpart(backref, start, len)
        backref = fn.strpart(backref, 0, start)
          .. ':'
          .. fn.strpart(ref_table, s, 1)
          .. fn.strpart(backref, start + len)
        s = s + count(fn.substitute(nested_ref, [[\\\\]], '', 'g'), [[\(]], '1')
      end
    end
    word = fn.strpart(word, 0, i - 1) .. backref .. fn.strpart(word, i + 1)
    i = fn.matchend(word, notslash .. [[\\\d]]) - 1
  end
  word = fn.substitute(word, notslash .. [[\zs:]], [[\\]], 'g')
  if output == 'table' then
    return ref_table
  elseif output == 'word' then
    return word
  else
    return ref_table .. word
  end
end

-- If patterns is "<pat1>,<pat2>,...", return the first matching pattern and,
-- when supplied, the corresponding alternative.
choose = function(patterns, string, comma, branch, prefix, suffix, ...)
  local args = { ... }
  local tail = fn.match(patterns, comma .. '$') ~= -1 and patterns or patterns .. comma
  local i = fn.matchend(tail, notslash .. comma)
  local alttail, j
  if #args > 0 then
    alttail = fn.match(args[1], comma .. '$') ~= -1 and args[1] or args[1] .. comma
    j = fn.matchend(alttail, notslash .. comma)
  end
  local current = fn.strpart(tail, 0, i - 1)
  local currpat = branch == '' and current
    or fn.substitute(current, notslash .. branch, [[\\|]], 'g')
  -- un-escape \, and \: to , and :
  currpat = fn.substitute(currpat, notslash .. [[\zs\\\(:\|,\)]], [[\1]], 'g')
  while fn.match(string, prefix .. currpat .. suffix) == -1 do
    tail = fn.strpart(tail, i)
    i = fn.matchend(tail, notslash .. comma)
    if i == -1 then
      return -1
    end
    current = fn.strpart(tail, 0, i - 1)
    currpat = branch == '' and current
      or fn.substitute(current, notslash .. branch, [[\\|]], 'g')
    currpat = fn.substitute(currpat, notslash .. [[\zs\\\(:\|,\)]], [[\1]], 'g')
    if #args > 0 then
      alttail = fn.strpart(alttail, j)
      j = fn.matchend(alttail, notslash .. comma)
    end
  end
  if #args > 0 then
    current = current .. comma .. fn.strpart(alttail, 0, j - 1)
  end
  return current
end

function M.match_debug()
  vim.b.match_debug = 1 -- Save debugging information.
  vim.cmd([[amenu &Matchit.&pat   :echo b:match_pat<CR>]])
  vim.cmd([[amenu &Matchit.&match :echo b:match_match<CR>]])
  vim.cmd([[amenu &Matchit.&curcol :echo b:match_col<CR>]])
  vim.cmd([[amenu &Matchit.wh&oleBR :echo b:match_wholeBR<CR>]])
  vim.cmd([[amenu &Matchit.ini&BR :echo b:match_iniBR<CR>]])
  vim.cmd([[amenu &Matchit.&ini :echo b:match_ini<CR>]])
  vim.cmd([[amenu &Matchit.&tail :echo b:match_tail<CR>]])
  vim.cmd([[amenu &Matchit.&word :echo b:match_word<CR>]])
  vim.cmd([[amenu &Matchit.t&able :echo '0:' .. b:match_table .. ':9'<CR>]])
end

-- Jump to the nearest unmatched "(" or "if" or "<tag>" if spflag == "bW"
-- or the nearest unmatched "</tag>" or "endif" or ")" if spflag == "W".
-- Return a "mark" for the original position, so that
--   local m = multi_match("bW", "n") ... winrestview(m)
-- will return to the original position.  If there is a problem, do not
-- move the cursor and return {}, unless a count is given, in which case
-- go up or down as many levels as possible and again return {}.
-- TODO This relies on the same patterns as % matching.  It might be a good
-- idea to give it its own matching patterns.
function M.multi_match(spflag, mode)
  local restore_options = restore_options()
  local startpos = { fn.line('.'), fn.col('.') }
  -- save v:count1 variable, might be reset from the restore_cursor command
  local level = vim.v.count1
  if mode == 'o' and fn.match(fn.mode(1), '[\\x16vV]') == -1 then
    vim.cmd('normal! v')
  end

  -- First step:  if not already done, set the script variables
  --   do_BR   flag for whether there are backrefs
  --   pat     parsed version of b:match_words
  --   all     regexp based on pat and the default groups
  -- This part is copied and slightly modified from match_wrapper().
  local match_words
  if vim.b.match_words == nil or vim.b.match_words == '' then
    match_words = ''
    -- Allow b:match_words = "GetVimMatchWords()" .
  elseif fn.match(vim.b.match_words, ':') ~= -1 then
    match_words = vim.b.match_words
  else
    match_words = fn.eval(vim.b.match_words)
  end
  if match_words ~= last_words or vim.o.matchpairs ~= last_mps or vim.b.match_debug ~= nil then
    local default = fn.escape(vim.o.matchpairs, [=[[$^.*~\/?]]=])
      .. (#vim.o.matchpairs > 0 and ',' or '')
      .. [[\/\*:\*\/,#\s*if\%(n\=def\)\=:#\s*else\>:#\s*elif\>:#\s*endif\>]]
    last_mps = vim.o.matchpairs
    match_words = append(match_words, default)
    last_words = match_words
    if fn.match(match_words, notslash .. [[\\\d]]) == -1 then
      do_BR = false
      pat = match_words
    else
      do_BR = true
      pat = parse_words(match_words)
    end
    all = [[\%(]] .. fn.substitute(pat, [=[[,:]\+]=], [[\\|]], 'g') .. [[\)]]
    if vim.b.match_debug ~= nil then
      vim.b.match_pat = pat
    end
    -- Reconstruct the version with unresolved backrefs.
    patBR = fn.substitute(match_words .. ',', notslash .. [[\zs[,:]*,[,:]*]], ',', 'g')
    patBR = fn.substitute(patBR, notslash .. [[\zs:\{2,}]], ':', 'g')
  end

  -- Second step:  figure out the patterns for searchpair()
  -- and save the screen, cursor position, and 'ignorecase'.
  -- - TODO:  A lot of this is copied from match_wrapper().
  -- - maybe even more functionality should be split off
  -- - into separate functions!
  local openlist = fn.split(pat .. ',', notslash .. [[\zs:.\{-}]] .. notslash .. ',')
  local midclolist = fn.split(',' .. pat, notslash .. [[\zs,.\{-}]] .. notslash .. ':')
  for i, value in ipairs(midclolist) do
    midclolist[i] = fn.split(value, notslash .. ':')
  end
  local closelist = {}
  local middlelist = {}
  for _, value in ipairs(midclolist) do
    table.insert(closelist, value[#value])
    for i = 1, #value - 1 do
      table.insert(middlelist, value[i])
    end
  end
  for i, value in ipairs(openlist) do
    if fn.match(value, notslash .. [[\\|]]) ~= -1 then
      openlist[i] = [[\%(]] .. value .. [[\)]]
    end
  end
  for i, value in ipairs(middlelist) do
    if fn.match(value, notslash .. [[\\|]]) ~= -1 then
      middlelist[i] = [[\%(]] .. value .. [[\)]]
    end
  end
  for i, value in ipairs(closelist) do
    if fn.match(value, notslash .. [[\\|]]) ~= -1 then
      closelist[i] = [[\%(]] .. value .. [[\)]]
    end
  end
  local open = table.concat(openlist, ',')
  local middle = table.concat(middlelist, ',')
  local close = table.concat(closelist, ',')
  local skip
  if vim.b.match_skip ~= nil then
    skip = vim.b.match_skip
  elseif vim.b.match_comment ~= nil then -- backwards compatibility and testing!
    skip = 'r:' .. vim.b.match_comment
  else
    skip = [[s:comment\|string]]
  end
  skip = parse_skip(skip)
  local view = fn.winsaveview()

  -- Third step: call searchpair().
  -- Replace '\('--but not '\\('--with '\%(' and ',' with '\|'.
  local openpat = fn.substitute(open, [[\%(]] .. notslash .. [[\)\@<=\\(]], [[\\%(]], 'g')
  openpat = fn.substitute(openpat, ',', [[\\|]], 'g')
  local closepat = fn.substitute(close, [[\%(]] .. notslash .. [[\)\@<=\\(]], [[\\%(]], 'g')
  closepat = fn.substitute(closepat, ',', [[\\|]], 'g')
  local middlepat = fn.substitute(middle, [[\%(]] .. notslash .. [[\)\@<=\\(]], [[\\%(]], 'g')
  middlepat = fn.substitute(middlepat, ',', [[\\|]], 'g')

  if (skip:find('synID', 1, true) and not (fn.has('syntax') == 1 and vim.g.syntax_on ~= nil))
    or (skip:find('v:lua.vim.treesitter', 1, true) and vim.b.ts_highlight == nil)
  then
    skip = '0'
  else
    local ok, result = pcall(fn.eval, skip)
    if not ok then
      if tostring(result):find('E363', 1, true) then
        -- We won't find anything, so skip searching, should keep Vim responsive.
        return {}
      end
      error(result)
    elseif result ~= 0 then
      skip = '0'
    end
  end
  vim.cmd([[mark ']])
  while level ~= 0 do
    if fn.searchpair(openpat, middlepat, closepat, spflag, skip) < 1 then
      clean_up(restore_options, mode, startpos)
      return {}
    end
    level = level - 1
  end

  -- Restore options and return a string to restore the original position.
  clean_up(restore_options, mode, startpos)
  return view
end

-- Parse special strings as typical skip arguments for searchpair():
--   s:foo becomes (current syntax item) =~ foo
--   S:foo becomes (current syntax item) !~ foo
--   r:foo becomes (line before cursor) =~ foo
--   R:foo becomes (line before cursor) !~ foo
--   t:foo becomes (current treesitter captures) =~ foo
--   T:foo becomes (current treesitter captures) !~ foo
parse_skip = function(str)
  local skip = str
  if skip:sub(2, 2) == ':' then
    local kind = skip:sub(1, 1)
    local pattern = fn.strpart(skip, 2)
    if kind == 't' or (kind == 's' and vim.o.syntax ~= 'on' and vim.b.ts_highlight ~= nil) then
      skip = "match(v:lua.vim.treesitter.get_captures_at_cursor(), '" .. pattern .. "') != -1"
    elseif kind == 'T'
      or (kind == 'S' and vim.o.syntax ~= 'on' and vim.b.ts_highlight ~= nil)
    then
      skip = "match(v:lua.vim.treesitter.get_captures_at_cursor(), '" .. pattern .. "') == -1"
    elseif kind == 's' then
      skip = "synIDattr(synID(line('.'),col('.'),1),'name') =~? '" .. pattern .. "'"
    elseif kind == 'S' then
      skip = "synIDattr(synID(line('.'),col('.'),1),'name') !~? '" .. pattern .. "'"
    elseif kind == 'r' then
      skip = "strpart(getline('.'),0,col('.'))=~'" .. pattern .. "'"
    elseif kind == 'R' then
      skip = "strpart(getline('.'),0,col('.'))!~'" .. pattern .. "'"
    end
  end
  return skip
end

function M.enable()
  vim.g.loaded_matchit = 1

  vim.cmd([[nnoremap <silent> <Plug>(MatchitNormalForward)     :<C-U>call matchit#Match_wrapper('',1,'n')<CR>]])
  vim.cmd([[nnoremap <silent> <Plug>(MatchitNormalBackward)    :<C-U>call matchit#Match_wrapper('',0,'n')<CR>]])
  vim.cmd([[xnoremap <silent> <Plug>(MatchitVisualForward)     :<C-U>call matchit#Match_wrapper('',1,'v')<CR>:if line("''") != line(".") \|\| col("''") != col("$") \| exe ":normal! m'" \| endif<CR>gv``]])
  vim.cmd([[xnoremap <silent> <Plug>(MatchitVisualBackward)    :<C-U>call matchit#Match_wrapper('',0,'v')<CR>m'gv``]])
  vim.cmd([[onoremap <silent> <Plug>(MatchitOperationForward)  :<C-U>call matchit#Match_wrapper('',1,'o')<CR>]])
  vim.cmd([[onoremap <silent> <Plug>(MatchitOperationBackward) :<C-U>call matchit#Match_wrapper('',0,'o')<CR>]])

  -- Analogues of [{ and ]} using matching patterns:
  vim.cmd([[nnoremap <silent> <Plug>(MatchitNormalMultiBackward)    :<C-U>call matchit#MultiMatch("bW", "n")<CR>]])
  vim.cmd([[nnoremap <silent> <Plug>(MatchitNormalMultiForward)     :<C-U>call matchit#MultiMatch("W",  "n")<CR>]])
  vim.cmd([[xnoremap <silent> <Plug>(MatchitVisualMultiBackward)    :<C-U>call matchit#MultiMatch("bW", "n")<CR>m'gv``]])
  vim.cmd([[xnoremap <silent> <Plug>(MatchitVisualMultiForward)     :<C-U>call matchit#MultiMatch("W",  "n")<CR>m'gv``]])
  vim.cmd([[onoremap <silent> <Plug>(MatchitOperationMultiBackward) :<C-U>call matchit#MultiMatch("bW", "o")<CR>]])
  vim.cmd([[onoremap <silent> <Plug>(MatchitOperationMultiForward)  :<C-U>call matchit#MultiMatch("W",  "o")<CR>]])

  -- text object:
  vim.cmd([[xmap <silent> <Plug>(MatchitVisualTextObject) <Plug>(MatchitVisualMultiBackward)o<Plug>(MatchitVisualMultiForward)]])

  if vim.g.no_plugin_maps == nil then
    vim.cmd([[nmap <silent> %  <Plug>(MatchitNormalForward)]])
    vim.cmd([[nmap <silent> g% <Plug>(MatchitNormalBackward)]])
    vim.cmd([[xmap <silent> %  <Plug>(MatchitVisualForward)]])
    vim.cmd([[xmap <silent> g% <Plug>(MatchitVisualBackward)]])
    vim.cmd([[omap <silent> %  <Plug>(MatchitOperationForward)]])
    vim.cmd([[omap <silent> g% <Plug>(MatchitOperationBackward)]])

    -- Analogues of [{ and ]} using matching patterns:
    vim.cmd([[nmap <silent> [% <Plug>(MatchitNormalMultiBackward)]])
    vim.cmd([[nmap <silent> ]% <Plug>(MatchitNormalMultiForward)]])
    vim.cmd([[xmap <silent> [% <Plug>(MatchitVisualMultiBackward)]])
    vim.cmd([[xmap <silent> ]% <Plug>(MatchitVisualMultiForward)]])
    vim.cmd([[omap <silent> [% <Plug>(MatchitOperationMultiBackward)]])
    vim.cmd([[omap <silent> ]% <Plug>(MatchitOperationMultiForward)]])

    -- Text object
    vim.cmd([[xmap a% <Plug>(MatchitVisualTextObject)]])
  end

  vim.api.nvim_create_user_command('MatchDebug', function()
    M.match_debug()
  end, { force = true })
  vim.api.nvim_create_user_command('MatchDisable', function()
    M.disable()
  end, { force = true })
  vim.api.nvim_create_user_command('MatchEnable', function()
    M.enable()
  end, { force = true })
end

function M.disable()
  -- remove all the setup keymappings
  vim.cmd('nunmap %')
  vim.cmd('nunmap g%')
  vim.cmd('xunmap %')
  vim.cmd('xunmap g%')
  vim.cmd('ounmap %')
  vim.cmd('ounmap g%')

  vim.cmd('nunmap [%')
  vim.cmd('nunmap ]%')
  vim.cmd('xunmap [%')
  vim.cmd('xunmap ]%')
  vim.cmd('ounmap [%')
  vim.cmd('ounmap ]%')

  vim.cmd('xunmap a%')
end

return M
