local luaassert = require('luassert')

local M = {}

local SUBTBL = {
  '\\000',
  '\\001',
  '\\002',
  '\\003',
  '\\004',
  '\\005',
  '\\006',
  '\\007',
  '\\008',
  '\\t',
  '\\n',
  '\\011',
  '\\012',
  '\\r',
  '\\014',
  '\\015',
  '\\016',
  '\\017',
  '\\018',
  '\\019',
  '\\020',
  '\\021',
  '\\022',
  '\\023',
  '\\024',
  '\\025',
  '\\026',
  '\\027',
  '\\028',
  '\\029',
  '\\030',
  '\\031',
}

--- @param v any
--- @return string
local function format_float(v)
  -- On windows exponent appears to have three digits and not two
  local ret = ('%.6e'):format(v)
  local l, f, es, e = ret:match('^(%-?%d)%.(%d+)e([+%-])0*(%d%d+)$')
  return l .. '.' .. f .. 'e' .. es .. e
end

-- Formats Lua value `v`.
--
-- TODO(justinmk): redundant with vim.inspect() ?
--
-- "Nice table formatting similar to screen:snapshot_util()".
-- Commit: 520c0b91a528
function M.format_luav(v, indent, opts)
  opts = opts or {}
  local linesep = '\n'
  local next_indent_arg = nil
  local indent_shift = opts.indent_shift or '  '
  local next_indent
  local nl = '\n'
  if indent == nil then
    indent = ''
    linesep = ''
    next_indent = ''
    nl = ' '
  else
    next_indent_arg = indent .. indent_shift
    next_indent = indent .. indent_shift
  end
  local ret = ''
  if type(v) == 'string' then
    if opts.literal_strings then
      ret = v
    else
      local quote = opts.dquote_strings and '"' or "'"
      ret = quote
        .. tostring(v)
          :gsub(opts.dquote_strings and '["\\]' or "['\\]", '\\%0')
          :gsub('[%z\1-\31]', function(match)
            return SUBTBL[match:byte() + 1]
          end)
        .. quote
    end
  elseif type(v) == 'table' then
    if v == vim.NIL then
      ret = 'REMOVE_THIS'
    else
      local processed_keys = {}
      ret = '{' .. linesep
      local non_empty = false
      local format_luav = M.format_luav
      for i, subv in ipairs(v) do
        ret = ('%s%s%s,%s'):format(ret, next_indent, format_luav(subv, next_indent_arg, opts), nl)
        processed_keys[i] = true
        non_empty = true
      end
      for k, subv in pairs(v) do
        if not processed_keys[k] then
          if type(k) == 'string' and k:match('^[a-zA-Z_][a-zA-Z0-9_]*$') then
            ret = ret .. next_indent .. k .. ' = '
          else
            ret = ('%s%s[%s] = '):format(ret, next_indent, format_luav(k, nil, opts))
          end
          ret = ret .. format_luav(subv, next_indent_arg, opts) .. ',' .. nl
          non_empty = true
        end
      end
      if nl == ' ' and non_empty then
        ret = ret:sub(1, -3)
      end
      ret = ret .. indent .. '}'
    end
  elseif type(v) == 'number' then
    if v % 1 == 0 then
      ret = ('%d'):format(v)
    else
      ret = format_float(v)
    end
  elseif type(v) == 'nil' then
    ret = 'nil'
  elseif type(v) == 'boolean' then
    ret = (v and 'true' or 'false')
  else
    print(type(v))
    -- Not implemented yet
    luaassert(false)
  end
  return ret
end

-- Like Python repr(), "{!r}".format(s)
--
-- Commit: 520c0b91a528
function M.format_string(fmt, ...)
  local i = 0
  local args = { ... }
  local function getarg()
    i = i + 1
    return args[i]
  end
  local ret = fmt:gsub('%%[0-9*]*%.?[0-9*]*[cdEefgGiouXxqsr%%]', function(match)
    local subfmt = match:gsub('%*', function()
      return tostring(getarg())
    end)
    local arg = nil
    if subfmt:sub(-1) ~= '%' then
      arg = getarg()
    end
    if subfmt:sub(-1) == 'r' or subfmt:sub(-1) == 'q' then
      -- %r is like built-in %q, but it is supposed to single-quote strings and
      -- not double-quote them, and also work not only for strings.
      -- Builtin %q is replaced here as it gives invalid and inconsistent with
      -- luajit results for e.g. "\e" on lua: luajit transforms that into `\27`,
      -- lua leaves as-is.
      arg = M.format_luav(arg, nil, { dquote_strings = (subfmt:sub(-1) == 'q') })
      subfmt = subfmt:sub(1, -2) .. 's'
    end
    if subfmt == '%e' then
      return format_float(arg)
    else
      return subfmt:format(arg)
    end
  end)
  return ret
end

return M
