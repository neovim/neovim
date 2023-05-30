--[[--------------------------------------------------------------------------
--   Copyright (C) 2012 by Simon Dales   --
--   simon@purrsoft.co.uk   --
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
----------------------------------------------------------------------------]]

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
Some functions can have their parameter lists extended over multiple lines to make it look neat.
Managing this where there are also some comments is a bit more coding than I want to do at this stage,
so it will probably not document accurately if we do do this.

However I have put in a hack that will insert the "missing" close paren.
The effect is that you will get the function documented, but not with the parameter list you might expect.
]]

local _debug_outfile = nil
local _debug_output = {}

local function class()
  local newClass = {} -- a new class newClass
  -- the class will be the metatable for all its newInstanceects,
  -- and they will look up their methods in it.
  newClass.__index = newClass

  -- expose a constructor which can be called by <classname>(<args>)
  setmetatable(newClass, {
    __call = function(class_tbl, ...)
      local newInstance = {}
      setmetatable(newInstance, newClass)
      --if init then
      --  init(newInstance,...)
      if class_tbl.init then
        class_tbl.init(newInstance, ...)
      end
      return newInstance
    end
  })
  return newClass
end

-- write to stdout
local function TCore_IO_write(Str)
  if Str then
    io.write(Str)
    if _debug_outfile then
      table.insert(_debug_output, Str)
    end
  end
end

-- write to stdout
local function TCore_IO_writeln(Str)
  TCore_IO_write(Str)
  TCore_IO_write('\n')
end

-- trims a string
local function string_trim(Str)
  return Str:match('^%s*(.-)%s*$')
end

-- split a string
--!
--! \param Str
--! \param Pattern
--! \returns table of string fragments
---@return string[]
local function string_split(Str, Pattern)
  local splitStr = {}
  local fpat = '(.-)' .. Pattern
  local last_end = 1
  local str, e, cap = string.find(Str, fpat, 1)
  while str do
    if str ~= 1 or cap ~= '' then
      table.insert(splitStr, cap)
    end
    last_end = e + 1
    str, e, cap = string.find(Str, fpat, last_end)
  end
  if last_end <= #Str then
    cap = string.sub(Str, last_end)
    table.insert(splitStr, cap)
  end
  return splitStr
end

-------------------------------
-- file buffer
--!
--! an input file buffer
local TStream_Read = class()

-- get contents of file
--!
--! \param Filename name of file to read (or nil == stdin)
function TStream_Read.getContents(this, Filename)
  assert(Filename, ('invalid file: %s'):format(Filename))
  -- get lines from file
  -- syphon lines to our table
  local filecontents = {}
  for line in io.lines(Filename) do
    table.insert(filecontents, line)
  end

  if filecontents then
    this.filecontents = filecontents
    this.contentsLen = #filecontents
    this.currentLineNo = 1
  end

  return filecontents
end

-- get lineno
function TStream_Read.getLineNo(this)
  return this.currentLineNo
end

-- get a line
function TStream_Read.getLine(this)
  local line
  if this.currentLine then
    line = this.currentLine
    this.currentLine = nil
  else
    -- get line
    if this.currentLineNo <= this.contentsLen then
      line = this.filecontents[this.currentLineNo]
      this.currentLineNo = this.currentLineNo + 1
    else
      line = ''
    end
  end
  return line
end

-- save line fragment
function TStream_Read.ungetLine(this, LineFrag)
  this.currentLine = LineFrag
end

-- is it eof?
function TStream_Read.eof(this)
  if this.currentLine or this.currentLineNo <= this.contentsLen then
    return false
  end
  return true
end

-- output stream
local TStream_Write = class()

-- constructor
function TStream_Write.init(this)
  this.tailLine = {}
end

-- write immediately
function TStream_Write.write(_, Str)
  TCore_IO_write(Str)
end

-- write immediately
function TStream_Write.writeln(_, Str)
  TCore_IO_writeln(Str)
end

-- write immediately
function TStream_Write.writelnComment(_, Str)
  TCore_IO_write('// ZZ: ')
  TCore_IO_writeln(Str)
end

-- write to tail
function TStream_Write.writelnTail(this, Line)
  if not Line then
    Line = ''
  end
  table.insert(this.tailLine, Line)
end

-- output tail lines
function TStream_Write.write_tailLines(this)
  for _, line in ipairs(this.tailLine) do
    TCore_IO_writeln(line)
  end
  TCore_IO_write('// Lua2DoX new eof')
end

-- input filter
local TLua2DoX_filter = class()

-- allow us to do errormessages
function TLua2DoX_filter.warning(this, Line, LineNo, Legend)
  this.outStream:writelnTail(
    '//! \todo warning! ' .. Legend .. ' (@' .. LineNo .. ')"' .. Line .. '"'
  )
end

-- trim comment off end of string
--!
--! If the string has a comment on the end, this trims it off.
--!
local function TString_removeCommentFromLine(Line)
  local pos_comment = string.find(Line, '%-%-')
  local tailComment
  if pos_comment then
    Line = string.sub(Line, 1, pos_comment - 1)
    tailComment = string.sub(Line, pos_comment)
  end
  return Line, tailComment
end

-- get directive from magic
local function getMagicDirective(Line)
  local macro, tail
  local macroStr = '[\\@]'
  local pos_macro = string.find(Line, macroStr)
  if pos_macro then
    --! ....\\ macro...stuff
    --! ....\@ macro...stuff
    local line = string.sub(Line, pos_macro + 1)
    local space = string.find(line, '%s+')
    if space then
      macro = string.sub(line, 1, space - 1)
      tail = string_trim(string.sub(line, space + 1))
    else
      macro = line
      tail = ''
    end
  end
  return macro, tail
end

-- check comment for fn
local function checkComment4fn(Fn_magic, MagicLines)
  local fn_magic = Fn_magic
  --    TCore_IO_writeln('// checkComment4fn "' .. MagicLines .. '"')

  local magicLines = string_split(MagicLines, '\n')

  local macro, tail

  for _, line in ipairs(magicLines) do
    macro, tail = getMagicDirective(line)
    if macro == 'fn' then
      fn_magic = tail
      --    TCore_IO_writeln('// found fn "' .. fn_magic .. '"')
      --else
      --TCore_IO_writeln('// not found fn "' .. line .. '"')
    end
  end

  return fn_magic
end

local types = { 'integer', 'number', 'string', 'table', 'list', 'boolean', 'function' }

local tagged_types = { 'TSNode', 'LanguageTree' }

-- Document these as 'table'
local alias_types = { 'Range', 'Range4', 'Range6', 'TSMetadata' }

-- Processes the file and writes filtered output to stdout.
function TLua2DoX_filter.filter(this, AppStamp, Filename)
  local inStream = TStream_Read()
  local outStream = TStream_Write()
  this.outStream = outStream -- save to this obj

  if inStream:getContents(Filename) then
    -- output the file
    local line
    local fn_magic -- function name/def from  magic comment

    outStream:writelnTail('// #######################')
    outStream:writelnTail('// app run:' .. AppStamp)
    outStream:writelnTail('// #######################')
    outStream:writelnTail()

    local state = '' -- luacheck: ignore 231 variable is set but never accessed.
    local offset = 0
    local generic = {}
    local l = 0
    while not (inStream:eof()) do
      line = string_trim(inStream:getLine())
      l = l + 1
      if string.sub(line, 1, 2) == '--' then -- it's a comment
        -- Allow people to write style similar to EmmyLua (since they are basically the same)
        -- instead of silently skipping things that start with ---
        if string.sub(line, 3, 3) == '@' then -- it's a magic comment
          offset = 0
        elseif string.sub(line, 1, 4) == '---@' then -- it's a magic comment
          offset = 1
        end

        line = line:gsub('@package', '@private')

        if vim.startswith(line, '---@cast')
          or vim.startswith(line, '---@diagnostic')
          or vim.startswith(line, '---@overload')
          or vim.startswith(line, '---@type') then
          -- Ignore LSP directives
          outStream:writeln('// gg:"' .. line .. '"')
        elseif string.sub(line, 3, 3) == '@' or string.sub(line, 1, 4) == '---@' then -- it's a magic comment
          state = 'in_magic_comment'
          local magic = string.sub(line, 4 + offset)

          local magic_split = string_split(magic, ' ')
          if magic_split[1] == 'param' then
            for _, type in ipairs(types) do
              magic = magic:gsub('^param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. ')%)', 'param %1 %2')
              magic =
                magic:gsub('^param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. '|nil)%)', 'param %1 %2')
            end
            magic_split = string_split(magic, ' ')
          elseif magic_split[1] == 'return' then
            for _, type in ipairs(types) do
              magic = magic:gsub('^return%s+.*%((' .. type .. ')%)', 'return %1')
              magic = magic:gsub('^return%s+.*%((' .. type .. '|nil)%)', 'return %1')
            end
            magic_split = string_split(magic, ' ')
          end

          if magic_split[1] == 'generic' then
            local generic_name, generic_type = line:match('@generic%s*(%w+)%s*:?%s*(.*)')
            if generic_type == '' then
              generic_type = 'any'
            end
            generic[generic_name] = generic_type
          else
            local type_index = 2
            if magic_split[1] == 'param' then
              type_index = type_index + 1
            end

            if magic_split[type_index] then
              -- fix optional parameters
              if magic_split[type_index] and magic_split[2]:find('%?$') then
                if not magic_split[type_index]:find('nil') then
                  magic_split[type_index] = magic_split[type_index] .. '|nil'
                end
                magic_split[2] = magic_split[2]:sub(1, -2)
              end
              -- replace generic types
              if magic_split[type_index] then
                for k, v in pairs(generic) do
                  magic_split[type_index] = magic_split[type_index]:gsub(k, v)
                end
              end

              for _, type in ipairs(tagged_types) do
                magic_split[type_index] =
                  magic_split[type_index]:gsub(type, '|%1|')
              end

              for _, type in ipairs(alias_types) do
                magic_split[type_index] =
                  magic_split[type_index]:gsub('^'..type..'$', 'table')
              end

              -- surround some types by ()
              for _, type in ipairs(types) do
                magic_split[type_index] =
                  magic_split[type_index]:gsub('^(' .. type .. '|nil):?$', '(%1)')
                magic_split[type_index] =
                  magic_split[type_index]:gsub('^(' .. type .. '):?$', '(%1)')
              end


            end

            magic = table.concat(magic_split, ' ')

            outStream:writeln('/// @' .. magic)
            fn_magic = checkComment4fn(fn_magic, magic)
          end
        elseif string.sub(line, 3, 3) == '-' then -- it's a nonmagic doc comment
          local comment = string.sub(line, 4)
          outStream:writeln('/// ' .. comment)
        elseif string.sub(line, 3, 4) == '[[' then -- it's a long comment
          line = string.sub(line, 5) -- nibble head
          local comment = ''
          local closeSquare, hitend, thisComment
          while not hitend and (not inStream:eof()) do
            closeSquare = string.find(line, ']]')
            if not closeSquare then -- need to look on another line
              thisComment = line .. '\n'
              line = inStream:getLine()
            else
              thisComment = string.sub(line, 1, closeSquare - 1)
              hitend = true

              -- unget the tail of the line
              -- in most cases it's empty. This may make us less efficient but
              -- easier to program
              inStream:ungetLine(string_trim(string.sub(line, closeSquare + 2)))
            end
            comment = comment .. thisComment
          end
          if string.sub(comment, 1, 1) == '@' then -- it's a long magic comment
            outStream:write('/*' .. comment .. '*/  ')
            fn_magic = checkComment4fn(fn_magic, comment)
          else -- discard
            outStream:write('/* zz:' .. comment .. '*/  ')
            fn_magic = nil
          end
        -- TODO(justinmk): Uncomment this if we want "--" lines to continue the
        --                 preceding magic ("---", "--@", …) lines.
        -- elseif state == 'in_magic_comment' then  -- next line of magic comment
        --   outStream:writeln('/// '.. line:sub(3))
        else -- discard
          outStream:writeln('// zz:"' .. line .. '"')
          fn_magic = nil
        end
      elseif string.find(line, '^function') or string.find(line, '^local%s+function') then
        generic = {}
        state = 'in_function' -- it's a function
        local pos_fn = string.find(line, 'function')
        -- function
        -- ....v...
        if pos_fn then
          -- we've got a function
          local fn = TString_removeCommentFromLine(string_trim(string.sub(line, pos_fn + 8)))
          if fn_magic then
            fn = fn_magic
          end

          if string.sub(fn, 1, 1) == '(' then
            -- it's an anonymous function
            outStream:writelnComment(line)
          else
            -- fn has a name, so is interesting

            -- want to fix for iffy declarations
            local open_paren = string.find(fn, '[%({]')
            if open_paren then
              -- we might have a missing close paren
              if not string.find(fn, '%)') then
                fn = fn .. ' ___MissingCloseParenHere___)'
              end
            end

            -- Big hax
            if string.find(fn, ':') then
              -- TODO: We need to add a first parameter of "SELF" here
              -- local colon_place = string.find(fn, ":")
              -- local name = string.sub(fn, 1, colon_place)
              fn = fn:gsub(':', '.', 1)
              outStream:writeln('/// @param self')

              local paren_start = string.find(fn, '(', 1, true)
              local paren_finish = string.find(fn, ')', 1, true)

              -- Nothing in between the parens
              local comma
              if paren_finish == paren_start + 1 then
                comma = ''
              else
                comma = ', '
              end
              fn = string.sub(fn, 1, paren_start)
                .. 'self'
                .. comma
                .. string.sub(fn, paren_start + 1)
            end

            -- add vanilla function
            outStream:writeln('function ' .. fn .. '{}')
          end
        else
          this:warning(inStream:getLineNo(), 'something weird here')
        end
        fn_magic = nil -- mustn't inadvertently use it again

      -- TODO: If we can make this learn how to generate these, that would be helpful.
      -- elseif string.find(line, "^M%['.*'%] = function") then
      --   state = 'in_function'  -- it's a function
      --   outStream:writeln("function textDocument/publishDiagnostics(...){}")

      --   fn_magic = nil -- mustn't inadvertently use it again
      else
        state = '' -- unknown
        if #line > 0 then -- we don't know what this line means, so just comment it out
          outStream:writeln('// zz: ' .. line)
        else
          outStream:writeln() -- keep this line blank
        end
      end
    end

    -- output the tail
    outStream:write_tailLines()
  else
    outStream:writeln('!empty file')
  end
end

-- this application
local TApp = class()

-- constructor
function TApp.init(this)
  this.timestamp = os.date('%c %Z', os.time())
  this.name = 'Lua2DoX'
  this.version = '0.2 20130128'
  this.copyright = 'Copyright (c) Simon Dales 2012-13'
end

function TApp.getRunStamp(this)
  return this.name .. ' (' .. this.version .. ') ' .. this.timestamp
end

function TApp.getVersion(this)
  return this.name .. ' (' .. this.version .. ') '
end

function TApp.getCopyright(this)
  return this.copyright
end

local This_app = TApp()

--main

if arg[1] == '--help' then
  TCore_IO_writeln(This_app:getVersion())
  TCore_IO_writeln(This_app:getCopyright())
  TCore_IO_writeln([[
  run as:
  nvim -l scripts/lua2dox.lua <param>
  --------------
  Param:
  <filename> : interprets filename
  --version  : show version/copyright info
  --help     : this help text]])
elseif arg[1] == '--version' then
  TCore_IO_writeln(This_app:getVersion())
  TCore_IO_writeln(This_app:getCopyright())
else  -- It's a filter.
  local filename = arg[1]

  if arg[2] == '--outdir' then
    local outdir = arg[3]
    if type(outdir) ~= 'string' or (0 ~= vim.fn.filereadable(outdir) and 0 == vim.fn.isdirectory(outdir)) then
      error(('invalid --outdir: "%s"'):format(tostring(outdir)))
    end
    vim.fn.mkdir(outdir, 'p')
    _debug_outfile = string.format('%s/%s.c', outdir, vim.fs.basename(filename))
  end

  local appStamp = This_app:getRunStamp()
  local filter = TLua2DoX_filter()
  filter:filter(appStamp, filename)

  if _debug_outfile then
    local f = assert(io.open(_debug_outfile, 'w'))
    f:write(table.concat(_debug_output))
    f:close()
  end
end

--eof
