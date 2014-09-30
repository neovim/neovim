" Vim syntax file
" Language:     Liquid
" Maintainer:   Tim Pope <vimNOSPAM@tpope.org>
" Filenames:    *.liquid
" Last Change:	2013 May 30

if exists('b:current_syntax')
  finish
endif

if !exists('main_syntax')
  let main_syntax = 'liquid'
endif

if !exists('g:liquid_default_subtype')
  let g:liquid_default_subtype = 'html'
endif

if !exists('b:liquid_subtype') && main_syntax == 'liquid'
  let s:lines = getline(1)."\n".getline(2)."\n".getline(3)."\n".getline(4)."\n".getline(5)."\n".getline("$")
  let b:liquid_subtype = matchstr(s:lines,'liquid_subtype=\zs\w\+')
  if b:liquid_subtype == ''
    let b:liquid_subtype = matchstr(&filetype,'^liquid\.\zs\w\+')
  endif
  if b:liquid_subtype == ''
    let b:liquid_subtype = matchstr(substitute(expand('%:t'),'\c\%(\.liquid\)\+$','',''),'\.\zs\w\+$')
  endif
  if b:liquid_subtype == ''
    let b:liquid_subtype = g:liquid_default_subtype
  endif
endif

if exists('b:liquid_subtype') && b:liquid_subtype != ''
  exe 'runtime! syntax/'.b:liquid_subtype.'.vim'
  unlet! b:current_syntax
endif

syn case match

if exists('b:liquid_subtype') && b:liquid_subtype != 'yaml'
  " YAML Front Matter
  syn include @liquidYamlTop syntax/yaml.vim
  unlet! b:current_syntax
  syn region liquidYamlHead start="\%^---$" end="^---\s*$" keepend contains=@liquidYamlTop,@Spell
endif

if !exists('g:liquid_highlight_types')
  let g:liquid_highlight_types = []
endif

if !exists('s:subtype')
  let s:subtype = exists('b:liquid_subtype') ? b:liquid_subtype : ''

  for s:type in map(copy(g:liquid_highlight_types),'matchstr(v:val,"[^=]*$")')
    if s:type =~ '\.'
      let b:{matchstr(s:type,'[^.]*')}_subtype = matchstr(s:type,'\.\zs.*')
    endif
    exe 'syn include @liquidHighlight'.substitute(s:type,'\.','','g').' syntax/'.matchstr(s:type,'[^.]*').'.vim'
    unlet! b:current_syntax
  endfor
  unlet! s:type

  if s:subtype == ''
    unlet! b:liquid_subtype
  else
    let b:liquid_subtype = s:subtype
  endif
  unlet s:subtype
endif

syn region  liquidStatement  matchgroup=liquidDelimiter start="{%" end="%}" contains=@liquidStatement containedin=ALLBUT,@liquidExempt keepend
syn region  liquidExpression matchgroup=liquidDelimiter start="{{" end="}}" contains=@liquidExpression  containedin=ALLBUT,@liquidExempt keepend
syn region  liquidComment    matchgroup=liquidDelimiter start="{%\s*comment\s*%}" end="{%\s*endcomment\s*%}" contains=liquidTodo,@Spell containedin=ALLBUT,@liquidExempt keepend
syn region  liquidRaw        matchgroup=liquidDelimiter start="{%\s*raw\s*%}" end="{%\s*endraw\s*%}" contains=TOP,@liquidExempt containedin=ALLBUT,@liquidExempt keepend

syn cluster liquidExempt contains=liquidStatement,liquidExpression,liquidComment,liquidRaw,@liquidStatement,liquidYamlHead
syn cluster liquidStatement contains=liquidConditional,liquidRepeat,liquidKeyword,@liquidExpression
syn cluster liquidExpression contains=liquidOperator,liquidString,liquidNumber,liquidFloat,liquidBoolean,liquidNull,liquidEmpty,liquidPipe,liquidForloop

syn keyword liquidKeyword highlight nextgroup=liquidTypeHighlight skipwhite contained
syn keyword liquidKeyword endhighlight contained
syn region liquidHighlight start="{%\s*highlight\s\+\w\+\s*%}" end="{% endhighlight %}" keepend

for s:type in g:liquid_highlight_types
  exe 'syn match liquidTypeHighlight "\<'.matchstr(s:type,'[^=]*').'\>" contained'
  exe 'syn region liquidHighlight'.substitute(matchstr(s:type,'[^=]*$'),'\..*','','').' start="{%\s*highlight\s\+'.matchstr(s:type,'[^=]*').'\s*%}" end="{% endhighlight %}" keepend contains=@liquidHighlight'.substitute(matchstr(s:type,'[^=]*$'),'\.','','g')
endfor
unlet! s:type

syn region liquidString matchgroup=liquidQuote start=+"+ end=+"+ contained
syn region liquidString matchgroup=liquidQuote start=+'+ end=+'+ contained
syn match liquidNumber "-\=\<\d\+\>" contained
syn match liquidFloat "-\=\<\d\+\>\.\.\@!\%(\d\+\>\)\=" contained
syn keyword liquidBoolean true false contained
syn keyword liquidNull null nil contained
syn match liquidEmpty "\<empty\>" contained

syn keyword liquidOperator and or not contained
syn match liquidPipe '|' contained skipwhite nextgroup=liquidFilter

syn keyword liquidFilter date capitalize downcase upcase first last join sort size strip_html strip_newlines newline_to_br replace replace_first remove remove_first truncate truncatewords prepend append minus plus times divided_by contained

syn keyword liquidConditional if elsif else endif unless endunless case when endcase ifchanged endifchanged contained
syn keyword liquidRepeat      for endfor tablerow endtablerow in contained
syn match   liquidRepeat      "\%({%\s*\)\@<=empty\>" contained
syn keyword liquidKeyword     assign cycle include with contained

syn keyword liquidForloop forloop nextgroup=liquidForloopDot contained
syn match liquidForloopDot "\." nextgroup=liquidForloopAttribute contained
syn keyword liquidForloopAttribute length index index0 rindex rindex0 first last contained

syn keyword liquidTablerowloop tablerowloop nextgroup=liquidTablerowloopDot contained
syn match liquidTablerowloopDot "\." nextgroup=liquidTableForloopAttribute contained
syn keyword liquidTablerowloopAttribute length index index0 col col0 index0 rindex rindex0 first last col_first col_last contained

hi def link liquidDelimiter             PreProc
hi def link liquidComment               Comment
hi def link liquidTypeHighlight         Type
hi def link liquidConditional           Conditional
hi def link liquidRepeat                Repeat
hi def link liquidKeyword               Keyword
hi def link liquidOperator              Operator
hi def link liquidString                String
hi def link liquidQuote                 Delimiter
hi def link liquidNumber                Number
hi def link liquidFloat                 Float
hi def link liquidEmpty                 liquidNull
hi def link liquidNull                  liquidBoolean
hi def link liquidBoolean               Boolean
hi def link liquidFilter                Function
hi def link liquidForloop               Identifier
hi def link liquidForloopAttribute      Identifier

let b:current_syntax = 'liquid'

if exists('main_syntax') && main_syntax == 'liquid'
  unlet main_syntax
endif
