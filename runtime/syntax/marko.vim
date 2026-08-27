" Vim syntax file
" Language:	Marko
" Maintainer:	Brian Carbone <brian@briancarbone.com>
" URL:		https://markojs.com
" Filenames:	*.marko
" Last Change:	2026 Jul 29

" Marko interleaves HTML-like tags, TypeScript expressions and CSS in two
" modes.  Mode is tracked structurally: element bodies and "--" text blocks
" are html mode (bare text stays plain), everywhere else is concise, where
" a line-start name is a tag:
"   <p>if you want, stop by</p>      body text, plain
"   my-tag size="large"              concise tag, highlighted
" Same-position priority goes to the item defined last; definition order
" is deliberate throughout.

if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = "marko"
endif

let s:cpo_save = &cpo
set cpo&vim

" Top level is mostly markup; regions holding prose opt into @Spell.
syn spell toplevel

" Both includes mutate shared state ("syn case", "syn iskeyword", sync,
" 'iskeyword'), restored or restated afterwards.
let s:iskeyword_save = &l:iskeyword
syn include @markoTS syntax/typescript.vim
unlet! b:current_syntax
syn include @markoCSS syntax/css.vim
unlet! b:current_syntax
let &l:iskeyword = s:iskeyword_save
unlet s:iskeyword_save
syn case match

" A "\%#=1" prefix pins a pattern to the backtracking regexp engine: the
" default NFA engine is much slower on this file's characteristic shapes
" (a lookbehind or bounded repeat in front of an alternation).  Both
" engines answer alike; only patterns measured faster carry the prefix.

" yats attaches type arguments via nextgroup after every identifier, so an
" unspaced "<" in any expression would hunt a ">" that may never come:
"   <div count=i<3>       would swallow the rest of the file
" That group stays cleared.  The comment region replaces yats' block
" comment, whose "extend" would escape every containing region below.
silent! syn clear typescriptTypeArguments
silent! syn clear typescriptComment
syn region typescriptComment contained start="/\*" end="\*/" contains=@Spell,typescriptCommentTodo

" yats claims call arguments, bodies, indexing, arrays, templates and
" parenthesized expressions via nextgroup, so the markoTS* pairs below
" never see those delimiters.  Each row is yats' own definition plus
" "contained extend", the one difference from upstream: a multiline group
" keeps its containing attribute value open, and a bracketed one shields
" the spaces inside, as the parser's group tracking does:
"   count=Math.max(0, tiers.findIndex((t) => t.featured))
"   pair=raw as [string, string]
for s:def in [
      \ 'typescriptBlock matchgroup=typescriptBraces start=/{/ end=/}/ contains=@typescriptStatement,@typescriptComments fold',
      \ 'typescriptFuncCallArg matchgroup=typescriptParens start=/(/ end=/)/ contains=@typescriptValue,@typescriptComments,typescriptCastKeyword nextgroup=@typescriptSymbols,typescriptDotNotation skipwhite skipempty skipnl',
      \ 'typescriptArray matchgroup=typescriptBraces start=/\[/ end=/]/ contains=@typescriptValue,@typescriptComments,typescriptCastKeyword nextgroup=@typescriptSymbols,typescriptDotNotation skipwhite skipempty fold',
      \ 'typescriptTemplate start=/`/ skip=/\\\\\|\\`\|\n/ end=/`\|$/ contains=typescriptTemplateSubstitution,typescriptSpecial,@Spell nextgroup=@typescriptSymbols skipwhite skipempty',
      \ 'typescriptObjectLiteral matchgroup=typescriptBraces start=/{/ end=/}/ contains=@typescriptComments,typescriptObjectLabel,typescriptStringProperty,typescriptComputedPropertyName,typescriptObjectAsyncKeyword,typescriptTernary,typescriptCastKeyword fold',
      \ 'typescriptObjectType matchgroup=typescriptBraces start=/{/ end=/}/ contains=@typescriptTypeMember,typescriptEndColons,@typescriptComments,typescriptAccessibilityModifier,typescriptReadonlyModifier nextgroup=@typescriptTypeOperator skipwhite skipnl fold',
      \ 'typescriptParenExp matchgroup=typescriptParens start=/(/ end=/)/ contains=@typescriptComments,@typescriptValue,typescriptCastKeyword nextgroup=@typescriptSymbols skipwhite skipempty',
      \ 'typescriptIndexExpr matchgroup=typescriptProperty start=/\[/ end=/]/ contains=@typescriptValue,typescriptCastKeyword nextgroup=@typescriptSymbols,typescriptDotNotation,typescriptFuncCallArg skipwhite skipempty',
      \ 'typescriptCall matchgroup=typescriptParens start=/(/ end=/)/ contains=typescriptDecorator,@typescriptParameterList,@typescriptComments nextgroup=typescriptTypeAnnotation,typescriptBlock skipwhite skipnl',
      \ 'typescriptTupleType matchgroup=typescriptBraces start=/\[/ end=/\]/ contains=@typescriptType,@typescriptComments,typescriptRestOrSpread,typescriptTupleLable skipwhite',
      \ 'typescriptParenthesizedType matchgroup=typescriptParens start=/(/ end=/)/ contains=@typescriptType nextgroup=@typescriptTypeOperator skipwhite skipempty fold',
      \ 'typescriptFuncType matchgroup=typescriptParens start=/(\(\k\+:\|)\)\@=/ end=/)\s*=>/me=e-2 contains=@typescriptParameterList nextgroup=typescriptFuncTypeArrow skipwhite skipnl oneline',
      \ 'typescriptStringLiteralType start=/\z(["'']\)/ skip=/\\\\\|\\\z1\|\\\n/ end=/\z1\|$/ nextgroup=typescriptUnion skipwhite skipempty',
      \ 'typescriptTemplateLiteralType start=/`/ skip=/\\\\\|\\`\|\n/ end=/`\|$/ contains=typescriptTemplateSubstitutionType nextgroup=typescriptTypeOperator skipwhite skipempty',
      \ ]
  silent! exe 'syn clear ' . matchstr(s:def, '^\S\+')
  exe 'syn region ' . s:def . ' contained extend'
endfor
unlet s:def
" yats' own arrow-function definitions, restated to stay last-defined at
" a "(": params eaten as a parenthesized expression turn the arrow's "{"
" body into an object literal, whose ternary region has no closing bound:
"   f((x) => { value = x ?? other; })
syntax match   typescriptArrowFuncDef          contained /\K\k*\s*=>/
      \ contains=typescriptArrowFuncArg,typescriptArrowFunc
      \ nextgroup=@typescriptExpression,typescriptBlock
      \ skipwhite skipempty
syntax match   typescriptArrowFuncDef          contained /(\%(\_[^()]\+\|(\_[^()]*)\)*)\_s*=>/
      \ contains=typescriptArrowFuncArg,typescriptArrowFunc,@typescriptCallSignature
      \ nextgroup=@typescriptExpression,typescriptBlock
      \ skipwhite skipempty
syntax region  typescriptArrowFuncDef          contained start=/(\%(\_[^()]\+\|(\_[^()]*)\)*):/ matchgroup=typescriptArrowFunc end=/=>/
      \ contains=typescriptArrowFuncArg,typescriptTypeAnnotation,@typescriptCallSignature
      \ nextgroup=@typescriptExpression,typescriptBlock
      \ skipwhite skipempty keepend

" The bracket pairs keep an outer region open across nested delimiters
" and shield the spaces inside groupings from value termination:
"   a={ b: { c: 1 } } d=2
" markoTSDelim is deliberately unlinked: delimiters render plain.
syn cluster markoExpr contains=@markoTS,markoTSBraces,markoTSParens,markoTSBrackets
for [s:pair, s:open, s:close] in [["Braces", '{', '}'], ["Parens", '(', ')'], ["Brackets", '\[', ']']]
  exe 'syn region markoTS' . s:pair . ' contained transparent matchgroup=markoTSDelim'
        \ . ' start="' . s:open . '" end="' . s:close . '"'
        \ . ' contains=@markoExpr extend'
endfor
unlet s:pair s:open s:close

" html-mode "//" and "/* */" comments open wherever whitespace precedes
" the slash (a URL's "//" follows ":", so it stays plain); concise context
" takes only the line-anchored forms, defined second so they win at a line
" start and keep their fold and indent handling:
"   // note    <p>done // for now</p>    <a href="https://x.co">plain</a>
" No comment item may take "display": a match skipped during offscreen
" state computation exposes its text, and a "<tag" inside a comment would
" open a body whose highlighting depends on scroll position.
syn match markoHtmlComment "\%(^\|\s\)\@1<=//.*$" contains=@Spell
syn region markoHtmlComment start="\%(^\|\s\)\@1<=/\*" end="\*/" contains=@Spell fold
syn region markoComment start="<!--" end="-->" contains=@Spell fold
syn match markoComment "^\s*//.*$" contains=@Spell
syn region markoComment start="^\s*/\*" end="\*/" contains=@Spell fold
syn region markoTagComment contained start="/\*" end="\*/" extend
syn match markoTagComment contained "//.*"

" Declarations before CDATA: both open at "<!" and the later wins:
"   <!doctype html>    <?xml version="1.0"?>    <![CDATA[ raw ]]>
syn region markoDeclaration start="<!\(--\)\@!" end=">"
syn region markoDeclaration start="<?" end=">"
syn region markoCData start="<!\[CDATA\[" end="]]>"

" Placeholders interpolate into text; backslashes escape pairwise:
"   ${user.name}    $!{rawHtml}    \${literal}    \\${live}
" markoEscape must never take "display" (it exists to suppress
" markoPlaceholder); it consumes an escaped "$", or stops before a "${"
" an even backslash run leaves live.
syn match markoEscape "\%(\\\\\)*\%(\\\$!\={\|\\\\\ze\$!\={\)"
syn region markoPlaceholder matchgroup=markoPlaceholderDelim
      \ start="\$!\={" end="}"
      \ contains=@markoExpr extend
" The no-"extend" variant for keepend parsed-text bodies and the CSS
" contexts: an unterminated "\${" must stop at the container's close.
syn region markoPlaceholderText contained matchgroup=markoPlaceholderDelim
      \ start="\$!\={" end="}"
      \ contains=@markoExpr
      \ containedin=cssDefinition,cssAttrRegion,cssStringQ,cssStringQQ

syn match markoEntity "&\%(#\d\+\|#[xX]\x\+\|\w\+\);" display

" Scriptlets; the whitespace after "$" keeps line-start placeholders out.
" No keepend: an open bracket continues, as the parser's group tracking
" does.  The "$ {" block form is second, so it wins where both start:
"   $ count += 1        $ { let total = 0; }
"   $ const rows = [
"       "a",
"     ]
syn region markoScriptlet matchgroup=markoScriptletDelim
      \ start="^\s*\$\s\+" end="$"
      \ contains=@markoExpr
syn region markoScriptlet matchgroup=markoScriptletDelim
      \ start="^\s*\$\s\+{" end="};\="
      \ contains=@markoExpr

" "--" marks the rest of the line as text; at end of line it opens an
" indented block instead:
"   p -- some text
"   p --
"     A block of text, <b>html mode</b>.
" The inline form is a one-line html region, so later dash runs on the
" line sit inside it and are never delimiters (the parser's rule), and
" keepend bounds what the line opens.  Both forms stand down on a line
" whose first non-blank is "<" (html content, where dashes are text).
" They overlap at a trailing "--": the nextgroup form is second and wins,
" and must not take "display".  A bare "--" line belongs to the
" later-defined markoTextDelimBlock.
syn region markoInlineText oneline keepend matchgroup=markoBlockDelim
      \ start="\%#=1\%(^\s*<.\{-}\)\@200<!\%(^\|\s\)\@1<=--\+\ze\s" end="$"
      \ contains=@markoHtmlContent
syn match markoBlockDelim
      \ "\%#=1\%(^\s*<.\{-}\)\@200<!\%(^\|\s\)\@1<=--\+\s*$"
      \ nextgroup=markoTextIndent skipnl
" The shared block body: its indent is the first following line's leading
" whitespace run, blank lines included (the parser's rule); an empty run
" leaves only the column-0 delimiter close, the dedent end being a
" negative lookahead on an empty match.
let s:indent_block = ' start="^\z(\s*\)\ze\%(\S\|$\)"'
      \ . ' matchgroup=markoBlockDelim end="^\z1--\+\s*$"'
      \ . ' matchgroup=NONE end="^\%(\z1\)\@!\ze\s*\S"'
exe 'syn region markoTextIndent contained' . s:indent_block
      \ . ' contains=@markoHtmlContent'

" A name may hold ":" (not the ":=" of a bound value) and any keyword
" character, and must not match a dynamic tag name's "${":
"   size="large"    total:=sum    xml:lang="es"    <spinner café="ok"/>
" An unquoted value ends at whitespace or the mode's terminators, except
" that the parser continues across whitespace flanked by an operator:
"   if=tag === "select"    content=a.desc ?? b.desc    onClick=(e) => go(e)
syn match markoAttrName contained "\%#=1\%(\$!\={\)\@![[:alnum:]_$@]\%(\k\|[$.]\|:=\@!\)*" display
syn match markoSpread contained "\.\.\." display
syn region markoString contained start=+\z(["']\)+ skip=+\\\z1+ end=+\z1+ contains=@Spell

" Regions so an interpolation can sit inside one (no keepend: the
" placeholder carries the region past its "}"):
"   <div.card#main>    <div#item-${id}>
syn region markoShorthandId contained oneline
      \ start="#[-[:alnum:]_$]\@=" end="[-[:alnum:]_$]\@!"
      \ contains=markoPlaceholder
syn region markoShorthandClass contained oneline
      \ start="\.[-[:alnum:]_$]\@=" end="[-[:alnum:]_$]\@!"
      \ contains=markoPlaceholder

" Tag variables, arguments, |parameters|, <type args> and method bodies:
"   <let/count=1/>    <for|item, i| of=list>    <while(cond)>
"   <generic-list<string>>    <button onClick(e) { handle(e) }>
" Params and type args hug the preceding name, so a "|" or "<" inside an
" expression cannot open them; params and the plain type-args form are
" oneline so an unmatched delimiter stops at its line.
syn match markoTagVar contained "/\%([[:alnum:]_$]\+\|\ze\s*[{[]\)"
      \ nextgroup=markoTagVarDestructure skipwhite display
syn region markoTagVarDestructure contained matchgroup=markoTagDelim
      \ start="\[" end="]"
      \ contains=@markoExpr extend
syn region markoArgs contained matchgroup=markoTagDelim
      \ start="(" end=")"
      \ contains=@markoExpr extend
syn region markoParams contained oneline matchgroup=markoTagDelim
      \ start="\%(\k\|[$)\]}>]\)\@4<=|" skip="||" end="|"
      \ contains=@markoExpr
syn region markoTypeArgs contained oneline matchgroup=markoTagDelim
      \ start="\%(\k\|\$\)\@4<=<" end=">"
      \ contains=@typescriptType,markoTypeArgs
" The braced form spans lines: the object type bounds it, and the parser
" reads "<{" after a name in tag scope as type args too.
syn region markoTypeArgs contained matchgroup=markoTagDelim
      \ start="\%(\k\|\$\)\@4<=<\ze\s*{" end=">"
      \ contains=@typescriptType,markoTypeArgs extend
syn region markoMethodBody contained matchgroup=markoTagDelim
      \ start="{" end="}"
      \ contains=@markoExpr extend

" The three value variants differ only in terminators: html ends at ","
" "/>" or the tag's ">"; concise at "," ";" or whitespace-led "--" (">"
" is a comparison there); grouped at "," or "]".  Defined after markoArgs
" so a "...spread" value wins at "(".  keepend bounds foreign TypeScript
" at the value's end; the markoTS* and yats groups carry extend and punch
" through.  A value survives its line end when either side of the break
" is an operator in html mode (the lookahead crosses blank lines), only
" a trailing one in concise:
"   <a href=translated
"        ? localizeUrl($global.url.href, { locale }).href
"        : baseHref>
" s:val_nocont, the trailing set, mirrors the parser: "=>" and ">>"
" continue but a bare ">" ends (operator only outside type position,
" untrackable, and honoring it swallowed "</div>"-style line ends;
" mid-line "x > 1" continues via the break end's own guard); single
" "+"/"-" continue, postfix "i++" ends; unary keywords count unless a
" word character precedes ("a-new Date()" stays whole), binary and type
" keywords only after whitespace ("class=step-in" ends); a trailing "."
" continues when a word character follows, across blank lines.  A "/"
" counts only when spaces flank it (ahead of the break it is ambiguous
" with "/>"), and the break demands a non-space before the space, so a
" continuation line's indent cannot end the value it continues:
"   ratio=total / count max=10
"   total=base +
"     tax
let s:val_nocont = '[&*^:=!<%|?~]\@1<!\%(=>\|>>\)\@2<!\%(+\@1<!+\|-\@1<!-\)\@1<!\%(\s/\)\@2<!'
      \ . '\%([0-9A-Za-z_$.]\@1<!\%(async\|await\|class\|function\|new\|typeof\|void\)\|\s\%(as\|extends\|instanceof\|in\|satisfies\|asserts\|infer\|is\|keyof\|readonly\|unique\)\)\@12<!'
      \ . '\%(\.\@1<=\_s*[0-9A-Za-z_$]\)\@!'
" Cheap zero-width lead tests keep the wide lookbehinds off most columns.
" s:val_last matches after the line's last non-blank, so trailing spaces
" and blank lines never host a value end.
let s:val_last = '\%#=1\%(\s*$\)\@=' . s:val_nocont . '\S\@1<='
let s:val_break = '\%#=1\s\@=>\@1<!' . s:val_nocont . '\S\@1<=\s'
let s:val_op = '[&*^!<%|~+?:={(]\|\.\%(\_s*\w\)\@=\|\<\%(as\|extends\|instanceof\|in\|satisfies\)\%(\_s\+[^:,=/>; \t]\)\@='
let s:val_head = ' contained matchgroup=markoOperator start=":\==>\@!\s*"'
      \ . ' matchgroup=NONE start="\.\@1<=\%(\.\.\.\)\@3<="'
let s:val_tail = ' contains=@markoExpr keepend extend'
exe 'syn region markoAttrValue' . s:val_head
      \ . ' end="\ze," end="\ze/>" end="=\@1<!\ze>"'
      \ . ' end="' . s:val_last . '\ze\s*\n\%(\_s*\%(' . s:val_op . '\|-\|/[/*>]\@!\)\)\@!"'
      \ . ' end="' . s:val_break . '\%(\_s*\%(' . s:val_op . '\|-\|/[/*>]\@!\)\)\@!"' . s:val_tail
exe 'syn region markoAttrValueConcise' . s:val_head
      \ . ' end="\ze[,;]" end="' . s:val_last . '"'
      \ . ' end="' . s:val_break . '\%(\s*\%(' . s:val_op . '\|--\@!\|/[/*]\@!\|>\)\)\@!"' . s:val_tail
exe 'syn region markoAttrValueInGroup' . s:val_head
      \ . ' end="\ze[,\]]" end="' . s:val_last . '"'
      \ . ' end="' . s:val_break . '\%(\s*\%(' . s:val_op . '\|-\|/[/*]\@!\|>\)\)\@!"' . s:val_tail
unlet s:val_nocont s:val_last s:val_break s:val_op s:val_head s:val_tail

syn cluster markoTagStuff contains=markoTagVar,markoShorthandId,markoShorthandClass,
      \markoAttrName,markoString,markoArgs,markoParams,markoTypeArgs,
      \markoMethodBody,markoSpread,markoTagComment,markoPlaceholder
" The name groups themselves are defined near the end of the file; a
" cluster may name them before they exist.
syn cluster markoTagNames contains=markoTagName,markoTagNameTail,markoAttrTagName,
      \markoTagNameConditional,markoTagNameRepeat,markoTagNameException,
      \markoTagNameStatement,markoTagNameBuiltin

" Attribute groups may span lines.  The lookbehind keeps a spread's array
" literal out; that "[" opens a value, not a group:
"   define [size = "large"]    my-tag ...[1, 2]
syn region markoAttrGroup contained matchgroup=markoTagDelim
      \ start="\%(\.\.\.\)\@3<!\[" end="]"
      \ contains=@markoTagStuff,markoAttrValueInGroup extend

" One list per highlight class.  The builtin list is factored by first
" letter; no name is a prefix of another, so grouping changes nothing.
let s:tag_name_classes = [
      \ ["Conditional", 'if\|else-if\|else'],
      \ ["Repeat", 'for\|while'],
      \ ["Exception", 'try'],
      \ ["Statement", 'await\|return'],
      \ ["Builtin", 'l\%(et\|ifecycle\|og\)\|c\%(onst\|ontext\)\|d\%(ebug\|efine\)\|s\%(tyle\|cript\)\|effect\|id\|macro\|textarea\|html-\%(comment\|style\|script\)'],
      \ ]

" Concise mode: a line-start name is a tag; so are "${tag}", ".class" and
" "#id".  The generic rule is first, so class names, "@" tags and the
" statement tags win over it.  A tag ends at its line unless a comma
" trails or leads the continuation; comments and blank lines may sit
" between, and a blank line never hosts the end.  Brackets, method bodies
" and attr groups carry extend, punching through keepend for multiline
" constructs:
"   link
"     ,rel="canonical"
"     // a comment between continued lines
"     ,href=baseHref
"   input type="text",
"     value=name
" Whitespace-led dashes end the tag and start text.  That end begins at
" the first dash with the space as lookbehind: the space is also the
" value's own break-end, and an end starting inside the value would be
" suppressed by its extend:
"   p ---- some text
let s:concise_tag_end = ' matchgroup=markoTagDelim end=";"'
      \ . ' end="\%#=1\%(,\s*\)\@9<!\%(^\s\{0,60}\)\@61<!\ze\n\%(\%(\s*\%(//.*\|/\*\_.\{-,200}\*/\s*\)\=\n\)\{0,20}\s*,\)\@!"'
      \ . ' end="\s\@1<=\ze-\{2,}\%(\s\|$\)"'
      \ . ' contains=@markoTagStuff,markoAttrGroup,markoAttrValueConcise,markoTagNameTail keepend'
exe 'syn region markoConciseTag matchgroup=markoTagName'
      \ . ' start="^\s*\zs\%(-\@!\k\|\$[{ \t]\@!\)\%(\k\|:\|\${\@!\)*"'
      \ . s:concise_tag_end
exe 'syn region markoConciseTag'
      \ . ' start="^\s*\ze\%(\$!\={\|[.#][-[:alnum:]_$]\)"'
      \ . s:concise_tag_end
for [s:class_suffix, s:name_pattern] in s:tag_name_classes
  exe 'syn region markoConciseTag matchgroup=markoTagName' . s:class_suffix
        \ . ' start="^\s*\zs\%(' . s:name_pattern . '\)\%(\k\|\$\|:=\@!\)\@!"'
        \ . s:concise_tag_end
endfor
exe 'syn region markoConciseTag matchgroup=markoAttrTagName'
      \ . ' start="^\s*\zs@[-[:alnum:]_$:]\+"'
      \ . s:concise_tag_end
unlet s:concise_tag_end

" One TypeScript statement each.  static/server/client are Marko keywords;
" import/export/class take the include's colors.  Defined after the
" concise regions so these names win there.
syn region markoStatement matchgroup=markoStatementKeyword
      \ start="^\s*\zs\%(static\|server\|client\)\>"
      \ matchgroup=NONE start="^\s*\ze\%(import\|export\|class\)\>"
      \ end="$" contains=@markoExpr

" A tag name may be empty (<.card>), dynamic (<${tag}>) or an attribute
" tag (<@body>); an arrow's ">" does not end the tag.
syn region markoTag matchgroup=markoTagDelim
      \ start="<\ze[^/ \t!?<>=]" end="/>" end="\%#=1=\@1<!>"
      \ contains=@markoTagStuff,@markoTagNames,markoAttrValue
" Recovers a close tag no body end consumed, eg a stray one in concise
" context.
syn region markoCloseTag matchgroup=markoTagDelim
      \ start="</" end=">"
      \ contains=@markoTagNames,markoPlaceholder

" The name of a close tag whose "</" a body end consumed, plus its ">".
" It stops before "${", so a dynamic close name's placeholder colors:
"   </${tag}>
syn match markoCloseName
      \ "/\@1<=\%(</\)\@2<=\%(\k\|:\|\$\%(!\={\)\@!\)\+\s*"
      \ nextgroup=markoCloseGt,markoClosePlaceholder display
syn match markoCloseGt contained ">" display
" A dynamic close name's placeholder, chained so the closing ">" keeps
" its color: </${tag}> via the body's nextgroup, </h${size}> via the
" close name's.
syn region markoClosePlaceholder contained matchgroup=markoPlaceholderDelim
      \ start="\$!\={" end="}"
      \ contains=@markoExpr
      \ nextgroup=markoCloseGt,markoCloseTail
syn match markoCloseTail contained "\%(\k\|:\)\+\s*"
      \ nextgroup=markoCloseGt,markoClosePlaceholder display
" The anonymous form (</>): a body end consumed the "</" and there is no
" close name to carry the nextgroup, so the ">" takes its color directly.
syn match markoCloseAnon "\%(</\)\@2<=>" display

" Statement and concise tags are absent: bare text in a body is prose.
" The close-name refinements keep </if> Conditional at any depth; generic
" markoTagName stays out or it would outrank markoCloseName.
syn cluster markoHtmlContent contains=markoTag,markoHtmlBody,markoDynamicBody,
      \markoStyle,markoScript,markoTextareaTag,markoHtmlCommentTag,
      \markoComment,markoHtmlComment,markoCData,markoDeclaration,markoEscape,markoPlaceholder,
      \markoEntity,markoScriptlet,markoCloseName,markoCloseAnon,markoAttrTagName,
      \markoTagNameConditional,markoTagNameRepeat,markoTagNameException,
      \markoTagNameStatement,markoTagNameBuiltin

" Whether "<name" begins a body turns on how its open tag ends: an atomic
" run over the groupings that may hold a ">" finds the structural one,
" and a "/>" there means self-closing, no body:
"   <my-tag onClick=() => go(a > b) />
"   <div onClick() { hidden = a > b }/>
" Nothing else hides a ">" (the parser ends an open tag at any ">" not
" preceded by "="), and the repeat counts bound the scan so a stray "<"
" costs a fixed lookahead; past them no body opens.
let s:tag_end_ahead = '\%(\%(\%(<\%([^<>]\|<\%([^<>]\|<[^<>]\{-,40}>\)\{-,60}>\)\{-,100}>'
      \ . '\|"[^"]\{-,200}"\|' . "'[^']\\{-,200}'"
      \ . '\|`[^`]\{-,200}`'
      \ . '\|(\%(\_[^()]\|(\%(\_[^()]\|([^()]\{-,60})\)\{-,100})\)\{-,300})'
      \ . '\|{\%(\_[^{}]\|{\_[^{}]\{-,100}}\)\{-,300}}'
      \ . '\|=>\|\_[^>]\)\{0,800}\)\@>/\@1<!=\@1<!>\)\@='

" Element bodies: html mode from a non-void, non-self-closing open tag to
" its matching close.  \z1 pairs the names; the end consumes only "</" so
" an inner same-name close cannot end the outer body:
"   <div><div>nested</div>still the outer body</div>
" The excluded names are the parser's void and text lists (<let/x=1>
" takes no close tag; <effect> is in neither and opens a body).  Defined
" after markoTag and the concise regions so a body wins at "<"; a missing
" close leaves the body open, as in html.vim.
exe 'syn region markoHtmlBody'
      \ . ' start=+<\ze\%(\%(area\|base\|br\|col\|embed\|hr\|img\|input\|link\|meta\|param'
      \ .   '\|source\|track\|wbr\|style\|script\|textarea\|html-comment\|html-style'
      \ .   '\|html-script\|let\|const\|id\|log\|debug\|lifecycle\|return\)'
      \ .   '\%(\k\|\$\|:=\@!\)\@!\)\@!'
      \ .   '\z(\%(\k\|[$:]\)\+\)\%(\_s\|[/>|(<.#=]\)\@=' . s:tag_end_ahead . '+'
      \ . ' matchgroup=markoTagDelim'
      \ . ' end="</\ze\z1\s*>" end="</\ze\s*>"'
      \ . ' contains=@markoHtmlContent'
" A dynamic name -- any mix of literal characters and "${...}"
" placeholders -- cannot be paired, so a dynamic body closes at the first
" close tag of dynamic shape, regardless of nesting:
"   <h${size}>heading</h${size}>    <${tag}>body</${tag}>
exe 'syn region markoDynamicBody'
      \ . ' start=+<\ze\%(\%(\k\|:\)*\$!\={\)\@=' . s:tag_end_ahead . '+'
      \ . ' matchgroup=markoTagDelim'
      \ . ' end="</\ze\%(\%(\k\|:\)*\%(\$!\={\_[^{}]*\%({\_[^{}]*}\_[^{}]*\)\{0,3}}\%(\k\|:\)*\)\+\)\=\s*>"'
      \ . ' contains=@markoHtmlContent nextgroup=markoClosePlaceholder'
unlet s:tag_end_ahead

" Standalone delimited blocks hold html content, like markoTextIndent.
" A block closes at its exact delimiter -- same indent, same dash count,
" longer or shorter runs are text -- or on any dedent; a column-0 block
" only at its delimiter (the empty \z1 kills the dedent end).  Defined
" after the markoBlockDelim forms so a bare "--" line opens a block:
"   --
"   A block of text, <b>html mode</b>.
"   --
syn region markoTextDelimBlock matchgroup=markoBlockDelim
      \ start="^\z(\s*\)\z(--\+\)\s*$"
      \ end="^\z1\z2\s*$" end="^\%(\z1\)\@!\ze\s*\S"
      \ contains=@markoHtmlContent

" Parsed-text tags: bodies hold only text and placeholders (style/script
" embed CSS and TypeScript).  Each region consumes only its "<"; the
" markoParsedOpen overlay colors the open tag normally:
"   <style/styles>    <script src="x" async>
" Defined after the generic tag and body regions to win at "<".  The
" "/\@1<!" keeps self-closing tags out; keepend stops an unterminated
" embedded construct at the close tag.
syn region markoParsedOpen contained matchgroup=markoTagDelim
      \ start="<\ze\%(html-\%(style\|script\|comment\)\|style\|script\|textarea\)\>\%(:=\@!\|\$\)\@!"
      \ matchgroup=markoTagDelim end="/\@1<!=\@1<!>"
      \ contains=@markoTagStuff,@markoTagNames,markoAttrValue
" The bounded lookahead for the open tag's own ">", shared by all four.
let s:open_end_ahead = '\%(\%("[^"]\{-,200}"\|''[^'']\{-,200}''\|`[^`]\{-,200}`\|=>\|\_[^>]\)\{-,300}/\@1<!=\@1<!>\)\@='
for [s:name, s:pat, s:body] in [
      \ ['markoStyle', '\%(html-\)\=style', '@markoCSS,markoPlaceholderText,markoParsedOpen keepend fold'],
      \ ['markoScript', '\%(html-\)\=script', '@markoTS,markoPlaceholderText,markoParsedOpen keepend fold'],
      \ ['markoTextareaTag', 'textarea', 'markoPlaceholderText,markoEntity,@Spell,markoParsedOpen keepend'],
      \ ['markoHtmlCommentTag', 'html-comment', 'markoPlaceholderText,@Spell,markoParsedOpen keepend'],
      \ ]
  exe 'syn region ' . s:name
        \ . ' start=+<\ze' . s:pat . '\>\%(:=\@!\|\$\)\@!' . s:open_end_ahead . '+'
        \ . ' matchgroup=markoTagDelim end="</\ze' . s:pat . '\s*>"'
        \ . ' contains=' . s:body
endfor
unlet s:name s:pat s:body
syn region markoStyle matchgroup=markoTagNameBuiltin
      \ start="^\s*style\%([./][^ \t{]*\)\=\s*{" end="}"
      \ contains=@markoCSS,markoPlaceholderText fold
" A trailing "--" on a concise style tag opens a delimited block of CSS;
" the lookbehind claims only the dashes, winning over the generic
" trailing-"--" form.  script works the same way with TypeScript:
"   style/styles --
"     .root { color: red }
"   --
for [s:kind, s:body] in [["Style", '@markoCSS'], ["Script", '@markoTS']]
  exe 'syn match marko' . s:kind . 'Delim'
        \ . ' "\%#=1\%(^\s*' . tolower(s:kind) . '\%(\k\|[$:]\)\@![^;{]*\)\@200<=--\+\s*$"'
        \ . ' nextgroup=marko' . s:kind . 'Text skipnl'
  exe 'syn region marko' . s:kind . 'Text contained' . s:indent_block
        \ . ' contains=' . s:body . ',markoPlaceholderText keepend fold'
endfor
unlet s:kind s:body s:indent_block
unlet s:open_end_ahead

" Names inside "<...>"/"</...>": a name stops before "${" and
" markoTagNameTail resumes after "}"; the tail's lookbehind demands the
" placeholder, so a method body's "}" cannot start one:
"   <h${size}>    <div onClick() { go() }disabled>   "disabled" is an attr
" Generic after attr name, class names after generic: later wins.
syn match markoTagName contained "\%(</\=\)\@2<=\%(-\@!\k\|\$[{ \t]\@!\)\%(\k\|:\|\${\@!\)*" display
syn match markoTagNameTail contained
      \ "}\@1<=\%(\$!\={[^{}]*}\)\@120<=\%(\k\|:\|\${\@!\)\+" display
syn match markoAttrTagName contained "\%#=1\%(</\=\)\@2<=@[-[:alnum:]_$:]\+" display
" The un-contained variants refine markoCloseName after a body's end has
" consumed the "</", so builtin and "@" close names keep their classes.
syn match markoAttrTagName "\%#=1\%(</\)\@2<=@\%(\k\|[$:]\)\+\s*" nextgroup=markoCloseGt display
for [s:class_suffix, s:name_pattern] in s:tag_name_classes
  exe 'syn match markoTagName' . s:class_suffix
        \ . ' contained "\%#=1\%(</\=\)\@2<=\%(' . s:name_pattern . '\)\%(\k\|\$\|:=\@!\)\@!" display'
  exe 'syn match markoTagName' . s:class_suffix
        \ . ' "\%#=1\%(</\)\@2<=\%(' . s:name_pattern . '\)\%(\k\|[$:]\)\@!\s*"'
        \ . ' nextgroup=markoCloseGt display'
endfor
unlet s:tag_name_classes s:class_suffix s:name_pattern

" The includes install sync rules; clear them and restate the keyword set
" ("syn sync clear" clears "syn iskeyword" too; "-" keeps css.vim's
" font-family whole).  fromstart is the only safe strategy -- bodies and
" blocks are unbounded -- and a 5000-line cold parse stays well under a
" second.
syn sync clear
syn sync fromstart
syn iskeyword @,48-57,_,192-255,-

" Scoping regions (tags, bodies, brackets, values) take no link: they
" bound contents that carry their own colors.
hi def link markoComment Comment
hi def link markoTagComment Comment
hi def link markoHtmlComment Comment
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
hi def link markoTagNameTail Statement
hi def link markoCloseName Statement
hi def link markoCloseTail Statement
hi def link markoCloseGt Special
hi def link markoCloseAnon Special
hi def link markoAttrTagName Identifier
hi def link markoTagNameConditional Conditional
hi def link markoTagNameRepeat Repeat
hi def link markoTagNameException Exception
hi def link markoTagNameStatement Statement
hi def link markoTagNameBuiltin Macro
hi def link markoShorthandId Constant
hi def link markoShorthandClass Identifier
hi def link markoStyleDelim Special
hi def link markoScriptDelim Special
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
