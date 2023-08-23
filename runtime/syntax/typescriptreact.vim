" Vim syntax file
" Language:     TypeScript with React (JSX)
" Maintainer:   The Vim Project <https://github.com/vim/vim>
" Last Change:  2023 Aug 13
" Based On:     Herrington Darkholme's yats.vim
" Changes:      See https://github.com/HerringtonDarkholme/yats.vim
" Credits:      See yats.vim on github

if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'typescriptreact'
endif

let s:cpo_save = &cpo
set cpo&vim

syntax region tsxTag
      \ start=+<\([^/!?<>="':]\+\)\@=+
      \ skip=+</[^ /!?<>"']\+>+
      \ end=+/\@<!>+
      \ end=+\(/>\)\@=+
      \ contained
      \ contains=tsxTagName,tsxIntrinsicTagName,tsxAttrib,tsxEscJs,
                \tsxCloseString,@tsxComment

syntax match tsxTag /<>/ contained


" <tag></tag>
" s~~~~~~~~~e
" and self close tag
" <tag/>
" s~~~~e
" A big start regexp borrowed from https://git.io/vDyxc
syntax region tsxRegion
      \ start=+<\_s*\z([a-zA-Z1-9\$_-]\+\(\.\k\+\)*\)+
      \ skip=+<!--\_.\{-}-->+
      \ end=+</\_s*\z1>+
      \ matchgroup=tsxCloseString end=+/>+
      \ fold
      \ contains=tsxRegion,tsxCloseString,tsxCloseTag,tsxTag,tsxCommentInvalid,tsxFragment,tsxEscJs,@Spell
      \ keepend
      \ extend

" <>   </>
" s~~~~~~e
" A big start regexp borrowed from https://git.io/vDyxc
syntax region tsxFragment
      \ start=+\(\((\|{\|}\|\[\|,\|&&\|||\|?\|:\|=\|=>\|\Wreturn\|^return\|\Wdefault\|^\|>\)\_s*\)\@<=<>+
      \ skip=+<!--\_.\{-}-->+
      \ end=+</>+
      \ fold
      \ contains=tsxRegion,tsxCloseString,tsxCloseTag,tsxTag,tsxCommentInvalid,tsxFragment,tsxEscJs,@Spell
      \ keepend
      \ extend

" </tag>
" ~~~~~~
syntax match tsxCloseTag
      \ +</\_s*[^/!?<>"']\+>+
      \ contained
      \ contains=tsxTagName,tsxIntrinsicTagName

syntax match tsxCloseTag +</>+ contained

syntax match tsxCloseString
      \ +/>+
      \ contained

" <!-- -->
" ~~~~~~~~
syntax match tsxCommentInvalid /<!--\_.\{-}-->/ display

syntax region tsxBlockComment
    \ contained
    \ start="/\*"
    \ end="\*/"

syntax match tsxLineComment
    \ "//.*$"
    \ contained
    \ display

syntax cluster tsxComment contains=tsxBlockComment,tsxLineComment

syntax match tsxEntity "&[^; \t]*;" contains=tsxEntityPunct
syntax match tsxEntityPunct contained "[&.;]"

" <tag key={this.props.key}>
"  ~~~
syntax match tsxTagName
    \ +[</]\_s*[^/!?<>"'* ]\++hs=s+1
    \ contained
    \ nextgroup=tsxAttrib
    \ skipwhite
    \ display
syntax match tsxIntrinsicTagName
    \ +[</]\_s*[a-z1-9-]\++hs=s+1
    \ contained
    \ nextgroup=tsxAttrib
    \ skipwhite
    \ display

" <tag key={this.props.key}>
"      ~~~
syntax match tsxAttrib
    \ +[a-zA-Z_][-0-9a-zA-Z_]*+
    \ nextgroup=tsxEqual skipwhite
    \ contained
    \ display

" <tag id="sample">
"        ~
syntax match tsxEqual +=+ display contained
  \ nextgroup=tsxString skipwhite

" <tag id="sample">
"         s~~~~~~e
syntax region tsxString contained start=+"+ end=+"+ contains=tsxEntity,@Spell display

" <tag key={this.props.key}>
"          s~~~~~~~~~~~~~~e
syntax region tsxEscJs
    \ contained
    \ contains=@typescriptValue,@tsxComment
    \ matchgroup=typescriptBraces
    \ start=+{+
    \ end=+}+
    \ extend


"""""""""""""""""""""""""""""""""""""""""""""""""""
" Source the part common with typescriptreact.vim
source <sfile>:h/shared/typescriptcommon.vim


syntax cluster typescriptExpression add=tsxRegion,tsxFragment

hi def link tsxTag htmlTag
hi def link tsxTagName Function
hi def link tsxIntrinsicTagName htmlTagName
hi def link tsxString String
hi def link tsxNameSpace Function
hi def link tsxCommentInvalid Error
hi def link tsxBlockComment Comment
hi def link tsxLineComment Comment
hi def link tsxAttrib Type
hi def link tsxEscJs tsxEscapeJs
hi def link tsxCloseTag htmlTag
hi def link tsxCloseString Identifier

let b:current_syntax = "typescriptreact"
if main_syntax == 'typescriptreact'
  unlet main_syntax
endif

let &cpo = s:cpo_save
unlet s:cpo_save
