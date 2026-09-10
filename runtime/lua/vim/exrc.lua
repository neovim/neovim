local M = {}

--- Executes the project-local ('exrc') configuration files ".nvim.lua",
--- ".nvimrc", and ".exrc" found in the |current-directory| and all parent
--- directories (ordered upwards), if they are in the |trust| list.
---
--- This is the same loading which Nvim performs at the end of startup if
--- 'exrc' is enabled, but it can be called at any point of |init.lua| to load
--- the exrc files early, so that they can influence the rest of the user
--- config:
---
--- ```lua
--- -- init.lua
--- vim.o.exrc = true
--- vim.exrc.load()
--- -- exrc files have run at this point, e.g. variables set by them can be
--- -- used to configure the rest of init.lua:
--- if vim.g.use_lsp then
---   -- ... setup LSP ...
--- end
--- ```
---
--- Notes:
--- - Exrc files are loaded at most once per session. If they were already
---   loaded (by a previous call, or by the automatic load at the end of
---   startup), this function does nothing.
--- - As with the automatic load, sourcing stops early if 'exrc' is disabled
---   (by the user, or by one of the sourced exrc files).
---
--- @since 15
function M.load()
  require('vim._core.exrc').load()
end

return M
