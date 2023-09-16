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

local TAGGED_TYPES = { 'TSNode', 'LanguageTree' }

-- Document these as 'table'
local ALIAS_TYPES = {
  'Range', 'Range4', 'Range6', 'TSMetadata',
  'vim.filetype.add.filetypes',
  'vim.filetype.match.args'
}

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
    filecontents[#filecontents+1] = line
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
local Lua2DoxFilter = {}
setmetatable(Lua2DoxFilter, { __index = Lua2DoxFilter })

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

--- Processes "@…" directives in a docstring line.
---
--- @param line string
--- @param generics table<string,string>
--- @return string?
local function process_magic(line, generics)
  line = line:gsub('^%s+@', '@')
  line = line:gsub('@package', '@private')
  line = line:gsub('@nodoc', '@private')

  if not vim.startswith(line, '@') then -- it's a magic comment
    return '/// ' .. line
  end

  local magic = line:sub(2)
  local magic_split = vim.split(magic, ' ', { plain = true })
  local directive = magic_split[1]

  if vim.list_contains({
    'cast', 'diagnostic', 'overload', 'meta', 'type'
  }, directive) then
    -- Ignore LSP directives
    return '// gg:"' .. line .. '"'
  end

  if directive == 'defgroup' or directive == 'addtogroup' then
    -- Can't use '.' in defgroup, so convert to '--'
    return '/// @' .. magic:gsub('%.', '-dot-')
  end

  if directive == 'generic' then
    local generic_name, generic_type = line:match('@generic%s*(%w+)%s*:?%s*(.*)')
    if generic_type == '' then
      generic_type = 'any'
    end
    generics[generic_name] = generic_type
    return
  end

  local type_index = 2

  if directive == 'param' then
    for _, type in ipairs(TYPES) do
      magic = magic:gsub('^param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. ')%)', 'param %1 %2')
      magic =
        magic:gsub('^param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. '|nil)%)', 'param %1 %2')
    end
    magic_split = vim.split(magic, ' ', { plain = true })
    type_index = 3
  elseif directive == 'return' then
    for _, type in ipairs(TYPES) do
      magic = magic:gsub('^return%s+.*%((' .. type .. ')%)', 'return %1')
      magic = magic:gsub('^return%s+.*%((' .. type .. '|nil)%)', 'return %1')
    end
    -- Remove first "#" comment char, if any. https://github.com/LuaLS/lua-language-server/wiki/Annotations#return
    magic = magic:gsub('# ', '', 1)
    -- handle the return of vim.spell.check
    magic = magic:gsub('({.*}%[%])', '`%1`')
    magic_split = vim.split(magic, ' ', { plain = true })
  end

  local ty = magic_split[type_index]

  if ty then
    -- fix optional parameters
    if magic_split[2]:find('%?$') then
      if not ty:find('nil') then
        ty = ty  .. '|nil'
      end
      magic_split[2] = magic_split[2]:sub(1, -2)
    end

    -- replace generic types
    for k, v in pairs(generics) do
      ty = ty:gsub(k, v) --- @type string
    end

    for _, type in ipairs(TAGGED_TYPES) do
      ty = ty:gsub(type, '|%1|')
    end

    for _, type in ipairs(ALIAS_TYPES) do
      ty = ty:gsub('^'..type..'$', 'table') --- @type string
    end

    -- surround some types by ()
    for _, type in ipairs(TYPES) do
      ty = ty
        :gsub('^(' .. type .. '|nil):?$', '(%1)')
        :gsub('^(' .. type .. '):?$', '(%1)')
    end

    magic_split[type_index] = ty

  end

  magic = table.concat(magic_split, ' ')

  return '/// @' .. magic
end

--- @param line string
--- @param in_stream StreamRead
--- @return string
local function process_block_comment(line, in_stream)
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
    comment_parts[#comment_parts+1] = thisComment
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
local function process_function_header(line)
  local pos_fn = assert(line:find('function'))
  -- we've got a function
  local fn = removeCommentFromLine(vim.trim(line:sub(pos_fn + 8)))

  if fn:sub(1, 1) == '(' then
    -- it's an anonymous function
    return '// ZZ: '..line
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

    fn = fn:sub(1, paren_start)
      .. 'self'
      .. comma
      .. fn:sub(paren_start + 1)
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
--- @param generics table<string,string>>
--- @return string?
local function process_line(line, in_stream, generics)
  local line_raw = line
  line = vim.trim(line)

  if vim.startswith(line, '---') then
    return process_magic(line:sub(4), generics)
  end

  if vim.startswith(line, '--'..'[[') then -- it's a long comment
    return process_block_comment(line:sub(5), in_stream)
  end

  -- Hax... I'm sorry
  -- M.fun = vim.memoize(function(...)
  --   ->
  -- function M.fun(...)
  line = line:gsub('^(.+) = .*_memoize%([^,]+, function%((.*)%)$', 'function %1(%2)')

  if line:find('^function') or line:find('^local%s+function') then
    return process_function_header(line)
  end

  if not line:match('^local') then
    local v = line_raw:match('^([A-Za-z][.a-zA-Z_]*)%s+%=')
    if v and v:match('%.') then
      -- Special: this lets gen_vimdoc.py handle tables.
      return 'table '..v..'() {}'
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

  local generics = {} --- @type table<string,string>

  while not in_stream:eof() do
    local line = in_stream:getLine()

    local out_line = process_line(line, in_stream, generics)

    if not vim.startswith(vim.trim(line), '---') then
      generics = {}
    end

    if out_line then
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
  copyright = 'Copyright (c) Simon Dales 2012-13'
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
else  -- It's a filter.
  local filename = arg[1]

  if arg[2] == '--outdir' then
    local outdir = arg[3]
    if type(outdir) ~= 'string' or (0 ~= vim.fn.filereadable(outdir) and 0 == vim.fn.isdirectory(outdir)) then
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
