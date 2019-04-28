if exists("b:current_syntax")
    finish
endif

syn include @VIM syntax/vim.vim
unlet b:current_syntax
syn include @TUTORSHELL syntax/sh.vim
unlet b:current_syntax
syn include @VIMNORMAL syntax/vimnormal.vim

syn match tutorLink /\[.\{-}\](.\{-})/ contains=tutorInlineNormal
syn match tutorLinkBands /\[\|\]\|(\|)/ contained containedin=tutorLink,tutorLinkAnchor conceal
syn match tutorLinkAnchor /(.\{-})/ contained containedin=tutorLink conceal
syn match tutorURL /\(https\?\|file\):\/\/[[:graph:]]\+\>\/\?/
syn match tutorEmail /\<[[:graph:]]\+@[[:graph:]]\+\>/
syn match tutorInternalAnchor /\*[[:alnum:]-]\+\*/ contained conceal containedin=tutorSection

syn match tutorSection /^#\{1,6}\s.\+$/ fold contains=tutorInlineNormal
syn match tutorSectionBullet /#/ contained containedin=tutorSection

syn match tutorTOC /\ctable of contents:/

syn match tutorConcealedEscapes /\\[`*!\[\]():$-]\@=/ conceal

syn region tutorEmphasis matchgroup=Delimiter start=/[\*]\@<!\*\*\@!/ end=/[\*]\@<!\*\*\@!/
	    \ concealends contains=tutorInlineCommand,tutorInlineNormal
syn region tutorBold matchgroup=Delimiter start=/\*\{2}/ end=/\*\{2}/
	    \ concealends contains=tutorInlineCommand,tutorInlineNormal

syn keyword tutorMarks TODO NOTE IMPORTANT TIP ATTENTION EXERCISE
syn keyword tutorMarks todo note tip attention exercise
syn keyword tutorMarks Todo Note Tip Excersise

syn region tutorCodeblock matchgroup=Delimiter start=/^\~\{3}.*$/ end=/^\~\{3}/

syn region tutorShell matchgroup=Delimiter start=/^\~\{3} sh\s*$/ end=/^\~\{3}/ keepend contains=@TUTORSHELL
syn match tutorShellPrompt /\(^\s*\)\@<=[$#]/ contained containedin=tutorShell

syn region tutorInlineCode matchgroup=Delimiter start=/\\\@<!`/ end=/\\\@<!\(`{\@!\|`\s\)/

syn region tutorCommand matchgroup=Delimiter start=/^\~\{3} cmd\( :\)\?\s*$/ end=/^\~\{3}/ keepend contains=@VIM
syn region tutorInlineCommand matchgroup=Delimiter start=/\\\@<!`\(.*{vim}\)\@=/ end=/\\\@<!`\({vim}\)\@=/ nextgroup=tutorInlineType contains=@VIM

syn region tutorNormal matchgroup=Delimiter start=/^\~\{3} norm\(al\?\)\?\s*$/ end=/^\~\{3}/ contains=@VIMNORMAL
syn region tutorInlineNormal matchgroup=Delimiter start=/\\\@<!`\(\S*{normal}\)\@=/ end=/\\\@<!`\({normal}\)\@=/ nextgroup=tutorInlineType contains=@VIMNORMAL

syn match tutorInlineType /{\(normal\|vim\)}/ contained conceal

syn match tutorInlineOK /✓/
syn match tutorInlineX /✗/

hi def tutorLink cterm=underline gui=underline ctermfg=lightblue guifg=#0088ff
hi def link tutorLinkBands Delimiter
hi def link tutorLinkAnchor Underlined
hi def link tutorInternalAnchor Underlined
hi def link tutorURL tutorLink
hi def link tutorEmail tutorLink

hi def link tutorSection Title
hi def link tutorSectionBullet Delimiter

hi def link tutorTOC Directory

hi def tutorMarks cterm=bold gui=bold

hi def tutorEmphasis gui=italic cterm=italic
hi def tutorBold gui=bold cterm=bold

hi def link tutorExpect Special
hi def tutorOK ctermfg=green guifg=#00ff88 cterm=bold gui=bold
hi def tutorX ctermfg=red guifg=#ff2000  cterm=bold gui=bold
hi def link tutorInlineOK tutorOK
hi def link tutorInlineX tutorX

hi def link tutorShellPrompt Delimiter

let b:current_syntax = "tutor"
