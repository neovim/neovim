" Language: Quarto (Markdown with chunks of R, Python and other languages)
" Maintainer: This runtime file is looking for a new maintainer.
" Former Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>
" Former Repository: https://github.com/jalvesaq/R-Vim-runtime
" Last Change: 2023 Feb 24  08:26AM
"		2024 Feb 19 by Vim Project (announce adoption)
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
