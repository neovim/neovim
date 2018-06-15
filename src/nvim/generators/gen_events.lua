if arg[1] == '--help' then
  print('Usage: gen_events.lua src/nvim enum_file event_names_file')
  os.exit(0)
end

local nvimsrcdir = arg[1]
local fileio_enum_file = arg[2]
local names_file = arg[3]

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local auevents = require('auevents')
local events = auevents.events
local aliases = auevents.aliases

enum_tgt = io.open(fileio_enum_file, 'w')
names_tgt = io.open(names_file, 'w')

enum_tgt:write('typedef enum auto_event {')
names_tgt:write([[
static const struct event_name {
  size_t len;
  char *name;
  event_T event;
} event_names[] = {]])

for i, event in ipairs(events) do
  enum_tgt:write(('\n  EVENT_%s = %u,'):format(event:upper(), i - 1))
  names_tgt:write(('\n  {%u, "%s", EVENT_%s},'):format(#event, event, event:upper()))
  if i == #events then  -- Last item.
    enum_tgt:write(('\n  NUM_EVENTS = %u,'):format(i))
  end
end

for alias, event in pairs(aliases) do
  names_tgt:write(('\n  {%u, "%s", EVENT_%s},'):format(#alias, alias, event:upper()))
end

names_tgt:write('\n  {0, NULL, (event_T)0},')

enum_tgt:write('\n} event_T;\n')
names_tgt:write('\n};\n')

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

enum_tgt:close()
names_tgt:close()
