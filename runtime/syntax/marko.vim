" Vim syntax file
" Language:	Marko
" Maintainer:	Brian Carbone <cordial.coffee1365@fastmail.com>
" URL:		https://markojs.com
" Filenames:	*.marko
" Last Change:	2026 Jul 28

" Marko interleaves HTML-like tags, TypeScript expressions and CSS style
" blocks, in two modes: an HTML-like mode and an indentation-based concise
" mode.  Mode is tracked structurally: the body of an html-mode element is
" an html-mode region (bare text stays plain there), while everywhere else
" is concise context, where a line-start name is a tag:
"   <p>if you want, stop by</p>      body text, plain
"   my-tag size="large"              concise tag, highlighted
"
" Same-position priority goes to the item defined last, so definition order
" is deliberate throughout; the load-bearing orderings are called out in
" the comments below.

if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = "marko"
endif

let s:cpo_save = &cpo
set cpo&vim

syn spell toplevel

" TypeScript for expressions and statement tags, CSS for style blocks.
" Both includes mutate shared state ("syn case", "syn iskeyword", sync
" rules, 'iskeyword'), all of it restored or restated afterwards.
let s:iskeyword_save = &l:iskeyword
syn include @markoTS syntax/typescript.vim
unlet! b:current_syntax
syn include @markoCSS syntax/css.vim
unlet! b:current_syntax
let &l:iskeyword = s:iskeyword_save
unlet s:iskeyword_save
syn case match

" typescript.vim (yats) attaches type arguments via nextgroup after every
" identifier, so an unspaced "<" in any expression opens a region hunting a
" ">" that may never come:
"   <div count=i<3>       would swallow the rest of the file
" Its block comment carries "extend", which would let one stray "/*" escape
" every containing region below.  Both are redefined bounded; the cost is
" generic-call coloring inside script blocks.
silent! syn clear typescriptTypeArguments
silent! syn clear typescriptComment
syn region typescriptComment contained start="/\*" end="\*/" contains=@Spell,typescriptCommentTodo

" Everything an embedded TypeScript expression may contain.  The bracket
" pairs keep an outer region open across nested delimiters and shield the
" spaces inside groupings from attribute-value termination:
"   a={ b: { c: 1 } } d=2
" Without the matchgroup each region would re-match at its own start
" character through its own contains and consume the closing delimiter.
" markoTSDelim is deliberately unlinked: the delimiters render as plain
" text, like brackets in a TypeScript buffer.
syn cluster markoExpr contains=@markoTS,markoTSBraces,markoTSParens,markoTSBrackets
syn region markoTSBraces contained transparent matchgroup=markoTSDelim
      \ start="{" end="}"
      \ contains=@markoExpr extend
syn region markoTSParens contained transparent matchgroup=markoTSDelim
      \ start="(" end=")"
      \ contains=@markoExpr extend
syn region markoTSBrackets contained transparent matchgroup=markoTSDelim
      \ start="\[" end="]"
      \ contains=@markoExpr extend

" Comments are recognized where the parser allows text to start; anchoring
" to the line start keeps "//" inside URLs as text:
"   <!-- note -->    // note    /* note */    https://example.com
syn region markoComment start="<!--" end="-->" contains=@Spell fold
syn match markoComment "^\s*//.*$" contains=@Spell display
syn region markoComment start="^\s*/\*" end="\*/" contains=@Spell fold
syn region markoTagComment contained start="/\*" end="\*/"
syn match markoTagComment contained "//.*"

syn region markoCData start="<!\[CDATA\[" end="]]>"
" Declarations; "<?...>" may close with ">" or "?>":
"   <!doctype html>    <?xml version="1.0"?>
syn region markoDeclaration start="<!\%(--\|\[CDATA\)\@!" end=">"
syn region markoDeclaration start="<?" end="?\=>"

" Placeholders interpolate into text, and backslashes escape pairwise:
"   ${user.name}    $!{rawHtml}    \${literal}    \\${live}
" The containedin lets them apply inside style rules and property values.
" markoEscape must never take "display": it exists to suppress
" markoPlaceholder, so skipping it during state computation would change
" what matches.
syn match markoEscape "\%(\\\\\)\+\ze\$!\={"
syn match markoEscape "\%(\\\\\)*\\\$!\={"
syn region markoPlaceholder matchgroup=markoPlaceholderDelim
      \ start="\$!\={" end="}"
      \ contains=@markoExpr containedin=cssDefinition,cssAttrRegion extend

syn match markoEntity "&\%(#\d\+\|#[xX]\x\+\|\w\+\);" display

" Scriptlets; the whitespace after "$" is required, so a line-start
" placeholder is not a scriptlet:
"   $ count += 1
"   $ { let total = 0; }
"   ${count}                     placeholder
syn region markoScriptlet matchgroup=markoScriptletDelim
      \ start="^\s*\$\s\+{\@!" end="$"
      \ contains=@markoExpr keepend
syn region markoScriptlet matchgroup=markoScriptletDelim
      \ start="^\s*\$\s\+{" end="};\="
      \ contains=@markoExpr

" "--" marks one line of text in concise mode:
"   p -- some text
syn match markoBlockDelim "\%(^\|\s\)\@1<=--\+\ze\%(\s\|$\)" display

" Attributes.  An unquoted value ends at whitespace (quoted strings and
" bracket pairs shield theirs), does not start at the "=" of an arrow, and
" continues across " => " so arrow values stay whole:
"   size="large"    total:=sum    ...spread    onClick=(e) => handle(e)
" The attr name must not match the "${" of a dynamic tag name.
syn match markoAttrName contained "\%(\$!\={\)\@![[:alnum:]_$@][-[:alnum:]_$.]*" display
syn match markoSpread contained "\.\.\." display
syn region markoAttrValue contained matchgroup=markoOperator
      \ start=":\==>\@!\s*" end="\ze\%(\%(=>\)\@2<!\s\%(\s*=>\)\@!\|=\@1<!>\|/>\)" end="$"
      \ contains=@markoExpr
syn region markoString contained start=+\z(["']\)+ skip=+\\\z1+ end=+\z1+ contains=@Spell

" Shorthands after the tag name:
"   <div.card#main>
syn match markoShorthandId contained "#[-[:alnum:]_$]\+" display
syn match markoShorthandClass contained "\.[-[:alnum:]_$]\+" display

" Tag variables, arguments, |parameters|, <type args> and attribute method
" shorthand bodies:
"   <let/count=1/>    <for|item, i| of=list>    <while(cond)>
"   <generic-list<string>>    <button onClick(e) { handle(e) }>
" Params and type args must hug the preceding name (the "\k" follows the
" "syn iskeyword" set below, which is what admits hyphenated names) so a
" "|" or "<" inside an expression cannot open them, and both are oneline
" so an unmatched delimiter cannot run past its line.
syn match markoTagVar contained "/\%([[:alnum:]_$]\+\|\ze\s*[{[]\)" display
syn region markoArgs contained matchgroup=markoTagDelim
      \ start="(" end=")"
      \ contains=@markoExpr extend
syn region markoParams contained oneline matchgroup=markoTagDelim
      \ start="\%(\k\|[$)\]}>]\)\@4<=|" skip="||" end="|"
      \ contains=@markoExpr
syn region markoTypeArgs contained oneline matchgroup=markoTagDelim
      \ start="\%(\k\|\$\)\@4<=<" end=">"
      \ contains=@markoExpr,markoTypeArgs
syn region markoMethodBody contained matchgroup=markoTagDelim
      \ start="{" end="}"
      \ contains=@markoExpr extend

syn cluster markoTagStuff contains=markoTagVar,markoShorthandId,markoShorthandClass,
      \markoAttrName,markoAttrValue,markoString,markoArgs,markoParams,markoTypeArgs,
      \markoMethodBody,markoSpread,markoTagComment,markoPlaceholder
syn cluster markoTagNames contains=markoTagName,markoAttrTagName,markoTagNameConditional,
      \markoTagNameRepeat,markoTagNameException,markoTagNameStatement,markoTagNameBuiltin

" Concise attribute groups may span lines:
"   define [
"     size = "large"
"   ]
syn region markoAttrGroup contained matchgroup=markoTagDelim
      \ start="\[" end="]"
      \ contains=@markoTagStuff extend

" One name list per highlight class, shared by the concise regions here
" and the tag-name matches below.
let s:tag_name_classes = [
      \ ["Conditional", 'if\|else-if\|else'],
      \ ["Repeat", 'for\|while'],
      \ ["Exception", 'try'],
      \ ["Statement", 'await\|return'],
      \ ["Builtin", 'let\|const\|effect\|lifecycle\|id\|log\|debug\|context\|define\|macro\|html-comment'],
      \ ]

" Concise mode: a line-start name is a tag.  The generic rule is defined
" first, so the builtin classes, "@" attribute tags and the statement tags
" below all win over it for their names.  keepend bounds each region to
" its line; brackets, method bodies and attr groups carry extend, which
" deliberately punches through for multiline constructs.
let s:concise_tag_end = ' matchgroup=markoTagDelim end=";" end="$" end="\s\zs\ze--\%(\s\|$\)"'
      \ . ' contains=@markoTagStuff,markoAttrGroup keepend'
exe 'syn region markoConciseTag matchgroup=markoTagName'
      \ . ' start="^\s*\zs[[:alnum:]][-[:alnum:]_$:]*\%([-[:alnum:]_$:]\)\@!"'
      \ . s:concise_tag_end
for [s:class_suffix, s:name_pattern] in s:tag_name_classes
  exe 'syn region markoConciseTag matchgroup=markoTagName' . s:class_suffix
        \ . ' start="^\s*\zs\%(' . s:name_pattern . '\)\%([-[:alnum:]_$:]\)\@!"'
        \ . s:concise_tag_end
endfor
exe 'syn region markoConciseTag matchgroup=markoAttrTagName'
      \ . ' start="^\s*\zs@[-[:alnum:]_$:]\+"'
      \ . s:concise_tag_end
unlet s:concise_tag_end

" Statement tags contain one TypeScript statement.  static/server/client
" are Marko keywords; import/export/class take their color from the
" TypeScript include.  A statement may span lines through an open brace or
" class body, so an unterminated "/*" runs on, as it would in a TypeScript
" buffer.  Defined after the concise regions so these names win there.
syn region markoStatement matchgroup=markoStatementKeyword
      \ start="^\s*\zs\%(static\|server\|client\)\>"
      \ end="$" contains=@markoExpr
syn region markoStatement
      \ start="^\s*\ze\%(import\|export\|class\)\>"
      \ end="$" contains=@markoExpr

" A tag name may be empty (<.card>), dynamic (<${tag}>) or an attribute
" tag (<@body>); the ">" of an arrow does not end the tag.
syn region markoTag matchgroup=markoTagDelim
      \ start="<\ze[^/ \t!?<>=]" end="/>" end="=\@1<!>"
      \ contains=@markoTagStuff,@markoTagNames
syn region markoCloseTag matchgroup=markoTagDelim
      \ start="</" end=">"
      \ contains=@markoTagNames,markoPlaceholder

" The name of a close tag whose "</" was consumed by an element body's end
" match below, plus its trailing ">".
syn match markoCloseName "\%(</\)\@2<=@\=\%(\k\|[$:]\)\+\s*" nextgroup=markoCloseGt display
syn match markoCloseGt contained ">" display

" Everything html-mode content may contain.  Statement tags and concise
" tags are absent: bare text inside an element body is prose.
syn cluster markoHtmlContent contains=markoTag,markoHtmlBody,markoDynamicBody,
      \markoStyle,markoScript,markoTextareaTag,markoHtmlCommentTag,
      \markoComment,markoCData,markoDeclaration,markoEscape,markoPlaceholder,
      \markoEntity,markoScriptlet,markoCloseName

" Whether "<name" begins an element body turns on how its open tag ends:
" an atomic (no-backtrack) run over quoted strings, (args), <type args>,
" "=>" and spaced comparisons finds the structural ">", and a "/>" there
" means self-closing, so no body:
"   <my-tag onClick=() => go(a > b) />
let s:tag_end_ahead = '\%(\%(\%(<\%([^<>]\|<\%([^<>]\|<[^<>]\{-,40}>\)\{-,60}>\)\{-,100}>'
      \ . '\|"[^"]\{-,200}"\|' . "'[^']\\{-,200}'"
      \ . '\|([^()]\{-,200})\|=>\|[ \t]>[ \t]\@=\|\_[^>]\)\{0,400}\)\@>/\@1<!=\@1<!>\)\@='

" Element bodies: html mode from a non-void, non-self-closing open tag to
" its matching close.  \z1 pairs the names, and the end consumes only
" "</" so an inner same-name close cannot end the outer bodies
" (markoCloseName colors the rest):
"   <div><div>nested</div>still the outer body</div>
" No body opens for html voids, parsed-text tags, bodiless core tags
" (<let/x=1> takes no close tag) or "@" attribute tags (those auto-close
" at their parent, which no name pairing can track).  Defined after
" markoTag so open tags still overlay inside bodies, and after the
" concise regions so html mode wins at a line-start "<".  A mismatched or
" missing close leaves its body open for the rest of the buffer, as an
" unclosed tag does in html.vim.
exe 'syn region markoHtmlBody'
      \ . ' start=+<\ze\%(\%(area\|base\|br\|col\|embed\|hr\|img\|input\|link\|meta\|param'
      \ .   '\|source\|track\|wbr\|style\|script\|textarea\|html-comment\|html-style'
      \ .   '\|html-script\|let\|const\|id\|log\|debug\|effect\|lifecycle\|return\)'
      \ .   '\%(\k\|[$:]\)\@!\)\@!'
      \ .   '\z(\%(\k\|[$:]\)\+\)\%(\_s\|[/>|(<.#=]\)\@=' . s:tag_end_ahead . '+'
      \ . ' matchgroup=markoTagDelim'
      \ . ' end="</\ze\z1\%(\k\|[$:]\)\@!\s*>" end="</\ze\s*>"'
      \ . ' contains=@markoHtmlContent'
exe 'syn region markoDynamicBody'
      \ . ' start=+<\ze\%(\$!\={\)\@=' . s:tag_end_ahead . '+'
      \ . ' matchgroup=markoTagDelim'
      \ . ' end="</\ze\%(\$!\={\_[^}]*}\)\=\s*>"'
      \ . ' contains=@markoHtmlContent'
unlet s:tag_end_ahead

" Delimited text blocks in concise mode contain html-mode content.  An
" indented block closes at a matching delimiter line or at any line
" indented less than its opener; a column-0 block closes only at its
" matching delimiter:
"   --
"   A block of text, <b>html mode</b>.
"   --
syn region markoTextBlock matchgroup=markoBlockDelim
      \ start="^\z(\s\+\)--\+\s*$"
      \ end="^\z1--\+\s*$" end="^\%(\z1\)\@!\ze\s*\S"
      \ contains=@markoHtmlContent
syn region markoTextBlock matchgroup=markoBlockDelim
      \ start="^--\+\s*$"
      \ end="^--\+\s*$"
      \ contains=@markoHtmlContent

" Parsed-text tags: bodies contain only text and placeholders (style and
" script embed CSS and TypeScript, a textarea body is plain text, an
" html-comment body is comment text).  Defined after the generic tag and
" body regions to win at the same "<".  The "/\@1<!" keeps self-closing
" open tags, which have no body, out:
"   <script src="x" />
" keepend stops an unterminated embedded construct at the close tag.
syn region markoStyle matchgroup=markoTagNameBuiltin
      \ start=+<\%(html-\)\=style\>\_[^>]\{-,300}/\@1<!=\@1<!>+
      \ end="</\%(html-\)\=style\s*>"
      \ contains=@markoCSS,markoPlaceholder keepend fold
syn region markoStyle matchgroup=markoTagNameBuiltin
      \ start="^\s*style\%([./][^ \t{]*\)\=\s*{" end="}"
      \ contains=@markoCSS,markoPlaceholder fold
syn region markoScript matchgroup=markoTagNameBuiltin
      \ start=+<\%(html-\)\=script\>\_[^>]\{-,300}/\@1<!=\@1<!>+
      \ end="</\%(html-\)\=script\s*>"
      \ contains=@markoTS,markoPlaceholder keepend fold
syn region markoTextareaTag matchgroup=markoTagNameBuiltin
      \ start=+<textarea\>\_[^>]\{-,300}/\@1<!=\@1<!>+
      \ end="</textarea\s*>"
      \ contains=markoPlaceholder,markoEntity,@Spell keepend
syn region markoHtmlCommentTag matchgroup=markoTagNameBuiltin
      \ start=+<html-comment\>\_[^>]\{-,300}/\@1<!=\@1<!>+
      \ end="</html-comment\s*>"
      \ contains=markoPlaceholder,@Spell keepend

" Tag names inside "<...>"/"</...>" (concise names are colored by the
" region matchgroups above).  The generic name is defined after the
" attribute name, so it wins right after "<"; the class-specific names are
" defined after the generic one, so they win over it.
syn match markoTagName contained "\%(</\=\)\@2<=[[:alnum:]][-[:alnum:]_$:]*" display
syn match markoAttrTagName contained "\%(</\=\)\@2<=@[-[:alnum:]_$:]\+" display
" The un-contained variants refine markoCloseName after a body's end has
" consumed the "</", so builtin and "@" close names keep their classes.
syn match markoAttrTagName "\%(</\)\@2<=@\%(\k\|[$:]\)\+\s*" nextgroup=markoCloseGt display
for [s:class_suffix, s:name_pattern] in s:tag_name_classes
  exe 'syn match markoTagName' . s:class_suffix
        \ . ' contained "\%(</\=\)\@2<=\%(' . s:name_pattern . '\)\%([-[:alnum:]_$]\)\@!" display'
  exe 'syn match markoTagName' . s:class_suffix
        \ . ' "\%(</\)\@2<=\%(' . s:name_pattern . '\)\%(\k\|[$:]\)\@!\s*"'
        \ . ' nextgroup=markoCloseGt display'
endfor
unlet s:tag_name_classes s:class_suffix s:name_pattern

" The includes install their own sync rules; clear them and restate the
" keyword characters ("syn sync clear" clears "syn iskeyword" too).  "-"
" keeps css.vim's hyphenated value keywords whole:
"   font-family: sans-serif
" fromstart is the only safe strategy, since element bodies, concise
" regions and style/script bodies are all unbounded or line-anchored; a
" cold parse of a 5000 line file stays well under a second on current
" hardware.
syn sync clear
syn sync fromstart
syn iskeyword @,48-57,_,192-255,-

hi def link markoComment Comment
hi def link markoTagComment Comment
hi def link markoHtmlCommentTag Comment
hi def link markoDeclaration PreProc
hi def link markoCData String
hi def link markoEscape Special
hi def link markoEntity Special
hi def link markoPlaceholderDelim Special
hi def link markoStatementKeyword Keyword
hi def link markoScriptletDelim Special
hi def link markoBlockDelim Special
hi def link markoTagDelim Special
hi def link markoTagName Statement
hi def link markoCloseName Statement
hi def link markoCloseGt Special
hi def link markoAttrTagName Identifier
hi def link markoTagNameConditional Conditional
hi def link markoTagNameRepeat Repeat
hi def link markoTagNameException Exception
hi def link markoTagNameStatement Statement
hi def link markoTagNameBuiltin Macro
hi def link markoShorthandId Constant
hi def link markoShorthandClass Identifier
hi def link markoTagVar Identifier
hi def link markoAttrName Type
hi def link markoString String
hi def link markoSpread Operator
hi def link markoOperator Operator

let b:current_syntax = "marko"
if main_syntax ==# "marko"
  unlet main_syntax
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
