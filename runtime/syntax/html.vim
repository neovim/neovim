" Vim syntax file
" Language:             HTML
" Maintainer:           Jorge Maldonado Ventura <jorgesumle@freakspot.net>
" Previous Maintainer:  Claudio Fleiner <claudio@fleiner.com>
" Repository:           https://notabug.org/jorgesumle/vim-html-syntax
" Last Change:          2018 Apr 7
" Included patch from Jorge Maldonado Ventura to fix rendering
"

" Please check :help html.vim for some comments and a description of the options

" quit when a syntax file was already loaded
if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'html'
endif

let s:cpo_save = &cpo
set cpo&vim

syntax spell toplevel

syn case ignore

" mark illegal characters
syn match htmlError "[<>&]"


" tags
syn region  htmlString   contained start=+"+ end=+"+ contains=htmlSpecialChar,javaScriptExpression,@htmlPreproc
syn region  htmlString   contained start=+'+ end=+'+ contains=htmlSpecialChar,javaScriptExpression,@htmlPreproc
syn match   htmlValue    contained "=[\t ]*[^'" \t>][^ \t>]*"hs=s+1   contains=javaScriptExpression,@htmlPreproc
syn region  htmlEndTag             start=+</+      end=+>+ contains=htmlTagN,htmlTagError
syn region  htmlTag                start=+<[^/]+   end=+>+ fold contains=htmlTagN,htmlString,htmlArg,htmlValue,htmlTagError,htmlEvent,htmlCssDefinition,@htmlPreproc,@htmlArgCluster
syn match   htmlTagN     contained +<\s*[-a-zA-Z0-9]\++hs=s+1 contains=htmlTagName,htmlSpecialTagName,@htmlTagNameCluster
syn match   htmlTagN     contained +</\s*[-a-zA-Z0-9]\++hs=s+2 contains=htmlTagName,htmlSpecialTagName,@htmlTagNameCluster
syn match   htmlTagError contained "[^>]<"ms=s+1


" tag names
syn keyword htmlTagName contained address applet area a base basefont
syn keyword htmlTagName contained big blockquote br caption center
syn keyword htmlTagName contained cite code dd dfn dir div dl dt font
syn keyword htmlTagName contained form hr html img
syn keyword htmlTagName contained input isindex kbd li link map menu
syn keyword htmlTagName contained meta ol option param pre p samp span
syn keyword htmlTagName contained select small sub sup
syn keyword htmlTagName contained table td textarea th tr tt ul var xmp
syn match htmlTagName contained "\<\(b\|i\|u\|h[1-6]\|em\|strong\|head\|body\|title\)\>"

" new html 4.0 tags
syn keyword htmlTagName contained abbr acronym bdo button col label
syn keyword htmlTagName contained colgroup fieldset iframe ins legend
syn keyword htmlTagName contained object optgroup q s tbody tfoot thead

" new html 5 tags
syn keyword htmlTagName contained article aside audio bdi canvas data
syn keyword htmlTagName contained datalist details embed figcaption figure
syn keyword htmlTagName contained footer header hgroup keygen main mark
syn keyword htmlTagName contained menuitem meter nav output picture
syn keyword htmlTagName contained progress rb rp rt rtc ruby section
syn keyword htmlTagName contained slot source template time track video wbr

" legal arg names
syn keyword htmlArg contained action
syn keyword htmlArg contained align alink alt archive background bgcolor
syn keyword htmlArg contained border bordercolor cellpadding
syn keyword htmlArg contained cellspacing checked class clear code codebase color
syn keyword htmlArg contained cols colspan content coords enctype face
syn keyword htmlArg contained gutter height hspace id
syn keyword htmlArg contained link lowsrc marginheight
syn keyword htmlArg contained marginwidth maxlength method name prompt
syn keyword htmlArg contained rel rev rows rowspan scrolling selected shape
syn keyword htmlArg contained size src start target text type url
syn keyword htmlArg contained usemap ismap valign value vlink vspace width wrap
syn match   htmlArg contained "\<\(http-equiv\|href\|title\)="me=e-1

" aria attributes
syn match htmlArg contained "\<\(aria-activedescendant\|aria-atomic\)\>"
syn match htmlArg contained "\<\(aria-autocomplete\|aria-busy\|aria-checked\)\>"
syn match htmlArg contained "\<\(aria-colcount\|aria-colindex\|aria-colspan\)\>"
syn match htmlArg contained "\<\(aria-controls\|aria-current\)\>"
syn match htmlArg contained "\<\(aria-describedby\|aria-details\)\>"
syn match htmlArg contained "\<\(aria-disabled\|aria-dropeffect\)\>"
syn match htmlArg contained "\<\(aria-errormessage\|aria-expanded\)\>"
syn match htmlArg contained "\<\(aria-flowto\|aria-grabbed\|aria-haspopup\)\>"
syn match htmlArg contained "\<\(aria-hidden\|aria-invalid\)\>"
syn match htmlArg contained "\<\(aria-keyshortcuts\|aria-label\)\>"
syn match htmlArg contained "\<\(aria-labelledby\|aria-level\|aria-live\)\>"
syn match htmlArg contained "\<\(aria-modal\|aria-multiline\)\>"
syn match htmlArg contained "\<\(aria-multiselectable\|aria-orientation\)\>"
syn match htmlArg contained "\<\(aria-owns\|aria-placeholder\|aria-posinset\)\>"
syn match htmlArg contained "\<\(aria-pressed\|aria-readonly\|aria-relevant\)\>"
syn match htmlArg contained "\<\(aria-required\|aria-roledescription\)\>"
syn match htmlArg contained "\<\(aria-rowcount\|aria-rowindex\|aria-rowspan\)\>"
syn match htmlArg contained "\<\(aria-selected\|aria-setsize\|aria-sort\)\>"
syn match htmlArg contained "\<\(aria-valuemax\|aria-valuemin\)\>"
syn match htmlArg contained "\<\(aria-valuenow\|aria-valuetext\)\>"
syn keyword htmlArg contained role

" Netscape extensions
syn keyword htmlTagName contained frame noframes frameset nobr blink
syn keyword htmlTagName contained layer ilayer nolayer spacer
syn keyword htmlArg     contained frameborder noresize pagex pagey above below
syn keyword htmlArg     contained left top visibility clip id noshade
syn match   htmlArg     contained "\<z-index\>"

" Microsoft extensions
syn keyword htmlTagName contained marquee

" html 4.0 arg names
syn match   htmlArg contained "\<\(accept-charset\|label\)\>"
syn keyword htmlArg contained abbr accept accesskey axis char charoff charset
syn keyword htmlArg contained cite classid codetype compact data datetime
syn keyword htmlArg contained declare defer dir disabled for frame
syn keyword htmlArg contained headers hreflang lang language longdesc
syn keyword htmlArg contained multiple nohref nowrap object profile readonly
syn keyword htmlArg contained rules scheme scope span standby style
syn keyword htmlArg contained summary tabindex valuetype version

" html 5 arg names
syn keyword htmlArg contained allowfullscreen async autocomplete autofocus
syn keyword htmlArg contained autoplay challenge contenteditable contextmenu
syn keyword htmlArg contained controls crossorigin default dialog dirname
syn keyword htmlArg contained download draggable dropzone form formaction
syn keyword htmlArg contained formenctype formmethod formnovalidate formtarget
syn keyword htmlArg contained hidden high icon inputmode keytype kind list loop
syn keyword htmlArg contained low max min minlength muted nonce novalidate open
syn keyword htmlArg contained optimum pattern placeholder poster preload
syn keyword htmlArg contained radiogroup required reversed sandbox spellcheck
syn keyword htmlArg contained sizes srcset srcdoc srclang step title translate
syn keyword htmlArg contained typemustmatch

" special characters
syn match htmlSpecialChar "&#\=[0-9A-Za-z]\{1,8};"

" Comments (the real ones or the old netscape ones)
if exists("html_wrong_comments")
  syn region htmlComment                start=+<!--+    end=+--\s*>+ contains=@Spell
else
  syn region htmlComment                start=+<!+      end=+>+   contains=htmlCommentPart,htmlCommentError,@Spell
  syn match  htmlCommentError contained "[^><!]"
  syn region htmlCommentPart  contained start=+--+      end=+--\s*+  contains=@htmlPreProc,@Spell
endif
syn region htmlComment                  start=+<!DOCTYPE+ keepend end=+>+

" server-parsed commands
syn region htmlPreProc start=+<!--#+ end=+-->+ contains=htmlPreStmt,htmlPreError,htmlPreAttr
syn match htmlPreStmt contained "<!--#\(config\|echo\|exec\|fsize\|flastmod\|include\|printenv\|set\|if\|elif\|else\|endif\|geoguide\)\>"
syn match htmlPreError contained "<!--#\S*"ms=s+4
syn match htmlPreAttr contained "\w\+=[^"]\S\+" contains=htmlPreProcAttrError,htmlPreProcAttrName
syn region htmlPreAttr contained start=+\w\+="+ skip=+\\\\\|\\"+ end=+"+ contains=htmlPreProcAttrName keepend
syn match htmlPreProcAttrError contained "\w\+="he=e-1
syn match htmlPreProcAttrName contained "\(expr\|errmsg\|sizefmt\|timefmt\|var\|cgi\|cmd\|file\|virtual\|value\)="he=e-1

if !exists("html_no_rendering")
  " rendering
  syn cluster htmlTop contains=@Spell,htmlTag,htmlEndTag,htmlSpecialChar,htmlPreProc,htmlComment,htmlLink,javaScript,@htmlPreproc

  syn region htmlStrike start="<del\>" end="</del\_s*>"me=s-1 contains=@htmlTop
  syn region htmlStrike start="<strike\>" end="</strike\_s*>"me=s-1 contains=@htmlTop

  syn region htmlBold start="<b\>" end="</b\_s*>"me=s-1 contains=@htmlTop,htmlBoldUnderline,htmlBoldItalic
  syn region htmlBold start="<strong\>" end="</strong\_s*>"me=s-1 contains=@htmlTop,htmlBoldUnderline,htmlBoldItalic
  syn region htmlBoldUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@htmlTop,htmlBoldUnderlineItalic
  syn region htmlBoldItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@htmlTop,htmlBoldItalicUnderline
  syn region htmlBoldItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@htmlTop,htmlBoldItalicUnderline
  syn region htmlBoldUnderlineItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@htmlTop
  syn region htmlBoldUnderlineItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@htmlTop
  syn region htmlBoldItalicUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@htmlTop,htmlBoldUnderlineItalic

  syn region htmlUnderline start="<u\>" end="</u\_s*>"me=s-1 contains=@htmlTop,htmlUnderlineBold,htmlUnderlineItalic
  syn region htmlUnderlineBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@htmlTop,htmlUnderlineBoldItalic
  syn region htmlUnderlineBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@htmlTop,htmlUnderlineBoldItalic
  syn region htmlUnderlineItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@htmlTop,htmlUnderlineItalicBold
  syn region htmlUnderlineItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@htmlTop,htmlUnderlineItalicBold
  syn region htmlUnderlineItalicBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@htmlTop
  syn region htmlUnderlineItalicBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@htmlTop
  syn region htmlUnderlineBoldItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@htmlTop
  syn region htmlUnderlineBoldItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@htmlTop

  syn region htmlItalic start="<i\>" end="</i\_s*>"me=s-1 contains=@htmlTop,htmlItalicBold,htmlItalicUnderline
  syn region htmlItalic start="<em\>" end="</em\_s*>"me=s-1 contains=@htmlTop
  syn region htmlItalicBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@htmlTop,htmlItalicBoldUnderline
  syn region htmlItalicBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@htmlTop,htmlItalicBoldUnderline
  syn region htmlItalicBoldUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@htmlTop
  syn region htmlItalicUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@htmlTop,htmlItalicUnderlineBold
  syn region htmlItalicUnderlineBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@htmlTop
  syn region htmlItalicUnderlineBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@htmlTop

  syn match htmlLeadingSpace "^\s\+" contained
  syn region htmlLink start="<a\>\_[^>]*\<href\>" end="</a\_s*>"me=s-1 contains=@Spell,htmlTag,htmlEndTag,htmlSpecialChar,htmlPreProc,htmlComment,htmlLeadingSpace,javaScript,@htmlPreproc
  syn region htmlH1 start="<h1\>" end="</h1\_s*>"me=s-1 contains=@htmlTop
  syn region htmlH2 start="<h2\>" end="</h2\_s*>"me=s-1 contains=@htmlTop
  syn region htmlH3 start="<h3\>" end="</h3\_s*>"me=s-1 contains=@htmlTop
  syn region htmlH4 start="<h4\>" end="</h4\_s*>"me=s-1 contains=@htmlTop
  syn region htmlH5 start="<h5\>" end="</h5\_s*>"me=s-1 contains=@htmlTop
  syn region htmlH6 start="<h6\>" end="</h6\_s*>"me=s-1 contains=@htmlTop
  syn region htmlHead start="<head\>" end="</head\_s*>"me=s-1 end="<body\>"me=s-1 end="<h[1-6]\>"me=s-1 contains=htmlTag,htmlEndTag,htmlSpecialChar,htmlPreProc,htmlComment,htmlLink,htmlTitle,javaScript,cssStyle,@htmlPreproc
  syn region htmlTitle start="<title\>" end="</title\_s*>"me=s-1 contains=htmlTag,htmlEndTag,htmlSpecialChar,htmlPreProc,htmlComment,javaScript,@htmlPreproc
endif

syn keyword htmlTagName         contained noscript
syn keyword htmlSpecialTagName  contained script style
if main_syntax != 'java' || exists("java_javascript")
  " JAVA SCRIPT
  syn include @htmlJavaScript syntax/javascript.vim
  unlet b:current_syntax
  syn region  javaScript start=+<script\_[^>]*>+ keepend end=+</script\_[^>]*>+me=s-1 contains=@htmlJavaScript,htmlCssStyleComment,htmlScriptTag,@htmlPreproc
  syn region  htmlScriptTag     contained start=+<script+ end=+>+ fold contains=htmlTagN,htmlString,htmlArg,htmlValue,htmlTagError,htmlEvent
  hi def link htmlScriptTag htmlTag

  " html events (i.e. arguments that include javascript commands)
  if exists("html_extended_events")
    syn region htmlEvent        contained start=+\<on\a\+\s*=[\t ]*'+ end=+'+ contains=htmlEventSQ
    syn region htmlEvent        contained start=+\<on\a\+\s*=[\t ]*"+ end=+"+ contains=htmlEventDQ
  else
    syn region htmlEvent        contained start=+\<on\a\+\s*=[\t ]*'+ end=+'+ keepend contains=htmlEventSQ
    syn region htmlEvent        contained start=+\<on\a\+\s*=[\t ]*"+ end=+"+ keepend contains=htmlEventDQ
  endif
  syn region htmlEventSQ        contained start=+'+ms=s+1 end=+'+me=s-1 contains=@htmlJavaScript
  syn region htmlEventDQ        contained start=+"+ms=s+1 end=+"+me=s-1 contains=@htmlJavaScript
  hi def link htmlEventSQ htmlEvent
  hi def link htmlEventDQ htmlEvent

  " a javascript expression is used as an arg value
  syn region  javaScriptExpression contained start=+&{+ keepend end=+};+ contains=@htmlJavaScript,@htmlPreproc
endif

if main_syntax != 'java' || exists("java_vb")
  " VB SCRIPT
  syn include @htmlVbScript syntax/vb.vim
  unlet b:current_syntax
  syn region  javaScript start=+<script \_[^>]*language *=\_[^>]*vbscript\_[^>]*>+ keepend end=+</script\_[^>]*>+me=s-1 contains=@htmlVbScript,htmlCssStyleComment,htmlScriptTag,@htmlPreproc
endif

syn cluster htmlJavaScript      add=@htmlPreproc

if main_syntax != 'java' || exists("java_css")
  " embedded style sheets
  syn keyword htmlArg           contained media
  syn include @htmlCss syntax/css.vim
  unlet b:current_syntax
  syn region cssStyle start=+<style+ keepend end=+</style>+ contains=@htmlCss,htmlTag,htmlEndTag,htmlCssStyleComment,@htmlPreproc
  syn match htmlCssStyleComment contained "\(<!--\|-->\)"
  syn region htmlCssDefinition matchgroup=htmlArg start='style="' keepend matchgroup=htmlString end='"' contains=css.*Attr,css.*Prop,cssComment,cssLength,cssColor,cssURL,cssImportant,cssError,cssString,@htmlPreproc
  hi def link htmlStyleArg htmlString
endif

if main_syntax == "html"
  " synchronizing (does not always work if a comment includes legal
  " html tags, but doing it right would mean to always start
  " at the first line, which is too slow)
  syn sync match htmlHighlight groupthere NONE "<[/a-zA-Z]"
  syn sync match htmlHighlight groupthere javaScript "<script"
  syn sync match htmlHighlightSkip "^.*['\"].*$"
  syn sync minlines=10
endif

" The default highlighting.
hi def link htmlTag                     Function
hi def link htmlEndTag                  Identifier
hi def link htmlArg                     Type
hi def link htmlTagName                 htmlStatement
hi def link htmlSpecialTagName          Exception
hi def link htmlValue                     String
hi def link htmlSpecialChar             Special

if !exists("html_no_rendering")
  hi def link htmlH1                      Title
  hi def link htmlH2                      htmlH1
  hi def link htmlH3                      htmlH2
  hi def link htmlH4                      htmlH3
  hi def link htmlH5                      htmlH4
  hi def link htmlH6                      htmlH5
  hi def link htmlHead                    PreProc
  hi def link htmlTitle                   Title
  hi def link htmlBoldItalicUnderline     htmlBoldUnderlineItalic
  hi def link htmlUnderlineBold           htmlBoldUnderline
  hi def link htmlUnderlineItalicBold     htmlBoldUnderlineItalic
  hi def link htmlUnderlineBoldItalic     htmlBoldUnderlineItalic
  hi def link htmlItalicUnderline         htmlUnderlineItalic
  hi def link htmlItalicBold              htmlBoldItalic
  hi def link htmlItalicBoldUnderline     htmlBoldUnderlineItalic
  hi def link htmlItalicUnderlineBold     htmlBoldUnderlineItalic
  hi def link htmlLink                    Underlined
  hi def link htmlLeadingSpace            None
  if !exists("html_my_rendering")
    hi def htmlBold                term=bold cterm=bold gui=bold
    hi def htmlBoldUnderline       term=bold,underline cterm=bold,underline gui=bold,underline
    hi def htmlBoldItalic          term=bold,italic cterm=bold,italic gui=bold,italic
    hi def htmlBoldUnderlineItalic term=bold,italic,underline cterm=bold,italic,underline gui=bold,italic,underline
    hi def htmlUnderline           term=underline cterm=underline gui=underline
    hi def htmlUnderlineItalic     term=italic,underline cterm=italic,underline gui=italic,underline
    hi def htmlItalic              term=italic cterm=italic gui=italic
    if v:version > 800 || v:version == 800 && has("patch1038")
        hi def htmlStrike              term=strikethrough cterm=strikethrough gui=strikethrough
    else
        hi def htmlStrike              term=underline cterm=underline gui=underline
    endif
  endif
endif

hi def link htmlPreStmt            PreProc
hi def link htmlPreError           Error
hi def link htmlPreProc            PreProc
hi def link htmlPreAttr            String
hi def link htmlPreProcAttrName    PreProc
hi def link htmlPreProcAttrError   Error
hi def link htmlSpecial            Special
hi def link htmlSpecialChar        Special
hi def link htmlString             String
hi def link htmlStatement          Statement
hi def link htmlComment            Comment
hi def link htmlCommentPart        Comment
hi def link htmlValue              String
hi def link htmlCommentError       htmlError
hi def link htmlTagError           htmlError
hi def link htmlEvent              javaScript
hi def link htmlError              Error

hi def link javaScript             Special
hi def link javaScriptExpression   javaScript
hi def link htmlCssStyleComment    Comment
hi def link htmlCssDefinition      Special

let b:current_syntax = "html"

if main_syntax == 'html'
  unlet main_syntax
endif

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
