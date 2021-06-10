" Vim syntax file
" Language:	lsp_markdown
" Maintainer:	Michael Lingelbach <m.j.lbach@gmail.com
" URL:		http://neovim.io
" Remark:	Uses markdown syntax file

" always source the system included markdown instead of any other installed
" markdown.vim syntax files
execute 'source' expand('<sfile>:p:h') .. '/markdown.vim'

syn cluster mkdNonListItem add=mkdEscape,mkdNbsp

syntax region mkdEscape matchgroup=mkdEscape start=/\\\ze[\\\x60*{}\[\]()#+\-,.!_>~|"$%&'\/:;<=?@^ ]/ end=/.\zs/ keepend contains=mkdEscapeCh oneline concealends
syntax match mkdEscapeCh /./ contained
syntax match mkdNbsp /&nbsp;/ conceal cchar= 

hi def link mkdEscape special
