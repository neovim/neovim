local function dedent(str, leave_indent)
  -- find minimum common indent across lines
  local indent = nil
  for line in str:gmatch('[^\n]+') do
    local line_indent = line:match('^%s+') or ''
    if indent == nil or #line_indent < #indent then
      indent = line_indent
    end
  end
  if indent == nil or #indent == 0 then
    -- no minimum common indent
    return str
  end
  local left_indent = (' '):rep(leave_indent or 0)
  -- create a pattern for the indent
  indent = indent:gsub('%s', '[ \t]')
  -- strip it from the first line
  str = str:gsub('^'..indent, left_indent)
  -- strip it from the remaining lines
  str = str:gsub('[\n]'..indent, '\n' .. left_indent)
  return str
end

local function shallowcopy(orig)
  local copy = {}
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return copy
end

local function concat_tables(...)
  local ret = {}
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    if tbl then
      for _, v in ipairs(tbl) do
        ret[#ret + 1] = v
      end
    end
  end
  return ret
end

local function map(func, tab)
  local rettab = {}
  for k, v in pairs(tab) do
    rettab[k] = func(v)
  end
  return rettab
end

local function filter(filter_func, tab)
  local rettab = {}
  for _, entry in pairs(tab) do
    if filter_func(entry) then
      table.insert(rettab, entry)
    end
  end
  return rettab
end

return {
  dedent = dedent,
  shallowcopy = shallowcopy,
  concat_tables = concat_tables,
  map = map,
  filter = filter,
}
