-- Nvim: load the matchit plugin by default.
if vim.g.loaded_matchit == nil and vim.o.packpath:find(vim.env.VIMRUNTIME, 1, true) then
  vim.cmd.packadd('matchit')
end
