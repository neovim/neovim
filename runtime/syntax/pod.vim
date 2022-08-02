" Vim syntax file
" Language:      Perl POD format
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Previously:    Scott Bigham <dsb@killerbunnies.org>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2022 Jun 13

" To add embedded POD documentation highlighting to your syntax file, add
" the commands:
"
"   syn include @Pod <sfile>:p:h/pod.vim
"   syn region myPOD start="^=pod" start="^=head" end="^=cut" keepend contained contains=@Pod
"
" and add myPod to the contains= list of some existing region, probably a
" comment.  The "keepend" flag is needed because "=cut" is matched as a
" pattern in its own right.


" Remove any old syntax stuff hanging around (this is suppressed
" automatically by ":syn include" if necessary).
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" TODO: add supported encodings when we can utilize better performing Vim 8 features
syn match podEncoding	"[0-9A-Za-z_-]\+" contained contains=@NoSpell

" Text of a =head1, =head2 or =item command
syn region podCmdText	start="\S.*$" end="^\ze\s*$" end="^\ze=cut\>" contained contains=podFormat,@NoSpell

" Indent amount of =over command
syn match podOverIndent	"\d*\.\=\d\+\>" contained contains=@NoSpell

" Formatter identifier keyword for =for, =begin and =end commands
syn match podForKeywd	"\S\+" contained contains=@NoSpell

" An indented line, to be displayed verbatim
syn region podVerbatim	start="^\s\+\S.*$" end="^\ze\s*$" end="^\ze=cut\>" contains=@NoSpell

syn region podOrdinary	start="^\S.*$" end="^\ze\s*$" end="^\ze=cut\>" contains=podFormat,podSpecial,@Spell

" Inline textual items handled specially by POD
syn match podSpecial	"\(\<\|&\)\I\i*\(::\I\i*\)*([^)]*)" contains=@NoSpell
syn match podSpecial	"[$@%]\I\i*\(::\I\i*\)*\>" contains=@NoSpell

" Special formatting sequences

syn cluster podFormat contains=podFormat,podFormatError

syn match  podFormatError "[ADGHJKM-RT-WY]<"

syn region podFormat	matchgroup=podFormatDelimiter start="[IBSCLFX]<"              end=">"              contains=@podFormat,@NoSpell
syn region podFormat	matchgroup=podFormatDelimiter start="[IBSCLFX]<<\%(\s\+\|$\)" end="\%(\s\+\|^\)>>" contains=@podFormat,@NoSpell

syn match  podFormat	"Z<>"

syn region podFormat	matchgroup=podFormatDelimiter start="E<" end=">" oneline contains=podEscape,podEscape2,@NoSpell

" HTML entities {{{1
" Source: Pod/Escapes.pm
syn keyword podEscape contained lt gt quot amp apos sol verbar lchevron rchevron nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr deg plusmn sup2 sup3 acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest Agrave Aacute Acirc Atilde Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml Igrave Iacute Icirc Iuml ETH Ntilde Ograve Oacute Ocirc Otilde Ouml times Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig agrave aacute acirc atilde auml aring aelig ccedil egrave eacute ecirc euml igrave iacute icirc iuml eth ntilde ograve oacute ocirc otilde ouml divide oslash ugrave uacute ucirc uuml yacute thorn yuml fnof Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa Lambda Mu Nu Xi Omicron Pi Rho Sigma Tau Upsilon Phi Chi Psi Omega alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigmaf sigma tau upsilon phi chi psi omega thetasym upsih piv bull hellip prime Prime oline frasl weierp image real trade alefsym larr uarr rarr darr harr crarr lArr uArr rArr dArr hArr forall part exist empty nabla isin notin ni prod sum minus lowast radic prop infin ang and or cap cup int there4 sim cong asymp ne equiv le ge sub sup nsub sube supe oplus otimes perp sdot lceil rceil lfloor rfloor lang rang loz spades clubs hearts diams OElig oelig Scaron scaron Yuml circ tilde ensp emsp thinsp zwnj zwj lrm rlm ndash mdash lsquo rsquo sbquo ldquo rdquo bdquo dagger Dagger permil lsaquo rsaquo
" }}}

syn match  podEscape2	"\d\+"     contained contains=@NoSpell
syn match  podEscape2	"0\=x\x\+" contained contains=@NoSpell
syn match  podEscape2	"0\o\+"    contained contains=@NoSpell


" POD commands
syn match podCommand    "^=encoding\>"   nextgroup=podEncoding skipwhite contains=@NoSpell
syn match podCommand    "^=head[1234]\>" nextgroup=podCmdText skipwhite skipnl contains=@NoSpell
syn match podCommand    "^=item\>"       nextgroup=podCmdText skipwhite skipnl contains=@NoSpell
syn match podCommand    "^=over\>"       nextgroup=podOverIndent skipwhite contains=@NoSpell
syn match podCommand    "^=back"         contains=@NoSpell
syn match podCommand    "^=cut"          contains=@NoSpell
syn match podCommand    "^=pod"          contains=@NoSpell
syn match podCommand    "^=for"          nextgroup=podForKeywd skipwhite contains=@NoSpell
syn match podCommand    "^=begin"        nextgroup=podForKeywd skipwhite contains=@NoSpell
syn match podCommand    "^=end"          nextgroup=podForKeywd skipwhite contains=@NoSpell

" Comments

syn keyword podForKeywd comment contained nextgroup=podForComment skipwhite skipnl

if exists("perl_pod_no_comment_fold")
  syn region podBeginComment start="^=begin\s\+comment\s*$" end="^=end\s\+comment\ze\s*$" keepend extend contains=podCommand
  syn region podForComment start="\S.*$" end="^\ze\s*$" end="^\ze=cut\>" contained contains=@Spell,podTodo
else
  syn region podBeginComment start="^=begin\s\+comment\s*$" end="^=end\s\+comment\ze\s*$" keepend extend contains=podCommand,podTodo fold
  syn region podForComment start="\S.*$" end="^\ze\s*$" end="^\ze=cut\>" contained contains=@Spell,podTodo fold
endif

syn keyword podTodo contained TODO FIXME XXX

" Plain Pod files
syn region podNonPod			   start="\%^\%(=\w\+\>\)\@!" end="^\ze=\a\w*\>"
syn region podNonPod matchgroup=podCommand start="^=cut\>"	      end="\%$"
syn region podNonPod matchgroup=podCommand start="^=cut\>"	      end="^\ze=\a\w*\>"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link podCommand		Statement
hi def link podBeginComment	Comment
hi def link podForComment	Comment
hi def link podNonPod		Comment
hi def link podTodo		Todo
hi def link podCmdText		String
hi def link podEncoding		Constant
hi def link podOverIndent	Number
hi def link podForKeywd		Identifier
hi def link podVerbatim		PreProc
hi def link podFormat		Identifier
hi def link podFormatDelimiter	podFormat
hi def link podFormatError	Error
hi def link podSpecial		Identifier
hi def link podEscape		Constant
hi def link podEscape2		Number

if exists("perl_pod_spellcheck_headings")
  " Spell-check headings
  syn clear podCmdText
  syn region podCmdText start="\S.*$" end="^\s*$" end="^\ze=cut\>" contained contains=podFormat
endif

if exists("perl_pod_formatting")
  " By default, escapes like C<> are not checked for spelling. Remove B<>
  " and I<> from the list of escapes.
  syn clear podFormat
  syn region podFormat start="[CLF]<[^<]"me=e-1 end=">" contains=@podFormat,@NoSpell
  syn region podFormat start="[CLF]<<\%(\s\+\|$\)" end="\%(\s\+\|^\)>>" contains=@podFormat,@NoSpell

  " Don't spell-check inside E<>, but ensure that the E< itself isn't
  " marked as a spelling mistake.
  syn region podFormat	start="E<" end=">" oneline contains=podEscape,podEscape2,@NoSpell

  " Z<> is a mock formatting code. Ensure Z<> on its own isn't marked as a
  " spelling mistake.
  syn match podFormat   "Z<>" contains=podEscape,podEscape2,@NoSpell

  " These are required so that whatever is *within* B<...>, I<...>, etc. is
  " spell-checked, but not the B, I, ... itself.
  syn match podBoldOpen    "B<" contains=@NoSpell
  syn match podItalicOpen  "I<" contains=@NoSpell
  syn match podNoSpaceOpen "S<" contains=@NoSpell
  syn match podIndexOpen   "X<" contains=@NoSpell

  " Same as above but for the << >> syntax.
  syn match podBoldAlternativeDelimOpen    "B<<\%(\s\+\|$\)" contains=@NoSpell
  syn match podItalicAlternativeDelimOpen  "I<<\%(\s\+\|$\)" contains=@NoSpell
  syn match podNoSpaceAlternativeDelimOpen "S<<\%(\s\+\|$\)" contains=@NoSpell
  syn match podIndexAlternativeDelimOpen   "X<<\%(\s\+\|$\)" contains=@NoSpell

  " Add support for spell checking text inside B<>, I<>, S<> and X<>.
  syn region podBold start="B<[^<]"me=e end=">" contains=podBoldItalic,podBoldOpen
  syn region podBoldAlternativeDelim start="B<<\%(\s\+\|$\)" end="\%(\s\+\|^\)>>" contains=podBoldAlternativeDelimOpen

  syn region podItalic start="I<[^<]"me=e end=">" contains=podItalicBold,podItalicOpen
  syn region podItalicAlternativeDelim start="I<<\%(\s\+\|$\)" end="\%(\s\+\|^\)>>" contains=podItalicAlternativeDelimOpen

  " Nested bold/italic and vice-versa
  syn region podBoldItalic contained start="I<[^<]"me=e end=">"
  syn region podItalicBold contained start="B<[^<]"me=e end=">"

  syn region podNoSpace start="S<[^<]"ms=s-2 end=">"me=e contains=podNoSpaceOpen
  syn region podNoSpaceAlternativeDelim start="S<<\%(\s\+\|$\)"ms=s-2 end="\%(\s\+\|^\)>>"me=e contains=podNoSpaceAlternativeDelimOpen

  syn region podIndex start="X<[^<]"ms=s-2 end=">"me=e contains=podIndexOpen
  syn region podIndexAlternativeDelim start="X<<\%(\s\+\|$\)"ms=s-2 end="\%(\s\+\|^\)>>"me=e contains=podIndexAlternativeDelimOpen

  " Restore this (otherwise B<> is shown as bold inside verbatim)
  syn region podVerbatim start="^\s\+\S.*$" end="^\ze\s*$" end="^\ze=cut\>" contains=@NoSpell

  " Ensure formatted text can be displayed in headings and items
  syn clear podCmdText

  if exists("perl_pod_spellcheck_headings")
    syn match podCmdText ".*$" contained contains=@podFormat,podBold,
          \podBoldAlternativeDelim,podItalic,podItalicAlternativeDelim,
          \podBoldOpen,podItalicOpen,podBoldAlternativeDelimOpen,
          \podItalicAlternativeDelimOpen,podNoSpaceOpen
  else
    syn match podCmdText ".*$" contained contains=@podFormat,podBold,
          \podBoldAlternativeDelim,podItalic,podItalicAlternativeDelim,
          \@NoSpell
  endif

  " Specify how to display these
  hi def podBold term=bold cterm=bold gui=bold

  hi link podBoldAlternativeDelim podBold
  hi link podBoldAlternativeDelimOpen podBold
  hi link podBoldOpen podBold

  hi link podNoSpace                 Identifier
  hi link podNoSpaceAlternativeDelim Identifier

  hi link podIndex                   Identifier
  hi link podIndexAlternativeDelim   Identifier

  hi def podItalic term=italic cterm=italic gui=italic

  hi link podItalicAlternativeDelim podItalic
  hi link podItalicAlternativeDelimOpen podItalic
  hi link podItalicOpen podItalic

  hi def podBoldItalic term=italic,bold cterm=italic,bold gui=italic,bold
  hi def podItalicBold term=italic,bold cterm=italic,bold gui=italic,bold
endif

let b:current_syntax = "pod"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker:
