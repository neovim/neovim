local do_not_run = true
if do_not_run then
  print([[
    This script was used to bootstrap the filetype patterns in runtime/lua/vim/filetype.lua. It
    should no longer be used except for testing purposes. New filetypes, or changes to existing
    filetypes, should be ported manually as part of the vim-patch process.
  ]])
  return
end

local filetype_vim = 'runtime/filetype.vim'
local filetype_lua = 'runtime/lua/vim/filetype.lua'

local keywords = {
  ['for'] = true,
  ['or'] = true,
  ['and'] = true,
  ['end'] = true,
  ['do'] = true,
  ['if'] = true,
  ['while'] = true,
  ['repeat'] = true,
}

local sections = {
  extension = { str = {}, func = {} },
  filename = { str = {}, func = {} },
  pattern = { str = {}, func = {} },
}

local specialchars = '%*%?\\%$%[%]%{%}'

local function add_pattern(pat, ft)
  local ok = true

  -- Patterns that start or end with { or } confuse splitting on commas and make parsing harder, so just skip those
  if not string.find(pat, '^%{') and not string.find(pat, '%}$') then
    for part in string.gmatch(pat, '[^,]+') do
      if not string.find(part, '[' .. specialchars .. ']') then
        if type(ft) == 'string' then
          sections.filename.str[part] = ft
        else
          sections.filename.func[part] = ft
        end
      elseif string.match(part, '^%*%.[^%./' .. specialchars .. ']+$') then
        if type(ft) == 'string' then
          sections.extension.str[part:sub(3)] = ft
        else
          sections.extension.func[part:sub(3)] = ft
        end
      else
        if string.match(part, '^%*/[^' .. specialchars .. ']+$') then
          -- For patterns matching */some/pattern we want to easily match files
          -- with path /some/pattern, so include those in filename detection
          if type(ft) == 'string' then
            sections.filename.str[part:sub(2)] = ft
          else
            sections.filename.func[part:sub(2)] = ft
          end
        end

        if string.find(part, '^[%w-_.*?%[%]/]+$') then
          local p = part:gsub('%.', '%%.'):gsub('%*', '.*'):gsub('%?', '.')
          -- Insert into array to maintain order rather than setting
          -- key-value directly
          if type(ft) == 'string' then
            sections.pattern.str[p] = ft
          else
            sections.pattern.func[p] = ft
          end
        else
          ok = false
        end
      end
    end
  end

  return ok
end

local function parse_line(line)
  local pat, ft
  pat, ft = line:match('^%s*au%a* Buf[%a,]+%s+(%S+)%s+setf%s+(%S+)')
  if pat then
    return add_pattern(pat, ft)
  else
    local func
    pat, func = line:match('^%s*au%a* Buf[%a,]+%s+(%S+)%s+call%s+(%S+)')
    if pat then
      return add_pattern(pat, function()
        return func
      end)
    end
  end
end

local unparsed = {}
local full_line
for line in io.lines(filetype_vim) do
  local cont = string.match(line, '^%s*\\%s*(.*)$')
  if cont then
    full_line = full_line .. ' ' .. cont
  else
    if full_line then
      if not parse_line(full_line) and string.find(full_line, '^%s*au%a* Buf') then
        table.insert(unparsed, full_line)
      end
    end
    full_line = line
  end
end

if #unparsed > 0 then
  print('Failed to parse the following patterns:')
  for _, v in ipairs(unparsed) do
    print(v)
  end
end

local function add_item(indent, key, ft)
  if type(ft) == 'string' then
    if string.find(key, '%A') or keywords[key] then
      key = string.format('["%s"]', key)
    end
    return string.format([[%s%s = "%s",]], indent, key, ft)
  elseif type(ft) == 'function' then
    local func = ft()
    if string.find(key, '%A') or keywords[key] then
      key = string.format('["%s"]', key)
    end
    -- Right now only a single argument is supported, which covers
    -- everything in filetype.vim as of this writing
    local arg = string.match(func, '%((.*)%)$')
    func = string.gsub(func, '%(.*$', '')
    if arg == '' then
      -- Function with no arguments, call the function directly
      return string.format([[%s%s = function() vim.fn["%s"]() end,]], indent, key, func)
    elseif string.match(arg, [[^(["']).*%1$]]) then
      -- String argument
      if func == 's:StarSetf' then
        return string.format([[%s%s = starsetf(%s),]], indent, key, arg)
      else
        return string.format([[%s%s = function() vim.fn["%s"](%s) end,]], indent, key, func, arg)
      end
    elseif string.find(arg, '%(') then
      -- Function argument
      return string.format(
        [[%s%s = function() vim.fn["%s"](vim.fn.%s) end,]],
        indent,
        key,
        func,
        arg
      )
    else
      assert(false, arg)
    end
  end
end

do
  local lines = {}
  local start = false
  for line in io.lines(filetype_lua) do
    if line:match('^%s+-- END [A-Z]+$') then
      start = false
    end

    if not start then
      table.insert(lines, line)
    end

    local indent, section = line:match('^(%s+)-- BEGIN ([A-Z]+)$')
    if section then
      start = true
      local t = sections[string.lower(section)]

      local sorted = {}
      for k, v in pairs(t.str) do
        table.insert(sorted, { [k] = v })
      end

      table.sort(sorted, function(a, b)
        return a[next(a)] < b[next(b)]
      end)

      for _, v in ipairs(sorted) do
        local k = next(v)
        table.insert(lines, add_item(indent, k, v[k]))
      end

      sorted = {}
      for k, v in pairs(t.func) do
        table.insert(sorted, { [k] = v })
      end

      table.sort(sorted, function(a, b)
        return next(a) < next(b)
      end)

      for _, v in ipairs(sorted) do
        local k = next(v)
        table.insert(lines, add_item(indent, k, v[k]))
      end
    end
  end
  local f = io.open(filetype_lua, 'w')
  f:write(table.concat(lines, '\n') .. '\n')
  f:close()
end
