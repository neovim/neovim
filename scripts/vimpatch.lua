--  Updates version.c list of applied Vim patches.
--
--  Usage:
--    VIM_SOURCE_DIR=~/neovim/.vim-src/ nvim -l ./scripts/vimpatch.lua

local nvim = vim.api

local function systemlist(...)
  local rv = nvim.nvim_call_function('systemlist', ...)
  local err = nvim.nvim_get_vvar('shell_error')
  local args_str = nvim.nvim_call_function('string', ...)
  if 0 ~= err then
    error('command failed: ' .. args_str)
  end
  return rv
end

local function vimpatch_sh_list_tokens()
  return systemlist({ { 'bash', '-c', 'scripts/vim-patch.sh -M' } })
end

-- Generates the lines to be inserted into the src/nvim/version.c
-- to populate the following:
-- - `vim_versions[]`
-- - `num_patches[]`
-- - `included_patchsets[]`
local function gen_version_c_lines()
  -- Sets of merged Vim x.y.zzzz patch numbers.
  local merged_patch_sets = {}
  for _, token in ipairs(vimpatch_sh_list_tokens()) do
    local major_version, minor_version, patch_num = string.match(token, '^(%d+).(%d+).(%d+)$')
    local n = tonumber(patch_num)
    -- TODO(@janlazo): Allow multiple Vim versions
    if n then
      local major_minor_version = major_version * 100 + minor_version
      merged_patch_sets[major_minor_version] = merged_patch_sets[major_minor_version] or {}
      table.insert(merged_patch_sets[major_minor_version], n)
    end
  end

  local version_lines = {}
  local num_lines = {}
  local patch_lines = {}
  for major_minor_version, patch_set in vim.spairs(merged_patch_sets) do
    table.insert(version_lines, string.format('  %d,', major_minor_version))
    table.insert(num_lines, string.format('  %d,', #patch_set))
    table.insert(patch_lines, string.format('  (const int[]) {  // %d', major_minor_version))
    for i = #patch_set, 1, -1 do
      local patch = patch_set[i]
      table.insert(patch_lines, string.format('    %s,', patch))
      if patch > 0 then
        local oldest_unmerged_patch = patch_set[i - 1] and (patch_set[i - 1] + 1) or 0
        for unmerged_patch = patch - 1, oldest_unmerged_patch, -1 do
          table.insert(patch_lines, string.format('    // %s,', unmerged_patch))
        end
      end
    end
    table.insert(patch_lines, '  },')
  end

  return version_lines, num_lines, patch_lines
end

local function patch_version_c()
  local version_lines, num_lines, patch_lines = gen_version_c_lines()

  nvim.nvim_command('silent noswapfile noautocmd edit src/nvim/version.c')
  nvim.nvim_command([[/static const int vim_versions]])
  -- Delete the existing lines.
  nvim.nvim_command('silent normal! j0d/};\rk')
  -- Insert the lines.
  nvim.nvim_call_function('append', {
    nvim.nvim_eval('line(".")'),
    version_lines,
  })
  nvim.nvim_command([[/static const int num_patches]])
  -- Delete the existing lines.
  nvim.nvim_command('silent normal! j0d/};\rk')
  -- Insert the lines.
  nvim.nvim_call_function('append', {
    nvim.nvim_eval('line(".")'),
    num_lines,
  })
  nvim.nvim_command([[/static const int \*included_patchsets]])
  -- Delete the existing lines.
  nvim.nvim_command('silent normal! j0d/};\rk')
  -- Insert the lines.
  nvim.nvim_call_function('append', {
    nvim.nvim_eval('line(".")'),
    patch_lines,
  })
  nvim.nvim_command('silent write')
end

patch_version_c()
