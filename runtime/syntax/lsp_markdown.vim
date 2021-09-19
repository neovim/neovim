" Vim syntax file
" Language:	lsp_markdown
" Maintainer:	Michael Lingelbach <m.j.lbach@gmail.com
" URL:		http://neovim.io
" Remark:	Uses markdown syntax file

" always source the system included markdown instead of any other installed
" markdown.vim syntax files
execute 'source' expand('<sfile>:p:h') .. '/markdown.vim'

syn cluster mkdNonListItem add=mkdEscape,mkdNbsp

syn clear markdownEscape
syntax region markdownEscape matchgroup=markdownEscape start=/\\\ze[\\\x60*{}\[\]()#+\-,.!_>~|"$%&'\/:;<=?@^ ]/ end=/./ containedin=ALL keepend oneline concealends

" conceal html entities
syntax match mkdNbsp /&nbsp;/ conceal cchar= 
syntax match mkdLt /&lt;/  conceal cchar=<
syntax match mkdGt /&gt;/  conceal cchar=>
syntax match mkdAmp /&amp;/  conceal cchar=&
syntax match mkdQuot /&quot;/  conceal cchar="

hi def link mkdEscape special
