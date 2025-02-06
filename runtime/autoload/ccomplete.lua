----------------------------------------
-- This file is generated via github.com/tjdevries/vim9jit
-- For any bugs, please first consider reporting there.
----------------------------------------

-- Ignore "value assigned to a local variable is unused" because
--  we can't guarantee that local variables will be used by plugins
-- luacheck: ignore
--- @diagnostic disable

local vim9 = require('_vim9script')
local M = {}
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
-- # Language:	C
-- # Maintainer:	The Vim Project <https://github.com/vim/vim>
-- # Last Change:	2023 Aug 10
-- #		Rewritten in Vim9 script by github user lacygoill
-- # Former Maintainer:   Bram Moolenaar <Bram@vim.org>

prepended = ''
grepCache = vim.empty_dict()

-- # This function is used for the 'omnifunc' option.

Complete = function(findstart, abase)
  findstart = vim9.bool(findstart)
  if vim9.bool(findstart) then
    -- # Locate the start of the item, including ".", "->" and "[...]".
    local line = vim9.fn.getline('.')
    local start = vim9.fn.charcol('.') - 1
    local lastword = -1
    while start > 0 do
      if vim9.ops.RegexpMatches(vim9.index(line, vim9.ops.Minus(start, 1)), '\\w') then
        start = start - 1
      elseif
        vim9.bool(vim9.ops.RegexpMatches(vim9.index(line, vim9.ops.Minus(start, 1)), '\\.'))
      then
        if lastword == -1 then
          lastword = start
        end
        start = start - 1
      elseif
        vim9.bool(
          start > 1
            and vim9.index(line, vim9.ops.Minus(start, 2)) == '-'
            and vim9.index(line, vim9.ops.Minus(start, 1)) == '>'
        )
      then
        if lastword == -1 then
          lastword = start
        end
        start = vim9.ops.Minus(start, 2)
      elseif vim9.bool(vim9.index(line, vim9.ops.Minus(start, 1)) == ']') then
        -- # Skip over [...].
        local n = 0
        start = start - 1
        while start > 0 do
          start = start - 1
          if vim9.index(line, start) == '[' then
            if n == 0 then
              break
            end
            n = n - 1
          elseif vim9.bool(vim9.index(line, start) == ']') then
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
      return vim9.fn.byteidx(line, start)
    end
    prepended = vim9.slice(line, start, vim9.ops.Minus(lastword, 1))
    return vim9.fn.byteidx(line, lastword)
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
    local e = vim9.fn.charidx(base, vim9.fn.match(base, '\\.\\|->\\|\\[', s))
    if e < 0 then
      if s == 0 or vim9.index(base, vim9.ops.Minus(s, 1)) ~= ']' then
        vim9.fn.add(items, vim9.slice(base, s, nil))
      end
      break
    end
    if s == 0 or vim9.index(base, vim9.ops.Minus(s, 1)) ~= ']' then
      vim9.fn.add(items, vim9.slice(base, s, vim9.ops.Minus(e, 1)))
    end
    if vim9.index(base, e) == '.' then
      -- # skip over '.'
      s = vim9.ops.Plus(e, 1)
    elseif vim9.bool(vim9.index(base, e) == '-') then
      -- # skip over '->'
      s = vim9.ops.Plus(e, 2)
    else
      -- # Skip over [...].
      local n = 0
      s = e
      e = e + 1
      while e < vim9.fn.strcharlen(base) do
        if vim9.index(base, e) == ']' then
          if n == 0 then
            break
          end
          n = n - 1
        elseif vim9.bool(vim9.index(base, e) == '[') then
          n = n + 1
        end
        e = e + 1
      end
      e = e + 1
      vim9.fn.add(items, vim9.slice(base, s, vim9.ops.Minus(e, 1)))
      arrays = arrays + 1
      s = e
    end
  end

  -- # Find the variable items[0].
  -- # 1. in current function (like with "gd")
  -- # 2. in tags file(s) (like with ":tag")
  -- # 3. in current file (like with "gD")
  local res = {}
  if vim9.fn.searchdecl(vim9.index(items, 0), false, true) == 0 then
    -- # Found, now figure out the type.
    -- # TODO: join previous line if it makes sense
    local line = vim9.fn.getline('.')
    local col = vim9.fn.charcol('.')
    if vim9.fn.stridx(vim9.slice(line, nil, vim9.ops.Minus(col, 1)), ';') >= 0 then
      -- # Handle multiple declarations on the same line.
      local col2 = vim9.ops.Minus(col, 1)
      while vim9.index(line, col2) ~= ';' do
        col2 = col2 - 1
      end
      line = vim9.slice(line, vim9.ops.Plus(col2, 1), nil)
      col = vim9.ops.Minus(col, col2)
    end
    if vim9.fn.stridx(vim9.slice(line, nil, vim9.ops.Minus(col, 1)), ',') >= 0 then
      -- # Handle multiple declarations on the same line in a function
      -- # declaration.
      local col2 = vim9.ops.Minus(col, 1)
      while vim9.index(line, col2) ~= ',' do
        col2 = col2 - 1
      end
      if
        vim9.ops.RegexpMatches(
          vim9.slice(line, vim9.ops.Plus(col2, 1), vim9.ops.Minus(col, 1)),
          ' *[^ ][^ ]*  *[^ ]'
        )
      then
        line = vim9.slice(line, vim9.ops.Plus(col2, 1), nil)
        col = vim9.ops.Minus(col, col2)
      end
    end
    if vim9.fn.len(items) == 1 then
      -- # Completing one word and it's a local variable: May add '[', '.' or
      -- # '->'.
      local match = vim9.index(items, 0)
      local kind = 'v'
      if vim9.fn.match(line, '\\<' .. match .. '\\s*\\[') > 0 then
        match = match .. '['
      else
        res = Nextitem(vim9.slice(line, nil, vim9.ops.Minus(col, 1)), { '' }, 0, true)
        if vim9.fn.len(res) > 0 then
          -- # There are members, thus add "." or "->".
          if vim9.fn.match(line, '\\*[ \\t(]*' .. match .. '\\>') > 0 then
            match = match .. '->'
          else
            match = match .. '.'
          end
        end
      end
      res = { { ['match'] = match, ['tagline'] = '', ['kind'] = kind, ['info'] = line } }
    elseif vim9.bool(vim9.fn.len(items) == vim9.ops.Plus(arrays, 1)) then
      -- # Completing one word and it's a local array variable: build tagline
      -- # from declaration line
      local match = vim9.index(items, 0)
      local kind = 'v'
      local tagline = '\t/^' .. line .. '$/'
      res = { { ['match'] = match, ['tagline'] = tagline, ['kind'] = kind, ['info'] = line } }
    else
      -- # Completing "var.", "var.something", etc.
      res =
        Nextitem(vim9.slice(line, nil, vim9.ops.Minus(col, 1)), vim9.slice(items, 1, nil), 0, true)
    end
  end

  if vim9.fn.len(items) == 1 or vim9.fn.len(items) == vim9.ops.Plus(arrays, 1) then
    -- # Only one part, no "." or "->": complete from tags file.
    local tags = {}
    if vim9.fn.len(items) == 1 then
      tags = vim9.fn.taglist('^' .. base)
    else
      tags = vim9.fn.taglist('^' .. vim9.index(items, 0) .. '$')
    end

    vim9.fn_mut('filter', {
      vim9.fn_mut('filter', {
        tags,
        function(_, v)
          return vim9.ternary(vim9.fn.has_key(v, 'kind'), function()
            return v.kind ~= 'm'
          end, true)
        end,
      }, { replace = 0 }),
      function(_, v)
        return vim9.ops.Or(
          vim9.ops.Or(
            vim9.prefix['Bang'](vim9.fn.has_key(v, 'static')),
            vim9.prefix['Bang'](vim9.index(v, 'static'))
          ),
          vim9.fn.bufnr('%') == vim9.fn.bufnr(vim9.index(v, 'filename'))
        )
      end,
    }, { replace = 0 })

    res = vim9.fn.extend(
      res,
      vim9.fn.map(tags, function(_, v)
        return Tag2item(v)
      end)
    )
  end

  if vim9.fn.len(res) == 0 then
    -- # Find the variable in the tags file(s)
    local diclist = vim9.fn.filter(
      vim9.fn.taglist('^' .. vim9.index(items, 0) .. '$'),
      function(_, v)
        return vim9.ternary(vim9.fn.has_key(v, 'kind'), function()
          return v.kind ~= 'm'
        end, true)
      end
    )

    res = {}

    for _, i in vim9.iter(vim9.fn.range(vim9.fn.len(diclist))) do
      -- # New ctags has the "typeref" field.  Patched version has "typename".
      if vim9.bool(vim9.fn.has_key(vim9.index(diclist, i), 'typename')) then
        res = vim9.fn.extend(
          res,
          StructMembers(
            vim9.index(vim9.index(diclist, i), 'typename'),
            vim9.slice(items, 1, nil),
            true
          )
        )
      elseif vim9.bool(vim9.fn.has_key(vim9.index(diclist, i), 'typeref')) then
        res = vim9.fn.extend(
          res,
          StructMembers(
            vim9.index(vim9.index(diclist, i), 'typeref'),
            vim9.slice(items, 1, nil),
            true
          )
        )
      end

      -- # For a variable use the command, which must be a search pattern that
      -- # shows the declaration of the variable.
      if vim9.index(vim9.index(diclist, i), 'kind') == 'v' then
        local line = vim9.index(vim9.index(diclist, i), 'cmd')
        if vim9.slice(line, nil, 1) == '/^' then
          local col =
            vim9.fn.charidx(line, vim9.fn.match(line, '\\<' .. vim9.index(items, 0) .. '\\>'))
          res = vim9.fn.extend(
            res,
            Nextitem(
              vim9.slice(line, 2, vim9.ops.Minus(col, 1)),
              vim9.slice(items, 1, nil),
              0,
              true
            )
          )
        end
      end
    end
  end

  if vim9.fn.len(res) == 0 and vim9.fn.searchdecl(vim9.index(items, 0), true) == 0 then
    -- # Found, now figure out the type.
    -- # TODO: join previous line if it makes sense
    local line = vim9.fn.getline('.')
    local col = vim9.fn.charcol('.')
    res =
      Nextitem(vim9.slice(line, nil, vim9.ops.Minus(col, 1)), vim9.slice(items, 1, nil), 0, true)
  end

  -- # If the last item(s) are [...] they need to be added to the matches.
  local last = vim9.fn.len(items) - 1
  local brackets = ''
  while last >= 0 do
    if vim9.index(vim9.index(items, last), 0) ~= '[' then
      break
    end
    brackets = vim9.index(items, last) .. brackets
    last = last - 1
  end

  return vim9.fn.map(res, function(_, v)
    return Tagline2item(v, brackets)
  end)
end
M['Complete'] = Complete

GetAddition = function(line, match, memarg, bracket)
  bracket = vim9.bool(bracket)
  -- # Guess if the item is an array.
  if vim9.bool(vim9.ops.And(bracket, vim9.fn.match(line, match .. '\\s*\\[') > 0)) then
    return '['
  end

  -- # Check if the item has members.
  if vim9.fn.len(SearchMembers(memarg, { '' }, false)) > 0 then
    -- # If there is a '*' before the name use "->".
    if vim9.fn.match(line, '\\*[ \\t(]*' .. match .. '\\>') > 0 then
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
  local res = vim9.convert.decl_dict({ ['match'] = vim9.index(val, 'name') })

  res[vim9.index_expr('extra')] =
    Tagcmd2extra(vim9.index(val, 'cmd'), vim9.index(val, 'name'), vim9.index(val, 'filename'))

  local s = Dict2info(val)
  if s ~= '' then
    res[vim9.index_expr('info')] = s
  end

  res[vim9.index_expr('tagline')] = ''
  if vim9.bool(vim9.fn.has_key(val, 'kind')) then
    local kind = vim9.index(val, 'kind')
    res[vim9.index_expr('kind')] = kind
    if kind == 'v' then
      res[vim9.index_expr('tagline')] = '\t' .. vim9.index(val, 'cmd')
      res[vim9.index_expr('dict')] = val
    elseif vim9.bool(kind == 'f') then
      res[vim9.index_expr('match')] = vim9.index(val, 'name') .. '('
    end
  end

  return res
end

Dict2info = function(dict)
  -- # Use all the items in dictionary for the "info" entry.
  local info = ''

  for _, k in vim9.iter(vim9.fn_mut('sort', { vim9.fn.keys(dict) }, { replace = 0 })) do
    info = info .. k .. vim9.fn['repeat'](' ', 10 - vim9.fn.strlen(k))
    if k == 'cmd' then
      info = info
        .. vim9.fn.substitute(
          vim9.fn.matchstr(vim9.index(dict, 'cmd'), '/^\\s*\\zs.*\\ze$/'),
          '\\\\\\(.\\)',
          '\\1',
          'g'
        )
    else
      local dictk = vim9.index(dict, k)
      if vim9.fn.typename(dictk) ~= 'string' then
        info = info .. vim9.fn.string(dictk)
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
  local l = vim9.fn.split(line, '\t')
  local d = vim.empty_dict()
  if vim9.fn.len(l) >= 3 then
    d[vim9.index_expr('name')] = vim9.index(l, 0)
    d[vim9.index_expr('filename')] = vim9.index(l, 1)
    d[vim9.index_expr('cmd')] = vim9.index(l, 2)
    local n = 2
    if vim9.ops.RegexpMatches(vim9.index(l, 2), '^/') then
      -- # Find end of cmd, it may contain Tabs.
      while n < vim9.fn.len(l) and vim9.ops.NotRegexpMatches(vim9.index(l, n), '/;"$') do
        n = n + 1
        d[vim9.index_expr('cmd')] = vim9.index(d, 'cmd') .. '  ' .. vim9.index(l, n)
      end
    end

    for _, i in vim9.iter(vim9.fn.range(vim9.ops.Plus(n, 1), vim9.fn.len(l) - 1)) do
      if vim9.index(l, i) == 'file:' then
        d[vim9.index_expr('static')] = 1
      elseif vim9.bool(vim9.ops.NotRegexpMatches(vim9.index(l, i), ':')) then
        d[vim9.index_expr('kind')] = vim9.index(l, i)
      else
        d[vim9.index_expr(vim9.fn.matchstr(vim9.index(l, i), '[^:]*'))] =
          vim9.fn.matchstr(vim9.index(l, i), ':\\zs.*')
      end
    end
  end

  return d
end

Tagline2item = function(val, brackets)
  -- # Turn a match item "val" into an item for completion.
  -- # "val['match']" is the matching item.
  -- # "val['tagline']" is the tagline in which the last part was found.
  local line = vim9.index(val, 'tagline')
  local add = GetAddition(line, vim9.index(val, 'match'), { val }, brackets == '')
  local res = vim9.convert.decl_dict({ ['word'] = vim9.index(val, 'match') .. brackets .. add })

  if vim9.bool(vim9.fn.has_key(val, 'info')) then
    -- # Use info from Tag2item().
    res[vim9.index_expr('info')] = vim9.index(val, 'info')
  else
    -- # Parse the tag line and add each part to the "info" entry.
    local s = Dict2info(ParseTagline(line))
    if s ~= '' then
      res[vim9.index_expr('info')] = s
    end
  end

  if vim9.bool(vim9.fn.has_key(val, 'kind')) then
    res[vim9.index_expr('kind')] = vim9.index(val, 'kind')
  elseif vim9.bool(add == '(') then
    res[vim9.index_expr('kind')] = 'f'
  else
    local s = vim9.fn.matchstr(line, '\\t\\(kind:\\)\\=\\zs\\S\\ze\\(\\t\\|$\\)')
    if s ~= '' then
      res[vim9.index_expr('kind')] = s
    end
  end

  if vim9.bool(vim9.fn.has_key(val, 'extra')) then
    res[vim9.index_expr('menu')] = vim9.index(val, 'extra')
    return res
  end

  -- # Isolate the command after the tag and filename.
  local s = vim9.fn.matchstr(
    line,
    '[^\\t]*\\t[^\\t]*\\t\\zs\\(/^.*$/\\|[^\\t]*\\)\\ze\\(;"\\t\\|\\t\\|$\\)'
  )
  if s ~= '' then
    res[vim9.index_expr('menu')] = Tagcmd2extra(
      s,
      vim9.index(val, 'match'),
      vim9.fn.matchstr(line, '[^\\t]*\\t\\zs[^\\t]*\\ze\\t')
    )
  end
  return res
end

Tagcmd2extra = function(cmd, name, fname)
  -- # Turn a command from a tag line to something that is useful in the menu
  local x = ''
  if vim9.ops.RegexpMatches(cmd, '^/^') then
    -- # The command is a search command, useful to see what it is.
    x = vim9.fn.substitute(
      vim9.fn.substitute(
        vim9.fn.matchstr(cmd, '^/^\\s*\\zs.*\\ze$/'),
        '\\<' .. name .. '\\>',
        '@@',
        ''
      ),
      '\\\\\\(.\\)',
      '\\1',
      'g'
    ) .. ' - ' .. fname
  elseif vim9.bool(vim9.ops.RegexpMatches(cmd, '^\\d*$')) then
    -- # The command is a line number, the file name is more useful.
    x = fname .. ' - ' .. cmd
  else
    -- # Not recognized, use command and file name.
    x = cmd .. ' - ' .. fname
  end
  return x
end

Nextitem = function(lead, items, depth, all)
  all = vim9.bool(all)
  -- # Find composing type in "lead" and match items[0] with it.
  -- # Repeat this recursively for items[1], if it's there.
  -- # When resolving typedefs "depth" is used to avoid infinite recursion.
  -- # Return the list of matches.

  -- # Use the text up to the variable name and split it in tokens.
  local tokens = vim9.fn.split(lead, '\\s\\+\\|\\<')

  -- # Try to recognize the type of the variable.  This is rough guessing...
  local res = {}

  local body = function(_, tidx)
    -- # Skip tokens starting with a non-ID character.
    if vim9.ops.NotRegexpMatches(vim9.index(tokens, tidx), '^\\h') then
      return vim9.ITER_CONTINUE
    end

    -- # Recognize "struct foobar" and "union foobar".
    -- # Also do "class foobar" when it's C++ after all (doesn't work very well
    -- # though).
    if
      (
        vim9.index(tokens, tidx) == 'struct'
        or vim9.index(tokens, tidx) == 'union'
        or vim9.index(tokens, tidx) == 'class'
      ) and vim9.ops.Plus(tidx, 1) < vim9.fn.len(tokens)
    then
      res = StructMembers(
        vim9.index(tokens, tidx) .. ':' .. vim9.index(tokens, vim9.ops.Plus(tidx, 1)),
        items,
        all
      )
      return vim9.ITER_BREAK
    end

    -- # TODO: add more reserved words
    if
      vim9.fn.index(
        { 'int', 'short', 'char', 'float', 'double', 'static', 'unsigned', 'extern' },
        vim9.index(tokens, tidx)
      ) >= 0
    then
      return vim9.ITER_CONTINUE
    end

    -- # Use the tags file to find out if this is a typedef.
    local diclist = vim9.fn.taglist('^' .. vim9.index(tokens, tidx) .. '$')

    local body = function(_, tagidx)
      local item = vim9.convert.decl_dict(vim9.index(diclist, tagidx))

      -- # New ctags has the "typeref" field.  Patched version has "typename".
      if vim9.bool(vim9.fn.has_key(item, 'typeref')) then
        res = vim9.fn.extend(res, StructMembers(vim9.index(item, 'typeref'), items, all))
        return vim9.ITER_CONTINUE
      end
      if vim9.bool(vim9.fn.has_key(item, 'typename')) then
        res = vim9.fn.extend(res, StructMembers(vim9.index(item, 'typename'), items, all))
        return vim9.ITER_CONTINUE
      end

      -- # Only handle typedefs here.
      if vim9.index(item, 'kind') ~= 't' then
        return vim9.ITER_CONTINUE
      end

      -- # Skip matches local to another file.
      if
        vim9.bool(
          vim9.ops.And(
            vim9.ops.And(vim9.fn.has_key(item, 'static'), vim9.index(item, 'static')),
            vim9.fn.bufnr('%') ~= vim9.fn.bufnr(vim9.index(item, 'filename'))
          )
        )
      then
        return vim9.ITER_CONTINUE
      end

      -- # For old ctags we recognize "typedef struct aaa" and
      -- # "typedef union bbb" in the tags file command.
      local cmd = vim9.index(item, 'cmd')
      local ei = vim9.fn.charidx(cmd, vim9.fn.matchend(cmd, 'typedef\\s\\+'))
      if ei > 1 then
        local cmdtokens = vim9.fn.split(vim9.slice(cmd, ei, nil), '\\s\\+\\|\\<')
        if vim9.fn.len(cmdtokens) > 1 then
          if
            vim9.index(cmdtokens, 0) == 'struct'
            or vim9.index(cmdtokens, 0) == 'union'
            or vim9.index(cmdtokens, 0) == 'class'
          then
            local name = ''
            -- # Use the first identifier after the "struct" or "union"

            for _, ti in vim9.iter(vim9.fn.range((vim9.fn.len(cmdtokens) - 1))) do
              if vim9.ops.RegexpMatches(vim9.index(cmdtokens, ti), '^\\w') then
                name = vim9.index(cmdtokens, ti)
                break
              end
            end

            if name ~= '' then
              res = vim9.fn.extend(
                res,
                StructMembers(vim9.index(cmdtokens, 0) .. ':' .. name, items, all)
              )
            end
          elseif vim9.bool(depth < 10) then
            -- # Could be "typedef other_T some_T".
            res = vim9.fn.extend(
              res,
              Nextitem(vim9.index(cmdtokens, 0), items, vim9.ops.Plus(depth, 1), all)
            )
          end
        end
      end

      return vim9.ITER_DEFAULT
    end

    for _, tagidx in vim9.iter(vim9.fn.range(vim9.fn.len(diclist))) do
      local nvim9_status, nvim9_ret = body(_, tagidx)
      if nvim9_status == vim9.ITER_BREAK then
        break
      elseif nvim9_status == vim9.ITER_RETURN then
        return nvim9_ret
      end
    end

    if vim9.fn.len(res) > 0 then
      return vim9.ITER_BREAK
    end

    return vim9.ITER_DEFAULT
  end

  for _, tidx in vim9.iter(vim9.fn.range(vim9.fn.len(tokens))) do
    local nvim9_status, nvim9_ret = body(_, tidx)
    if nvim9_status == vim9.ITER_BREAK then
      break
    elseif nvim9_status == vim9.ITER_RETURN then
      return nvim9_ret
    end
  end

  return res
end

StructMembers = function(atypename, items, all)
  all = vim9.bool(all)

  -- # Search for members of structure "typename" in tags files.
  -- # Return a list with resulting matches.
  -- # Each match is a dictionary with "match" and "tagline" entries.
  -- # When "all" is true find all, otherwise just return 1 if there is any member.

  -- # Todo: What about local structures?
  local fnames = vim9.fn.join(vim9.fn.map(vim9.fn.tagfiles(), function(_, v)
    return vim9.fn.escape(v, ' \\#%')
  end))
  if fnames == '' then
    return {}
  end

  local typename = atypename
  local qflist = {}
  local cached = 0
  local n = ''
  if vim9.bool(vim9.prefix['Bang'](all)) then
    n = '1'
    if vim9.bool(vim9.fn.has_key(grepCache, typename)) then
      qflist = vim9.index(grepCache, typename)
      cached = 1
    end
  else
    n = ''
  end
  if vim9.bool(vim9.prefix['Bang'](cached)) then
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

      qflist = vim9.fn.getqflist()
      if vim9.fn.len(qflist) > 0 or vim9.fn.match(typename, '::') < 0 then
        break
      end
      -- # No match for "struct:context::name", remove "context::" and try again.
      typename = vim9.fn.substitute(typename, ':[^:]*::', ':', '')
    end

    if vim9.bool(vim9.prefix['Bang'](all)) then
      -- # Store the result to be able to use it again later.
      grepCache[vim9.index_expr(typename)] = qflist
    end
  end

  -- # Skip over [...] items
  local idx = 0
  local target = ''
  while 1 do
    if idx >= vim9.fn.len(items) then
      target = ''
      break
    end
    if vim9.index(vim9.index(items, idx), 0) ~= '[' then
      target = vim9.index(items, idx)
      break
    end
    idx = idx + 1
  end
  -- # Put matching members in matches[].
  local matches = {}

  for _, l in vim9.iter(qflist) do
    local memb = vim9.fn.matchstr(vim9.index(l, 'text'), '[^\\t]*')
    if vim9.ops.RegexpMatches(memb, '^' .. target) then
      -- # Skip matches local to another file.
      if
        vim9.fn.match(vim9.index(l, 'text'), '\tfile:') < 0
        or vim9.fn.bufnr('%')
          == vim9.fn.bufnr(vim9.fn.matchstr(vim9.index(l, 'text'), '\\t\\zs[^\\t]*'))
      then
        local item =
          vim9.convert.decl_dict({ ['match'] = memb, ['tagline'] = vim9.index(l, 'text') })

        -- # Add the kind of item.
        local s =
          vim9.fn.matchstr(vim9.index(l, 'text'), '\\t\\(kind:\\)\\=\\zs\\S\\ze\\(\\t\\|$\\)')
        if s ~= '' then
          item[vim9.index_expr('kind')] = s
          if s == 'f' then
            item[vim9.index_expr('match')] = memb .. '('
          end
        end

        vim9.fn.add(matches, item)
      end
    end
  end

  if vim9.fn.len(matches) > 0 then
    -- # Skip over next [...] items
    idx = idx + 1
    while 1 do
      if idx >= vim9.fn.len(items) then
        return matches
      end
      if vim9.index(vim9.index(items, idx), 0) ~= '[' then
        break
      end
      idx = idx + 1
    end

    -- # More items following.  For each of the possible members find the
    -- # matching following members.
    return SearchMembers(matches, vim9.slice(items, idx, nil), all)
  end

  -- # Failed to find anything.
  return {}
end

SearchMembers = function(matches, items, all)
  all = vim9.bool(all)

  -- # For matching members, find matches for following items.
  -- # When "all" is true find all, otherwise just return 1 if there is any member.
  local res = {}

  for _, i in vim9.iter(vim9.fn.range(vim9.fn.len(matches))) do
    local typename = ''
    local line = ''
    if vim9.bool(vim9.fn.has_key(vim9.index(matches, i), 'dict')) then
      if vim9.bool(vim9.fn.has_key(vim9.index(vim9.index(matches, i), 'dict'), 'typename')) then
        typename = vim9.index(vim9.index(vim9.index(matches, i), 'dict'), 'typename')
      elseif vim9.bool(vim9.fn.has_key(vim9.index(vim9.index(matches, i), 'dict'), 'typeref')) then
        typename = vim9.index(vim9.index(vim9.index(matches, i), 'dict'), 'typeref')
      end
      line = '\t' .. vim9.index(vim9.index(vim9.index(matches, i), 'dict'), 'cmd')
    else
      line = vim9.index(vim9.index(matches, i), 'tagline')
      local eb = vim9.fn.matchend(line, '\\ttypename:')
      local e = vim9.fn.charidx(line, eb)
      if e < 0 then
        eb = vim9.fn.matchend(line, '\\ttyperef:')
        e = vim9.fn.charidx(line, eb)
      end
      if e > 0 then
        -- # Use typename field
        typename = vim9.fn.matchstr(line, '[^\\t]*', eb)
      end
    end

    if typename ~= '' then
      res = vim9.fn.extend(res, StructMembers(typename, items, all))
    else
      -- # Use the search command (the declaration itself).
      local sb = vim9.fn.match(line, '\\t\\zs/^')
      local s = vim9.fn.charidx(line, sb)
      if s > 0 then
        local e = vim9.fn.charidx(
          line,
          vim9.fn.match(line, '\\<' .. vim9.index(vim9.index(matches, i), 'match') .. '\\>', sb)
        )
        if e > 0 then
          res =
            vim9.fn.extend(res, Nextitem(vim9.slice(line, s, vim9.ops.Minus(e, 1)), items, 0, all))
        end
      end
    end
    if vim9.bool(vim9.ops.And(vim9.prefix['Bang'](all), vim9.fn.len(res) > 0)) then
      break
    end
  end

  return res
end

-- #}}}1

-- # vim: noet sw=2 sts=2
return M
