-- A script to generate vimdoc |ex-cmd-index| in runtime/doc/index.txt
-- This script will print the generated index into stdout.
-- See scripts/gen_vimdoc.py.

---@type vim.ExCmd[]
local ex_cmds = require('src/nvim/ex_cmds').cmds
ex_cmds = vim.tbl_filter(function(ex_cmd)
  return not ex_cmd.removed
  -- return ex_cmd.short_command ~= nil
end, ex_cmds) --[[ @as vim.ExCmd[] ]]

-- see #27084
local print = function(...)
  io.stdout:write(...)
end

local START_OFFSET = 32
local TEXT_WIDTH = 78

local function word_wrap(text, text_width, indent)
  local lines = {}
  local line = ''
  local start_offset = indent

  local indent_if_necssary = function(l)
    assert(START_OFFSET % 8 == 0) -- tabsize must be 8
    return (#lines > 0 and string.rep('\t', START_OFFSET / 8) or '') .. l
  end

  ---@diagnostic disable-next-line: no-unknown
  for word in text:gmatch('%S+') do
    ---@cast word string
    if #line + #word + 1 + start_offset > text_width then
      table.insert(lines, indent_if_necssary(line))
      start_offset = 0
      line = word
    else
      if #line > 0 then
        line = line .. ' ' .. word
      else
        line = word
      end
    end
  end

  table.insert(lines, indent_if_necssary(line))
  return table.concat(lines, '\n')
end

local HEADER = [[
==============================================================================
6. EX commands				*Ex-commands* *ex-cmd-index* *:index*

This is a brief but complete listing of all the ":" commands, without
mentioning any arguments.  The optional part of the command name is inside [].
The commands are sorted on the non-optional part of their name.

Note: the following list of |Ex-commands| is auto-generated.

tag		command		action ~
------------------------------------------------------------------------------ ~
|:|		:		nothing
|:range|	:{range}	go to last line in {range}
]]

print(HEADER)

-- manually add a few exceptions that are not included in the ex_cmds list.
vim.list_extend(ex_cmds, {
  { command = '!!', short_command = '!!', desc = [[repeat last ":!" command]] },
  { command = 'star', short_command = '*', desc = [[use the last Visual area, like :'<,'>]] },
  { command = '@@', short_command = '@@', desc = [[repeat the previous ":@"]] },
  { command = 'dl', short_command = 'dl', desc = [[short for |:delete| with the 'l' flag]] },
  { command = 'dp', short_command = 'd[elete]p', desc = [[short for |:delete| with the 'p' flag]] },
})

-- sort by short command name
table.sort(ex_cmds, function(lhs, rhs)
  return lhs.short_command < rhs.short_command
end)

for _, excmd in ipairs(ex_cmds) do
  local tag = '|:' .. excmd.command .. '|'
  local command = ':' .. excmd.short_command

  -- mostly, short_command is a prefix of command, e.g. :e[dit]
  -- but there are only one exception with non-prefix short commands: :d[elete]p
  if vim.tbl_contains({ 'dp', 'star' }, excmd.command) then
    -- pass; use the hard-coded short_command
    assert(excmd.short_command)
  elseif excmd.short_command ~= excmd.command then
    assert(vim.startswith(excmd.command, excmd.short_command), vim.inspect(excmd))
    command = command .. '[' .. string.sub(excmd.command, #excmd.short_command + 1) .. ']'
  end

  local action = excmd.desc

  local function tab_separator(x)
    return (#x >= 16 and string.rep(' ', 18 - #x) or #x >= 8 and '\t' or #x >= 0 and '\t\t')
  end

  print(
    tag,
    tab_separator(tag),
    command,
    tab_separator(command),
    word_wrap(action, TEXT_WIDTH, START_OFFSET),
    '\n'
  )
end
