#!/usr/bin/lua

local fname = arg[1]
local static_fname = arg[2]
local non_static_fname = arg[3]
local preproc_fname = arg[4]


local lpeg = require('lpeg')

local fold = function (func, ...)
  local result = nil
  for i, v in ipairs({...}) do
    if result == nil then
      result = v
    else
      result = func(result, v)
    end
  end
  return result
end

local folder = function (func)
  return function (...)
    return fold(func, ...)
  end
end

local lit = lpeg.P
local set = function(...)
  return lpeg.S(fold(function (a, b) return a .. b end, ...))
end
local any_character = lpeg.P(1)
local rng = function(s, e) return lpeg.R(s .. e) end
local concat = folder(function (a, b) return a * b end)
local branch = folder(function (a, b) return a + b end)
local one_or_more = function(v) return v ^ 1 end
local two_or_more = function(v) return v ^ 2 end
local any_amount = function(v) return v ^ 0 end
local one_or_no = function(v) return v ^ -1 end
local look_behind = lpeg.B
local look_ahead = function(v) return #v end
local neg_look_ahead = function(v) return -v end
local neg_look_behind = function(v) return -look_behind(v) end

local w = branch(
  rng('a', 'z'),
  rng('A', 'Z'),
  lit('_')
)
local aw = branch(
  w,
  rng('0', '9')
)
local s = set(' ', '\n', '\t')
local raw_word = concat(w, any_amount(aw))
local right_word = concat(
  raw_word,
  neg_look_ahead(aw)
)
local word = branch(
  concat(
    branch(lit('ArrayOf('), lit('DictionaryOf(')), -- typed container macro
    one_or_more(any_character - lit(')')),
    lit(')')
  ),
  concat(
    neg_look_behind(aw),
    right_word
  )
)
local spaces = any_amount(branch(
  s,
  -- Comments are really handled by preprocessor, so the following is not needed
  concat(
    lit('/*'),
    any_amount(concat(
      neg_look_ahead(lit('*/')),
      any_character
    )),
    lit('*/')
  ),
  concat(
    lit('//'),
    any_amount(concat(
      neg_look_ahead(lit('\n')),
      any_character
    )),
    lit('\n')
  ),
  -- Linemarker inserted by preprocessor
  concat(
    lit('# '),
    any_amount(concat(
      neg_look_ahead(lit('\n')),
      any_character
    )),
    lit('\n')
  )
))
local typ_part = concat(
  word,
  any_amount(concat(
    spaces,
    lit('*')
  )),
  spaces
)
local typ = one_or_more(typ_part)
local typ_id = two_or_more(typ_part)
local arg = typ_id         -- argument name is swallowed by typ
local pattern = concat(
  typ_id,                  -- return type with function name
  spaces,
  lit('('),
  spaces,
  one_or_no(branch(        -- function arguments
    concat(
      arg,                 -- first argument, does not require comma
      any_amount(concat(   -- following arguments, start with a comma
        spaces,
        lit(','),
        spaces,
        arg,
        any_amount(concat(
          lit('['),
          spaces,
          any_amount(aw),
          spaces,
          lit(']')
        ))
      )),
      one_or_no(concat(
        spaces,
        lit(','),
        spaces,
        lit('...')
      ))
    ),
    lit('void')            -- also accepts just void
  )),
  spaces,
  lit(')'),
  any_amount(concat(       -- optional attributes
    spaces,
    lit('FUNC_'),
    any_amount(aw),
    one_or_no(concat(      -- attribute argument
      spaces,
      lit('('),
      any_amount(concat(
        neg_look_ahead(lit(')')),
        any_character
      )),
      lit(')')
    ))
  )),
  look_ahead(concat(       -- definition must be followed by "{"
    spaces,
    lit('{')
  ))
)

if fname == '--help' then
  print'Usage:'
  print()
  print'  gendeclarations.lua definitions.c static.h non-static.h preprocessor.i'
  os.exit()
end

local preproc_f = io.open(preproc_fname)
local text = preproc_f:read("*all")
preproc_f:close()


local header = [[
#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "nvim/func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
]]

local footer = [[
#include "nvim/func_attr.h"
]]

local non_static = header
local static = header

local filepattern = '^#%a* %d+ "[^"]-/?([^"/]+)"'
local curfile

init = 0
curfile = nil
neededfile = fname:match('[^/]+$')
while init ~= nil do
  init = text:find('\n', init)
  if init == nil then
    break
  end
  init = init + 1
  if text:sub(init, init) == '#' then
    file = text:match(filepattern, init)
    if file ~= nil then
      curfile = file
    end
  elseif curfile == neededfile then
    s = init
    e = pattern:match(text, init)
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
      declaration = declaration .. ';\n'
      if text:sub(s, s + 5) == 'static' then
        static = static .. declaration
      else
        non_static = non_static .. declaration
      end
      init = e
    end
  end
end

non_static = non_static .. footer
static = static .. footer

local F
F = io.open(static_fname, 'w')
F:write(static)
F:close()

-- Before generating the non-static headers, check if the current file(if
-- exists) is different from the new one. If they are the same, we won't touch
-- the current version to avoid triggering an unnecessary rebuilds of modules
-- that depend on this one
F = io.open(non_static_fname, 'r')
if F ~= nil then
  if F:read('*a') == non_static then
    os.exit(0)
  end
  io.close(F)
end

F = io.open(non_static_fname, 'w')
F:write(non_static)
F:close()
