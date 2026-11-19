--- @param dark boolean
--- @return table<string, vim.api.keyset.highlight>
local function groups(dark)
  return {
    ['@diff.plus.diff'] = {
      fg = dark and 'NvimLightGreen' or 'NvimDarkGreen',
      bg = dark and 'NvimDarkGreen' or 'NvimLightGreen',
      ctermfg = dark and 10 or 2,
    },
    ['@diff.minus.diff'] = {
      fg = dark and 'NvimLightRed' or 'NvimDarkRed',
      bg = dark and 'NvimDarkRed' or 'NvimLightRed',
      ctermfg = dark and 9 or 1,
    },
  }
end

local function define()
  for name, spec in pairs(groups(vim.o.background == 'dark')) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend('force', spec, { default = true }))
  end
end

--- @param name string
--- @param spec vim.api.keyset.highlight
local function has_spec(name, spec)
  local hl = vim.api.nvim_get_hl(0, { name = name, create = false })
  return hl.fg == vim.api.nvim_get_color_by_name(spec.fg --[[@as string]])
    and hl.bg == vim.api.nvim_get_color_by_name(spec.bg --[[@as string]])
    and hl.ctermfg == spec.ctermfg
end

define()

local augroup = vim.api.nvim_create_augroup('nvim.diffhl', {})
-- Colorschemes run `:hi clear`, which removes these groups. Define them again.
vim.api.nvim_create_autocmd('ColorScheme', { group = augroup, callback = define })
-- Without a colorscheme, a 'background' change does not update these groups. Switch them to
-- the colors for the new 'background', unless the user changed them.
vim.api.nvim_create_autocmd('OptionSet', {
  group = augroup,
  pattern = 'background',
  callback = function()
    local new = groups(vim.v.option_new == 'dark')
    for name, old in pairs(groups(vim.v.option_old == 'dark')) do
      if has_spec(name, old) then
        vim.api.nvim_set_hl(0, name, new[name])
      end
    end
  end,
})
