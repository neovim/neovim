" Vim plugin for editing compressed files.
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2025 Jan 21
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Exit quickly when:
" - this plugin was already loaded
" - when 'compatible' is set
" - some autocommands are already taking care of compressed files
if exists("loaded_gzip") || &cp || exists("#BufReadPre#*.gz")
  finish
endif
let loaded_gzip = 1

augroup gzip
  " Remove all gzip autocommands
  au!

  " Enable editing of gzipped files.
  " The functions are defined in autoload/gzip.vim.
  "
  " Set binary mode before reading the file.
  " Use "gzip -d", gunzip isn't always available.
  autocmd BufReadPre,FileReadPre	*.gz,*.bz2,*.Z,*.lzma,*.xz,*.lz,*.zst,*.br,*.lzo,*.lz4 setlocal bin
  autocmd BufReadPost,FileReadPost	*.gz  call gzip#read("gzip -dn")
  autocmd BufReadPost,FileReadPost	*.bz2 call gzip#read("bzip2 -d")
  autocmd BufReadPost,FileReadPost	*.Z   call gzip#read("uncompress")
  autocmd BufReadPost,FileReadPost	*.lzma call gzip#read("lzma -d")
  autocmd BufReadPost,FileReadPost	*.xz  call gzip#read("xz -d")
  autocmd BufReadPost,FileReadPost	*.lz  call gzip#read("lzip -d")
  autocmd BufReadPost,FileReadPost	*.zst call gzip#read("zstd -d --rm")
  autocmd BufReadPost,FileReadPost	*.br call gzip#read("brotli -d --rm")
  autocmd BufReadPost,FileReadPost	*.lzo call gzip#read("lzop -d -U")
  autocmd BufReadPost,FileReadPost	*.lz4 call gzip#read("lz4 -d -q --rm")
  autocmd BufWritePost,FileWritePost	*.gz  call gzip#write("gzip")
  autocmd BufWritePost,FileWritePost	*.bz2 call gzip#write("bzip2")
  autocmd BufWritePost,FileWritePost	*.Z   call gzip#write("compress -f")
  autocmd BufWritePost,FileWritePost	*.lzma call gzip#write("lzma -z")
  autocmd BufWritePost,FileWritePost	*.xz  call gzip#write("xz -z")
  autocmd BufWritePost,FileWritePost	*.lz  call gzip#write("lzip")
  autocmd BufWritePost,FileWritePost	*.zst  call gzip#write("zstd --rm")
  autocmd BufWritePost,FileWritePost	*.br  call gzip#write("brotli --rm")
  autocmd BufWritePost,FileWritePost	*.lzo  call gzip#write("lzop -U")
  autocmd BufWritePost,FileWritePost	*.lz4  call gzip#write("lz4 -q --rm")
  autocmd FileAppendPre			*.gz  call gzip#appre("gzip -dn")
  autocmd FileAppendPre			*.bz2 call gzip#appre("bzip2 -d")
  autocmd FileAppendPre			*.Z   call gzip#appre("uncompress")
  autocmd FileAppendPre			*.lzma call gzip#appre("lzma -d")
  autocmd FileAppendPre			*.xz   call gzip#appre("xz -d")
  autocmd FileAppendPre			*.lz   call gzip#appre("lzip -d")
  autocmd FileAppendPre			*.zst call gzip#appre("zstd -d --rm")
  autocmd FileAppendPre			*.br call gzip#appre("brotli -d --rm")
  autocmd FileAppendPre			*.lzo call gzip#appre("lzop -d -U")
  autocmd FileAppendPre			*.lz4 call gzip#appre("lz4 -d -q --rm")
  autocmd FileAppendPost		*.gz  call gzip#write("gzip")
  autocmd FileAppendPost		*.bz2 call gzip#write("bzip2")
  autocmd FileAppendPost		*.Z   call gzip#write("compress -f")
  autocmd FileAppendPost		*.lzma call gzip#write("lzma -z")
  autocmd FileAppendPost		*.xz call gzip#write("xz -z")
  autocmd FileAppendPost		*.lz call gzip#write("lzip")
  autocmd FileAppendPost		*.zst call gzip#write("zstd --rm")
  autocmd FileAppendPost		*.br call gzip#write("brotli --rm")
  autocmd FileAppendPost		*.lzo call gzip#write("lzop -U")
  autocmd FileAppendPost		*.lz4 call gzip#write("lz4 --rm")
augroup END
