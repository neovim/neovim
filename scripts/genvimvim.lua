mpack = require('mpack')

if arg[1] == '--help' then
  print('Usage: lua genvimvim.lua src/nvim runtime/syntax/vim/generated.vim')
  os.exit(0)
end

local nvimsrcdir = arg[1]
local syntax_file = arg[2]
local funcs_file = arg[3]

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local lld = {}
local syn_fd = io.open(syntax_file, 'w')
lld.line_length = 0
local w = function(s)
  syn_fd:write(s)
  if s:find('\n') then
    lld.line_length = #(s:gsub('.*\n', ''))
  else
    lld.line_length = lld.line_length + #s
  end
end

local options = require('options')
local auevents = require('auevents')
local ex_cmds = require('ex_cmds')

local cmd_kw = function(prev_cmd, cmd)
  if not prev_cmd then
    return cmd:sub(1, 1) .. '[' .. cmd:sub(2) .. ']'
  else
    local shift = 1
    while cmd:sub(shift, shift) == prev_cmd:sub(shift, shift) do
      shift = shift + 1
    end
    if shift >= #cmd then
      return cmd
    else
      return cmd:sub(1, shift) .. '[' .. cmd:sub(shift + 1) .. ']'
    end
  end
end

vimcmd_start = 'syn keyword vimCommand contained '
w(vimcmd_start)
local prev_cmd = nil
for _, cmd_desc in ipairs(ex_cmds) do
  if lld.line_length > 850 then
    w('\n' .. vimcmd_start)
  end
  local cmd = cmd_desc.command
  if cmd:match('%w') and cmd ~= 'z' then
    w(' ' .. cmd_kw(prev_cmd, cmd))
  end
  prev_cmd = cmd
end

local vimopt_start = 'syn keyword vimOption contained '
w('\n\n' .. vimopt_start)

for _, opt_desc in ipairs(options.options) do
  if not opt_desc.varname or opt_desc.varname:sub(1, 7) ~= 'p_force' then
    if lld.line_length > 850 then
      w('\n' .. vimopt_start)
    end
    w(' ' .. opt_desc.full_name)
    if opt_desc.abbreviation then
      w(' ' .. opt_desc.abbreviation)
    end
    if opt_desc.type == 'bool' then
      w(' inv' .. opt_desc.full_name)
      w(' no' .. opt_desc.full_name)
      if opt_desc.abbreviation then
        w(' inv' .. opt_desc.abbreviation)
        w(' no' .. opt_desc.abbreviation)
      end
    end
  end
end

w('\n\nsyn case ignore')
local vimau_start = 'syn keyword vimAutoEvent contained '
w('\n\n' .. vimau_start)

for _, au in ipairs(auevents.events) do
  if not auevents.nvim_specific[au] then
    if lld.line_length > 850 then
      w('\n' .. vimau_start)
    end
    w(' ' .. au)
  end
end
for au, _ in pairs(auevents.aliases) do
  if not auevents.nvim_specific[au] then
    if lld.line_length > 850 then
      w('\n' .. vimau_start)
    end
    w(' ' .. au)
  end
end

local nvimau_start = 'syn keyword nvimAutoEvent contained '
w('\n\n' .. nvimau_start)

for au, _ in pairs(auevents.nvim_specific) do
  if lld.line_length > 850 then
    w('\n' .. nvimau_start)
  end
  w(' ' .. au)
end

w('\n\nsyn case match')
local vimfun_start = 'syn keyword vimFuncName contained '
w('\n\n' .. vimfun_start)
funcs = mpack.unpack(io.open(funcs_file):read("*all"))
local started = 0
for name, def in pairs(funcs) do
  if name then
    if lld.line_length > 850 then
      w('\n' .. vimfun_start)
    end
    w(' ' .. name)
  end
end

w('\n')
syn_fd:close()
