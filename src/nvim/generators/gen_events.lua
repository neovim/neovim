local fileio_enum_file = arg[1]
local names_file = arg[2]

local auevents = require('auevents')
local events = auevents.events

local enum_tgt = io.open(fileio_enum_file, 'w')
local names_tgt = io.open(names_file, 'w')

enum_tgt:write([[
// IWYU pragma: private, include "nvim/autocmd_defs.h"

typedef enum auto_event {]])
names_tgt:write([[
static const struct event_name {
  size_t len;
  char *name;
  int event;
} event_names[] = {]])

local aliases = 0
for i, event in ipairs(events) do
  enum_tgt:write(('\n  EVENT_%s = %u,'):format(event[1]:upper(), i + aliases - 1))
  -- Events with positive keys aren't allowed in 'eventignorewin'.
  local event_int = ('%sEVENT_%s'):format(event[3] and '-' or '', event[1]:upper())
  names_tgt:write(('\n  {%u, "%s", %s},'):format(#event[1], event[1], event_int))
  for _, alias in ipairs(event[2]) do
    aliases = aliases + 1
    names_tgt:write(('\n  {%u, "%s", %s},'):format(#alias, alias, event_int))
    enum_tgt:write(('\n  EVENT_%s = %u,'):format(alias:upper(), i + aliases - 1))
  end
  if i == #events then -- Last item.
    enum_tgt:write(('\n  NUM_EVENTS = %u,'):format(i + aliases))
  end
end

names_tgt:write('\n  {0, NULL, (event_T)0},\n};\n')
names_tgt:write('\nstatic AutoCmdVec autocmds[NUM_EVENTS] = { 0 };\n')
names_tgt:close()

enum_tgt:write('\n} event_T;\n')
enum_tgt:close()
