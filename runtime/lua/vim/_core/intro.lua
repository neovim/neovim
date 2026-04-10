local M = {}

--- @brief
---
--- Defines the intro screen content shown in the default startup buffer when
--- Neovim opens without a file.
---
--- To customize the intro screen, override `display()` in your config. This is
--- an ordinary Lua function, so it can return static content or build the
--- screen from dynamic state such as `vim.version()`.
---
--- The return value is a list of lines. Each line is given by a list of
--- `[text, hl_group]` "chunks", like |nvim_echo()|. `hl_group` is a
--- |highlight-groups| name.
---
--- Minimal example:
--- ```lua
--- require('vim._core.intro').display = function()
---   return {
---     { { 'Minimal intro override', 'String' } },
---     {},
---     {
---       { 'type  ' },
---       { ':', 'SpecialKey' },
---       { 'q', 'Identifier' },
---       { '<Enter>', 'SpecialKey' },
---       { ' to quit' },
---     },
---   }
--- end
--- ```
---
--- `logo` contains the built-in logo lines used by the default implementation,
--- so an override can reuse the default logo and only replace the rest of the
--- screen:
--- ```lua
--- local intro = require('vim._core.intro')
---
--- intro.display = function()
---   local v = vim.version()
---   return vim.list_extend(vim.deepcopy(intro.logo), {
---     {},
---     { { ('NVIM %s'):format(tostring(v)), 'String' } },
---     { { 'type  :help nvim', 'Identifier' } },
---   })
--- end
--- ```
---
--- See also |nvim_echo()| for chunk formatting, |nvim_set_hl()| and
--- |highlight-groups| for custom highlights, and |vim.version()| if the intro
--- depends on the current Nvim version.
---
---[intro-events]()
---
---The intro lifecycle is defined by these events:
---- [IntroLeave]() - Triggers when the intro screen is dismissed

---@alias vim._core.intro.Chunk [string, string?]
---@alias vim._core.intro.Line vim._core.intro.Chunk[]

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

---@type vim._core.intro.Line[]
M.logo = {
  { { '│', 'Special' }, { ' ' }, { '╲', 'String' }, { ' ' }, { '││', 'String' } },
  { { '││', 'Special' }, { '╲╲││', 'String' } },
  { { '││', 'Special' }, { ' ' }, { '╲', 'String' }, { ' ' }, { '│', 'String' } },
}

---@return vim._core.intro.Line[]
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

function M.dismiss()
  vim.api.nvim__dismiss_intro()
  vim.api.nvim__redraw({ valid = false, flush = true })
end

return M
