local fileio_enum_file = arg[1]
local names_file = arg[2]

local hashy = require('gen.hashy')
local auevents = require('nvim.auevents')
local events = auevents.events
local aliases = auevents.aliases

--- @type string[]
local names = vim.tbl_keys(vim.tbl_extend('error', events, aliases))
table.sort(names, function(a, b)
  return a:lower() < b:lower()
end)

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
} event_names[NUM_EVENTS] = {]])

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
enum_tgt:write('\n} event_T;\n')
enum_tgt:close()

names_tgt:write('\n};\n')
names_tgt:write('\nstatic AutoCmdVec autocmds[NUM_EVENTS] = { 0 };\n')

local hashorder = vim.tbl_map(string.lower, names)
local hashfun
hashorder, hashfun = hashy.hashy_hash('event_name2nr', hashorder, function(idx)
  return 'event_names[event_hash[' .. idx .. ']].name'
end, true)

names_tgt:write([[

static const event_T event_hash[] = {]])

for _, lower_name in ipairs(hashorder) do
  names_tgt:write(('\n  EVENT_%s,'):format(lower_name:upper()))
end

names_tgt:write('\n};\n\n')
names_tgt:write('static ' .. hashfun)
names_tgt:close()
