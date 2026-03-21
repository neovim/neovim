--- Hide file name and line number for filetype outline (TOC)
local w = vim.w
local qf_toc_title_regex = vim.regex [[\<TOC$\|\<Table of contents\>]]
if w.qf_toc or (w.quickfix_title and qf_toc_title_regex:match_str(w.quickfix_title)) then
  vim.wo.conceallevel = 3
  vim.wo.concealcursor = 'nc'
  vim.cmd [[syn match Ignore "^[^|]*|[^|]*| " conceal]]
end
