--  Updates version.c list of applied Vim patches.
--
--  Usage:
--    VIM_SOURCE_DIR=~/neovim/.vim-src/ nvim -i NONE -u NONE --headless +'luafile ./scripts/vimpatch.lua' +q

local nvim = vim.api

local function pprint(o)
  print(nvim.nvim_call_function('string', { o }))
end

local function systemlist(...)
  local rv = nvim.nvim_call_function('systemlist', ...)
  local err = nvim.nvim_get_vvar('shell_error')
  local args_str = nvim.nvim_call_function('string', ...)
  if 0 ~= err then
    error('command failed: '..args_str)
  end
  return rv
end

local function vimpatch_sh_list_numbers()
  return systemlist( { { 'bash', '-c', 'scripts/vim-patch.sh -M', } } )
end

-- Generates the lines to be inserted into the src/version.c
-- `included_patches[]` definition.
local function gen_version_c_lines()
  -- Set of merged Vim 8.0.zzzz patch numbers.
  local merged_patch_numbers = {}
  local highest = 0
  for _, n in ipairs(vimpatch_sh_list_numbers()) do
    if n then
      merged_patch_numbers[tonumber(n)] = true
      highest = math.max(highest, n)
    end
  end

  local lines = {}
  for i = highest, 0, -1 do
    local is_merged = (nil ~= merged_patch_numbers[i])
    if is_merged then
      table.insert(lines, string.format('  %s,', i))
    else
      table.insert(lines, string.format('  // %s,', i))
    end
  end

  return lines
end

local function patch_version_c()
  local lines = gen_version_c_lines()

  nvim.nvim_command('silent noswapfile noautocmd edit src/nvim/version.c')
  nvim.nvim_command('/static const int included_patches')
  -- Delete the existing lines.
  nvim.nvim_command('silent normal! j0d/};\rk')
  -- Insert the lines.
  nvim.nvim_call_function('append', {
      nvim.nvim_eval('line(".")'),
      lines,
    })
  nvim.nvim_command('silent write')
end

patch_version_c()
