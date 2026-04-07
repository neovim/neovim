local M = {}

local sep =
  '────────────────────────────────────────────'

local function intro_command(name, tail)
  return {
    { 'type  ' },
    { ':', 'SpecialKey' },
    { name, 'Identifier' },
    { '<Enter>', 'SpecialKey' },
    { tail },
  }
end

M.logo = {
  { { '│', 'Special' }, { ' ' }, { '╲', 'String' }, { ' ' }, { '││', 'String' } },
  { { '││', 'Special' }, { '╲╲││', 'String' } },
  { { '││', 'Special' }, { ' ' }, { '╲', 'String' }, { ' ' }, { '│', 'String' } },
}

M.display = function()
  ---@type vim.Version
  local v = vim.version()

  return vim.list_extend(vim.deepcopy(M.logo), {
    {},
    { { ('NVIM %s'):format(tostring(v)), 'String' } },
    { { sep, 'NonText' } },
    { { 'Nvim is open source and freely distributable' } },
    { { 'https://neovim.io/#chat' } },
    { { sep, 'NonText' } },
    intro_command('help nvim', '     if you are new! '),
    intro_command('checkhealth', '   to optimize Nvim'),
    intro_command('q', '             to exit         '),
    intro_command('help', '          for help        '),
    { { sep, 'NonText' } },
    intro_command('help news', ('     for v%s.%s notes '):format(v.major, v.minor)),
    { { sep, 'NonText' } },
    { { 'Help poor children in Uganda!' } },
    intro_command('help Kuwasha', '  for information '),
  })
end

return M
