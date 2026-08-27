-- File-watcher backing for the 'autoread' option.
-- Lives here (not in vim/_core/defaults.lua) so that `-u NONE` / `--noplugin`
-- skip it: the BufReadPost/BufWritePost autocmds it registers would otherwise
-- show up in every test that inspects the autocmd list. Matches the pattern
-- used by runtime/plugin/matchparen.lua.

if vim.g.loaded_autoread ~= nil then
  return
end
vim.g.loaded_autoread = 1

require('nvim.autoread').enable()
