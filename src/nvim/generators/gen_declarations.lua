local fname = arg[1]
local static_fname = arg[2]
local non_static_fname = arg[3]
local preproc_fname = arg[4]

if fname == '--help' then
  print([[
Usage:

    gen_declarations.lua definitions.c static.h non-static.h definitions.i

Generates declarations for a C file definitions.c, putting declarations for
static functions into static.h and declarations for non-static functions into
non-static.h. File `definitions.i' should contain an already preprocessed
version of definitions.c and it is the only one which is actually parsed,
definitions.c is needed only to determine functions from which file out of all
functions found in definitions.i are needed and to generate an IWYU comment.

Additionally uses the following environment variables:

    NVIM_GEN_DECLARATIONS_LINE_NUMBERS:
        If set to 1 then all generated declarations receive a comment with file
        name and line number after the declaration. This may be useful for
        debugging gen_declarations script, but not much beyond that with
        configured development environment (i.e. with with clang/etc).

        WARNING: setting this to 1 will cause extensive rebuilds: declarations
                 generator script will not regenerate non-static.h file if its
                 contents did not change, but including line numbers will make
                 contents actually change.

                 With contents changed timestamp of the file is regenerated even
                 when no real changes were made (e.g. a few lines were added to
                 a function which is not at the bottom of the file).

                 With changed timestamp build system will assume that header
                 changed, triggering rebuilds of all C files which depend on the
                 "changed" header.
]])
  os.exit()
end

local preproc_f = assert(io.open(preproc_fname))
--- @type string
local text = preproc_f:read('*all')
preproc_f:close()

local non_static = [[
#define DEFINE_FUNC_ATTRIBUTES
#include "nvim/func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
#ifndef DLLEXPORT
#  ifdef MSWIN
#    define DLLEXPORT __declspec(dllexport)
#  else
#    define DLLEXPORT
#  endif
#endif
]]

local static = [[
#define DEFINE_FUNC_ATTRIBUTES
#include "nvim/func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
]]

local non_static_footer = [[
#include "nvim/func_attr.h"
]]

local static_footer = [[
#define DEFINE_EMPTY_ATTRIBUTES
#include "nvim/func_attr.h"  // IWYU pragma: export
]]

if fname:find('.*/src/nvim/.*%.c$') then
  -- Add an IWYU pragma comment if the corresponding .h file exists.
  local header_fname = fname:sub(1, -3) .. '.h'
  local header_f = io.open(header_fname, 'r')
  if header_f ~= nil then
    header_f:close()
    non_static = ([[
// IWYU pragma: private, include "%s"
]]):format(header_fname:gsub('.*/src/nvim/', 'nvim/')) .. non_static
  end
elseif non_static_fname:find('/include/api/private/dispatch_wrappers%.h%.generated%.h$') then
  non_static = [[
// IWYU pragma: private, include "nvim/api/private/dispatch.h"
]] .. non_static
elseif non_static_fname:find('/include/ui_events_call%.h%.generated%.h$') then
  non_static = [[
// IWYU pragma: private, include "nvim/ui.h"
]] .. non_static
elseif non_static_fname:find('/include/ui_events_client%.h%.generated%.h$') then
  non_static = [[
// IWYU pragma: private, include "nvim/ui_client.h"
]] .. non_static
elseif non_static_fname:find('/include/ui_events_remote%.h%.generated%.h$') then
  non_static = [[
// IWYU pragma: private, include "nvim/api/ui.h"
]] .. non_static
end

local function api_type(x)
  if x == 'arena' then
    return 'Arena *'
  elseif x == 'lstate' then
    return 'lua_State *'
  elseif x == 'error' then
    return 'Error *'
  end
  return x
end

--- @param fn nvim.c_grammar.Proto
--- @param iwu string?
--- @return string
local function build_decl(fn, iwu)
  local params = {} --- @type string[]
  if not next(fn.parameters) then
    params[1] = 'void'
  else
    for _, p in ipairs(fn.parameters) do
      p[1] = api_type(p[1])
      params[#params + 1] = table.concat(p, ' ')
    end
  end

  local attrs_s = {} --- @type string[]
  for k, attrs in pairs({
    API = fn.attrs,
    ATTR = fn.attrs1,
  }) do
    local pfx = 'FUNC_' .. k .. '_'
    for a, v in pairs(attrs) do
      if v == true then
        attrs_s[#attrs_s + 1] = pfx .. a:upper()
      else
        v = type(v) == 'table' and v or { v }
        attrs_s[#attrs_s + 1] = string.format('%s%s(%s)', pfx, a:upper(), table.concat(v, ', '))
      end
    end
  end

  return (
    string
      .format(
        '%s %s %s(%s)%s;%s\n',
        fn.static and 'static' or 'DLLEXPORT',
        api_type(fn.return_type),
        fn.name,
        table.concat(params, ', '),
        attrs_s and ' ' .. table.concat(attrs_s, ' ') or '',
        iwu or ''
      )
      :gsub(' +', ' ')
  )
end

local neededfile = fname:match('[^/]+$')
local is_needed_file = false
local grammar = require('generators/c_grammar').grammar
local iwu --- @type string?

for _, m in ipairs(grammar:match(text)) do
  if m[1] == 'preproc' then
    --- @cast m nvim.c_grammar.Preproc
    local line = tonumber(m.name)
    if line then
      -- Linemarker. See https://gcc.gnu.org/onlinedocs/cpp/Preprocessor-Output.html
      local dir, file = m.body:match('^"([^"]-)/?([^"/]+)"')
      is_needed_file = (file == neededfile)

      if os.getenv('NVIM_GEN_DECLARATIONS_LINE_NUMBERS') == '1' then
        local declline = line - 1
        --- @type string
        local rdir = dir:gsub('.*/src/nvim/', '')
        iwu = ('  // %s/%s:%u'):format(rdir, file, declline)
      end
    end
  elseif m[1] == 'proto' and is_needed_file then
    --- @cast m nvim.c_grammar.Proto
    local decl = build_decl(m, iwu)
    if m.static then
      static = static .. decl
    else
      non_static = non_static .. decl
    end
  end
end

non_static = non_static .. non_static_footer
static = static .. static_footer

do
  local F = assert(io.open(static_fname, 'w'))
  F:write(static)
  F:close()
end

do
  -- Before generating the non-static headers, check if the current file (if
  -- exists) is different from the new one. If they are the same, we won't touch
  -- the current version to avoid triggering an unnecessary rebuilds of modules
  -- that depend on this one
  local F = io.open(non_static_fname, 'r')
  if F ~= nil then
    if F:read('*a') == non_static then
      os.exit(0)
    end
    io.close(F)
  end
end

do
  local F = assert(io.open(non_static_fname, 'w'))
  F:write(non_static)
  F:close()
end
