" Vim syntax file
" Language:     FlexWiki, http://www.flexwiki.com/
" Maintainer:   George V. Reilly  <george@reilly.org>
" Home:         http://www.georgevreilly.com/vim/flexwiki/
" Other Home:   http://www.vim.org/scripts/script.php?script_id=1529
" Author:       George V. Reilly
" Filenames:    *.wiki
" Last Change: Wed Apr 26 11:00 PM 2006 P
" Version:      0.3

" Note: The horrible regexps were reverse-engineered from
" FlexWikiCore\EngineSource\Formatter.cs, with help from the Regex Analyzer
" in The Regulator, http://regulator.sourceforge.net/  .NET uses Perl-style
" regexes, which use a different syntax than Vim (fewer \s).
" The primary test case is FlexWiki\FormattingRules.wiki

" Quit if syntax file is already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

" A WikiWord (unqualifiedWikiName)
syntax match  flexwikiWord          /\%(_\?\([A-Z]\{2,}[a-z0-9]\+[A-Za-z0-9]*\)\|\([A-Z][a-z0-9]\+[A-Za-z0-9]*[A-Z]\+[A-Za-z0-9]*\)\)/
" A [bracketed wiki word]
syntax match  flexwikiWord          /\[[[:alnum:]\s]\+\]/

" text: "this is a link (optional tooltip)":http://www.microsoft.com
" TODO: check URL syntax against RFC
syntax match flexwikiLink           `\("[^"(]\+\((\([^)]\+\))\)\?":\)\?\(https\?\|ftp\|gopher\|telnet\|file\|notes\|ms-help\):\(\(\(//\)\|\(\\\\\)\)\+[A-Za-z0-9:#@%/;$~_?+-=.&\-\\\\]*\)`

" text: *strong* 
syntax match flexwikiBold           /\(^\|\W\)\zs\*\([^ ].\{-}\)\*/
" '''bold'''
syntax match flexwikiBold           /'''\([^'].\{-}\)'''/

" text: _emphasis_
syntax match flexwikiItalic         /\(^\|\W\)\zs_\([^ ].\{-}\)_/
" ''italic''
syntax match flexwikiItalic         /''\([^'].\{-}\)''/

" ``deemphasis``
syntax match flexwikiDeEmphasis     /``\([^`].\{-}\)``/

" text: @code@ 
syntax match flexwikiCode           /\(^\|\s\|(\|\[\)\zs@\([^@]\+\)@/

"   text: -deleted text- 
syntax match flexwikiDelText        /\(^\|\s\+\)\zs-\([^ <a ]\|[^ <img ]\|[^ -].*\)-/

"   text: +inserted text+ 
syntax match flexwikiInsText        /\(^\|\W\)\zs+\([^ ].\{-}\)+/

"   text: ^superscript^ 
syntax match flexwikiSuperScript    /\(^\|\W\)\zs^\([^ ].\{-}\)^/

"   text: ~subscript~ 
syntax match flexwikiSubScript      /\(^\|\W\)\zs\~\([^ ].\{-}\)\~/

"   text: ??citation?? 
syntax match flexwikiCitation       /\(^\|\W\)\zs??\([^ ].\{-}\)??/

" Emoticons: must come after the Textilisms, as later rules take precedence
" over earlier ones. This match is an approximation for the ~70 distinct
" patterns that FlexWiki knows.
syntax match flexwikiEmoticons      /\((.)\|:[()|$@]\|:-[DOPS()\]|$@]\|;)\|:'(\)/

" Aggregate all the regular text highlighting into flexwikiText
syntax cluster flexwikiText contains=flexwikiItalic,flexwikiBold,flexwikiCode,flexwikiDeEmphasis,flexwikiDelText,flexwikiInsText,flexwikiSuperScript,flexwikiSubScript,flexwikiCitation,flexwikiLink,flexwikiWord,flexwikiEmoticons

" single-line WikiPropertys
syntax match flexwikiSingleLineProperty /^:\?[A-Z_][_a-zA-Z0-9]\+:/

" TODO: multi-line WikiPropertys

" Header levels, 1-6
syntax match flexwikiH1             /^!.*$/
syntax match flexwikiH2             /^!!.*$/
syntax match flexwikiH3             /^!!!.*$/
syntax match flexwikiH4             /^!!!!.*$/
syntax match flexwikiH5             /^!!!!!.*$/
syntax match flexwikiH6             /^!!!!!!.*$/

" <hr>, horizontal rule
syntax match flexwikiHR             /^----.*$/

" Formatting can be turned off by ""enclosing it in pairs of double quotes""
syntax match flexwikiEscape         /"".\{-}""/

" Tables. Each line starts and ends with '||'; each cell is separated by '||'
syntax match flexwikiTable          /||/

" Bulleted list items start with one or tabs, followed by whitespace, then '*'
" Numeric  list items start with one or tabs, followed by whitespace, then '1.'
" Eight spaces at the beginning of the line is equivalent to the leading tab.
syntax match flexwikiList           /^\(\t\| \{8}\)\s*\(\*\|1\.\).*$/   contains=@flexwikiText

" Treat all other lines that start with spaces as PRE-formatted text.
syntax match flexwikiPre            /^[ \t]\+[^ \t*1].*$/


" Link FlexWiki syntax items to colors
hi def link flexwikiH1                    Title
hi def link flexwikiH2                    flexwikiH1
hi def link flexwikiH3                    flexwikiH2
hi def link flexwikiH4                    flexwikiH3
hi def link flexwikiH5                    flexwikiH4
hi def link flexwikiH6                    flexwikiH5
hi def link flexwikiHR                    flexwikiH6
    
hi def flexwikiBold                       term=bold cterm=bold gui=bold
hi def flexwikiItalic                     term=italic cterm=italic gui=italic

hi def link flexwikiCode                  Statement
hi def link flexwikiWord                  Underlined

hi def link flexwikiEscape                Todo
hi def link flexwikiPre                   PreProc
hi def link flexwikiLink                  Underlined
hi def link flexwikiList                  Type
hi def link flexwikiTable                 Type
hi def link flexwikiEmoticons             Constant
hi def link flexwikiDelText               Comment
hi def link flexwikiDeEmphasis            Comment
hi def link flexwikiInsText               Constant
hi def link flexwikiSuperScript           Constant
hi def link flexwikiSubScript             Constant
hi def link flexwikiCitation              Constant

hi def link flexwikiSingleLineProperty    Identifier

let b:current_syntax="FlexWiki"

" vim:tw=0:
