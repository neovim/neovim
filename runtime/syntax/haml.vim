" Vim syntax file
" Language:	Haml
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Filenames:	*.haml
" Last Change:	2019 Dec 05

if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'haml'
endif
let b:ruby_no_expensive = 1

runtime! syntax/html.vim
unlet! b:current_syntax
silent! syn include @hamlSassTop syntax/sass.vim
unlet! b:current_syntax
syn include @hamlRubyTop syntax/ruby.vim

syn case match

syn region  rubyCurlyBlock   start="{" end="}" contains=@hamlRubyTop contained
syn cluster hamlRubyTop add=rubyCurlyBlock

syn cluster hamlComponent    contains=hamlAttributes,hamlAttributesHash,hamlClassChar,hamlIdChar,hamlObject,hamlDespacer,hamlSelfCloser,hamlRuby,hamlPlainChar,hamlInterpolatable
syn cluster hamlEmbeddedRuby contains=hamlAttributesHash,hamlObject,hamlRuby,hamlRubyFilter
syn cluster hamlTop          contains=hamlBegin,hamlPlainFilter,hamlRubyFilter,hamlSassFilter,hamlComment,hamlHtmlComment

syn match   hamlBegin "^\s*\%([<>]\|&[^=~ ]\)\@!" nextgroup=hamlTag,hamlClassChar,hamlIdChar,hamlRuby,hamlPlainChar,hamlInterpolatable

syn match   hamlTag        "%\w\+\%(:\w\+\)\=" contained contains=htmlTagName,htmlSpecialTagName nextgroup=@hamlComponent
syn region  hamlAttributes     matchgroup=hamlAttributesDelimiter start="(" end=")" contained contains=htmlArg,hamlAttributeString,hamlAttributeVariable,htmlEvent,htmlCssDefinition nextgroup=@hamlComponent
syn region  hamlAttributesHash matchgroup=hamlAttributesDelimiter start="{" end="}" contained contains=@hamlRubyTop nextgroup=@hamlComponent
syn region  hamlObject         matchgroup=hamlObjectDelimiter     start="\[" end="\]" contained contains=@hamlRubyTop nextgroup=@hamlComponent
syn match   hamlDespacer "[<>]" contained nextgroup=hamlDespacer,hamlSelfCloser,hamlRuby,hamlPlainChar,hamlInterpolatable
syn match   hamlSelfCloser "/" contained
syn match   hamlClassChar "\." contained nextgroup=hamlClass
syn match   hamlIdChar "#{\@!" contained nextgroup=hamlId
syn match   hamlClass "\%(\w\|-\|\:\)\+" contained nextgroup=@hamlComponent
syn match   hamlId    "\%(\w\|-\)\+" contained nextgroup=@hamlComponent
syn region  hamlDocType start="^\s*!!!" end="$"

syn region  hamlRuby   matchgroup=hamlRubyOutputChar start="[!&]\==\|\~" skip=",\s*$" end="$" contained contains=@hamlRubyTop keepend
syn region  hamlRuby   matchgroup=hamlRubyChar       start="-"           skip=",\s*$" end="$" contained contains=@hamlRubyTop keepend
syn match   hamlPlainChar "\\" contained
syn region hamlInterpolatable matchgroup=hamlInterpolatableChar start="!\===\|!=\@!" end="$" keepend contained contains=hamlInterpolation,hamlInterpolationEscape,@hamlHtmlTop
syn region hamlInterpolatable matchgroup=hamlInterpolatableChar start="&==\|&=\@!"   end="$" keepend contained contains=hamlInterpolation,hamlInterpolationEscape
syn region hamlInterpolation matchgroup=hamlInterpolationDelimiter start="#{" end="}" contains=@hamlRubyTop containedin=javascriptStringS,javascriptStringD
syn match  hamlInterpolationEscape "\\\@<!\%(\\\\\)*\\\%(\\\ze#{\|#\ze{\)"
syn region hamlErbInterpolation matchgroup=hamlInterpolationDelimiter start="<%[=-]\=" end="-\=%>" contained contains=@hamlRubyTop

syn region  hamlAttributeString start=+\%(=\s*\)\@<='+ skip=+\%(\\\\\)*\\'+ end=+'+ contains=hamlInterpolation,hamlInterpolationEscape
syn region  hamlAttributeString start=+\%(=\s*\)\@<="+ skip=+\%(\\\\\)*\\"+ end=+"+ contains=hamlInterpolation,hamlInterpolationEscape
syn match   hamlAttributeVariable "\%(=\s*\)\@<=\%(@@\=\|\$\)\=\w\+" contained

syn match   hamlHelper  "\<action_view?\|\<block_is_haml?\|\<is_haml?\|\.\@<!\<flatten" contained containedin=@hamlEmbeddedRuby,@hamlRubyTop
syn keyword hamlHelper   capture_haml escape_once find_and_preserve haml_concat haml_indent haml_tag html_attrs html_esape init_haml_helpers list_of non_haml precede preserve succeed surround tab_down tab_up page_class contained containedin=@hamlEmbeddedRuby,@hamlRubyTop

syn cluster hamlHtmlTop contains=@htmlTop,htmlBold,htmlItalic,htmlUnderline
syn region  hamlPlainFilter      matchgroup=hamlFilter start="^\z(\s*\):\%(plain\|preserve\|redcloth\|textile\|markdown\|maruku\)\s*$" end="^\%(\z1 \| *$\)\@!" contains=@hamlHtmlTop,hamlInterpolation
syn region  hamlEscapedFilter    matchgroup=hamlFilter start="^\z(\s*\):\%(escaped\|cdata\)\s*$"    end="^\%(\z1 \| *$\)\@!" contains=hamlInterpolation
syn region  hamlErbFilter        matchgroup=hamlFilter start="^\z(\s*\):erb\s*$"        end="^\%(\z1 \| *$\)\@!" contains=@hamlHtmlTop,hamlErbInterpolation
syn region  hamlRubyFilter       matchgroup=hamlFilter start="^\z(\s*\):ruby\s*$"       end="^\%(\z1 \| *$\)\@!" contains=@hamlRubyTop
syn region  hamlJavascriptFilter matchgroup=hamlFilter start="^\z(\s*\):javascript\s*$" end="^\%(\z1 \| *$\)\@!" contains=@htmlJavaScript,hamlInterpolation keepend
syn region  hamlCSSFilter        matchgroup=hamlFilter start="^\z(\s*\):css\s*$"        end="^\%(\z1 \| *$\)\@!" contains=@htmlCss,hamlInterpolation keepend
syn region  hamlSassFilter       matchgroup=hamlFilter start="^\z(\s*\):sass\s*$"       end="^\%(\z1 \| *$\)\@!" contains=@hamlSassTop

syn region  hamlJavascriptBlock start="^\z(\s*\)%script\%((type=[\"']text/javascript[\"'])\)\=\s*$" nextgroup=@hamlComponent,hamlError end="^\%(\z1 \| *$\)\@!" contains=@hamlTop,@htmlJavaScript keepend
syn region  hamlCssBlock        start="^\z(\s*\)%style" nextgroup=@hamlComponent,hamlError  end="^\%(\z1 \| *$\)\@!" contains=@hamlTop,@htmlCss keepend
syn match   hamlError "\$" contained

syn region  hamlComment     start="^\z(\s*\)-#" end="^\%(\z1 \| *$\)\@!" contains=rubyTodo
syn region  hamlHtmlComment start="^\z(\s*\)/"  end="^\%(\z1 \| *$\)\@!" contains=@hamlTop,rubyTodo
syn match   hamlIEConditional "\%(^\s*/\)\@<=\[if\>[^]]*]" contained containedin=hamlHtmlComment

hi def link hamlSelfCloser             Special
hi def link hamlDespacer               Special
hi def link hamlClassChar              Special
hi def link hamlIdChar                 Special
hi def link hamlTag                    Special
hi def link hamlClass                  Type
hi def link hamlId                     Identifier
hi def link hamlPlainChar              Special
hi def link hamlInterpolatableChar     hamlRubyChar
hi def link hamlRubyOutputChar         hamlRubyChar
hi def link hamlRubyChar               Special
hi def link hamlInterpolationDelimiter Delimiter
hi def link hamlInterpolationEscape    Special
hi def link hamlAttributeString        String
hi def link hamlAttributeVariable      Identifier
hi def link hamlDocType                PreProc
hi def link hamlFilter                 PreProc
hi def link hamlAttributesDelimiter    Delimiter
hi def link hamlObjectDelimiter        Delimiter
hi def link hamlHelper                 Function
hi def link hamlHtmlComment            hamlComment
hi def link hamlComment                Comment
hi def link hamlIEConditional          SpecialComment
hi def link hamlError                  Error

let b:current_syntax = "haml"

if main_syntax == "haml"
  unlet main_syntax
endif

" vim:set sw=2:
