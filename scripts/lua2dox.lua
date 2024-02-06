-----------------------------------------------------------------------------
--   Copyright (C) 2012 by Simon Dales                                     --
--   simon@purrsoft.co.uk                                                  --
--                                                                         --
--   This program is free software; you can redistribute it and/or modify  --
--   it under the terms of the GNU General Public License as published by  --
--   the Free Software Foundation; either version 2 of the License, or     --
--   (at your option) any later version.                                   --
--                                                                         --
--   This program is distributed in the hope that it will be useful,       --
--   but WITHOUT ANY WARRANTY; without even the implied warranty of        --
--   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
--   GNU General Public License for more details.                          --
--                                                                         --
--   You should have received a copy of the GNU General Public License     --
--   along with this program; if not, write to the                         --
--   Free Software Foundation, Inc.,                                       --
--   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             --
-----------------------------------------------------------------------------

--[[!
Lua-to-Doxygen converter

Partially from lua2dox
http://search.cpan.org/~alec/Doxygen-Lua-0.02/lib/Doxygen/Lua.pm

RUNNING
-------

This script "lua2dox.lua" gets called by "gen_vimdoc.py".

DEBUGGING/DEVELOPING
---------------------

1. To debug, run gen_vimdoc.py with --keep-tmpfiles:
   python3 scripts/gen_vimdoc.py -t treesitter --keep-tmpfiles
2. The filtered result will be written to ./tmp-lua2dox-doc/….lua.c

Doxygen must be on your system. You can experiment like so:

- Run "doxygen -g" to create a default Doxyfile.
- Then alter it to let it recognise lua. Add the following line:
    FILE_PATTERNS   = *.lua
- Then run "doxygen".

The core function reads the input file (filename or stdin) and outputs some pseudo C-ish language.
It only has to be good enough for doxygen to see it as legal.

One limitation is that each line is treated separately (except for long comments).
The implication is that class and function declarations must be on the same line.

There is hack that will insert the "missing" close paren.
The effect is that you will get the function documented, but not with the parameter list you might expect.
]]

local TYPES = { 'integer', 'number', 'string', 'table', 'list', 'boolean', 'function' }

local luacats_parser = require('src/nvim/generators/luacats_grammar')

local debug_outfile = nil --- @type string?
local debug_output = {}

--- write to stdout
--- @param str? string
local function write(str)
  if not str then
    return
  end

  io.write(str)
  if debug_outfile then
    table.insert(debug_output, str)
  end
end

--- write to stdout
--- @param str? string
local function writeln(str)
  write(str)
  write('\n')
end

--- an input file buffer
--- @class StreamRead
--- @field currentLine string?
--- @field contentsLen integer
--- @field currentLineNo integer
--- @field filecontents string[]
local StreamRead = {}

--- @return StreamRead
--- @param filename string
function StreamRead.new(filename)
  assert(filename, ('invalid file: %s'):format(filename))
  -- get lines from file
  -- syphon lines to our table
  local filecontents = {} --- @type string[]
  for line in io.lines(filename) do
    filecontents[#filecontents + 1] = line
  end

  return setmetatable({
    filecontents = filecontents,
    contentsLen = #filecontents,
    currentLineNo = 1,
  }, { __index = StreamRead })
end

-- get a line
function StreamRead:getLine()
  if self.currentLine then
    self.currentLine = nil
    return self.currentLine
  end

  -- get line
  if self.currentLineNo <= self.contentsLen then
    local line = self.filecontents[self.currentLineNo]
    self.currentLineNo = self.currentLineNo + 1
    return line
  end

  return ''
end

-- save line fragment
--- @param line_fragment string
function StreamRead:ungetLine(line_fragment)
  self.currentLine = line_fragment
end

-- is it eof?
function StreamRead:eof()
  return not self.currentLine and self.currentLineNo > self.contentsLen
end

-- input filter
--- @class Lua2DoxFilter
local Lua2DoxFilter = {
  generics = {}, --- @type table<string,string>
  block_ignore = false, --- @type boolean
}
setmetatable(Lua2DoxFilter, { __index = Lua2DoxFilter })

function Lua2DoxFilter:reset()
  self.generics = {}
  self.block_ignore = false
end

--- trim comment off end of string
---
--- @param line string
--- @return string, string?
local function removeCommentFromLine(line)
  local pos_comment = line:find('%-%-')
  if not pos_comment then
    return line
  end
  return line:sub(1, pos_comment - 1), line:sub(pos_comment)
end

--- @param parsed luacats.Return
--- @return string
local function get_return_type(parsed)
  local elems = {} --- @type string[]
  for _, v in ipairs(parsed) do
    local e = v.type --- @type string
    if v.name then
      e = e .. ' ' .. v.name --- @type string
    end
    elems[#elems + 1] = e
  end
  return '(' .. table.concat(elems, ', ') .. ')'
end

--- @param name string
--- @return string
local function process_name(name, optional)
  if optional then
    name = name:sub(1, -2) --- @type string
  end
  return name
end

--- @param ty string
--- @param generics table<string,string>
--- @return string
local function process_type(ty, generics, optional)
  -- replace generic types
  for k, v in pairs(generics) do
    ty = ty:gsub(k, v) --- @type string
  end

  -- strip parens
  ty = ty:gsub('^%((.*)%)$', '%1')

  if optional and not ty:find('nil') then
    ty = ty .. '?'
  end

  -- remove whitespace in unions
  ty = ty:gsub('%s*|%s*', '|')

  -- replace '|nil' with '?'
  ty = ty:gsub('|nil', '?')
  ty = ty:gsub('nil|(.*)', '%1?')

  return '(`' .. ty .. '`)'
end

--- @param parsed luacats.Param
--- @param generics table<string,string>
--- @return string
local function process_param(parsed, generics)
  local name, ty = parsed.name, parsed.type
  local optional = vim.endswith(name, '?')

  return table.concat({
    '/// @param',
    process_name(name, optional),
    process_type(ty, generics, optional),
    parsed.desc,
  }, ' ')
end

--- @param parsed luacats.Return
--- @param generics table<string,string>
--- @return string
local function process_return(parsed, generics)
  local ty, name --- @type string, string
  if #parsed == 1 then
    ty, name = parsed[1].type, parsed[1].name or ''
  else
    ty, name = get_return_type(parsed), ''
  end

  local optional = vim.endswith(name, '?')

  return table.concat({
    '/// @return',
    process_type(ty, generics, optional),
    process_name(name, optional),
    parsed.desc,
  }, ' ')
end

--- Processes "@…" directives in a docstring line.
---
--- @param line string
--- @return string?
function Lua2DoxFilter:process_magic(line)
  line = line:gsub('^%s+@', '@')
  line = line:gsub('@package', '@private')
  line = line:gsub('@nodoc', '@private')

  if self.block_ignore then
    return '// gg:" ' .. line .. '"'
  end

  if not vim.startswith(line, '@') then -- it's a magic comment
    return '/// ' .. line
  end

  local magic_split = vim.split(line, ' ', { plain = true })
  local directive = magic_split[1]

  if
    vim.list_contains({
      '@cast',
      '@diagnostic',
      '@overload',
      '@meta',
      '@type',
    }, directive)
  then
    -- Ignore LSP directives
    return '// gg:"' .. line .. '"'
  elseif directive == '@defgroup' or directive == '@addtogroup' then
    -- Can't use '.' in defgroup, so convert to '--'
    return '/// ' .. line:gsub('%.', '-dot-')
  end

  if directive == '@alias' then
    -- this contiguous block should be all ignored.
    self.block_ignore = true
    return '// gg:"' .. line .. '"'
  end

  -- preprocess line before parsing
  if directive == '@param' or directive == '@return' then
    for _, type in ipairs(TYPES) do
      line = line:gsub('^@param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. ')%)', '@param %1 %2')
      line = line:gsub('^@param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. '|nil)%)', '@param %1 %2')
      line = line:gsub('^@param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. '%?)%)', '@param %1 %2')

      line = line:gsub('^@return%s+.*%((' .. type .. ')%)', '@return %1')
      line = line:gsub('^@return%s+.*%((' .. type .. '|nil)%)', '@return %1')
      line = line:gsub('^@return%s+.*%((' .. type .. '%?)%)', '@return %1')
    end
  end

  local parsed = luacats_parser:match(line)

  if not parsed then
    return '/// ' .. line
  end

  local kind = parsed.kind

  if kind == 'generic' then
    self.generics[parsed.name] = parsed.type or 'any'
    return
  elseif kind == 'param' then
    return process_param(parsed --[[@as luacats.Param]], self.generics)
  elseif kind == 'return' then
    return process_return(parsed --[[@as luacats.Return]], self.generics)
  end

  error(string.format('unhandled parsed line %q: %s', line, parsed))
end

--- @param line string
--- @param in_stream StreamRead
--- @return string
function Lua2DoxFilter:process_block_comment(line, in_stream)
  local comment_parts = {} --- @type string[]
  local done --- @type boolean?

  while not done and not in_stream:eof() do
    local thisComment --- @type string?
    local closeSquare = line:find(']]')
    if not closeSquare then -- need to look on another line
      thisComment = line .. '\n'
      line = in_stream:getLine()
    else
      thisComment = line:sub(1, closeSquare - 1)
      done = true

      -- unget the tail of the line
      -- in most cases it's empty. This may make us less efficient but
      -- easier to program
      in_stream:ungetLine(vim.trim(line:sub(closeSquare + 2)))
    end
    comment_parts[#comment_parts + 1] = thisComment
  end

  local comment = table.concat(comment_parts)

  if comment:sub(1, 1) == '@' then -- it's a long magic comment
    return '/*' .. comment .. '*/  '
  end

  -- discard
  return '/* zz:' .. comment .. '*/  '
end

--- @param line string
--- @return string
function Lua2DoxFilter:process_function_header(line)
  local pos_fn = assert(line:find('function'))
  -- we've got a function
  local fn = removeCommentFromLine(vim.trim(line:sub(pos_fn + 8)))

  if fn:sub(1, 1) == '(' then
    -- it's an anonymous function
    return '// ZZ: ' .. line
  end
  -- fn has a name, so is interesting

  -- want to fix for iffy declarations
  if fn:find('[%({]') then
    -- we might have a missing close paren
    if not fn:find('%)') then
      fn = fn .. ' ___MissingCloseParenHere___)'
    end
  end

  -- Big hax
  if fn:find(':') then
    fn = fn:gsub(':', '.', 1)

    local paren_start = fn:find('(', 1, true)
    local paren_finish = fn:find(')', 1, true)

    -- Nothing in between the parens
    local comma --- @type string
    if paren_finish == paren_start + 1 then
      comma = ''
    else
      comma = ', '
    end

    fn = fn:sub(1, paren_start) .. 'self' .. comma .. fn:sub(paren_start + 1)
  end

  if line:match('local') then
    -- Special: tell gen_vimdoc.py this is a local function.
    return 'local_function ' .. fn .. '{}'
  end

  -- add vanilla function
  return 'function ' .. fn .. '{}'
end

--- @param line string
--- @param in_stream StreamRead
--- @return string?
function Lua2DoxFilter:process_line(line, in_stream)
  local line_raw = line
  line = vim.trim(line)

  if vim.startswith(line, '---') then
    return Lua2DoxFilter:process_magic(line:sub(4))
  end

  if vim.startswith(line, '--' .. '[[') then -- it's a long comment
    return Lua2DoxFilter:process_block_comment(line:sub(5), in_stream)
  end

  -- Hax... I'm sorry
  -- M.fun = vim.memoize(function(...)
  --   ->
  -- function M.fun(...)
  line = line:gsub('^(.+) = .*_memoize%([^,]+, function%((.*)%)$', 'function %1(%2)')

  if line:find('^function') or line:find('^local%s+function') then
    return Lua2DoxFilter:process_function_header(line)
  end

  if not line:match('^local') then
    local v = line_raw:match('^([A-Za-z][.a-zA-Z_]*)%s+%=')
    if v and v:match('%.') then
      -- Special: this lets gen_vimdoc.py handle tables.
      return 'table ' .. v .. '() {}'
    end
  end

  if #line > 0 then -- we don't know what this line means, so just comment it out
    return '// zz: ' .. line
  end

  return ''
end

-- Processes the file and writes filtered output to stdout.
---@param filename string
function Lua2DoxFilter:filter(filename)
  local in_stream = StreamRead.new(filename)

  local last_was_magic = false

  while not in_stream:eof() do
    local line = in_stream:getLine()

    local out_line = self:process_line(line, in_stream)

    if not vim.startswith(vim.trim(line), '---') then
      self:reset()
    end

    if out_line then
      -- Ensure all magic blocks associate with some object to prevent doxygen
      -- from getting confused.
      if vim.startswith(out_line, '///') then
        last_was_magic = true
      else
        if last_was_magic and out_line:match('^// zz: [^-]+') then
          writeln('local_function _ignore() {}')
        end
        last_was_magic = false
      end
      writeln(out_line)
    end
  end
end

--- @class TApp
--- @field timestamp string|osdate
--- @field name string
--- @field version string
--- @field copyright string
--- this application
local TApp = {
  timestamp = os.date('%c %Z', os.time()),
  name = 'Lua2DoX',
  version = '0.2 20130128',
  copyright = 'Copyright (c) Simon Dales 2012-13',
}

setmetatable(TApp, { __index = TApp })

function TApp:getRunStamp()
  return self.name .. ' (' .. self.version .. ') ' .. self.timestamp
end

function TApp:getVersion()
  return self.name .. ' (' .. self.version .. ') '
end

--main

if arg[1] == '--help' then
  writeln(TApp:getVersion())
  writeln(TApp.copyright)
  writeln([[
  run as:
  nvim -l scripts/lua2dox.lua <param>
  --------------
  Param:
  <filename> : interprets filename
  --version  : show version/copyright info
  --help     : this help text]])
elseif arg[1] == '--version' then
  writeln(TApp:getVersion())
  writeln(TApp.copyright)
else -- It's a filter.
  local filename = arg[1]

  if arg[2] == '--outdir' then
    local outdir = arg[3]
    if
      type(outdir) ~= 'string'
      or (0 ~= vim.fn.filereadable(outdir) and 0 == vim.fn.isdirectory(outdir))
    then
      error(('invalid --outdir: "%s"'):format(tostring(outdir)))
    end
    vim.fn.mkdir(outdir, 'p')
    debug_outfile = string.format('%s/%s.c', outdir, vim.fs.basename(filename))
  end

  Lua2DoxFilter:filter(filename)

  -- output the tail
  writeln('// #######################')
  writeln('// app run:' .. TApp:getRunStamp())
  writeln('// #######################')
  writeln()

  if debug_outfile then
    local f = assert(io.open(debug_outfile, 'w'))
    f:write(table.concat(debug_output))
    f:close()
  end
end
