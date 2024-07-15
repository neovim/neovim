local fname = arg[1]
local static_fname = arg[2]
local non_static_fname = arg[3]
local preproc_fname = arg[4]
local static_basename = arg[5]

local lpeg = vim.lpeg

local fold = function(func, ...)
  local result = nil
  for _, v in ipairs({ ... }) do
    if result == nil then
      result = v
    else
      result = func(result, v)
    end
  end
  return result
end

local folder = function(func)
  return function(...)
    return fold(func, ...)
  end
end

local lit = lpeg.P
local set = function(...)
  return lpeg.S(fold(function(a, b)
    return a .. b
  end, ...))
end
local any_character = lpeg.P(1)
local rng = function(s, e)
  return lpeg.R(s .. e)
end
local concat = folder(function(a, b)
  return a * b
end)
local branch = folder(function(a, b)
  return a + b
end)
local one_or_more = function(v)
  return v ^ 1
end
local two_or_more = function(v)
  return v ^ 2
end
local any_amount = function(v)
  return v ^ 0
end
local one_or_no = function(v)
  return v ^ -1
end
local look_behind = lpeg.B
local look_ahead = function(v)
  return #v
end
local neg_look_ahead = function(v)
  return -v
end
local neg_look_behind = function(v)
  return -look_behind(v)
end

local w = branch(rng('a', 'z'), rng('A', 'Z'), lit('_'))
local aw = branch(w, rng('0', '9'))
local s = set(' ', '\n', '\t')
local raw_word = concat(w, any_amount(aw))
local right_word = concat(raw_word, neg_look_ahead(aw))
local word = branch(
  concat(
    branch(lit('ArrayOf('), lit('DictionaryOf('), lit('Dict(')), -- typed container macro
    one_or_more(any_character - lit(')')),
    lit(')')
  ),
  concat(neg_look_behind(aw), right_word)
)
local inline_comment =
  concat(lit('/*'), any_amount(concat(neg_look_ahead(lit('*/')), any_character)), lit('*/'))
local spaces = any_amount(branch(
  s,
  -- Comments are really handled by preprocessor, so the following is not needed
  inline_comment,
  concat(lit('//'), any_amount(concat(neg_look_ahead(lit('\n')), any_character)), lit('\n')),
  -- Linemarker inserted by preprocessor
  concat(lit('# '), any_amount(concat(neg_look_ahead(lit('\n')), any_character)), lit('\n'))
))
local typ_part = concat(word, any_amount(concat(spaces, lit('*'))), spaces)

local typ_id = two_or_more(typ_part)
local arg = typ_id -- argument name is swallowed by typ
local pattern = concat(
  any_amount(branch(set(' ', '\t'), inline_comment)),
  typ_id, -- return type with function name
  spaces,
  lit('('),
  spaces,
  one_or_no(branch( -- function arguments
    concat(
      arg, -- first argument, does not require comma
      any_amount(concat( -- following arguments, start with a comma
        spaces,
        lit(','),
        spaces,
        arg,
        any_amount(concat(lit('['), spaces, any_amount(aw), spaces, lit(']')))
      )),
      one_or_no(concat(spaces, lit(','), spaces, lit('...')))
    ),
    lit('void') -- also accepts just void
  )),
  spaces,
  lit(')'),
  any_amount(concat( -- optional attributes
    spaces,
    lit('FUNC_'),
    any_amount(aw),
    one_or_no(concat( -- attribute argument
      spaces,
      lit('('),
      any_amount(concat(neg_look_ahead(lit(')')), any_character)),
      lit(')')
    ))
  )),
  look_ahead(concat( -- definition must be followed by "{"
    spaces,
    lit('{')
  ))
)

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

local preproc_f = io.open(preproc_fname)
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
elseif fname:find('.*/src/nvim/.*%.h$') then
  static = ([[
// IWYU pragma: private, include "%s"
]]):format(fname:gsub('.*/src/nvim/', 'nvim/')) .. static
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

local filepattern = '^#%a* (%d+) "([^"]-)/?([^"/]+)"'

local init = 1
local curfile = nil
local neededfile = fname:match('[^/]+$')
local declline = 0
local declendpos = 0
local curdir = nil
local is_needed_file = false
local init_is_nl = true
local any_static = false
while init ~= nil do
  if init_is_nl and text:sub(init, init) == '#' then
    local line, dir, file = text:match(filepattern, init)
    if file ~= nil then
      curfile = file
      is_needed_file = (curfile == neededfile)
      declline = tonumber(line) - 1
      curdir = dir:gsub('.*/src/nvim/', '')
    else
      declline = declline - 1
    end
  elseif init < declendpos then -- luacheck: ignore 542
    -- Skipping over declaration
  elseif is_needed_file then
    s = init
    local e = pattern:match(text, init)
    if e ~= nil then
      local declaration = text:sub(s, e - 1)
      -- Comments are really handled by preprocessor, so the following is not
      -- needed
      declaration = declaration:gsub('/%*.-%*/', '')
      declaration = declaration:gsub('//.-\n', '\n')

      declaration = declaration:gsub('# .-\n', '')

      declaration = declaration:gsub('\n', ' ')
      declaration = declaration:gsub('%s+', ' ')
      declaration = declaration:gsub(' ?%( ?', '(')
      -- declaration = declaration:gsub(' ?%) ?', ')')
      declaration = declaration:gsub(' ?, ?', ', ')
      declaration = declaration:gsub(' ?(%*+) ?', ' %1')
      declaration = declaration:gsub(' ?(FUNC_ATTR_)', ' %1')
      declaration = declaration:gsub(' $', '')
      declaration = declaration:gsub('^ ', '')
      declaration = declaration .. ';'

      if os.getenv('NVIM_GEN_DECLARATIONS_LINE_NUMBERS') == '1' then
        declaration = declaration .. ('  // %s/%s:%u'):format(curdir, curfile, declline)
      end
      declaration = declaration .. '\n'
      if declaration:sub(1, 6) == 'static' then
        if declaration:find('FUNC_ATTR_') then
          any_static = true
        end
        static = static .. declaration
      else
        declaration = 'DLLEXPORT ' .. declaration
        non_static = non_static .. declaration
      end
      declendpos = e
    end
  end
  init = text:find('[\n;}]', init)
  if init == nil then
    break
  end
  init_is_nl = text:sub(init, init) == '\n'
  init = init + 1
  if init_is_nl and is_needed_file then
    declline = declline + 1
  end
end

non_static = non_static .. non_static_footer
static = static .. static_footer

local F
F = io.open(static_fname, 'w')
F:write(static)
F:close()

if any_static then
  F = io.open(fname, 'r')
  local orig_text = F:read('*a')
  local pat = '\n#%s?include%s+"' .. static_basename .. '"\n'
  local pat_comment = '\n#%s?include%s+"' .. static_basename .. '"%s*//'
  if not string.find(orig_text, pat) and not string.find(orig_text, pat_comment) then
    error('fail: missing include for ' .. static_basename .. ' in ' .. fname)
  end
  F:close()
end

if non_static_fname == 'SKIP' then
  return -- only want static declarations
end

-- Before generating the non-static headers, check if the current file (if
-- exists) is different from the new one. If they are the same, we won't touch
-- the current version to avoid triggering an unnecessary rebuilds of modules
-- that depend on this one
F = io.open(non_static_fname, 'r')
if F ~= nil then
  if F:read('*a') == non_static then
    os.exit(0)
  end
  F:close()
end

F = io.open(non_static_fname, 'w')
F:write(non_static)
F:close()
