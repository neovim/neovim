local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local lread = require 'elisp.lread'
local b = require 'elisp.bytes'
local print_ = require 'elisp.print'
local signal = require 'elisp.signal'
local alloc = require 'elisp.alloc'
local fns = require 'elisp.fns'
local M = {}
local function at_endline_loc_p(...)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return false
end
local function at_begline_loc_p(...)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return false
end
local search_regs = { start = {}, end_ = {} }
local last_search_thing = vars.Qnil
---@param s vim.elisp.obj
---@return [string,number][]
---@return table
local function eregex_to_vimregex(s)
  local signal_err = function(msg)
    signal.xsignal(vars.Qinvalid_regexp, alloc.make_string(msg))
  end
  if _G.vim_elisp_later then
    error('TODO: signal error on bad pattern')
  end
  local data = {}
  local in_buf = lread.make_readcharfun(s, 0)
  local out_buf = print_.make_printcharfun()
  --vim doesn't have a way to get the position of a sub-match, so this is the current workaround
  local tokens = {}
  local parens_stack = {}
  while true do
    local c = in_buf.read()
    if c == -1 then
      break
    end
    if c == b '\\' then
      c = in_buf.read()
      if c == -1 then
        signal_err('Trailing backslash')
      end
      if c == b '(' then
        if _G.vim_elisp_later then
          error('TODO: signal error on bad capture')
        end
        c = in_buf.read()
        in_buf.unread()
        if c ~= -1 then
          if c == b '?' then
            in_buf.read()
            c = in_buf.read()
            if c == b ':' then
              out_buf.write('\\%(')
              table.insert(parens_stack, true)
              goto continue
            else
              error('TODO')
            end
          end
        end
        table.insert(tokens, out_buf.out())
        out_buf = print_.make_printcharfun()
        local parents = {}
        for _, v in ipairs(parens_stack) do
          if v ~= true then
            parents[v] = true
          end
        end
        table.insert(tokens, { start = true, parents = parents })
        table.insert(parens_stack, tokens[#tokens])
      elseif c == b ')' then
        if #parens_stack == 0 then
          signal_err('Unmatched ) or \\)')
        end
        table.remove(parens_stack)
        out_buf.write('\\)')
      elseif c == b '|' then
        out_buf.write('\\|')
      elseif c == b '{' then
        error('TODO')
      elseif c == b '=' then
        error('TODO')
      elseif c == b 's' then
        error('TODO')
      elseif c == b 'S' then
        error('TODO')
      elseif c == b 'c' then
        error('TODO')
      elseif c == b 'C' then
        error('TODO')
      elseif c == b 'w' then
        error('TODO')
      elseif c == b 'W' then
        error('TODO')
      elseif c == b '<' then
        out_buf.write('\\<')
      elseif c == b '>' then
        error('TODO')
      elseif c == b '_' then
        error('TODO')
      elseif c == b 'b' then
        error('TODO')
      elseif c == b 'B' then
        error('TODO')
      elseif c == b '`' then
        out_buf.write('\\^')
      elseif c == b "'" then
        out_buf.write('\\$')
      elseif string.char(c):match('[1-9]') then
        error('TODO')
      elseif c == b '\\' then
        out_buf.write('\\\\')
      else
        out_buf.write(c)
      end
    elseif c == b '^' then
      if not (in_buf.idx == 0 or at_begline_loc_p(in_buf, in_buf.idx)) then
        goto normal_char
      end
      data.start_match = true
      out_buf.write('\\%(\\^\\|\\n\\@<=\\)')
    elseif c == b ' ' then
      if lisp.nilp(vars.V.search_spaces_regexp) then
        goto normal_char
      end
      out_buf.write('\\%(\\$\\|\\n\\@=\\)')
      error('TODO')
    elseif c == b '$' then
      if not (in_buf.read() == -1 or at_endline_loc_p(in_buf, in_buf.idx)) then
        goto normal_char
      end
      out_buf.write('\\%(\\$\\|\\n\\@=\\)')
    elseif c == b '+' or c == b '*' or c == b '?' then
      if _G.vim_elisp_later then
        error('TODO: if previous expression is not valid the treat it as a literal')
      end
      out_buf.write('\\')
      out_buf.write(c)
    elseif c == b '.' then
      out_buf.write('\\.')
    elseif c == b '[' then
      out_buf.write('\\[')
      local p = print_.make_printcharfun()
      c = in_buf.read()
      if c == -1 then
        signal_err('Unmatched [ or [^')
      end
      if c == b '^' then
        out_buf.write('^')
        c = in_buf.read()
      end
      if c == b ']' then
        out_buf.write(']')
        c = in_buf.read()
      end
      while c ~= b ']' do
        if c == b '\\' then
          p.write('\\')
        end
        p.write(c)
        if c == -1 then
          signal_err('Unmatched [ or [^')
        end
        c = in_buf.read()
      end
      p.write(c)
      local pat = p.out()
      if pat:find('[:word:]', 1, true) then
        error('TODO')
      elseif pat:find('[:ascii:]', 1, true) then
        error('TODO')
      elseif pat:find('[:nonascii:]', 1, true) then
        error('TODO')
      elseif pat:find('[:ff:]', 1, true) then
        error('TODO')
      elseif pat:find('[:return:]', 1, true) then
        pat = pat:gsub('%[:return:%]', ':return:[]')
      elseif pat:find('[:tab:]', 1, true) then
        pat = pat:gsub('%[:tab:%]', ':tab:[]')
      elseif pat:find('[:escape:]', 1, true) then
        pat = pat:gsub('%[:escape:%]', ':escape:[]')
      elseif pat:find('[:backspace:]', 1, true) then
        pat = pat:gsub('%[:backspace:%]', ':backspace:[]')
      elseif pat:find('[:ident:]', 1, true) then
        pat = pat:gsub('%[:ident:%]', ':ident:[]')
      elseif pat:find('[:keyword:]', 1, true) then
        pat = pat:gsub('%[:keyword:%]', ':keyword:[]')
      elseif pat:find('[:fname:]', 1, true) then
        pat = pat:gsub('%[:fname:%]', ':fname:[]')
      end
      out_buf.write(pat)
    else
      goto normal_char
    end
    goto continue
    ::normal_char::
    out_buf.write(c)
    ::continue::
  end
  assert(#parens_stack == 0)
  table.insert(tokens, out_buf.out())
  if #tokens > 1 then
    local patterns = {}
    data.sub_patterns = true
    for k, v in ipairs(tokens) do
      if (k % 2) == 0 then
        local pattern = print_.make_printcharfun()
        pattern.write('\\V\\(')
        local parents = 0
        for tk, t in ipairs(tokens) do
          if type(t) == 'table' then
            if v == t then
              assert(tk == k)
              pattern.write('\\)\\(')
            elseif v.parents[t] then
              pattern.write('\\)\\%(\\(')
              parents = parents + 1
            else
              pattern.write('\\%(')
            end
          else
            pattern.write(t)
          end
        end
        table.insert(patterns, { pattern.out(), parents })
      end
    end
    return patterns, data
  else
    return { { '\\V' .. tokens[1], 0 } }, data
  end
end

---@type vim.elisp.F
local F = {}
local function string_match_1(regexp, s, start, posix, modify_data)
  lisp.check_string(regexp)
  lisp.check_string(s)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local pos_bytes = 0
  if not lisp.nilp(start) then
    local len = lisp.schars(s)
    lisp.check_fixnum(start)
    local pos = lisp.fixnum(start)
    if pos < 0 and -pos <= len then
      pos = len + pos
    elseif pos > 0 and pos > len then
      signal.args_out_of_range(s, start)
    end
    pos_bytes = fns.string_char_to_byte(s, pos)
  end
  local vregex, data = eregex_to_vimregex(regexp)
  if data.start_match and pos_bytes > 0 then
    return vars.Qnil
  end
  local _, pat_start, pat_end = unpack(vim.fn.matchstrpos(lisp.sdata(s), vregex[1][1], pos_bytes))
  if _G.vim_elisp_later then
    error("TODO: somehow also return the positions of the submatches (or nil if they didn't match)")
  end
  if start == -1 or pat_end == -1 then
    return vars.Qnil
  end
  search_regs = {
    start = { pat_start },
    end_ = { pat_end },
  }
  if data.sub_patterns then
    for _, v in ipairs(vregex) do
      local list = vim.fn.matchlist(lisp.sdata(s), v[1], pos_bytes)
      local offset = 0
      for i = 2, v[2] + 2 do
        offset = offset + #list[i]
      end
      local match = list[v[2] + 3]
      local sub_start = offset
      local sub_end = offset + #match
      if match == '' then
        if _G.vim_elisp_later then
          error('TODO: non-matches are trimmed')
          error('TODO: empty matches should not be treated as non-matches')
        end
        table.insert(search_regs.start, -1)
        table.insert(search_regs.end_, -1)
      else
        table.insert(search_regs.start, sub_start)
        table.insert(search_regs.end_, sub_end)
      end
    end
  end
  if lisp.string_multibyte(s) then
    for i = 1, #search_regs.start do
      if search_regs.start[i] >= 0 then
        search_regs.start[i] = vim.str_utfindex(lisp.sdata(s), search_regs.start[i])
        search_regs.end_[i] = vim.str_utfindex(lisp.sdata(s), search_regs.end_[i])
      end
    end
  end
  last_search_thing = vars.Qt
  return lisp.make_fixnum(search_regs.start[1])
end
F.string_match = {
  'string-match',
  2,
  4,
  0,
  [[Return index of start of first match for REGEXP in STRING, or nil.
Matching ignores case if `case-fold-search' is non-nil.
If third arg START is non-nil, start search at that index in STRING.

If INHIBIT-MODIFY is non-nil, match data is not changed.

If INHIBIT-MODIFY is nil or missing, match data is changed, and
`match-end' and `match-beginning' give indices of substrings matched
by parenthesis constructs in the pattern.  You can use the function
`match-string' to extract the substrings matched by the parenthesis
constructions in REGEXP.  For index of first char beyond the match, do
(match-end 0).]],
}
function F.string_match.f(regexp, s, start, inhibit_modify)
  return string_match_1(regexp, s, start, false, lisp.nilp(inhibit_modify))
end
F.match_data = {
  'match-data',
  0,
  3,
  0,
  [[Return a list of positions that record text matched by the last search.
Element 2N of the returned list is the position of the beginning of the
match of the Nth subexpression; it corresponds to `(match-beginning N)';
element 2N + 1 is the position of the end of the match of the Nth
subexpression; it corresponds to `(match-end N)'.  See `match-beginning'
and `match-end'.
If the last search was on a buffer, all the elements are by default
markers or nil (nil when the Nth pair didn't match); they are integers
or nil if the search was on a string.  But if the optional argument
INTEGERS is non-nil, the elements that represent buffer positions are
always integers, not markers, and (if the search was on a buffer) the
buffer itself is appended to the list as one additional element.

Use `set-match-data' to reinstate the match data from the elements of
this list.

Note that non-matching optional groups at the end of the regexp are
elided instead of being represented with two `nil's each.  For instance:

  (progn
    (string-match "^\\(a\\)?\\(b\\)\\(c\\)?$" "b")
    (match-data))
  => (0 1 nil nil 0 1)

If REUSE is a list, store the value in REUSE by destructively modifying it.
If REUSE is long enough to hold all the values, its length remains the
same, and any unused elements are set to nil.  If REUSE is not long
enough, it is extended.  Note that if REUSE is long enough and INTEGERS
is non-nil, no consing is done to make the return value; this minimizes GC.

If optional third argument RESEAT is non-nil, any previous markers on the
REUSE list will be modified to point to nowhere.

Return value is undefined if the last search failed.]],
}
function F.match_data.f(integers, reuse, reseat)
  if not lisp.nilp(reseat) then
    error('TODO')
  end
  if lisp.nilp(last_search_thing) then
    return vars.Qnil
  end
  local data = {}
  for i = 1, #search_regs.start do
    local start = search_regs.start[i]
    if start >= 0 then
      if lisp.bufferp(last_search_thing) then
        error('TODO')
      end
      data[2 * i - 1] = lisp.make_fixnum(start)
      data[2 * i] = lisp.make_fixnum(search_regs.end_[i])
    else
      data[i * 2 - 1] = vars.Qnil
      data[i * 2] = vars.Qnil
    end
  end
  if lisp.bufferp(last_search_thing) then
    error('TODO')
  end
  if not lisp.consp(reuse) then
    reuse = vars.F.list(data)
  else
    error('TODO')
  end
  return reuse
end
F.set_match_data = {
  'set-match-data',
  1,
  2,
  0,
  [[Set internal data on last search match from elements of LIST.
LIST should have been created by calling `match-data' previously.

If optional arg RESEAT is non-nil, make markers on LIST point nowhere.]],
}
function F.set_match_data.f(list, reseat)
  lisp.check_list(list)
  local length = lisp.list_length(list) / 2
  last_search_thing = vars.Qt
  local num_regs = search_regs and #search_regs.start or 0
  local i = 0
  while lisp.consp(list) do
    local marker = lisp.xcar(list)
    if lisp.bufferp(marker) then
      error('TODO')
    end
    if i >= length then
      break
    end
    if lisp.nilp(marker) then
      search_regs.start[i + 1] = -1
      list = lisp.xcdr(list)
    else
      if lisp.markerp(marker) then
        error('TODO')
      end
      local form = marker
      if not lisp.nilp(reseat) and lisp.markerp(marker) then
        error('TODO')
      end
      list = lisp.xcdr(list)
      if not lisp.consp(list) then
        break
      end
      marker = lisp.xcar(list)
      if lisp.markerp(marker) then
        error('TODO')
      end
      search_regs.start[i + 1] = lisp.fixnum(form)
      search_regs.end_[i + 1] = lisp.fixnum(marker)
    end
    list = lisp.xcdr(list)
    i = i + 1
  end
  while i < num_regs do
    search_regs.start[i + 1] = nil
    search_regs.end_[i + 1] = nil
    i = i + 1
  end
  return vars.Qnil
end
local function match_limit(num, beginning)
  lisp.check_fixnum(num)
  local n = lisp.fixnum(num)
  if n < 0 then
    signal.args_out_of_range(num, lisp.make_fixnum(0))
  end
  if #search_regs.start <= 0 then
    signal.error('No match data, because no search succeeded')
  end
  if n >= #search_regs.start or search_regs.start[n + 1] < 0 then
    return vars.Qnil
  end
  return lisp.make_fixnum(beginning and search_regs.start[n + 1] or search_regs.end_[n + 1])
end
F.match_beginning = {
  'match-beginning',
  1,
  1,
  0,
  [[Return position of start of text matched by last search.
SUBEXP, a number, specifies which parenthesized expression in the last
  regexp.
Value is nil if SUBEXPth pair didn't match, or there were less than
  SUBEXP pairs.
Zero means the entire text matched by the whole regexp or whole string.

Return value is undefined if the last search failed.]],
}
function F.match_beginning.f(subexp)
  return match_limit(subexp, true)
end
F.match_end = {
  'match-end',
  1,
  1,
  0,
  [[Return position of end of text matched by last search.
SUBEXP, a number, specifies which parenthesized expression in the last
  regexp.
Value is nil if SUBEXPth pair didn't match, or there were less than
  SUBEXP pairs.
Zero means the entire text matched by the whole regexp or whole string.

Return value is undefined if the last search failed.]],
}
function F.match_end.f(subexp)
  return match_limit(subexp, false)
end
F.match_data__translate =
  { 'match-data--translate', 1, 1, 0, [[Add N to all positions in the match data.  Internal.]] }
function F.match_data__translate.f(n)
  lisp.check_fixnum(n)
  local delta = lisp.fixnum(n)
  if not lisp.nilp(last_search_thing) then
    for i = 1, #search_regs.start do
      if search_regs.start[i] >= 0 then
        search_regs.start[i] = math.max(search_regs.start[i] + delta, 0)
        search_regs.end_[i] = math.max(search_regs.end_[i] + delta, 0)
      end
    end
  end
  return vars.Qnil
end
F.replace_match = {
  'replace-match',
  1,
  5,
  0,
  [[Replace text matched by last search with NEWTEXT.
Leave point at the end of the replacement text.

If optional second arg FIXEDCASE is non-nil, do not alter the case of
the replacement text.  Otherwise, maybe capitalize the whole text, or
maybe just word initials, based on the replaced text.  If the replaced
text has only capital letters and has at least one multiletter word,
convert NEWTEXT to all caps.  Otherwise if all words are capitalized
in the replaced text, capitalize each word in NEWTEXT.  Note that
what exactly is a word is determined by the syntax tables in effect
in the current buffer.

If optional third arg LITERAL is non-nil, insert NEWTEXT literally.
Otherwise treat `\\' as special:
  `\\&' in NEWTEXT means substitute original matched text.
  `\\N' means substitute what matched the Nth `\\(...\\)'.
       If Nth parens didn't match, substitute nothing.
  `\\\\' means insert one `\\'.
  `\\?' is treated literally
       (for compatibility with `query-replace-regexp').
  Any other character following `\\' signals an error.
Case conversion does not apply to these substitutions.

If optional fourth argument STRING is non-nil, it should be a string
to act on; this should be the string on which the previous match was
done via `string-match'.  In this case, `replace-match' creates and
returns a new string, made by copying STRING and replacing the part of
STRING that was matched (the original STRING itself is not altered).

The optional fifth argument SUBEXP specifies a subexpression;
it says to replace just that subexpression with NEWTEXT,
rather than replacing the entire matched text.
This is, in a vague sense, the inverse of using `\\N' in NEWTEXT;
`\\N' copies subexp N into NEWTEXT, but using N as SUBEXP puts
NEWTEXT in place of subexp N.
This is useful only after a regular expression search or match,
since only regular expressions have distinguished subexpressions.]],
}
function F.replace_match.f(newtext, fixedcase, literal, str, subexp)
  lisp.check_string(newtext)
  if not lisp.nilp(str) then
    lisp.check_string(str)
  end
  if lisp.nilp(literal) and (not lisp.sdata(newtext):find('\\')) then
    literal = vars.Qt
  end
  if #search_regs.start <= 0 then
    signal.error("`replace-match' called before any match found")
  end

  local sub = (not lisp.nilp(subexp) and error('TODO') or 0) + 1
  local sub_start = search_regs.start[sub]
  local sub_end = search_regs.end_[sub]
  assert(sub_start <= sub_end)

  if
    not (
      (lisp.nilp(str) and error('TODO'))
      or ((not lisp.nilp(str)) and (0 <= sub_start and sub_end <= lisp.schars(str)))
    )
  then
    if sub_start < 0 then
      signal.xsignal(
        vars.Qerror,
        alloc.make_string('replace-match subexpression does not exist'),
        subexp
      )
    end
    signal.args_out_of_range(lisp.make_fixnum(sub_start), lisp.make_fixnum(sub_end))
  end

  local case_action = 'nochange'
  if lisp.nilp(fixedcase) then
    error('TODO')
  end

  if lisp.nilp(str) then
    error('TODO')
  end
  local before = vars.F.substring(str, lisp.make_fixnum(0), lisp.make_fixnum(sub_start))
  local after = vars.F.substring(str, lisp.make_fixnum(sub_end), vars.Qnil)
  if lisp.nilp(literal) then
    error('TODO')
  end
  if case_action == 'nochange' then
  else
    error('TODO')
  end
  return vars.F.concat { before, newtext, after }
end
F.regexp_quote = {
  'regexp-quote',
  1,
  1,
  0,
  [[Return a regexp string which matches exactly STRING and nothing else.]],
}
function F.regexp_quote.f(str)
  lisp.check_string(str)
  local out = lisp.sdata(str):gsub('[[*.\\?+^$]', '\\%0')
  return #out == lisp.sbytes(str) and str
    or alloc.make_specified_string(out, -1, lisp.string_multibyte(str))
end

function M.init_syms()
  vars.defsubr(F, 'string_match')
  vars.defsubr(F, 'match_data')
  vars.defsubr(F, 'set_match_data')
  vars.defsubr(F, 'match_beginning')
  vars.defsubr(F, 'match_end')
  vars.defsubr(F, 'match_data__translate')
  vars.defsubr(F, 'replace_match')
  vars.defsubr(F, 'regexp_quote')

  vars.defvar_lisp(
    'search_spaces_regexp',
    'search-spaces-regexp',
    [[Regexp to substitute for bunches of spaces in regexp search.
Some commands use this for user-specified regexps.
Spaces that occur inside character classes or repetition operators
or other such regexp constructs are not replaced with this.
A value of nil (which is the normal value) means treat spaces
literally.  Note that a value with capturing groups can change the
numbering of existing capture groups in unexpected ways.]]
  )
  vars.V.search_spaces_regexp = vars.Qnil
end
return M
