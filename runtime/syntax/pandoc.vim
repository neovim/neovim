scriptencoding utf-8
" Vim syntax file
" Language:	Pandoc (superset of Markdown)
" Maintainer:	Felipe Morales <hel.sheep@gmail.com>
" Maintainer:	Caleb Maclennan <caleb@alerque.com>
" Upstream:	https://github.com/vim-pandoc/vim-pandoc-syntax/tree/ea3fc415784bdcbae7f0093b80070ca4ff9e44c8
" Contributor:	David Sanson <dsanson@gmail.com>
"		Jorge Israel Peña <jorge.israel.p@gmail.com>
"		Christian Brabandt @chrisbra
" Original Author:	Jeremy Schultz <taozhyn@gmail.com>
" Version: 5.0
" Last Change:	2024 Apr 08
" 2025 Jun 27 by Vim project: sync with upstream (#17598)

if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

" Configuration: {{{1
"
" use conceal? {{{2
if !exists('g:pandoc#syntax#conceal#use')
    let g:pandoc#syntax#conceal#use = 1
endif
"}}}2

" what groups not to use conceal in. works as a blacklist {{{2
if !exists('g:pandoc#syntax#conceal#blacklist')
    let g:pandoc#syntax#conceal#blacklist = []
endif
" }}}2

" cchars used in conceal rules {{{2
" utf-8 defaults (preferred)
if &encoding ==# 'utf-8'
    let s:cchars = {
                \'newline': '↵',
                \'image': '▨',
                \'super': 'ⁿ',
                \'sub': 'ₙ',
                \'strike': 'x̶',
                \'atx': '§',
                \'codelang': 'λ',
                \'codeend': '—',
                \'abbrev': '→',
                \'footnote': '†',
                \'definition': ' ',
                \'li': '•',
                \'html_c_s': '‹',
                \'html_c_e': '›',
                \'quote_s': '“',
                \'quote_e': '”'}
else
    " ascii defaults
    let s:cchars = {
                \'newline': ' ',
                \'image': 'i',
                \'super': '^',
                \'sub': '_',
                \'strike': '~',
                \'atx': '#',
                \'codelang': 'l',
                \'codeend': '-',
                \'abbrev': 'a',
                \'footnote': 'f',
                \'definition': ' ',
                \'li': '*',
                \'html_c_s': '+',
                \'html_c_e': '+'}
endif
" }}}2

" if the user has a dictionary with replacements for the default cchars, use those {{{2
if exists('g:pandoc#syntax#conceal#cchar_overrides')
    let s:cchars = extend(s:cchars, g:pandoc#syntax#conceal#cchar_overrides)
endif
" }}}2

"should the urls in links be concealed? {{{2
if !exists('g:pandoc#syntax#conceal#urls')
    let g:pandoc#syntax#conceal#urls = 0
endif
" should backslashes in escapes be concealed? {{{2
if !exists('g:pandoc#syntax#conceal#backslash')
    let g:pandoc#syntax#conceal#backslash = 0
endif
" }}}2

" leave specified codeblocks as Normal (i.e. 'unhighlighted') {{{2
if !exists('g:pandoc#syntax#codeblocks#ignore')
    let g:pandoc#syntax#codeblocks#ignore = []
endif
" }}}2

" use embedded highlighting for delimited codeblocks where a language is specifed. {{{2
if !exists('g:pandoc#syntax#codeblocks#embeds#use')
    let g:pandoc#syntax#codeblocks#embeds#use = 1
endif
" }}}2

" for what languages and using what vim syntax files highlight those embeds. {{{2
" defaults to None.
if !exists('g:pandoc#syntax#codeblocks#embeds#langs')
    let g:pandoc#syntax#codeblocks#embeds#langs = []
endif
" }}}2

" use italics ? {{{2
if !exists('g:pandoc#syntax#style#emphases')
    let g:pandoc#syntax#style#emphases = 1
endif
" if 0, we don't conceal the emphasis marks, otherwise there wouldn't be a way
" to tell where the styles apply.
if g:pandoc#syntax#style#emphases == 0
    call add(g:pandoc#syntax#conceal#blacklist, 'block')
endif
" }}}2

" underline subscript, superscript and strikeout? {{{2
if !exists('g:pandoc#syntax#style#underline_special')
    let g:pandoc#syntax#style#underline_special = 1
endif
" }}}2

" protect code blocks? {{{2
if !exists('g:pandoc#syntax#protect#codeblocks')
    let g:pandoc#syntax#protect#codeblocks = 1
endif
" }}}2

" use color column? {{{2
if !exists('g:pandoc#syntax#colorcolumn')
    let g:pandoc#syntax#colorcolumn = 0
endif
" }}}2

" highlight new lines? {{{2
if !exists('g:pandoc#syntax#newlines')
    let g:pandoc#syntax#newlines = 1
endif
" }}}

" detect roman-numeral list items? {{{2
if !exists('g:pandoc#syntax#roman_lists')
    let g:pandoc#syntax#roman_lists = 0
endif
" }}}2

" disable syntax highlighting for definition lists? (better performances) {{{2
if !exists('g:pandoc#syntax#use_definition_lists')
    let g:pandoc#syntax#use_definition_lists = 1
endif
" }}}2

" }}}1

" Functions: {{{1
" EnableEmbedsforCodeblocksWithLang {{{2
function! EnableEmbedsforCodeblocksWithLang(entry)
    " prevent embedded language syntaxes from changing 'foldmethod'
    if has('folding')
        let s:foldmethod = &l:foldmethod
        let s:foldtext = &l:foldtext
    endif

    try
        let s:langname = matchstr(a:entry, '^[^=]*')
        let s:langsyntaxfile = matchstr(a:entry, '[^=]*$')
        unlet! b:current_syntax
        exe 'syn include @'.toupper(s:langname).' syntax/'.s:langsyntaxfile.'.vim'
        " We might have just turned off spellchecking by including the file,
        " so we turn it back on here.
        exe 'syntax spell toplevel'
        exe 'syn region pandocDelimitedCodeBlock_' . s:langname . ' start=/\(\_^\( \+\|\t\)\=\(`\{3,}`*\|\~\{3,}\~*\)\s*\%({[^.]*[.=]\)\=' . s:langname . '\>.*\n\)\@<=\_^/' .
                    \' end=/\_$\n\(\( \+\|\t\)\=\(`\{3,}`*\|\~\{3,}\~*\)\_$\n\_$\)\@=/ contained containedin=pandocDelimitedCodeBlock' .
                    \' contains=@' . toupper(s:langname)
        exe 'syn region pandocDelimitedCodeBlockinBlockQuote_' . s:langname . ' start=/>\s\(`\{3,}`*\|\~\{3,}\~*\)\s*\%({[^.]*\.\)\=' . s:langname . '\>/' .
                    \ ' end=/\(`\{3,}`*\|\~\{3,}\~*\)/ contained containedin=pandocDelimitedCodeBlock' .
                    \' contains=@' . toupper(s:langname) .
                    \',pandocDelimitedCodeBlockStart,pandocDelimitedCodeBlockEnd,pandodDelimitedCodeblockLang,pandocBlockQuoteinDelimitedCodeBlock'
    catch /E484/
      echo "No syntax file found for '" . s:langsyntaxfile . "'"
    endtry

    if exists('s:foldmethod') && s:foldmethod !=# &l:foldmethod
        let &l:foldmethod = s:foldmethod
    endif
    if exists('s:foldtext') && s:foldtext !=# &l:foldtext
        let &l:foldtext = s:foldtext
    endif
endfunction
" }}}2

" DisableEmbedsforCodeblocksWithLang {{{2
function! DisableEmbedsforCodeblocksWithLang(langname)
    try
      exe 'syn clear pandocDelimitedCodeBlock_'.a:langname
      exe 'syn clear pandocDelimitedCodeBlockinBlockQuote_'.a:langname
    catch /E28/
      echo "No existing highlight definitions found for '" . a:langname . "'"
    endtry
endfunction
" }}}2

" WithConceal {{{2
function! s:WithConceal(rule_group, rule, conceal_rule)
    let l:rule_tail = ''
    if g:pandoc#syntax#conceal#use != 0
        if index(g:pandoc#syntax#conceal#blacklist, a:rule_group) == -1
            let l:rule_tail = ' ' . a:conceal_rule
        endif
    endif
    execute a:rule . l:rule_tail
endfunction
" }}}2

" }}}1

" Commands: {{{1
command! -buffer -nargs=1 -complete=syntax PandocHighlight call EnableEmbedsforCodeblocksWithLang(<f-args>)
command! -buffer -nargs=1 -complete=syntax PandocUnhighlight call DisableEmbedsforCodeblocksWithLang(<f-args>)
" }}}1

" BASE:
syntax clear
syntax spell toplevel
" }}}1

" Syntax Rules: {{{1

" Embeds: {{{2

" prevent embedded language syntaxes from changing 'foldmethod'
if has('folding')
    let s:foldmethod = &l:foldmethod
endif

" HTML: {{{3
" Set embedded HTML highlighting
syn include @HTML syntax/html.vim
syn match pandocHTML /<\/\?\a\_.\{-}>/ contains=@HTML
" Support HTML multi line comments
syn region pandocHTMLComment start=/<!--\s\=/ end=/\s\=-->/ keepend contains=pandocHTMLCommentStart,pandocHTMLCommentEnd
call s:WithConceal('html_c_s', 'syn match pandocHTMLCommentStart /<!--/ contained', 'conceal cchar='.s:cchars['html_c_s'])
call s:WithConceal('html_c_e', 'syn match pandocHTMLCommentEnd /-->/ contained', 'conceal cchar='.s:cchars['html_c_e'])
" }}}3

" LaTeX: {{{3
" Set embedded LaTex (pandoc extension) highlighting
" Unset current_syntax so the 2nd include will work
unlet b:current_syntax
syn include @LATEX syntax/tex.vim
if index(g:pandoc#syntax#conceal#blacklist, 'inlinemath') == -1
    " Can't use WithConceal here because it will mess up all other conceals
    " when dollar signs are used normally. It must be skipped entirely if
    " inlinemath is blacklisted
    syn region pandocLaTeXInlineMath start=/\v\\@<!\$\S@=/ end=/\v\\@<!\$\d@!/ keepend contains=@LATEX
    syn region pandocLaTeXInlineMath start=/\\\@<!\\(/ end=/\\\@<!\\)/ keepend contains=@LATEX
endif
syn match pandocEscapedDollar /\\\$/ conceal cchar=$
syn match pandocProtectedFromInlineLaTeX /\\\@<!\${.*}\(\(\s\|[[:punct:]]\)\([^$]*\|.*\(\\\$.*\)\{2}\)\n\n\|$\)\@=/ display
" contains=@LATEX
syn region pandocLaTeXMathBlock start=/\$\$/ end=/\$\$/ keepend contains=@LATEX
syn region pandocLaTeXMathBlock start=/\\\@<!\\\[/ end=/\\\@<!\\\]/ keepend contains=@LATEX
syn match pandocLaTeXCommand /\\[[:alpha:]]\+\(\({.\{-}}\)\=\(\[.\{-}\]\)\=\)*/ contains=@LATEX
syn region pandocLaTeXRegion start=/\\begin{\z(.\{-}\)}/ end=/\\end{\z1}/ keepend contains=@LATEX
" we rehighlight sectioning commands, because otherwise tex.vim captures all text until EOF or a new sectioning command
syn region pandocLaTexSection start=/\\\(part\|chapter\|\(sub\)\{,2}section\|\(sub\)\=paragraph\)\*\=\(\[.*\]\)\={/ end=/\}/ keepend
syn match pandocLaTexSectionCmd /\\\(part\|chapter\|\(sub\)\{,2}section\|\(sub\)\=paragraph\)/ contained containedin=pandocLaTexSection
syn match pandocLaTeXDelimiter /[[\]{}]/ contained containedin=pandocLaTexSection
" }}}3

if exists('s:foldmethod') && s:foldmethod !=# &l:foldmethod
    let &l:foldmethod = s:foldmethod
endif

" }}}2

" Titleblock: {{{2
syn region pandocTitleBlock start=/\%^%/ end=/\n\n/ contains=pandocReferenceLabel,pandocReferenceURL,pandocNewLine
call s:WithConceal('titleblock', 'syn match pandocTitleBlockMark /%\ / contained containedin=pandocTitleBlock,pandocTitleBlockTitle', 'conceal')
syn match pandocTitleBlockTitle /\%^%.*\n/ contained containedin=pandocTitleBlock
" }}}2

" Blockquotes: {{{2
syn match pandocBlockQuote /^\s\{,3}>.*\n\(.*\n\@1<!\n\)*/ contains=@Spell,pandocEmphasis,pandocStrong,pandocPCite,pandocSuperscript,pandocSubscript,pandocStrikeout,pandocUListItem,pandocNoFormatted,pandocAmpersandEscape,pandocLaTeXInlineMath,pandocEscapedDollar,pandocLaTeXCommand,pandocLaTeXMathBlock,pandocLaTeXRegion skipnl
syn match pandocBlockQuoteMark /\_^\s\{,3}>/ contained containedin=pandocEmphasis,pandocStrong,pandocPCite,pandocSuperscript,pandocSubscript,pandocStrikeout,pandocUListItem,pandocNoFormatted
" }}}2

" Code Blocks: {{{2
if g:pandoc#syntax#protect#codeblocks == 1
    syn match pandocCodeblock /\([ ]\{4}\|\t\).*$/
endif
syn region pandocCodeBlockInsideIndent   start=/\(\(\d\|\a\|*\).*\n\)\@<!\(^\(\s\{8,}\|\t\+\)\).*\n/ end=/.\(\n^\s*\n\)\@=/ contained
" }}}2

" Links: {{{2

" Base: {{{3
syn region pandocReferenceLabel matchgroup=pandocOperator start=/!\{,1}\\\@<!\^\@<!\[/ skip=/\(\\\@<!\]\]\@=\|`[^`]*`\)/ end=/\\\@<!\]/ keepend display
if g:pandoc#syntax#conceal#urls == 1
    syn region pandocReferenceURL matchgroup=pandocOperator start=/\]\@1<=(/ end=/)/ keepend conceal
else
    syn region pandocReferenceURL matchgroup=pandocOperator start=/\]\@1<=(/ end=/)/ keepend
endif
" let's not consider "a [label] a" as a label, remove formatting - Note: breaks implicit links
syn match pandocNoLabel /\]\@1<!\(\s\{,3}\|^\)\[[^\[\]]\{-}\]\(\s\+\|$\)[\[(]\@!/ contains=pandocPCite
syn match pandocLinkTip /\s*".\{-}"/ contained containedin=pandocReferenceURL contains=@Spell,pandocAmpersandEscape display
call s:WithConceal('image', 'syn match pandocImageIcon /!\[\@=/ display', 'conceal cchar='. s:cchars['image'])
" }}}3

" Definitions: {{{3
syn region pandocReferenceDefinition start=/\[.\{-}\]:/ end=/\(\n\s*".*"$\|$\)/ keepend
syn match pandocReferenceDefinitionLabel /\[\zs.\{-}\ze\]:/ contained containedin=pandocReferenceDefinition display
syn match pandocReferenceDefinitionAddress /:\s*\zs.*/ contained containedin=pandocReferenceDefinition
syn match pandocReferenceDefinitionTip /\s*".\{-}"/ contained containedin=pandocReferenceDefinition,pandocReferenceDefinitionAddress contains=@Spell,pandocAmpersandEscape
" }}}3

" Automatic_links: {{{3
syn match pandocAutomaticLink /<\(https\{0,1}.\{-}\|[A-Za-z0-9!#$%&'*+\-/=?^_`{|}~.]\{-}@[A-Za-z0-9\-]\{-}\.\w\{-}\)>/ contains=NONE
" }}}3

" }}}2

" Citations: {{{2
" parenthetical citations
syn match pandocPCite "\^\@<!\[[^\[\]]\{-}-\{0,1}@[[:alnum:]_][[:digit:][:lower:][:upper:]_:.#$%&\-+?<>~/]*.\{-}\]" contains=pandocEmphasis,pandocStrong,pandocLatex,pandocCiteKey,@Spell,pandocAmpersandEscape display
" in-text citations with location
syn match pandocICite "@[[:alnum:]_][[:digit:][:lower:][:upper:]_:.#$%&\-+?<>~/]*\s\[.\{-1,}\]" contains=pandocCiteKey,@Spell display
" cite keys
syn match pandocCiteKey /\(-\=@[[:alnum:]_][[:digit:][:lower:][:upper:]_:.#$%&\-+?<>~/]*\)/ containedin=pandocPCite,pandocICite contains=@NoSpell display
syn match pandocCiteAnchor /[-@]/ contained containedin=pandocCiteKey display
syn match pandocCiteLocator /[\[\]]/ contained containedin=pandocPCite,pandocICite
" }}}2

" Text Styles: {{{2

" Emphasis: {{{3
call s:WithConceal('block', 'syn region pandocEmphasis matchgroup=pandocOperator start=/\\\@1<!\(\_^\|\s\|[[:punct:]]\)\@<=\*\S\@=/ skip=/\(\*\*\|__\)/ end=/\*\([[:punct:]]\|\a\|\s\|\_$\)\@=/ contains=@Spell,pandocNoFormattedInEmphasis,pandocLatexInlineMath,pandocAmpersandEscape', 'concealends')
call s:WithConceal('block', 'syn region pandocEmphasis matchgroup=pandocOperator start=/\\\@1<!\(\_^\|\s\|[[:punct:]]\)\@<=_\S\@=/ skip=/\(\*\*\|__\)/ end=/\S\@1<=_\([[:punct:]]\|\a\|\s\|\_$\)\@=/ contains=@Spell,pandocNoFormattedInEmphasis,pandocLatexInlineMath,pandocAmpersandEscape', 'concealends')
" }}}3

" Strong: {{{3
call s:WithConceal('block', 'syn region pandocStrong matchgroup=pandocOperator start=/\(\\\@<!\*\)\{2}/ end=/\(\\\@<!\*\)\{2}/ contains=@Spell,pandocNoFormattedInStrong,pandocLatexInlineMath,pandocAmpersandEscape', 'concealends')
call s:WithConceal('block', 'syn region pandocStrong matchgroup=pandocOperator start=/__/ end=/__/ contains=@Spell,pandocNoFormattedInStrong,pandocLatexInlineMath,pandocAmpersandEscape', 'concealends')
" }}}3

" Strong Emphasis: {{{3
call s:WithConceal('block', 'syn region pandocStrongEmphasis matchgroup=pandocOperator start=/\*\{3}\(\S[^*]*\(\*\S\|\n[^*]*\*\S\)\)\@=/ end=/\S\@<=\*\{3}/ contains=@Spell,pandocAmpersandEscape', 'concealends')
call s:WithConceal('block', 'syn region pandocStrongEmphasis matchgroup=pandocOperator start=/\(___\)\S\@=/ end=/\S\@<=___/ contains=@Spell,pandocAmpersandEscape', 'concealends')
" }}}3

" Mixed: {{{3
call s:WithConceal('block', 'syn region pandocStrongInEmphasis matchgroup=pandocOperator start=/\*\*/ end=/\*\*/ contained containedin=pandocEmphasis contains=@Spell,pandocAmpersandEscape', 'concealends')
call s:WithConceal('block', 'syn region pandocStrongInEmphasis matchgroup=pandocOperator start=/__/ end=/__/ contained containedin=pandocEmphasis contains=@Spell,pandocAmpersandEscape', 'concealends')
call s:WithConceal('block', 'syn region pandocEmphasisInStrong matchgroup=pandocOperator start=/\\\@1<!\(\_^\|\s\|[[:punct:]]\)\@<=\*\S\@=/ skip=/\(\*\*\|__\)/ end=/\S\@<=\*\([[:punct:]]\|\s\|\_$\)\@=/ contained containedin=pandocStrong contains=@Spell,pandocAmpersandEscape', 'concealends')
call s:WithConceal('block', 'syn region pandocEmphasisInStrong matchgroup=pandocOperator start=/\\\@<!\(\_^\|\s\|[[:punct:]]\)\@<=_\S\@=/ skip=/\(\*\*\|__\)/ end=/\S\@<=_\([[:punct:]]\|\s\|\_$\)\@=/ contained containedin=pandocStrong contains=@Spell,pandocAmpersandEscape', 'concealends')
" }}}3

" Inline Code: {{{3
" Using single back ticks
call s:WithConceal('inlinecode', 'syn region pandocNoFormatted matchgroup=pandocOperator start=/\\\@<!`/ end=/\\\@<!`/ nextgroup=pandocNoFormattedAttrs', 'concealends')
call s:WithConceal('inlinecode', 'syn region pandocNoFormattedInEmphasis matchgroup=pandocOperator start=/\\\@<!`/ end=/\\\@<!`/ nextgroup=pandocNoFormattedAttrs contained', 'concealends')
call s:WithConceal('inlinecode', 'syn region pandocNoFormattedInStrong matchgroup=pandocOperator start=/\\\@<!`/ end=/\\\@<!`/ nextgroup=pandocNoFormattedAttrs contained', 'concealends')
" Using double back ticks
call s:WithConceal('inlinecode', 'syn region pandocNoFormatted matchgroup=pandocOperator start=/\\\@<!``/ end=/\\\@<!``/ nextgroup=pandocNoFormattedAttrs', 'concealends')
call s:WithConceal('inlinecode', 'syn region pandocNoFormattedInEmphasis matchgroup=pandocOperator start=/\\\@<!``/ end=/\\\@<!``/ nextgroup=pandocNoFormattedAttrs contained', 'concealends')
call s:WithConceal('inlinecode', 'syn region pandocNoFormattedInStrong matchgroup=pandocOperator start=/\\\@<!``/ end=/\\\@<!``/ nextgroup=pandocNoFormattedAttrs contained', 'concealends')
syn match pandocNoFormattedAttrs /{.\{-}}/ contained
" }}}3

" Subscripts: {{{3
syn region pandocSubscript start=/\~\(\([[:graph:]]\(\\ \)\=\)\{-}\~\)\@=/ end=/\~/ keepend
call s:WithConceal('subscript', 'syn match pandocSubscriptMark /\~/ contained containedin=pandocSubscript', 'conceal cchar='.s:cchars['sub'])
" }}}3

" Superscript: {{{3
syn region pandocSuperscript start=/\^\(\([[:graph:]]\(\\ \)\=\)\{-}\^\)\@=/ skip=/\\ / end=/\^/ keepend
call s:WithConceal('superscript', 'syn match pandocSuperscriptMark /\^/ contained containedin=pandocSuperscript', 'conceal cchar='.s:cchars['super'])
" }}}3

" Strikeout: {{{3
syn region pandocStrikeout start=/\~\~/ end=/\~\~/ contains=@Spell,pandocAmpersandEscape keepend
call s:WithConceal('strikeout', 'syn match pandocStrikeoutMark /\~\~/ contained containedin=pandocStrikeout', 'conceal cchar='.s:cchars['strike'])
" }}}3

" }}}2

" Headers: {{{2
syn match pandocAtxHeader /\(\%^\|<.\+>.*\n\|^\s*\n\)\@<=#\{1,6}.*\n/ contains=pandocEmphasis,pandocStrong,pandocNoFormatted,pandocLaTeXInlineMath,pandocEscapedDollar,@Spell,pandocAmpersandEscape,pandocReferenceLabel,pandocReferenceURL display
syn match pandocAtxHeaderMark /\(^#\{1,6}\|\\\@<!#\+\(\s*.*$\)\@=\)/ contained containedin=pandocAtxHeader
call s:WithConceal('atx', 'syn match pandocAtxStart /#/ contained containedin=pandocAtxHeaderMark', 'conceal cchar='.s:cchars['atx'])
syn match pandocSetexHeader /^.\+\n[=]\+$/ contains=pandocEmphasis,pandocStrong,pandocNoFormatted,pandocLaTeXInlineMath,pandocEscapedDollar,@Spell,pandocAmpersandEscape
syn match pandocSetexHeader /^.\+\n[-]\+$/ contains=pandocEmphasis,pandocStrong,pandocNoFormatted,pandocLaTeXInlineMath,pandocEscapedDollar,@Spell,pandocAmpersandEscape
syn match pandocHeaderAttr /{.*}/ contained containedin=pandocAtxHeader,pandocSetexHeader
syn match pandocHeaderID /#[-_:.[:lower:][:upper:]]*/ contained containedin=pandocHeaderAttr
" }}}2

" Line Blocks: {{{2
syn region pandocLineBlock start=/^|/ end=/\(^|\(.*\n|\@!\)\@=.*\)\@<=\n/ transparent
syn match pandocLineBlockDelimiter /^|/ contained containedin=pandocLineBlock
" }}}2

" Tables: {{{2

" Simple: {{{3
syn region pandocSimpleTable start=/\%#=2\(^.*[[:graph:]].*\n\)\@<!\(^.*[[:graph:]].*\n\)\(-\{2,}\s*\)\+\n\n\@!/ end=/\n\n/ containedin=ALLBUT,pandocDelimitedCodeBlock,pandocDelimitedCodeBlockStart,pandocYAMLHeader keepend
syn match pandocSimpleTableDelims /\-/ contained containedin=pandocSimpleTable
syn match pandocSimpleTableHeader /\%#=2\(^.*[[:graph:]].*\n\)\@<!\(^.*[[:graph:]].*\n\)/ contained containedin=pandocSimpleTable

syn region pandocTable start=/\%#=2^\(-\{2,}\s*\)\+\n\n\@!/ end=/\%#=2^\(-\{2,}\s*\)\+\n\n/ containedin=ALLBUT,pandocDelimitedCodeBlock,pandocYAMLHeader keepend
syn match pandocTableDelims /\-/ contained containedin=pandocTable
syn region pandocTableMultilineHeader start=/\%#=2\(^-\{2,}\n\)\@<=./ end=/\%#=2\n-\@=/ contained containedin=pandocTable
" }}}3

" Grid: {{{3
syn region pandocGridTable start=/\%#=2\n\@1<=+-/ end=/+\n\n/ containedin=ALLBUT,pandocDelimitedCodeBlock,pandocYAMLHeader keepend
syn match pandocGridTableDelims /[\|=]/ contained containedin=pandocGridTable
syn match pandocGridTableDelims /\%#=2\([\-+][\-+=]\@=\|[\-+=]\@1<=[\-+]\)/ contained containedin=pandocGridTable
syn match pandocGridTableHeader /\%#=2\(^.*\n\)\(+=.*\)\@=/ contained containedin=pandocGridTable
" }}}3

" Pipe: {{{3
" with beginning and end pipes
syn region pandocPipeTable start=/\%#=2\([+|]\n\)\@<!\n\@1<=|\(.*|\)\@=/ end=/|.*\n\(\n\|{\)/ containedin=ALLBUT,pandocDelimitedCodeBlock,pandocYAMLHeader keepend
" without beginning and end pipes
syn region pandocPipeTable start=/\%#=2^.*\n-.\{-}|/ end=/|.*\n\n/ keepend
syn match pandocPipeTableDelims /[\|\-:+]/ contained containedin=pandocPipeTable
syn match pandocPipeTableHeader /\(^.*\n\)\(|-\)\@=/ contained containedin=pandocPipeTable
syn match pandocPipeTableHeader /\(^.*\n\)\(-\)\@=/ contained containedin=pandocPipeTable
" }}}3

syn match pandocTableHeaderWord /\<.\{-}\>/ contained containedin=pandocGridTableHeader,pandocPipeTableHeader contains=@Spell
" }}}2

" Delimited Code Blocks: {{{2
" this is here because we can override strikeouts and subscripts
syn region pandocDelimitedCodeBlock start=/^\(>\s\)\?\z(\([ ]\+\|\t\)\=\~\{3,}\~*\)/ end=/^\z1\~*/ skipnl contains=pandocDelimitedCodeBlockStart,pandocDelimitedCodeBlockEnd keepend
syn region pandocDelimitedCodeBlock start=/^\(>\s\)\?\z(\([ ]\+\|\t\)\=`\{3,}`*\)/ end=/^\z1`*/ skipnl contains=pandocDelimitedCodeBlockStart,pandocDelimitedCodeBlockEnd keepend
call s:WithConceal('codeblock_start', 'syn match pandocDelimitedCodeBlockStart /\(\(\_^\n\_^\|\%^\)\(>\s\)\?\( \+\|\t\)\=\)\@<=\(\~\{3,}\~*\|`\{3,}`*\)/ contained containedin=pandocDelimitedCodeBlock nextgroup=pandocDelimitedCodeBlockLanguage', 'conceal cchar='.s:cchars['codelang'])
syn match pandocDelimitedCodeBlockLanguage /\(\s\?\)\@<=.\+\(\_$\)\@=/ contained
call s:WithConceal('codeblock_delim', 'syn match pandocDelimitedCodeBlockEnd /\(`\{3,}`*\|\~\{3,}\~*\)\(\_$\n\(>\s\)\?\_$\)\@=/ contained containedin=pandocDelimitedCodeBlock', 'conceal cchar='.s:cchars['codeend'])
syn match pandocBlockQuoteinDelimitedCodeBlock '^>' contained containedin=pandocDelimitedCodeBlock
syn match pandocCodePre /<pre>.\{-}<\/pre>/ skipnl
syn match pandocCodePre /<code>.\{-}<\/code>/ skipnl

" enable highlighting for embedded region in codeblocks if there exists a
" g:pandoc#syntax#codeblocks#embeds#langs *list*.
"
" entries in this list are the language code interpreted by pandoc,
" if this differs from the name of the vim syntax file, append =vimname
" e.g. let g:pandoc#syntax#codeblocks#embeds#langs = ["haskell", "literatehaskell=lhaskell"]
"
if g:pandoc#syntax#codeblocks#embeds#use != 0
    for l in g:pandoc#syntax#codeblocks#embeds#langs
      call EnableEmbedsforCodeblocksWithLang(l)
    endfor
endif
" }}}2

" Abbreviations: {{{2
syn region pandocAbbreviationDefinition start=/^\*\[.\{-}\]:\s*/ end='$' contains=pandocNoFormatted,@Spell,pandocAmpersandEscape
call s:WithConceal('abbrev', 'syn match pandocAbbreviationSeparator /:/ contained containedin=pandocAbbreviationDefinition', 'conceal cchar='.s:cchars['abbrev'])
syn match pandocAbbreviation /\*\[.\{-}\]/ contained containedin=pandocAbbreviationDefinition
call s:WithConceal('abbrev', 'syn match pandocAbbreviationHead /\*\[/ contained containedin=pandocAbbreviation', 'conceal')
call s:WithConceal('abbrev', 'syn match pandocAbbreviationTail /\]/ contained containedin=pandocAbbreviation', 'conceal')
" }}}2

" Footnotes: {{{2
" we put these here not to interfere with superscripts.
syn match pandocFootnoteID /\[\^[^\]]\+\]/ nextgroup=pandocFootnoteDef

"   Inline footnotes
syn region pandocFootnoteDef start=/\^\[/ skip=/\[.\{-}]/ end=/\]/ contains=pandocReferenceLabel,pandocReferenceURL,pandocLatex,pandocPCite,pandocCiteKey,pandocStrong,pandocEmphasis,pandocStrongEmphasis,pandocNoFormatted,pandocSuperscript,pandocSubscript,pandocStrikeout,pandocEnDash,pandocEmDash,pandocEllipses,pandocBeginQuote,pandocEndQuote,@Spell,pandocAmpersandEscape skipnl keepend
call s:WithConceal('footnote', 'syn match pandocFootnoteDefHead /\^\[/ contained containedin=pandocFootnoteDef', 'conceal cchar='.s:cchars['footnote'])
call s:WithConceal('footnote', 'syn match pandocFootnoteDefTail /\]/ contained containedin=pandocFootnoteDef', 'conceal')

" regular footnotes
syn region pandocFootnoteBlock start=/\[\^.\{-}\]:\s*\n*/ end=/^\n^\s\@!/ contains=pandocReferenceLabel,pandocReferenceURL,pandocLatex,pandocPCite,pandocCiteKey,pandocStrong,pandocEmphasis,pandocNoFormatted,pandocSuperscript,pandocSubscript,pandocStrikeout,pandocEnDash,pandocEmDash,pandocNewLine,pandocStrongEmphasis,pandocEllipses,pandocBeginQuote,pandocEndQuote,pandocLaTeXInlineMath,pandocEscapedDollar,pandocLaTeXCommand,pandocLaTeXMathBlock,pandocLaTeXRegion,pandocAmpersandEscape,@Spell skipnl
syn match pandocFootnoteBlockSeparator /:/ contained containedin=pandocFootnoteBlock
syn match pandocFootnoteID /\[\^.\{-}\]/ contained containedin=pandocFootnoteBlock
call s:WithConceal('footnote', 'syn match pandocFootnoteIDHead /\[\^/ contained containedin=pandocFootnoteID', 'conceal cchar='.s:cchars['footnote'])
call s:WithConceal('footnote', 'syn match pandocFootnoteIDTail /\]/ contained containedin=pandocFootnoteID', 'conceal')
" }}}2

" List Items: {{{2
" Unordered lists
syn match pandocUListItem /^>\=\s*[*+-]\s\+-\@!.*$/ nextgroup=pandocUListItem,pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocDelimitedCodeBlock,pandocListItemContinuation contains=@Spell,pandocEmphasis,pandocStrong,pandocNoFormatted,pandocStrikeout,pandocSubscript,pandocSuperscript,pandocStrongEmphasis,pandocStrongEmphasis,pandocPCite,pandocICite,pandocCiteKey,pandocReferenceLabel,pandocLaTeXCommand,pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocReferenceURL,pandocAutomaticLink,pandocFootnoteDef,pandocFootnoteBlock,pandocFootnoteID,pandocAmpersandEscape skipempty display
call s:WithConceal('list', 'syn match pandocUListItemBullet /^>\=\s*\zs[*+-]/ contained containedin=pandocUListItem', 'conceal cchar='.s:cchars['li'])

" Ordered lists
syn match pandocListItem /^\s*(\?\(\d\+\|\l\|\#\|@\)[.)].*$/ nextgroup=pandocListItem,pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocDelimitedCodeBlock,pandocListItemContinuation contains=@Spell,pandocEmphasis,pandocStrong,pandocReferenceURL,pandocNoFormatted,pandocStrikeout,pandocSubscript,pandocSuperscript,pandocStrongEmphasis,pandocStrongEmphasis,pandocPCite,pandocICite,pandocCiteKey,pandocReferenceLabel,pandocLaTeXCommand,pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocAutomaticLink,pandocFootnoteDef,pandocFootnoteBlock,pandocFootnoteID,pandocAmpersandEscape skipempty display

" support for roman numerals up to 'c'
if g:pandoc#syntax#roman_lists != 0
    syn match pandocListItem /^\s*(\?x\=l\=\(i\{,3}[vx]\=\)\{,3}c\{,3}[.)].*$/ nextgroup=pandocListItem,pandocMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocDelimitedCodeBlock,pandocListItemContinuation,pandocAutomaticLink skipempty display
endif
syn match pandocListItemBullet /^(\?.\{-}[.)]/ contained containedin=pandocListItem
syn match pandocListItemBulletId /\(\d\+\|\l\|\#\|@.\{-}\|x\=l\=\(i\{,3}[vx]\=\)\{,3}c\{,3}\)/ contained containedin=pandocListItemBullet

syn match pandocListItemContinuation /^\s\+\([-+*]\s\+\|(\?.\+[).]\)\@<!\([[:upper:][:lower:]_"[]\|\*\S\)\@=.*$/ nextgroup=pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocDelimitedCodeBlock,pandocListItemContinuation,pandocListItem contains=@Spell,pandocEmphasis,pandocStrong,pandocNoFormatted,pandocStrikeout,pandocSubscript,pandocSuperscript,pandocStrongEmphasis,pandocStrongEmphasis,pandocPCite,pandocICite,pandocCiteKey,pandocReferenceLabel,pandocReferenceURL,pandocLaTeXCommand,pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocAutomaticLink,pandocFootnoteDef,pandocFootnoteBlock,pandocFootnoteID,pandocAmpersandEscape contained skipempty display
" }}}2

" Definitions: {{{2
if g:pandoc#syntax#use_definition_lists == 1
    syn region pandocDefinitionBlock start=/^\%(\_^\s*\([`~]\)\1\{2,}\)\@!.*\n\(^\s*\n\)\=\s\{0,2}\([:~]\)\(\3\{2,}\3*\)\@!/ skip=/\n\n\zs\s/ end=/\n\n/ contains=@Spell,pandocDefinitionBlockMark,pandocDefinitionBlockTerm,pandocCodeBlockInsideIndent,pandocEmphasis,pandocStrong,pandocStrongEmphasis,pandocNoFormatted,pandocStrikeout,pandocSubscript,pandocSuperscript,pandocFootnoteID,pandocReferenceURL,pandocReferenceLabel,pandocLaTeXMathBlock,pandocLaTeXInlineMath,pandocEscapedDollar,pandocAutomaticLink,pandocEmDash,pandocEnDash,pandocFootnoteDef,pandocFootnoteBlock,pandocFootnoteID
    syn match pandocDefinitionBlockTerm /^.*\n\(^\s*\n\)\=\(\s*[:~]\)\@=/ contained contains=@Spell,pandocNoFormatted,pandocEmphasis,pandocStrong,pandocLaTeXInlineMath,pandocEscapedDollar,pandocFootnoteDef,pandocFootnoteBlock,pandocFootnoteID nextgroup=pandocDefinitionBlockMark
    call s:WithConceal('definition', 'syn match pandocDefinitionBlockMark /^\s*[:~]/ contained', 'conceal cchar='.s:cchars['definition'])
endif
" }}}2

" Special: {{{2

" New_lines: {{{3
if g:pandoc#syntax#newlines == 1
  call s:WithConceal('newline', 'syn match pandocNewLine /\%(\%(\S\)\@<= \{2,}\|\\\)$/ display containedin=pandocEmphasis,pandocStrong,pandocStrongEmphasis,pandocStrongInEmphasis,pandocEmphasisInStrong', 'conceal cchar='.s:cchars['newline'])
endif
" }}}3

" Emdashes: {{{3
if &encoding ==# 'utf-8'
  call s:WithConceal('emdashes', 'syn match pandocEllipses /\([^-]\)\@<=---\([^-]\)\@=/ display', 'conceal cchar=—')
endif
" }}}3

" Endashes: {{{3
if &encoding ==# 'utf-8'
  call s:WithConceal('endashes', 'syn match pandocEllipses /\([^-]\)\@<=--\([^-]\)\@=/ display', 'conceal cchar=–')
endif
" }}}3

" Ellipses: {{{3
if &encoding ==# 'utf-8'
    call s:WithConceal('ellipses', 'syn match pandocEllipses /\.\.\./ display', 'conceal cchar=…')
endif
" }}}3

" Quotes: {{{3
if &encoding ==# 'utf-8'
    call s:WithConceal('quotes', 'syn match pandocBeginQuote /"\</  containedin=pandocEmphasis,pandocStrong,pandocListItem,pandocListItemContinuation,pandocUListItem display', 'conceal cchar='.s:cchars['quote_s'])
    call s:WithConceal('quotes', 'syn match pandocEndQuote /\(\>[[:punct:]]*\)\@<="[[:blank:][:punct:]\n]\@=/  containedin=pandocEmphasis,pandocStrong,pandocUListItem,pandocListItem,pandocListItemContinuation display', 'conceal cchar='.s:cchars['quote_e'])
endif
" }}}3

" Hrule: {{{3
syn match pandocHRule /^\s*\([*\-_]\)\s*\%(\1\s*\)\{2,}$/ display
" }}}3

" Backslashes: {{{3
if g:pandoc#syntax#conceal#backslash == 1
    syn match pandocBackslash /\v\\@<!\\((re)?newcommand)@!/ containedin=ALLBUT,pandocCodeblock,pandocCodeBlockInsideIndent,pandocNoFormatted,pandocNoFormattedInEmphasis,pandocNoFormattedInStrong,pandocDelimitedCodeBlock,pandocLineBlock,pandocYAMLHeader conceal
endif
" }}}3

" &-escaped Special Characters: {{{3
syn match pandocAmpersandEscape /\v\&(#\d+|#x\x+|[[:alnum:]]+)\;/ contains=@NoSpell
" }}}3

" YAML: {{{2
try
    unlet! b:current_syntax
    syn include @YAML syntax/yaml.vim
catch /E484/
endtry
syn region pandocYAMLHeader start=/\%(\%^\|\_^\s*\n\)\@<=\_^-\{3}\ze\n.\+/ end=/^\([-.]\)\1\{2}$/ keepend contains=@YAML containedin=TOP
" }}}2

" }}}1

" Styling: {{{1
function! s:SetupPandocHighlights()

  hi def link pandocOperator Operator

  " override this for consistency
  hi pandocTitleBlock term=italic gui=italic
  hi def link pandocTitleBlockTitle Directory
  hi def link pandocAtxHeader Title
  hi def link pandocAtxStart Operator
  hi def link pandocSetexHeader Title
  hi def link pandocHeaderAttr Comment
  hi def link pandocHeaderID Identifier

  hi def link pandocLaTexSectionCmd texSection
  hi def link pandocLaTeXDelimiter texDelimiter

  hi def link pandocHTMLComment Comment
  hi def link pandocHTMLCommentStart Delimiter
  hi def link pandocHTMLCommentEnd Delimiter
  hi def link pandocBlockQuote Comment
  hi def link pandocBlockQuoteMark Comment
  hi def link pandocAmpersandEscape Special

  " if the user sets g:pandoc#syntax#codeblocks#ignore to contain
  " a codeblock type, don't highlight it so that it remains Normal
  if index(g:pandoc#syntax#codeblocks#ignore, 'definition') == -1
    hi def link pandocCodeBlockInsideIndent String
  endif

  if index(g:pandoc#syntax#codeblocks#ignore, 'delimited') == -1
    hi def link pandocDelimitedCodeBlock Special
  endif

  hi def link pandocDelimitedCodeBlockStart Delimiter
  hi def link pandocDelimitedCodeBlockEnd Delimiter
  hi def link pandocDelimitedCodeBlockLanguage Comment
  hi def link pandocBlockQuoteinDelimitedCodeBlock pandocBlockQuote
  hi def link pandocCodePre String

  hi def link pandocLineBlockDelimiter Delimiter

  hi def link pandocListItemBullet Operator
  hi def link pandocUListItemBullet Operator
  hi def link pandocListItemBulletId Identifier

  hi def link pandocReferenceLabel Label
  hi def link pandocReferenceURL Underlined
  hi def link pandocLinkTip Identifier
  hi def link pandocImageIcon Operator

  hi def link pandocReferenceDefinition Operator
  hi def link pandocReferenceDefinitionLabel Label
  hi def link pandocReferenceDefinitionAddress Underlined
  hi def link pandocReferenceDefinitionTip Identifier

  hi def link pandocAutomaticLink Underlined

  hi def link pandocDefinitionBlockTerm Identifier
  hi def link pandocDefinitionBlockMark Operator

  hi def link pandocSimpleTableDelims Delimiter
  hi def link pandocSimpleTableHeader pandocStrong
  hi def link pandocTableMultilineHeader pandocStrong
  hi def link pandocTableDelims Delimiter
  hi def link pandocGridTableDelims Delimiter
  hi def link pandocGridTableHeader Delimiter
  hi def link pandocPipeTableDelims Delimiter
  hi def link pandocPipeTableHeader Delimiter
  hi def link pandocTableHeaderWord pandocStrong

  hi def link pandocAbbreviationHead Type
  hi def link pandocAbbreviation Label
  hi def link pandocAbbreviationTail Type
  hi def link pandocAbbreviationSeparator Identifier
  hi def link pandocAbbreviationDefinition Comment

  hi def link pandocFootnoteID Label
  hi def link pandocFootnoteIDHead Type
  hi def link pandocFootnoteIDTail Type
  hi def link pandocFootnoteDef Comment
  hi def link pandocFootnoteDefHead Type
  hi def link pandocFootnoteDefTail Type
  hi def link pandocFootnoteBlock Comment
  hi def link pandocFootnoteBlockSeparator Operator

  hi def link pandocPCite Operator
  hi def link pandocICite Operator
  hi def link pandocCiteKey Label
  hi def link pandocCiteAnchor Operator
  hi def link pandocCiteLocator Operator

  if g:pandoc#syntax#style#emphases == 1
      hi pandocEmphasis gui=italic cterm=italic
      hi pandocStrong gui=bold cterm=bold
      hi pandocStrongEmphasis gui=bold,italic cterm=bold,italic
      hi pandocStrongInEmphasis gui=bold,italic cterm=bold,italic
      hi pandocEmphasisInStrong gui=bold,italic cterm=bold,italic
      if !exists('s:hi_tail')
          let s:fg = '' " Vint can't figure ou these get set dynamically
          let s:bg = '' " so initialize them manually first
          for s:i in ['fg', 'bg']
              let s:tmp_val = synIDattr(synIDtrans(hlID('String')), s:i)
              let s:tmp_ui =  has('gui_running') || (has('termguicolors') && &termguicolors) ? 'gui' : 'cterm'
              if !empty(s:tmp_val) && s:tmp_val != -1
                  exe 'let s:'.s:i . ' = "'.s:tmp_ui.s:i.'='.s:tmp_val.'"'
              else
                  exe 'let s:'.s:i . ' = ""'
              endif
          endfor
          let s:hi_tail = ' '.s:fg.' '.s:bg
      endif
      exe 'hi pandocNoFormattedInEmphasis gui=italic cterm=italic'.s:hi_tail
      exe 'hi pandocNoFormattedInStrong gui=bold cterm=bold'.s:hi_tail
  endif
  hi def link pandocNoFormatted String
  hi def link pandocNoFormattedAttrs Comment
  hi def link pandocSubscriptMark Operator
  hi def link pandocSuperscriptMark Operator
  hi def link pandocStrikeoutMark Operator
  if g:pandoc#syntax#style#underline_special == 1
      hi pandocSubscript gui=underline cterm=underline
      hi pandocSuperscript gui=underline cterm=underline
      hi pandocStrikeout gui=underline cterm=underline
  endif
  hi def link pandocNewLine Error
  hi def link pandocHRule Delimiter
endfunction

call s:SetupPandocHighlights()

" }}}1

let b:current_syntax = 'pandoc'

syntax sync clear
syntax sync minlines=1000

let &cpoptions = s:cpo_save
unlet s:cpo_save

" vim: set fdm=marker foldlevel=0:
