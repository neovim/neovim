" Vim syntax file
" Language:     Markdown-like LSP docstrings
" Maintainer:   https://github.com/neovim/neovim
" URL:          http://neovim.io
" Remark:       Uses markdown syntax file

" Source the default Nvim markdown syntax, not other random ones.
execute 'source' expand('<sfile>:p:h') .. '/markdown.vim'

syn cluster mkdNonListItem add=mkdEscape,mkdNbsp

" Don't highlight invalid markdown syntax in LSP docstrings.
syn clear markdownError

syn clear markdownEscape
syntax region markdownEscape matchgroup=markdownEscape start=/\\\ze[\\\x60*{}\[\]()#+\-,.!_>~|"$%&'\/:;<=?@^ ]/ end=/./ containedin=ALL keepend oneline concealends

" Conceal backticks (which delimit code fragments).
" We ignore g:markdown_syntax_conceal here.
syn region markdownCode matchgroup=markdownCodeDelimiter start="`" end="`" keepend contains=markdownLineStart concealends
syn region markdownCode matchgroup=markdownCodeDelimiter start="`` \=" end=" \=``" keepend contains=markdownLineStart concealends
syn region markdownCode matchgroup=markdownCodeDelimiter start="^\s*````*.*$" end="^\s*````*\ze\s*$" keepend concealends

" Highlight code fragments.
hi def link markdownCode Special

" Conceal HTML entities.
syntax match mkdNbsp /&nbsp;/ conceal cchar= 
syntax match mkdLt /&lt;/  conceal cchar=<
syntax match mkdGt /&gt;/  conceal cchar=>
syntax match mkdAmp /&amp;/  conceal cchar=&
syntax match mkdQuot /&quot;/  conceal cchar="

hi def link mkdEscape Special
