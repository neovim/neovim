----------------------------------------
-- This file is generated via github.com/tjdevries/vim9jit
-- For any bugs, please first consider reporting there.
----------------------------------------

local NVIM9 = require('_vim9script')
local __VIM9_MODULE = {}
local prepended = nil
local grepCache = nil
local Complete = nil
local GetAddition = nil
local Tag2item = nil
local Dict2info = nil
local ParseTagline = nil
local Tagline2item = nil
local Tagcmd2extra = nil
local Nextitem = nil
local StructMembers = nil
local SearchMembers = nil
-- vim9script

-- # Vim completion script
-- # Language:     C
-- # Maintainer:   Bram Moolenaar <Bram@vim.org>
-- #		Rewritten in Vim9 script by github user lacygoill
-- # Last Change:  2022 Jan 31

prepended = ''
grepCache = vim.empty_dict()

-- # This function is used for the 'omnifunc' option.

Complete = function(findstart, abase)
  findstart = NVIM9.bool(findstart)
  if NVIM9.bool(findstart) then
    -- # Locate the start of the item, including ".", "->" and "[...]".
    local line = NVIM9.fn.getline('.')
    local start = NVIM9.fn.charcol('.') - 1
    local lastword = -1
    while start > 0 do
      if NVIM9.ops.RegexpMatches(NVIM9.index(line, NVIM9.ops.Minus(start, 1)), '\\w') then
        start = start - 1
      elseif
        NVIM9.bool(NVIM9.ops.RegexpMatches(NVIM9.index(line, NVIM9.ops.Minus(start, 1)), '\\.'))
      then
        if lastword == -1 then
          lastword = start
        end
        start = start - 1
      elseif
        NVIM9.bool(
          start > 1
            and NVIM9.index(line, NVIM9.ops.Minus(start, 2)) == '-'
            and NVIM9.index(line, NVIM9.ops.Minus(start, 1)) == '>'
        )
      then
        if lastword == -1 then
          lastword = start
        end
        start = NVIM9.ops.Minus(start, 2)
      elseif NVIM9.bool(NVIM9.index(line, NVIM9.ops.Minus(start, 1)) == ']') then
        -- # Skip over [...].
        local n = 0
        start = start - 1
        while start > 0 do
          start = start - 1
          if NVIM9.index(line, start) == '[' then
            if n == 0 then
              break
            end
            n = n - 1
          elseif NVIM9.bool(NVIM9.index(line, start) == ']') then
            n = n + 1
          end
        end
      else
        break
      end
    end

    -- # Return the column of the last word, which is going to be changed.
    -- # Remember the text that comes before it in prepended.
    if lastword == -1 then
      prepended = ''
      return NVIM9.fn.byteidx(line, start)
    end
    prepended = NVIM9.slice(line, start, NVIM9.ops.Minus(lastword, 1))
    return NVIM9.fn.byteidx(line, lastword)
  end

  -- # Return list of matches.

  local base = prepended .. abase

  -- # Don't do anything for an empty base, would result in all the tags in the
  -- # tags file.
  if base == '' then
    return {}
  end

  -- # init cache for vimgrep to empty
  grepCache = {}

  -- # Split item in words, keep empty word after "." or "->".
  -- # "aa" -> ['aa'], "aa." -> ['aa', ''], "aa.bb" -> ['aa', 'bb'], etc.
  -- # We can't use split, because we need to skip nested [...].
  -- # "aa[...]" -> ['aa', '[...]'], "aa.bb[...]" -> ['aa', 'bb', '[...]'], etc.
  local items = {}
  local s = 0
  local arrays = 0
  while 1 do
    local e = NVIM9.fn.charidx(base, NVIM9.fn.match(base, '\\.\\|->\\|\\[', s))
    if e < 0 then
      if s == 0 or NVIM9.index(base, NVIM9.ops.Minus(s, 1)) ~= ']' then
        NVIM9.fn.add(items, NVIM9.slice(base, s, nil))
      end
      break
    end
    if s == 0 or NVIM9.index(base, NVIM9.ops.Minus(s, 1)) ~= ']' then
      NVIM9.fn.add(items, NVIM9.slice(base, s, NVIM9.ops.Minus(e, 1)))
    end
    if NVIM9.index(base, e) == '.' then
      -- # skip over '.'
      s = NVIM9.ops.Plus(e, 1)
    elseif NVIM9.bool(NVIM9.index(base, e) == '-') then
      -- # skip over '->'
      s = NVIM9.ops.Plus(e, 2)
    else
      -- # Skip over [...].
      local n = 0
      s = e
      e = e + 1
      while e < NVIM9.fn.strcharlen(base) do
        if NVIM9.index(base, e) == ']' then
          if n == 0 then
            break
          end
          n = n - 1
        elseif NVIM9.bool(NVIM9.index(base, e) == '[') then
          n = n + 1
        end
        e = e + 1
      end
      e = e + 1
      NVIM9.fn.add(items, NVIM9.slice(base, s, NVIM9.ops.Minus(e, 1)))
      arrays = arrays + 1
      s = e
    end
  end

  -- # Find the variable items[0].
  -- # 1. in current function (like with "gd")
  -- # 2. in tags file(s) (like with ":tag")
  -- # 3. in current file (like with "gD")
  local res = {}
  if NVIM9.fn.searchdecl(NVIM9.index(items, 0), false, true) == 0 then
    -- # Found, now figure out the type.
    -- # TODO: join previous line if it makes sense
    local line = NVIM9.fn.getline('.')
    local col = NVIM9.fn.charcol('.')
    if NVIM9.fn.stridx(NVIM9.slice(line, nil, NVIM9.ops.Minus(col, 1)), ';') >= 0 then
      -- # Handle multiple declarations on the same line.
      local col2 = NVIM9.ops.Minus(col, 1)
      while NVIM9.index(line, col2) ~= ';' do
        col2 = col2 - 1
      end
      line = NVIM9.slice(line, NVIM9.ops.Plus(col2, 1), nil)
      col = NVIM9.ops.Minus(col, col2)
    end
    if NVIM9.fn.stridx(NVIM9.slice(line, nil, NVIM9.ops.Minus(col, 1)), ',') >= 0 then
      -- # Handle multiple declarations on the same line in a function
      -- # declaration.
      local col2 = NVIM9.ops.Minus(col, 1)
      while NVIM9.index(line, col2) ~= ',' do
        col2 = col2 - 1
      end
      if
        NVIM9.ops.RegexpMatches(
          NVIM9.slice(line, NVIM9.ops.Plus(col2, 1), NVIM9.ops.Minus(col, 1)),
          ' *[^ ][^ ]*  *[^ ]'
        )
      then
        line = NVIM9.slice(line, NVIM9.ops.Plus(col2, 1), nil)
        col = NVIM9.ops.Minus(col, col2)
      end
    end
    if NVIM9.fn.len(items) == 1 then
      -- # Completing one word and it's a local variable: May add '[', '.' or
      -- # '->'.
      local match = NVIM9.index(items, 0)
      local kind = 'v'
      if NVIM9.fn.match(line, '\\<' .. match .. '\\s*\\[') > 0 then
        match = match .. '['
      else
        res = Nextitem(NVIM9.slice(line, nil, NVIM9.ops.Minus(col, 1)), { '' }, 0, true)
        if NVIM9.fn.len(res) > 0 then
          -- # There are members, thus add "." or "->".
          if NVIM9.fn.match(line, '\\*[ \\t(]*' .. match .. '\\>') > 0 then
            match = match .. '->'
          else
            match = match .. '.'
          end
        end
      end
      res = { { ['match'] = match, ['tagline'] = '', ['kind'] = kind, ['info'] = line } }
    elseif NVIM9.bool(NVIM9.fn.len(items) == NVIM9.ops.Plus(arrays, 1)) then
      -- # Completing one word and it's a local array variable: build tagline
      -- # from declaration line
      local match = NVIM9.index(items, 0)
      local kind = 'v'
      local tagline = '\t/^' .. line .. '$/'
      res = { { ['match'] = match, ['tagline'] = tagline, ['kind'] = kind, ['info'] = line } }
    else
      -- # Completing "var.", "var.something", etc.
      res = Nextitem(
        NVIM9.slice(line, nil, NVIM9.ops.Minus(col, 1)),
        NVIM9.slice(items, 1, nil),
        0,
        true
      )
    end
  end

  if NVIM9.fn.len(items) == 1 or NVIM9.fn.len(items) == NVIM9.ops.Plus(arrays, 1) then
    -- # Only one part, no "." or "->": complete from tags file.
    local tags = {}
    if NVIM9.fn.len(items) == 1 then
      tags = NVIM9.fn.taglist('^' .. base)
    else
      tags = NVIM9.fn.taglist('^' .. NVIM9.index(items, 0) .. '$')
    end

    NVIM9.fn_mut('filter', {
      NVIM9.fn_mut('filter', {
        tags,
        function(_, v)
          return NVIM9.ternary(NVIM9.fn.has_key(v, 'kind'), function()
            return v.kind ~= 'm'
          end, true)
        end,
      }, { replace = 0 }),
      function(_, v)
        return NVIM9.ops.Or(
          NVIM9.ops.Or(
            NVIM9.prefix['Bang'](NVIM9.fn.has_key(v, 'static')),
            NVIM9.prefix['Bang'](NVIM9.index(v, 'static'))
          ),
          NVIM9.fn.bufnr('%') == NVIM9.fn.bufnr(NVIM9.index(v, 'filename'))
        )
      end,
    }, { replace = 0 })

    res = NVIM9.fn.extend(
      res,
      NVIM9.fn.map(tags, function(_, v)
        return Tag2item(v)
      end)
    )
  end

  if NVIM9.fn.len(res) == 0 then
    -- # Find the variable in the tags file(s)
    local diclist = NVIM9.fn.filter(
      NVIM9.fn.taglist('^' .. NVIM9.index(items, 0) .. '$'),
      function(_, v)
        return NVIM9.ternary(NVIM9.fn.has_key(v, 'kind'), function()
          return v.kind ~= 'm'
        end, true)
      end
    )

    res = {}

    for _, i in NVIM9.iter(NVIM9.fn.range(NVIM9.fn.len(diclist))) do
      -- # New ctags has the "typeref" field.  Patched version has "typename".
      if NVIM9.bool(NVIM9.fn.has_key(NVIM9.index(diclist, i), 'typename')) then
        res = NVIM9.fn.extend(
          res,
          StructMembers(
            NVIM9.index(NVIM9.index(diclist, i), 'typename'),
            NVIM9.slice(items, 1, nil),
            true
          )
        )
      elseif NVIM9.bool(NVIM9.fn.has_key(NVIM9.index(diclist, i), 'typeref')) then
        res = NVIM9.fn.extend(
          res,
          StructMembers(
            NVIM9.index(NVIM9.index(diclist, i), 'typeref'),
            NVIM9.slice(items, 1, nil),
            true
          )
        )
      end

      -- # For a variable use the command, which must be a search pattern that
      -- # shows the declaration of the variable.
      if NVIM9.index(NVIM9.index(diclist, i), 'kind') == 'v' then
        local line = NVIM9.index(NVIM9.index(diclist, i), 'cmd')
        if NVIM9.slice(line, nil, 1) == '/^' then
          local col =
            NVIM9.fn.charidx(line, NVIM9.fn.match(line, '\\<' .. NVIM9.index(items, 0) .. '\\>'))
          res = NVIM9.fn.extend(
            res,
            Nextitem(
              NVIM9.slice(line, 2, NVIM9.ops.Minus(col, 1)),
              NVIM9.slice(items, 1, nil),
              0,
              true
            )
          )
        end
      end
    end
  end

  if NVIM9.fn.len(res) == 0 and NVIM9.fn.searchdecl(NVIM9.index(items, 0), true) == 0 then
    -- # Found, now figure out the type.
    -- # TODO: join previous line if it makes sense
    local line = NVIM9.fn.getline('.')
    local col = NVIM9.fn.charcol('.')
    res =
      Nextitem(NVIM9.slice(line, nil, NVIM9.ops.Minus(col, 1)), NVIM9.slice(items, 1, nil), 0, true)
  end

  -- # If the last item(s) are [...] they need to be added to the matches.
  local last = NVIM9.fn.len(items) - 1
  local brackets = ''
  while last >= 0 do
    if NVIM9.index(NVIM9.index(items, last), 0) ~= '[' then
      break
    end
    brackets = NVIM9.index(items, last) .. brackets
    last = last - 1
  end

  return NVIM9.fn.map(res, function(_, v)
    return Tagline2item(v, brackets)
  end)
end
__VIM9_MODULE['Complete'] = Complete

GetAddition = function(line, match, memarg, bracket)
  bracket = NVIM9.bool(bracket)
  -- # Guess if the item is an array.
  if NVIM9.bool(NVIM9.ops.And(bracket, NVIM9.fn.match(line, match .. '\\s*\\[') > 0)) then
    return '['
  end

  -- # Check if the item has members.
  if NVIM9.fn.len(SearchMembers(memarg, { '' }, false)) > 0 then
    -- # If there is a '*' before the name use "->".
    if NVIM9.fn.match(line, '\\*[ \\t(]*' .. match .. '\\>') > 0 then
      return '->'
    else
      return '.'
    end
  end
  return ''
end

Tag2item = function(val)
  -- # Turn the tag info "val" into an item for completion.
  -- # "val" is is an item in the list returned by taglist().
  -- # If it is a variable we may add "." or "->".  Don't do it for other types,
  -- # such as a typedef, by not including the info that GetAddition() uses.
  local res = NVIM9.convert.decl_dict({ ['match'] = NVIM9.index(val, 'name') })

  res[NVIM9.index_expr('extra')] =
    Tagcmd2extra(NVIM9.index(val, 'cmd'), NVIM9.index(val, 'name'), NVIM9.index(val, 'filename'))

  local s = Dict2info(val)
  if s ~= '' then
    res[NVIM9.index_expr('info')] = s
  end

  res[NVIM9.index_expr('tagline')] = ''
  if NVIM9.bool(NVIM9.fn.has_key(val, 'kind')) then
    local kind = NVIM9.index(val, 'kind')
    res[NVIM9.index_expr('kind')] = kind
    if kind == 'v' then
      res[NVIM9.index_expr('tagline')] = '\t' .. NVIM9.index(val, 'cmd')
      res[NVIM9.index_expr('dict')] = val
    elseif NVIM9.bool(kind == 'f') then
      res[NVIM9.index_expr('match')] = NVIM9.index(val, 'name') .. '('
    end
  end

  return res
end

Dict2info = function(dict)
  -- # Use all the items in dictionary for the "info" entry.
  local info = ''

  for _, k in NVIM9.iter(NVIM9.fn_mut('sort', { NVIM9.fn.keys(dict) }, { replace = 0 })) do
    info = info .. k .. NVIM9.fn['repeat'](' ', 10 - NVIM9.fn.strlen(k))
    if k == 'cmd' then
      info = info
        .. NVIM9.fn.substitute(
          NVIM9.fn.matchstr(NVIM9.index(dict, 'cmd'), '/^\\s*\\zs.*\\ze$/'),
          '\\\\\\(.\\)',
          '\\1',
          'g'
        )
    else
      local dictk = NVIM9.index(dict, k)
      if NVIM9.fn.typename(dictk) ~= 'string' then
        info = info .. NVIM9.fn.string(dictk)
      else
        info = info .. dictk
      end
    end
    info = info .. '\n'
  end

  return info
end

ParseTagline = function(line)
  -- # Parse a tag line and return a dictionary with items like taglist()
  local l = NVIM9.fn.split(line, '\t')
  local d = vim.empty_dict()
  if NVIM9.fn.len(l) >= 3 then
    d[NVIM9.index_expr('name')] = NVIM9.index(l, 0)
    d[NVIM9.index_expr('filename')] = NVIM9.index(l, 1)
    d[NVIM9.index_expr('cmd')] = NVIM9.index(l, 2)
    local n = 2
    if NVIM9.ops.RegexpMatches(NVIM9.index(l, 2), '^/') then
      -- # Find end of cmd, it may contain Tabs.
      while n < NVIM9.fn.len(l) and NVIM9.ops.NotRegexpMatches(NVIM9.index(l, n), '/;"$') do
        n = n + 1
        d[NVIM9.index_expr('cmd')] = NVIM9.index(d, 'cmd') .. '  ' .. NVIM9.index(l, n)
      end
    end

    for _, i in NVIM9.iter(NVIM9.fn.range(NVIM9.ops.Plus(n, 1), NVIM9.fn.len(l) - 1)) do
      if NVIM9.index(l, i) == 'file:' then
        d[NVIM9.index_expr('static')] = 1
      elseif NVIM9.bool(NVIM9.ops.NotRegexpMatches(NVIM9.index(l, i), ':')) then
        d[NVIM9.index_expr('kind')] = NVIM9.index(l, i)
      else
        d[NVIM9.index_expr(NVIM9.fn.matchstr(NVIM9.index(l, i), '[^:]*'))] =
          NVIM9.fn.matchstr(NVIM9.index(l, i), ':\\zs.*')
      end
    end
  end

  return d
end

Tagline2item = function(val, brackets)
  -- # Turn a match item "val" into an item for completion.
  -- # "val['match']" is the matching item.
  -- # "val['tagline']" is the tagline in which the last part was found.
  local line = NVIM9.index(val, 'tagline')
  local add = GetAddition(line, NVIM9.index(val, 'match'), { val }, brackets == '')
  local res = NVIM9.convert.decl_dict({ ['word'] = NVIM9.index(val, 'match') .. brackets .. add })

  if NVIM9.bool(NVIM9.fn.has_key(val, 'info')) then
    -- # Use info from Tag2item().
    res[NVIM9.index_expr('info')] = NVIM9.index(val, 'info')
  else
    -- # Parse the tag line and add each part to the "info" entry.
    local s = Dict2info(ParseTagline(line))
    if s ~= '' then
      res[NVIM9.index_expr('info')] = s
    end
  end

  if NVIM9.bool(NVIM9.fn.has_key(val, 'kind')) then
    res[NVIM9.index_expr('kind')] = NVIM9.index(val, 'kind')
  elseif NVIM9.bool(add == '(') then
    res[NVIM9.index_expr('kind')] = 'f'
  else
    local s = NVIM9.fn.matchstr(line, '\\t\\(kind:\\)\\=\\zs\\S\\ze\\(\\t\\|$\\)')
    if s ~= '' then
      res[NVIM9.index_expr('kind')] = s
    end
  end

  if NVIM9.bool(NVIM9.fn.has_key(val, 'extra')) then
    res[NVIM9.index_expr('menu')] = NVIM9.index(val, 'extra')
    return res
  end

  -- # Isolate the command after the tag and filename.
  local s = NVIM9.fn.matchstr(
    line,
    '[^\\t]*\\t[^\\t]*\\t\\zs\\(/^.*$/\\|[^\\t]*\\)\\ze\\(;"\\t\\|\\t\\|$\\)'
  )
  if s ~= '' then
    res[NVIM9.index_expr('menu')] = Tagcmd2extra(
      s,
      NVIM9.index(val, 'match'),
      NVIM9.fn.matchstr(line, '[^\\t]*\\t\\zs[^\\t]*\\ze\\t')
    )
  end
  return res
end

Tagcmd2extra = function(cmd, name, fname)
  -- # Turn a command from a tag line to something that is useful in the menu
  local x = ''
  if NVIM9.ops.RegexpMatches(cmd, '^/^') then
    -- # The command is a search command, useful to see what it is.
    x = NVIM9.fn.substitute(
      NVIM9.fn.substitute(
        NVIM9.fn.matchstr(cmd, '^/^\\s*\\zs.*\\ze$/'),
        '\\<' .. name .. '\\>',
        '@@',
        ''
      ),
      '\\\\\\(.\\)',
      '\\1',
      'g'
    ) .. ' - ' .. fname
  elseif NVIM9.bool(NVIM9.ops.RegexpMatches(cmd, '^\\d*$')) then
    -- # The command is a line number, the file name is more useful.
    x = fname .. ' - ' .. cmd
  else
    -- # Not recognized, use command and file name.
    x = cmd .. ' - ' .. fname
  end
  return x
end

Nextitem = function(lead, items, depth, all)
  all = NVIM9.bool(all)
  -- # Find composing type in "lead" and match items[0] with it.
  -- # Repeat this recursively for items[1], if it's there.
  -- # When resolving typedefs "depth" is used to avoid infinite recursion.
  -- # Return the list of matches.

  -- # Use the text up to the variable name and split it in tokens.
  local tokens = NVIM9.fn.split(lead, '\\s\\+\\|\\<')

  -- # Try to recognize the type of the variable.  This is rough guessing...
  local res = {}

  local body = function(_, tidx)
    -- # Skip tokens starting with a non-ID character.
    if NVIM9.ops.NotRegexpMatches(NVIM9.index(tokens, tidx), '^\\h') then
      return NVIM9.ITER_CONTINUE
    end

    -- # Recognize "struct foobar" and "union foobar".
    -- # Also do "class foobar" when it's C++ after all (doesn't work very well
    -- # though).
    if
      (
        NVIM9.index(tokens, tidx) == 'struct'
        or NVIM9.index(tokens, tidx) == 'union'
        or NVIM9.index(tokens, tidx) == 'class'
      ) and NVIM9.ops.Plus(tidx, 1) < NVIM9.fn.len(tokens)
    then
      res = StructMembers(
        NVIM9.index(tokens, tidx) .. ':' .. NVIM9.index(tokens, NVIM9.ops.Plus(tidx, 1)),
        items,
        all
      )
      return NVIM9.ITER_BREAK
    end

    -- # TODO: add more reserved words
    if
      NVIM9.fn.index(
        { 'int', 'short', 'char', 'float', 'double', 'static', 'unsigned', 'extern' },
        NVIM9.index(tokens, tidx)
      ) >= 0
    then
      return NVIM9.ITER_CONTINUE
    end

    -- # Use the tags file to find out if this is a typedef.
    local diclist = NVIM9.fn.taglist('^' .. NVIM9.index(tokens, tidx) .. '$')

    local body = function(_, tagidx)
      local item = NVIM9.convert.decl_dict(NVIM9.index(diclist, tagidx))

      -- # New ctags has the "typeref" field.  Patched version has "typename".
      if NVIM9.bool(NVIM9.fn.has_key(item, 'typeref')) then
        res = NVIM9.fn.extend(res, StructMembers(NVIM9.index(item, 'typeref'), items, all))
        return NVIM9.ITER_CONTINUE
      end
      if NVIM9.bool(NVIM9.fn.has_key(item, 'typename')) then
        res = NVIM9.fn.extend(res, StructMembers(NVIM9.index(item, 'typename'), items, all))
        return NVIM9.ITER_CONTINUE
      end

      -- # Only handle typedefs here.
      if NVIM9.index(item, 'kind') ~= 't' then
        return NVIM9.ITER_CONTINUE
      end

      -- # Skip matches local to another file.
      if
        NVIM9.bool(
          NVIM9.ops.And(
            NVIM9.ops.And(NVIM9.fn.has_key(item, 'static'), NVIM9.index(item, 'static')),
            NVIM9.fn.bufnr('%') ~= NVIM9.fn.bufnr(NVIM9.index(item, 'filename'))
          )
        )
      then
        return NVIM9.ITER_CONTINUE
      end

      -- # For old ctags we recognize "typedef struct aaa" and
      -- # "typedef union bbb" in the tags file command.
      local cmd = NVIM9.index(item, 'cmd')
      local ei = NVIM9.fn.charidx(cmd, NVIM9.fn.matchend(cmd, 'typedef\\s\\+'))
      if ei > 1 then
        local cmdtokens = NVIM9.fn.split(NVIM9.slice(cmd, ei, nil), '\\s\\+\\|\\<')
        if NVIM9.fn.len(cmdtokens) > 1 then
          if
            NVIM9.index(cmdtokens, 0) == 'struct'
            or NVIM9.index(cmdtokens, 0) == 'union'
            or NVIM9.index(cmdtokens, 0) == 'class'
          then
            local name = ''
            -- # Use the first identifier after the "struct" or "union"

            for _, ti in NVIM9.iter(NVIM9.fn.range((NVIM9.fn.len(cmdtokens) - 1))) do
              if NVIM9.ops.RegexpMatches(NVIM9.index(cmdtokens, ti), '^\\w') then
                name = NVIM9.index(cmdtokens, ti)
                break
              end
            end

            if name ~= '' then
              res = NVIM9.fn.extend(
                res,
                StructMembers(NVIM9.index(cmdtokens, 0) .. ':' .. name, items, all)
              )
            end
          elseif NVIM9.bool(depth < 10) then
            -- # Could be "typedef other_T some_T".
            res = NVIM9.fn.extend(
              res,
              Nextitem(NVIM9.index(cmdtokens, 0), items, NVIM9.ops.Plus(depth, 1), all)
            )
          end
        end
      end

      return NVIM9.ITER_DEFAULT
    end

    for _, tagidx in NVIM9.iter(NVIM9.fn.range(NVIM9.fn.len(diclist))) do
      local nvim9_status, nvim9_ret = body(_, tagidx)
      if nvim9_status == NVIM9.ITER_BREAK then
        break
      elseif nvim9_status == NVIM9.ITER_RETURN then
        return nvim9_ret
      end
    end

    if NVIM9.fn.len(res) > 0 then
      return NVIM9.ITER_BREAK
    end

    return NVIM9.ITER_DEFAULT
  end

  for _, tidx in NVIM9.iter(NVIM9.fn.range(NVIM9.fn.len(tokens))) do
    local nvim9_status, nvim9_ret = body(_, tidx)
    if nvim9_status == NVIM9.ITER_BREAK then
      break
    elseif nvim9_status == NVIM9.ITER_RETURN then
      return nvim9_ret
    end
  end

  return res
end

StructMembers = function(atypename, items, all)
  all = NVIM9.bool(all)

  -- # Search for members of structure "typename" in tags files.
  -- # Return a list with resulting matches.
  -- # Each match is a dictionary with "match" and "tagline" entries.
  -- # When "all" is true find all, otherwise just return 1 if there is any member.

  -- # Todo: What about local structures?
  local fnames = NVIM9.fn.join(NVIM9.fn.map(NVIM9.fn.tagfiles(), function(_, v)
    return NVIM9.fn.escape(v, ' \\#%')
  end))
  if fnames == '' then
    return {}
  end

  local typename = atypename
  local qflist = {}
  local cached = 0
  local n = ''
  if NVIM9.bool(NVIM9.prefix['Bang'](all)) then
    n = '1'
    if NVIM9.bool(NVIM9.fn.has_key(grepCache, typename)) then
      qflist = NVIM9.index(grepCache, typename)
      cached = 1
    end
  else
    n = ''
  end
  if NVIM9.bool(NVIM9.prefix['Bang'](cached)) then
    while 1 do
      vim.api.nvim_command(
        'silent! keepjumps noautocmd '
          .. n
          .. 'vimgrep '
          .. '/\\t'
          .. typename
          .. '\\(\\t\\|$\\)/j '
          .. fnames
      )

      qflist = NVIM9.fn.getqflist()
      if NVIM9.fn.len(qflist) > 0 or NVIM9.fn.match(typename, '::') < 0 then
        break
      end
      -- # No match for "struct:context::name", remove "context::" and try again.
      typename = NVIM9.fn.substitute(typename, ':[^:]*::', ':', '')
    end

    if NVIM9.bool(NVIM9.prefix['Bang'](all)) then
      -- # Store the result to be able to use it again later.
      grepCache[NVIM9.index_expr(typename)] = qflist
    end
  end

  -- # Skip over [...] items
  local idx = 0
  local target = ''
  while 1 do
    if idx >= NVIM9.fn.len(items) then
      target = ''
      break
    end
    if NVIM9.index(NVIM9.index(items, idx), 0) ~= '[' then
      target = NVIM9.index(items, idx)
      break
    end
    idx = idx + 1
  end
  -- # Put matching members in matches[].
  local matches = {}

  for _, l in NVIM9.iter(qflist) do
    local memb = NVIM9.fn.matchstr(NVIM9.index(l, 'text'), '[^\\t]*')
    if NVIM9.ops.RegexpMatches(memb, '^' .. target) then
      -- # Skip matches local to another file.
      if
        NVIM9.fn.match(NVIM9.index(l, 'text'), '\tfile:') < 0
        or NVIM9.fn.bufnr('%')
          == NVIM9.fn.bufnr(NVIM9.fn.matchstr(NVIM9.index(l, 'text'), '\\t\\zs[^\\t]*'))
      then
        local item =
          NVIM9.convert.decl_dict({ ['match'] = memb, ['tagline'] = NVIM9.index(l, 'text') })

        -- # Add the kind of item.
        local s =
          NVIM9.fn.matchstr(NVIM9.index(l, 'text'), '\\t\\(kind:\\)\\=\\zs\\S\\ze\\(\\t\\|$\\)')
        if s ~= '' then
          item[NVIM9.index_expr('kind')] = s
          if s == 'f' then
            item[NVIM9.index_expr('match')] = memb .. '('
          end
        end

        NVIM9.fn.add(matches, item)
      end
    end
  end

  if NVIM9.fn.len(matches) > 0 then
    -- # Skip over next [...] items
    idx = idx + 1
    while 1 do
      if idx >= NVIM9.fn.len(items) then
        return matches
      end
      if NVIM9.index(NVIM9.index(items, idx), 0) ~= '[' then
        break
      end
      idx = idx + 1
    end

    -- # More items following.  For each of the possible members find the
    -- # matching following members.
    return SearchMembers(matches, NVIM9.slice(items, idx, nil), all)
  end

  -- # Failed to find anything.
  return {}
end

SearchMembers = function(matches, items, all)
  all = NVIM9.bool(all)

  -- # For matching members, find matches for following items.
  -- # When "all" is true find all, otherwise just return 1 if there is any member.
  local res = {}

  for _, i in NVIM9.iter(NVIM9.fn.range(NVIM9.fn.len(matches))) do
    local typename = ''
    local line = ''
    if NVIM9.bool(NVIM9.fn.has_key(NVIM9.index(matches, i), 'dict')) then
      if NVIM9.bool(NVIM9.fn.has_key(NVIM9.index(NVIM9.index(matches, i), 'dict'), 'typename')) then
        typename = NVIM9.index(NVIM9.index(NVIM9.index(matches, i), 'dict'), 'typename')
      elseif
        NVIM9.bool(NVIM9.fn.has_key(NVIM9.index(NVIM9.index(matches, i), 'dict'), 'typeref'))
      then
        typename = NVIM9.index(NVIM9.index(NVIM9.index(matches, i), 'dict'), 'typeref')
      end
      line = '\t' .. NVIM9.index(NVIM9.index(NVIM9.index(matches, i), 'dict'), 'cmd')
    else
      line = NVIM9.index(NVIM9.index(matches, i), 'tagline')
      local eb = NVIM9.fn.matchend(line, '\\ttypename:')
      local e = NVIM9.fn.charidx(line, eb)
      if e < 0 then
        eb = NVIM9.fn.matchend(line, '\\ttyperef:')
        e = NVIM9.fn.charidx(line, eb)
      end
      if e > 0 then
        -- # Use typename field
        typename = NVIM9.fn.matchstr(line, '[^\\t]*', eb)
      end
    end

    if typename ~= '' then
      res = NVIM9.fn.extend(res, StructMembers(typename, items, all))
    else
      -- # Use the search command (the declaration itself).
      local sb = NVIM9.fn.match(line, '\\t\\zs/^')
      local s = NVIM9.fn.charidx(line, sb)
      if s > 0 then
        local e = NVIM9.fn.charidx(
          line,
          NVIM9.fn.match(line, '\\<' .. NVIM9.index(NVIM9.index(matches, i), 'match') .. '\\>', sb)
        )
        if e > 0 then
          res = NVIM9.fn.extend(
            res,
            Nextitem(NVIM9.slice(line, s, NVIM9.ops.Minus(e, 1)), items, 0, all)
          )
        end
      end
    end
    if NVIM9.bool(NVIM9.ops.And(NVIM9.prefix['Bang'](all), NVIM9.fn.len(res) > 0)) then
      break
    end
  end

  return res
end

-- #}}}1

-- # vim: noet sw=2 sts=2
return __VIM9_MODULE
