" Vim syntax file.
" Language:    Astro
" Author:      Wuelner Martínez <wuelner.martinez@outlook.com>
" Maintainer:  Wuelner Martínez <wuelner.martinez@outlook.com>
" URL:         https://github.com/wuelnerdotexe/vim-astro
" Last Change: 2022 Aug 22
" Based On:    Evan Lecklider's vim-svelte
" Changes:     See https://github.com/evanleck/vim-svelte
" Credits:     See vim-svelte on github

" Quit when a (custom) syntax file was already loaded.
if !exists('main_syntax')
  if exists('b:current_syntax')
    finish
  endif
  let main_syntax = 'astro'
elseif exists('b:current_syntax') && b:current_syntax == 'astro'
  finish
endif

" Astro syntax variables are initialized.
let g:astro_typescript = get(g:, 'astro_typescript', 'disable')
let g:astro_stylus = get(g:, 'astro_stylus', 'disable')

let s:cpoptions_save = &cpoptions
set cpoptions&vim

" Embedded HTML syntax.
runtime! syntax/html.vim

" htmlTagName: expand HTML tag names to include mixed case and periods.
syntax match htmlTagName contained "\<[a-zA-Z\.]*\>"

" astroDirectives: add Astro Directives to HTML arguments.
syntax match astroDirectives contained '\<[a-z]\+:[a-z|]*\>' containedin=htmlTag

unlet b:current_syntax

if g:astro_typescript == 'enable'
  " Embedded TypeScript syntax.
  syntax include @astroJavaScript syntax/typescript.vim

  " javaScriptExpression: a javascript expression is used as an arg value.
  syntax clear javaScriptExpression
  syntax region javaScriptExpression
        \ contained start=+&{+
        \ keepend end=+};+
        \ contains=@astroJavaScript,@htmlPreproc

  " javaScript: add TypeScript support to HTML script tag.
  syntax clear javaScript
  syntax region javaScript
        \ start=+<script\_[^>]*>+
        \ keepend
        \ end=+</script\_[^>]*>+me=s-1
        \ contains=htmlScriptTag,@astroJavaScript,@htmlPreproc,htmlCssStyleComment
else
  " Embedded JavaScript syntax.
  syntax include @astroJavaScript syntax/javascript.vim
endif

" astroFence: detect the Astro fence.
syntax match astroFence contained +^---$+

" astrojavaScript: add TypeScript support to Astro code fence.
syntax region astroJavaScript
      \ start=+^---$+
      \ keepend
      \ end=+^---$+
      \ contains=htmlTag,@astroJavaScript,@htmlPreproc,htmlCssStyleComment,htmlEndTag,astroFence
      \ fold

unlet b:current_syntax

if g:astro_typescript == 'enable'
  " Embedded TypeScript React (TSX) syntax.
  syntax include @astroJavaScriptReact syntax/typescriptreact.vim
else
  " Embedded JavaScript React (JSX) syntax.
  syntax include @astroJavaScriptReact syntax/javascriptreact.vim
endif

" astroJavaScriptExpression: add {JSX or TSX} support to Astro expresions.
execute 'syntax region astroJavaScriptExpression start=+{+ keepend end=+}+ ' .
      \ 'contains=@astroJavaScriptReact, @htmlPreproc containedin=' . join([
      \   'htmlArg', 'htmlBold', 'htmlBoldItalic', 'htmlBoldItalicUnderline',
      \   'htmlBoldUnderline', 'htmlBoldUnderlineItalic', 'htmlH1', 'htmlH2',
      \   'htmlH3', 'htmlH4', 'htmlH5', 'htmlH6', 'htmlHead', 'htmlItalic',
      \   'htmlItalicBold', 'htmlItalicBoldUnderline', 'htmlItalicUnderline',
      \   'htmlItalicUnderlineBold', 'htmlLeadingSpace', 'htmlLink',
      \   'htmlStrike', 'htmlString', 'htmlTag', 'htmlTitle', 'htmlUnderline',
      \   'htmlUnderlineBold', 'htmlUnderlineBoldItalic',
      \   'htmlUnderlineItalic', 'htmlUnderlineItalicBold', 'htmlValue'
      \ ], ',')

" cssStyle: add CSS style tags support in TypeScript React.
syntax region cssStyle
      \ start=+<style\_[^>]*>+
      \ keepend
      \ end=+</style\_[^>]*>+me=s-1
      \ contains=htmlTag,@htmlCss,htmlCssStyleComment,@htmlPreproc,htmlEndTag
      \ containedin=@astroJavaScriptReact

unlet b:current_syntax

" Embedded SCSS syntax.
syntax include @astroScss syntax/scss.vim

" cssStyle: add SCSS style tags support in Astro.
syntax region scssStyle
      \ start=/<style\>\_[^>]*\(lang\)=\("\|''\)[^\2]*scss[^\2]*\2\_[^>]*>/
      \ keepend
      \ end=+</style>+me=s-1
      \ contains=@astroScss,astroSurroundingTag
      \ fold

unlet b:current_syntax

" Embedded SASS syntax.
syntax include @astroSass syntax/sass.vim

" cssStyle: add SASS style tags support in Astro.
syntax region sassStyle
      \ start=/<style\>\_[^>]*\(lang\)=\("\|''\)[^\2]*sass[^\2]*\2\_[^>]*>/
      \ keepend
      \ end=+</style>+me=s-1
      \ contains=@astroSass,astroSurroundingTag
      \ fold

unlet b:current_syntax

" Embedded LESS syntax.
syntax include @astroLess syntax/less.vim

" cssStyle: add LESS style tags support in Astro.
syntax region lessStyle
      \ start=/<style\>\_[^>]*\(lang\)=\("\|''\)[^\2]*less[^\2]*\2\_[^>]*>/
      \ keepend
      \ end=+</style>+me=s-1
      \ contains=@astroLess,astroSurroundingTag
      \ fold

unlet b:current_syntax

" Embedded Stylus syntax.
" NOTE: Vim does not provide stylus support by default, but you can install
"       this plugin to support it: https://github.com/wavded/vim-stylus
if g:astro_stylus == 'enable'
  try
    " Embedded Stylus syntax.
    syntax include @astroStylus syntax/stylus.vim

    " stylusStyle: add Stylus style tags support in Astro.
    syntax region stylusStyle
          \ start=/<style\>\_[^>]*\(lang\)=\("\|''\)[^\2]*stylus[^\2]*\2\_[^>]*>/
          \ keepend
          \ end=+</style>+me=s-1
          \ contains=@astroStylus,astroSurroundingTag
          \ fold

    unlet b:current_syntax
  catch
    echomsg "you need install a external plugin for support stylus in .astro files"
  endtry
endif

" astroSurroundingTag: add surround HTML tag to script and style.
syntax region astroSurroundingTag
      \ start=+<\(script\|style\)+
      \ end=+>+
      \ contains=htmlTagError,htmlTagN,htmlArg,htmlValue,htmlEvent,htmlString
      \ contained
      \ fold

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet.
highlight default link astroDirectives Special
highlight default link astroFence Comment

let b:current_syntax = 'astro'
if main_syntax == 'astro'
  unlet main_syntax
endif

" Sync from start because of the wacky nesting.
syntax sync fromstart

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
" vim: ts=8
