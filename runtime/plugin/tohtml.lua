if vim.g.loaded_2html_plugin ~= nil then
  return
end
vim.g.loaded_2html_plugin = true

vim.api.nvim_create_user_command('TOhtml', function(args)
  local outfile = args.args ~= '' and args.args or vim.fn.tempname() .. '.html'
  local html = require('tohtml').tohtml(0, { range = { args.line1, args.line2 } })
  vim.fn.writefile(html, outfile)
  vim.cmd.split(outfile)
  vim.bo.filetype = 'html'
end, { bar = true, nargs = '?', range = '%' })
