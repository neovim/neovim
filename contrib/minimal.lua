-- Run this file as `nvim --clean -u minimal.lua`

for name, url in pairs {
  -- ADD PLUGINS _NECESSARY_ TO REPRODUCE THE ISSUE, e.g:
  -- 'https://github.com/author1/plugin1',
  -- 'https://github.com/author2/plugin2',
} do
  local install_path = vim.fn.fnamemodify('nvim_issue/' .. name, ':p')
  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system { 'git', 'clone', '--depth=1', url, install_path }
  end
  vim.opt.runtimepath:append(install_path)
end

-- ADD INIT.LUA SETTINGS _NECESSARY_ FOR REPRODUCING THE ISSUE
