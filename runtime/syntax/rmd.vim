" markdown Text with R statements
" Language: markdown with R code chunks
" Homepage: https://github.com/jalvesaq/R-Vim-runtime
" Last Change: Thu Apr 18, 2019  09:17PM
"
"   For highlighting pandoc extensions to markdown like citations and TeX and
"   many other advanced features like folding of markdown sections, it is
"   recommended to install the vim-pandoc filetype plugin as well as the
"   vim-pandoc-syntax filetype plugin from https://github.com/vim-pandoc.


if exists("b:current_syntax")
  finish
endif

" Configuration if not using pandoc syntax:
" Add syntax highlighting of YAML header
let g:rmd_syn_hl_yaml = get(g:, 'rmd_syn_hl_yaml', 1)
" Add syntax highlighting of citation keys
let g:rmd_syn_hl_citations = get(g:, 'rmd_syn_hl_citations', 1)
" Highlight the header of the chunk of R code
let g:rmd_syn_hl_chunk = get(g:, 'g:rmd_syn_hl_chunk', 0)

" Pandoc-syntax has more features, but it is slower.
" https://github.com/vim-pandoc/vim-pandoc-syntax
let g:pandoc#syntax#codeblocks#embeds#langs = get(g:, 'pandoc#syntax#codeblocks#embeds#langs', ['r'])
runtime syntax/pandoc.vim
if exists("b:current_syntax")
  " Fix recognition of R code
  syn region pandocDelimitedCodeBlock_r start=/^```{r\>.*}$/ end=/^```$/ contained containedin=pandocDelimitedCodeBlock contains=@R
  syn region rmdrInline matchgroup=rmdInlineDelim start="`r "  end="`" contains=@R containedin=pandocLaTeXRegion,yamlFlowString keepend
  hi def link rmdInlineDelim Delimiter
  let b:current_syntax = "rmd"
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" R chunks will not be highlighted by syntax/markdown because their headers
" follow a non standard pattern: "```{lang" instead of "^```lang".
" Make a copy of g:markdown_fenced_languages to highlight the chunks later:
if exists('g:markdown_fenced_languages')
  if !exists('g:rmd_fenced_languages')
    let g:rmd_fenced_languages = deepcopy(g:markdown_fenced_languages)
    let g:markdown_fenced_languages = []
  endif
else
  let g:rmd_fenced_languages = ['r']
endif

runtime syntax/markdown.vim

" Now highlight chunks:
for s:type in g:rmd_fenced_languages
  if s:type =~ '='
    let s:ft = substitute(s:type, '.*=', '', '')
    let s:nm = substitute(s:type, '=.*', '', '')
  else
    let s:ft = s:type
    let s:nm  = s:type
  endif
  unlet! b:current_syntax
  exe 'syn include @Rmd'.s:nm.' syntax/'.s:ft.'.vim'
  if g:rmd_syn_hl_chunk
    exe 'syn region rmd'.s:nm.'ChunkDelim matchgroup=rmdCodeDelim start="^\s*```\s*{\s*'.s:nm.'\>" matchgroup=rmdCodeDelim end="}$" keepend containedin=rmd'.s:nm.'Chunk contains=@Rmd'.s:nm
    exe 'syn region rmd'.s:nm.'Chunk start="^\s*```\s*{\s*'.s:nm.'\>.*$" matchgroup=rmdCodeDelim end="^\s*```\ze\s*$" keepend contains=rmd'.s:nm.'ChunkDelim,@Rmd'.s:nm
  else
    exe 'syn region rmd'.s:nm.'Chunk matchgroup=rmdCodeDelim start="^\s*```\s*{\s*'.s:nm.'\>.*$" matchgroup=rmdCodeDelim end="^\s*```\ze\s*$" keepend contains=@Rmd'.s:nm
  endif
  exe 'syn region rmd'.s:nm.'Inline matchgroup=rmdInlineDelim start="`'.s:nm.' "  end="`" contains=@Rmd'.s:nm.' keepend'
endfor
unlet! s:type

hi def link rmdInlineDelim Delimiter
hi def link rmdCodeDelim Delimiter

" You don't need this if either your markdown/syntax.vim already highlights
" the YAML header or you are writing standard markdown
if g:rmd_syn_hl_yaml
  " Minimum highlighting of yaml header
  syn match rmdYamlFieldTtl /^\s*\zs\w*\ze:/ contained
  syn match rmdYamlFieldTtl /^\s*-\s*\zs\w*\ze:/ contained
  syn region yamlFlowString matchgroup=yamlFlowStringDelimiter start='"' skip='\\"' end='"' contains=yamlEscape,rmdrInline contained
  syn region yamlFlowString matchgroup=yamlFlowStringDelimiter start="'" skip="''"  end="'" contains=yamlSingleEscape,rmdrInline contained
  syn match  yamlEscape contained '\\\%([\\"abefnrtv\^0_ NLP\n]\|x\x\x\|u\x\{4}\|U\x\{8}\)'
  syn match  yamlSingleEscape contained "''"
  syn region pandocYAMLHeader matchgroup=rmdYamlBlockDelim start=/\%(\%^\|\_^\s*\n\)\@<=\_^-\{3}\ze\n.\+/ end=/^\([-.]\)\1\{2}$/ keepend contains=rmdYamlFieldTtl,yamlFlowString
  hi def link rmdYamlBlockDelim Delimiter
  hi def link rmdYamlFieldTtl Identifier
  hi def link yamlFlowString String
endif

" You don't need this if either your markdown/syntax.vim already highlights
" citations or you are writing standard markdown
if g:rmd_syn_hl_citations
  " From vim-pandoc-syntax
  " parenthetical citations
  syn match pandocPCite /\^\@<!\[[^\[\]]\{-}-\{0,1}@[[:alnum:]_][[:alnum:]à-öø-ÿÀ-ÖØ-ß_:.#$%&\-+?<>~\/]*.\{-}\]/ contains=pandocEmphasis,pandocStrong,pandocLatex,pandocCiteKey,@Spell,pandocAmpersandEscape display
  " in-text citations with location
  syn match pandocICite /@[[:alnum:]_][[:alnum:]à-öø-ÿÀ-ÖØ-ß_:.#$%&\-+?<>~\/]*\s\[.\{-1,}\]/ contains=pandocCiteKey,@Spell display
  " cite keys
  syn match pandocCiteKey /\(-\=@[[:alnum:]_][[:alnum:]à-öø-ÿÀ-ÖØ-ß_:.#$%&\-+?<>~\/]*\)/ containedin=pandocPCite,pandocICite contains=@NoSpell display
  syn match pandocCiteAnchor /[-@]/ contained containedin=pandocCiteKey display
  syn match pandocCiteLocator /[\[\]]/ contained containedin=pandocPCite,pandocICite
  hi def link pandocPCite Operator
  hi def link pandocICite Operator
  hi def link pandocCiteKey Label
  hi def link pandocCiteAnchor Operator
  hi def link pandocCiteLocator Operator
endif

let b:current_syntax = "rmd"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
