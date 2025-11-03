" Vim filetype plugin
" Language:         SysML
" Author:           Daumantas Kavolis <daumantas.kavolis@sensmetry.com>
" Last Change:      2025-10-03

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves mostly just like KerML, only differs by keywords
runtime! ftplugin/kerml.vim
