" Language: Quarto (Markdown with chunks of R, Python and other languages)
" Provisory Maintainer: Jakson Aquino <jalvesaq@gmail.com>
" Homepage: https://github.com/jalvesaq/R-Vim-runtime
" Last Change: Fri Feb 24, 2023  08:26AM
"
" The developers of tools for Quarto maintain Vim runtime files in their
" Github repository and, if required, I will hand over the maintenance of
" this script for them.

runtime syntax/rmd.vim

syn match quartoShortarg /\S\+/ contained
syn keyword quartoShortkey var meta env pagebreak video include contained
syn region quartoShortcode matchgroup=PreProc start='{{< ' end=' >}}' contains=quartoShortkey,quartoShortarg transparent keepend

hi def link quartoShortkey Include
hi def link quartoShortarg String
