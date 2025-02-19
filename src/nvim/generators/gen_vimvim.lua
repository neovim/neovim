local mpack = vim.mpack

local syntax_file = arg[1]
local funcs_file = arg[2]

local lld = {}
local syn_fd = io.open(syntax_file, 'w')
lld.line_length = 0
local function w(s)
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

local function cmd_kw(prev_cmd, cmd)
  if not prev_cmd then
    return cmd:sub(1, 1) .. '[' .. cmd:sub(2) .. ']'
  else
    local shift = 1
    while cmd:sub(shift, shift) == prev_cmd:sub(shift, shift) do
      shift = shift + 1
    end
    if cmd:sub(1, shift) == 'def' then
      shift = shift + 1
    end
    if shift >= #cmd then
      return cmd
    else
      return cmd:sub(1, shift) .. '[' .. cmd:sub(shift + 1) .. ']'
    end
  end
end

-- Exclude these from the vimCommand keyword list, they are handled specially
-- in syntax/vim.vim (vimAugroupKey, vimAutoCmd, vimGlobal, vimSubst). #9327
local function is_special_cased_cmd(cmd)
  return (
    cmd == 'augroup'
    or cmd == 'autocmd'
    or cmd == 'doautocmd'
    or cmd == 'doautoall'
    or cmd == 'global'
    or cmd == 'substitute'
  )
end

local vimcmd_start = 'syn keyword vimCommand contained '
local vimcmd_end = ' nextgroup=vimBang'
w(vimcmd_start)

local prev_cmd = nil
for _, cmd_desc in ipairs(ex_cmds.cmds) do
  if lld.line_length > 850 then
    w(vimcmd_end .. '\n' .. vimcmd_start)
  end
  local cmd = cmd_desc.command
  if cmd:match('%w') and cmd ~= 'z' and not is_special_cased_cmd(cmd) then
    w(' ' .. cmd_kw(prev_cmd, cmd))
  end
  if cmd == 'delete' then
    -- Add special abbreviations of :delete
    w(' ' .. cmd_kw('d', 'dl'))
    w(' ' .. cmd_kw('del', 'dell'))
    w(' ' .. cmd_kw('dele', 'delel'))
    w(' ' .. cmd_kw('delet', 'deletl'))
    w(' ' .. cmd_kw('delete', 'deletel'))
    w(' ' .. cmd_kw('d', 'dp'))
    w(' ' .. cmd_kw('de', 'dep'))
    w(' ' .. cmd_kw('del', 'delp'))
    w(' ' .. cmd_kw('dele', 'delep'))
    w(' ' .. cmd_kw('delet', 'deletp'))
    w(' ' .. cmd_kw('delete', 'deletep'))
  end
  prev_cmd = cmd
end

w(vimcmd_end .. '\n')

local vimopt_start = 'syn keyword vimOption contained '
local vimopt_end = ' skipwhite nextgroup=vimSetEqual,vimSetMod'
w('\n' .. vimopt_start)

for _, opt_desc in ipairs(options.options) do
  if not opt_desc.immutable then
    if lld.line_length > 850 then
      w(vimopt_end .. '\n' .. vimopt_start)
    end
    w(' ' .. opt_desc.full_name)
    if opt_desc.abbreviation then
      w(' ' .. opt_desc.abbreviation)
    end
    if opt_desc.type == 'boolean' then
      w(' inv' .. opt_desc.full_name)
      w(' no' .. opt_desc.full_name)
      if opt_desc.abbreviation then
        w(' inv' .. opt_desc.abbreviation)
        w(' no' .. opt_desc.abbreviation)
      end
    end
  end
end

w(vimopt_end .. '\n')

w('\nsyn case ignore')
local vimau_start = 'syn keyword vimAutoEvent contained '
w('\n\n' .. vimau_start)

for _, au in ipairs(auevents.events) do
  if not auevents.nvim_specific[au[1]] then
    if lld.line_length > 850 then
      w('\n' .. vimau_start)
    end
    w(' ' .. au[1])
    for _, alias in ipairs(au[2]) do
      if lld.line_length > 850 then
        w('\n' .. vimau_start)
      end
      -- au[1] is aliased to alias
      w(' ' .. alias)
    end
  end
end

local nvimau_start = 'syn keyword nvimAutoEvent contained '
w('\n\n' .. nvimau_start)

for au, _ in vim.spairs(auevents.nvim_specific) do
  if lld.line_length > 850 then
    w('\n' .. nvimau_start)
  end
  w(' ' .. au)
end

w('\n\nsyn case match')
local vimfun_start = 'syn keyword vimFuncName contained '
w('\n\n' .. vimfun_start)
local funcs = mpack.decode(io.open(funcs_file, 'rb'):read('*all'))
for _, name in ipairs(funcs) do
  if name then
    if lld.line_length > 850 then
      w('\n' .. vimfun_start)
    end
    w(' ' .. name)
  end
end

w('\n')
syn_fd:close()
