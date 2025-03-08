local fileio_enum_file = arg[1]
local names_file = arg[2]

local auevents = require('nvim.auevents')
local events = auevents.events
local aliases = auevents.aliases

--- @type string[]
local names = vim.tbl_keys(vim.tbl_extend('error', events, aliases))
table.sort(names)

local enum_tgt = assert(io.open(fileio_enum_file, 'w'))
local names_tgt = assert(io.open(names_file, 'w'))

enum_tgt:write([[
// IWYU pragma: private, include "nvim/autocmd_defs.h"

typedef enum auto_event {]])
names_tgt:write([[
static const struct event_name {
  size_t len;
  char *name;
  int event;
} event_names[] = {]])

for i, name in ipairs(names) do
  enum_tgt:write(('\n  EVENT_%s = %u,'):format(name:upper(), i - 1))
  local pref_name = aliases[name] ~= nil and aliases[name] or name
  local win_local = events[pref_name]
  assert(win_local ~= nil)
  -- Events with positive keys aren't allowed in 'eventignorewin'.
  names_tgt:write(
    ('\n  [EVENT_%s] = {%u, "%s", %sEVENT_%s},'):format(
      name:upper(),
      #name,
      name,
      win_local and '-' or '',
      pref_name:upper()
    )
  )
end

enum_tgt:write(('\n  NUM_EVENTS = %u,'):format(#names))
names_tgt:write('\n  [NUM_EVENTS] = {0, NULL, (event_T)0},\n};\n')
names_tgt:write('\nstatic AutoCmdVec autocmds[NUM_EVENTS] = { 0 };\n')
names_tgt:close()

enum_tgt:write('\n} event_T;\n')
enum_tgt:close()
