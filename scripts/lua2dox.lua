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
\file
\brief a hack lua2dox converter
]]

--[[!
\mainpage

Introduction
------------

A hack lua2dox converter
Version 0.2

This lets us make Doxygen output some documentation to let
us develop this code.

It is partially cribbed from the functionality of lua2dox
(http://search.cpan.org/~alec/Doxygen-Lua-0.02/lib/Doxygen/Lua.pm).
Found on CPAN when looking for something else; kinda handy.

Improved from lua2dox to make the doxygen output more friendly.
Also it runs faster in lua rather than Perl.

Because this Perl based system is called "lua2dox"., I have decided to add ".lua" to the name
to keep the two separate.

Running
-------

<ol>
<li>  Ensure doxygen is installed on your system and that you are familiar with its use.
Best is to try to make and document some simple C/C++/PHP to see what it produces.
You can experiment with the enclosed example code.

<li> Run "doxygen -g" to create a default Doxyfile.

Then alter it to let it recognise lua. Add the two following lines:

\code{.bash}
FILE_PATTERNS   = *.lua

FILTER_PATTERNS = *.lua=lua2dox_filter
\endcode


Either add them to the end or find the appropriate entry in Doxyfile.

There are other lines that you might like to alter, but see futher documentation for details.

<li> When Doxyfile is edited run "doxygen"

The core function reads the input file (filename or stdin) and outputs some pseudo C-ish language.
It only has to be good enough for doxygen to see it as legal.
Therefore our lua interpreter is fairly limited, but "good enough".

One limitation is that each line is treated separately (except for long comments).
The implication is that class and function declarations must be on the same line.
Some functions can have their parameter lists extended over multiple lines to make it look neat.
Managing this where there are also some comments is a bit more coding than I want to do at this stage,
so it will probably not document accurately if we do do this.

However I have put in a hack that will insert the "missing" close paren.
The effect is that you will get the function documented, but not with the parameter list you might expect.
</ol>

Installation
------------

Here for linux or unix-like, for any other OS you need to refer to other documentation.

This file is "lua2dox.lua". It gets called by "lua2dox_filter"(bash).
Somewhere in your path (e.g. "~/bin" or "/usr/local/bin") put a link to "lua2dox_filter".

Documentation
-------------

Read the external documentation that should be part of this package.
For example look for the "README" and some .PDFs.

]]

-- we won't use our library code, so this becomes more portable

-- require 'elijah_fix_require'
-- require 'elijah_class'
-- 
--! \brief ``declare'' as class
--! 
--! use as:
--! \code{.lua}
--! TWibble = class()
--! function TWibble.init(this,Str)
--! 	this.str = Str
--! 	-- more stuff here
--! end
--! \endcode
--! 
function class(BaseClass, ClassInitialiser)
  local newClass = {}    -- a new class newClass
  if not ClassInitialiser and type(BaseClass) == 'function' then
    ClassInitialiser = BaseClass
    BaseClass = nil
  elseif type(BaseClass) == 'table' then
    -- our new class is a shallow copy of the base class!
    for i,v in pairs(BaseClass) do
      newClass[i] = v
    end
    newClass._base = BaseClass
  end
  -- the class will be the metatable for all its newInstanceects,
  -- and they will look up their methods in it.
  newClass.__index = newClass

  -- expose a constructor which can be called by <classname>(<args>)
  local classMetatable = {}
  classMetatable.__call = 
  function(class_tbl, ...)
    local newInstance = {}
    setmetatable(newInstance,newClass)
    --if init then
    --	init(newInstance,...)
    if class_tbl.init then
      class_tbl.init(newInstance,...)
    else 
      -- make sure that any stuff from the base class is initialized!
      if BaseClass and BaseClass.init then
        BaseClass.init(newInstance, ...)
      end
    end
    return newInstance
  end
  newClass.init = ClassInitialiser
  newClass.is_a = 
  function(this, klass)
    local thisMetatable = getmetatable(this)
    while thisMetatable do 
      if thisMetatable == klass then
        return true
      end
      thisMetatable = thisMetatable._base
    end
    return false
  end
  setmetatable(newClass, classMetatable)
  return newClass
end

-- require 'elijah_clock'

--! \class TCore_Clock
--! \brief a clock
TCore_Clock = class()

--! \brief get the current time
function TCore_Clock.GetTimeNow()
  if os.gettimeofday then
    return os.gettimeofday()
  else
    return os.time()
  end
end

--! \brief constructor
function TCore_Clock.init(this,T0)
  if T0 then
    this.t0 = T0
  else
    this.t0 = TCore_Clock.GetTimeNow()
  end
end

--! \brief get time string
function TCore_Clock.getTimeStamp(this,T0)
  local t0
  if T0 then
    t0 = T0
  else
    t0 = this.t0
  end
  return os.date('%c %Z',t0)
end


--require 'elijah_io'

--! \class TCore_IO
--! \brief io to console
--! 
--! pseudo class (no methods, just to keep documentation tidy)
TCore_IO = class()
-- 
--! \brief write to stdout
function TCore_IO_write(Str)
  if (Str) then
    io.write(Str)
  end
end

--! \brief write to stdout
function TCore_IO_writeln(Str)
  if (Str) then
    io.write(Str)
  end
  io.write("\n")
end


--require 'elijah_string'

--! \brief trims a string
function string_trim(Str)
  return Str:match("^%s*(.-)%s*$")
end

--! \brief split a string
--! 
--! \param Str
--! \param Pattern
--! \returns table of string fragments
function string_split(Str, Pattern)
  local splitStr = {}
  local fpat = "(.-)" .. Pattern
  local last_end = 1
  local str, e, cap = string.find(Str,fpat, 1)
  while str do
    if str ~= 1 or cap ~= "" then
      table.insert(splitStr,cap)
    end
    last_end = e+1
    str, e, cap = string.find(Str,fpat, last_end)
  end
  if last_end <= #Str then
    cap = string.sub(Str,last_end)
    table.insert(splitStr, cap)
  end
  return splitStr
end


--require 'elijah_commandline'

--! \class TCore_Commandline
--! \brief reads/parses commandline
TCore_Commandline = class()

--! \brief constructor
function TCore_Commandline.init(this)
  this.argv = arg
  this.parsed = {}
  this.params = {}
end

--! \brief get value
function TCore_Commandline.getRaw(this,Key,Default)
  local val = this.argv[Key]
  if not val then
    val = Default
  end
  return val
end


--require 'elijah_debug'

-------------------------------
--! \brief file buffer
--! 
--! an input file buffer
TStream_Read = class()

--! \brief get contents of file
--! 
--! \param Filename name of file to read (or nil == stdin)
function 	TStream_Read.getContents(this,Filename)
  -- get lines from file
  local filecontents
  if Filename then
    -- syphon lines to our table
    --TCore_Debug_show_var('Filename',Filename)
    filecontents={}
    for line in io.lines(Filename) do
      table.insert(filecontents,line)
    end
  else
    -- get stuff from stdin as a long string (with crlfs etc)
    filecontents=io.read('*a')
    --  make it a table of lines
    filecontents = TString_split(filecontents,'[\n]') -- note this only works for unix files.
    Filename = 'stdin'
  end

  if filecontents then
    this.filecontents = filecontents
    this.contentsLen = #filecontents
    this.currentLineNo = 1
  end

  return filecontents
end

--! \brief get lineno
function TStream_Read.getLineNo(this)
  return this.currentLineNo
end

--! \brief get a line
function TStream_Read.getLine(this)
  local line
  if this.currentLine then
    line = this.currentLine
    this.currentLine = nil
  else
    -- get line
    if this.currentLineNo<=this.contentsLen then
      line = this.filecontents[this.currentLineNo]
      this.currentLineNo = this.currentLineNo + 1
    else
      line = ''
    end
  end
  return line
end

--! \brief save line fragment
function TStream_Read.ungetLine(this,LineFrag)
  this.currentLine = LineFrag
end

--! \brief is it eof?
function TStream_Read.eof(this)
  if this.currentLine or this.currentLineNo<=this.contentsLen then
    return false
  end
  return true
end

--! \brief output stream
TStream_Write = class()

--! \brief constructor
function TStream_Write.init(this)
  this.tailLine = {}
end

--! \brief write immediately
function TStream_Write.write(this,Str)
  TCore_IO_write(Str)
end

--! \brief write immediately
function TStream_Write.writeln(this,Str)
  TCore_IO_writeln(Str)
end

--! \brief write immediately
function TStream_Write.writelnComment(this,Str)
  TCore_IO_write('// ZZ: ')
  TCore_IO_writeln(Str)
end

--! \brief write to tail
function TStream_Write.writelnTail(this,Line)
  if not Line then
    Line = ''
  end
  table.insert(this.tailLine,Line)
end

--! \brief outout tail lines
function TStream_Write.write_tailLines(this)
  for k,line in ipairs(this.tailLine) do
    TCore_IO_writeln(line)
  end
  TCore_IO_write('// Lua2DoX new eof')
end

--! \brief input filter
TLua2DoX_filter = class()

--! \brief allow us to do errormessages
function TLua2DoX_filter.warning(this,Line,LineNo,Legend)
  this.outStream:writelnTail(
  '//! \todo warning! ' .. Legend .. ' (@' .. LineNo .. ')"' .. Line .. '"'
  )
end

--! \brief trim comment off end of string
--!
--! If the string has a comment on the end, this trims it off.
--!
local function TString_removeCommentFromLine(Line)
  local pos_comment = string.find(Line,'%-%-')
  local tailComment
  if pos_comment then
    Line = string.sub(Line,1,pos_comment-1)
    tailComment = string.sub(Line,pos_comment)
  end
  return Line,tailComment
end

--! \brief get directive from magic
local function getMagicDirective(Line)
  local macro,tail
  local macroStr = '[\\@]'
  local pos_macro = string.find(Line,macroStr)
  if pos_macro then
    --! ....\\ macro...stuff
    --! ....\@ macro...stuff
    local line = string.sub(Line,pos_macro+1)
    local space = string.find(line,'%s+')
    if space then
      macro = string.sub(line,1,space-1)
      tail  = string_trim(string.sub(line,space+1))
    else
      macro = line
      tail  = ''
    end
  end
  return macro,tail
end

--! \brief check comment for fn
local function checkComment4fn(Fn_magic,MagicLines)
  local fn_magic = Fn_magic
  --	TCore_IO_writeln('// checkComment4fn "' .. MagicLines .. '"')

  local magicLines = string_split(MagicLines,'\n')

  local macro,tail

  for k,line in ipairs(magicLines) do
    macro,tail = getMagicDirective(line)
    if macro == 'fn' then
      fn_magic = tail
      --	TCore_IO_writeln('// found fn "' .. fn_magic .. '"')
    else
      --TCore_IO_writeln('// not found fn "' .. line .. '"')
    end
  end

  return fn_magic
end
--! \brief run the filter
function TLua2DoX_filter.readfile(this,AppStamp,Filename)
  local err

  local inStream = TStream_Read()
  local outStream = TStream_Write()
  this.outStream = outStream -- save to this obj

  if (inStream:getContents(Filename)) then
    -- output the file
    local line
    local fn_magic -- function name/def from  magic comment

    outStream:writelnTail('// #######################')
    outStream:writelnTail('// app run:' .. AppStamp)
    outStream:writelnTail('// #######################')
    outStream:writelnTail()

    local state = ''
    while not (err or inStream:eof()) do
      line = string_trim(inStream:getLine())
      -- 			TCore_Debug_show_var('inStream',inStream)
      -- 			TCore_Debug_show_var('line',line )
      if string.sub(line,1,2)=='--' then -- it's a comment
        if string.sub(line,3,3)=='@' then -- it's a magic comment
          state = 'in_magic_comment'
          local magic = string.sub(line,4)
          outStream:writeln('/// @' .. magic)
          fn_magic = checkComment4fn(fn_magic,magic)
        elseif string.sub(line,3,3)=='-' then -- it's a nonmagic doc comment
          local comment = string.sub(line,4)
          outStream:writeln('/// '.. comment)
        elseif string.sub(line,3,4)=='[[' then -- it's a long comment
          line = string.sub(line,5) -- nibble head
          local comment = ''
          local closeSquare,hitend,thisComment
          while (not err) and (not hitend) and (not inStream:eof()) do
            closeSquare = string.find(line,']]')
            if not closeSquare then -- need to look on another line
              thisComment = line .. '\n'
              line = inStream:getLine()
            else
              thisComment = string.sub(line,1,closeSquare-1)
              hitend = true

              -- unget the tail of the line
              -- in most cases it's empty. This may make us less efficient but
              -- easier to program
              inStream:ungetLine(string_trim(string.sub(line,closeSquare+2)))
            end
            comment = comment .. thisComment
          end
          if string.sub(comment,1,1)=='@' then -- it's a long magic comment
            outStream:write('/*' .. comment .. '*/  ')
            fn_magic = checkComment4fn(fn_magic,comment)
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
      elseif string.find(line,'^function') or string.find(line,'^local%s+function') then
        state = 'in_function'  -- it's a function
        local pos_fn = string.find(line,'function')
        -- function
        -- ....v...
        if pos_fn then
          -- we've got a function
          local fn_type
          if string.find(line,'^local%s+') then
            fn_type = ''--'static ' -- static functions seem to be excluded
          else
            fn_type = ''
          end
          local fn = TString_removeCommentFromLine(string_trim(string.sub(line,pos_fn+8)))
          if fn_magic then
            fn = fn_magic
            fn_magic = nil
          end

          if string.sub(fn,1,1)=='(' then
            -- it's an anonymous function
            outStream:writelnComment(line)
          else
            -- fn has a name, so is interesting

            -- want to fix for iffy declarations
            local open_paren = string.find(fn,'[%({]')
            local fn0 = fn
            if open_paren then
              fn0 = string.sub(fn,1,open_paren-1)
              -- we might have a missing close paren
              if not string.find(fn,'%)') then
                fn = fn .. ' ___MissingCloseParenHere___)'
              end
            end

            local dot = string.find(fn0,'[%.:]')
            if dot then -- it's a method
              local klass = string.sub(fn,1,dot-1)
              local method = string.sub(fn,dot+1)
              --TCore_IO_writeln('function ' .. klass .. '::' .. method .. ftail .. '{}')
              --TCore_IO_writeln(klass .. '::' .. method .. ftail .. '{}')
              outStream:writeln(
              '/*! \\memberof ' .. klass .. ' */ '
              .. method .. '{}'
              )
            else
              -- add vanilla function

              outStream:writeln(fn_type .. 'function ' .. fn .. '{}')
            end
          end
        else
          this:warning(inStream:getLineNo(),'something weird here')
        end
        fn_magic = nil -- mustn't indavertently use it again
      elseif string.find(line,'=%s*class%(') then
        state = 'in_class'  -- it's a class declaration
        local tailComment
        line,tailComment = TString_removeCommentFromLine(line)
        local equals = string.find(line,'=')
        local klass = string_trim(string.sub(line,1,equals-1))
        local tail =  string_trim(string.sub(line,equals+1))
        -- class(wibble wibble)
        -- ....v.
        local parent = string.sub(tail,7,-2)
        if #parent>0 then
          parent = ' :public ' .. parent
        end
        outStream:writeln('class ' .. klass .. parent .. '{};')
      else
        state = ''  -- unknown
        if #line>0 then  -- we don't know what this line means, so just comment it out
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

--! \brief this application
TApp = class()

--! \brief constructor
function TApp.init(this)
  local t0 = TCore_Clock()
  this.timestamp = t0:getTimeStamp()
  this.name = 'Lua2DoX'
  this.version = '0.2 20130128'
  this.copyright = 'Copyright (c) Simon Dales 2012-13'
end

function TApp.getRunStamp(this)
  return this.name .. ' (' .. this.version .. ') ' 
  .. this.timestamp
end

function TApp.getVersion(this)
  return this.name .. ' (' .. this.version .. ') ' 
end

function TApp.getCopyright(this)
  return this.copyright 
end

local This_app = TApp()

--main
local cl = TCore_Commandline()

local argv1 = cl:getRaw(2)
if argv1 == '--help' then
  TCore_IO_writeln(This_app:getVersion())
  TCore_IO_writeln(This_app:getCopyright())
  TCore_IO_writeln([[
  run as:
  lua2dox_filter <param>
  --------------
  Param:
  <filename> : interprets filename
  --version  : show version/copyright info
  --help     : this help text]])
elseif argv1 == '--version' then
  TCore_IO_writeln(This_app:getVersion())
  TCore_IO_writeln(This_app:getCopyright())
else
  -- it's a filter
  local appStamp = This_app:getRunStamp()
  local filename = argv1

  local filter = TLua2DoX_filter()
  filter:readfile(appStamp,filename)
end


--eof
