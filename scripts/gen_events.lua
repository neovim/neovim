if arg[1] == '--help' then
  print('Usage: gen_events.lua src/nvim enum_file event_names_file find_event_file')
  os.exit(0)
end

local nvimsrcdir = arg[1]
local fileio_enum_file = arg[2]
local names_file = arg[3]
local find_event_file = arg[4]

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local auevents = require('auevents')
local events = auevents.events
local aliases = auevents.aliases

enum_tgt = io.open(fileio_enum_file, 'w')
names_tgt = io.open(names_file, 'w')
find_event_tgt = io.open(find_event_file, 'w')

enum_tgt:write('typedef enum auto_event {')
names_tgt:write([[
static const struct event_name {
  size_t len;
  char *name;
  event_T event;
} event_names[] = {]])

for i, event in ipairs(events) do
  if i > 1 then
    comma = ',\n'
  else
    comma = '\n'
  end
  enum_tgt:write(('%s  EVENT_%s = %u'):format(comma, event:upper(), i - 1))
  names_tgt:write(('%s  {%u, "%s", EVENT_%s}'):format(comma, #event, event, event:upper()))
end

for alias, event in pairs(aliases) do
  names_tgt:write((',\n {%u, "%s", EVENT_%s}'):format(#alias, alias, event:upper()))
end

enum_tgt:write(',\n  ANY_EVENT = -1,\n  NO_EVENT = -2')
names_tgt:write(',\n  {0, NULL, (event_T)0}')

enum_tgt:write('\n} event_T;\n')
names_tgt:write('\n};\n')

enum_tgt:write(('\n#define NUM_EVENTS %u\n'):format(#events))
names_tgt:write('\n#ifndef NO_FIRST_AUTOPAT')
names_tgt:write('\nstatic AutoPat *first_autopat[NUM_EVENTS] = {\n ')
line_len = 1
for i = 1,((#events) - 1) do
  line_len = line_len + #(' NULL,')
  if line_len > 80 then
    names_tgt:write('\n ')
    line_len = 1 + #(' NULL,')
  end
  names_tgt:write(' NULL,')
end
if line_len + #(' NULL') > 80 then
  names_tgt:write('\n  NULL')
else
  names_tgt:write(' NULL')
end
names_tgt:write('\n};\n')
names_tgt:write('#endif\n')

enum_tgt:close()
names_tgt:close()

lc_events = {}
for i, event in ipairs(events) do
  lc_events[i] = event:lower()
end
local lc_event_meta
lc_event_meta = {
  __index = function(table, key)
    local existing = rawget(table, key)
    if existing then
      return existing
    elseif type(key) == 'number' then
      local new = {}
      setmetatable(new, lc_event_meta)
      table[key] = new
      return new
    end
  end,
}
lc_event_tree = {}
setmetatable(lc_event_tree, lc_event_meta)

local lc_aliases = {}
for k, v in pairs(aliases) do
  lc_aliases[k:lower()] = v:lower()
  lc_events[#lc_events + 1] = k:lower()
end
setmetatable(lc_aliases, {
  __index = function(table, key)
    return rawget(table, key) or key
  end,
})

table.sort(lc_events)

for i, event in ipairs(lc_events) do
  local subtree = lc_event_tree
  for j = 1,#event do
    local char = event:sub(j, j)
    if ((i == #lc_events or lc_events[i + 1]:sub(j, j) ~= char)
        and (i == 1 or lc_events[i - 1]:sub(j, j) ~= char)) then
      subtree[#subtree + 1] = event:sub(j)
      break
    else
      subtree = subtree[#subtree +
        ((i > 1
          and lc_events[i - 1]:sub(1, j) == event:sub(1, j)) and 0 or 1)]
      subtree.char = char
      if j == #event then
        subtree.is_end = true
      end
    end
  end
end

local w = function(s)
  return find_event_tgt:write(s .. '\n')
end

local dump_tree
dump_tree = function(tree, level, indent, event)
  indent = indent or '  '
  event = event or ''
  if type(tree) == 'string' then
    local condition
    if (#tree == 1) then
      condition = ''
    else
      condition = ('STRNICMP(p + %u, "%s", %u) == 0 && '):format(level, tree:sub(2), #tree - 1)
    end
    condition = condition .. ('(ascii_iswhite(p[%u]) || p[%u] == \',\' || p[%u] == NUL)'):format(
      #event, #event, #event)
    w(('%sif (%s) {'):format(indent, condition))
    w(('%s  *pp += %u;'):format(indent, #event))
    w(('%s  return EVENT_%s;'):format(indent, lc_aliases[event]:upper()))
    w(('%s}'):format(indent))
  elseif type(tree) == 'table' then
    level = level or 0
    w(('%sswitch (p[%u]) {'):format(indent, level))
    for i, subtree in ipairs(tree) do
      local char, cur_event
      if type(subtree) == 'table' then
        char = subtree.char
        cur_event = event .. char
      else
        char = subtree:sub(1, 1)
        cur_event = event .. subtree
      end
      w(('%s  case \'%s\':'):format(indent, char:upper()))
      w(('%s  case \'%s\': {'):format(indent, char))
      dump_tree(subtree, level + 1, indent .. '    ', cur_event)
      w(('%s    break;'):format(indent))
      w(('%s  }'):format(indent))
    end
    if tree.is_end then
      w(('%s  case \'\\t\':'):format(indent))
      w(('%s  case \' \':'):format(indent))
      w(('%s  case \',\':'):format(indent))
      w(('%s  case NUL: {'):format(indent))
      w(('%s    *pp += %u;'):format(indent, #event))
      w(('%s    return EVENT_%s;'):format(indent, lc_aliases[event]:upper()))
      w(('%s  }'):format(indent))
    end
    w(('%s}'):format(indent))
  end
end
w('static AuEvent find_event(const char **pp)')
w('{')
w('  const char *p = *pp;')
dump_tree(lc_event_tree)
w('  return NO_EVENT;')
w('}')
find_event_tgt:close()
