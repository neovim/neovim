if vim.g.did_load_filetypes then
  return
end
vim.g.did_load_filetypes = 1

vim.api.nvim_create_augroup('filetypedetect', { clear = false })

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile', 'StdinReadPost' }, {
  group = 'filetypedetect',
  callback = function(args)
    if not vim.api.nvim_buf_is_valid(args.buf) then
      return
    end
    local ft, on_detect = vim.filetype.match({ filename = args.match, buf = args.buf })
    if not ft then
      -- Generic configuration file used as fallback
      ft = require('vim.filetype.detect').conf(args.file, args.buf)
      if ft then
        vim.api.nvim_buf_call(args.buf, function()
          vim.api.nvim_cmd({ cmd = 'setf', args = { 'FALLBACK', ft } }, {})
        end)
      end
    else
      vim.api.nvim_buf_call(args.buf, function()
        vim.api.nvim_cmd({ cmd = 'setf', args = { ft } }, {})
      end)
      if on_detect then
        on_detect(args.buf)
      end
    end
  end,
})

-- These *must* be sourced after the autocommand above is created
if not vim.g.did_load_ftdetect then
  vim.cmd([[
  augroup filetypedetect
  runtime! ftdetect/*.vim
  runtime! ftdetect/*.lua
  augroup END
  ]])
end

-- Set up the autocmd for user scripts.vim
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = 'filetypedetect',
  command = "if !did_filetype() && expand('<amatch>') !~ g:ft_ignore_pat | runtime! scripts.vim | endif",
})

vim.api.nvim_create_autocmd('StdinReadPost', {
  group = 'filetypedetect',
  command = 'if !did_filetype() | runtime! scripts.vim | endif',
})

if not vim.g.ft_ignore_pat then
  vim.g.ft_ignore_pat = '\\.\\(Z\\|gz\\|bz2\\|zip\\|tgz\\)$'
end
