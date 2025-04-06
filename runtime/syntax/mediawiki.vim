" mediawiki.vim (formerly named Wikipedia.vim)
"
" Vim syntax file
" Language: MediaWiki
" Maintainer: Avid Seeker <avidseeker7@protonmail.com>
" Home: http://en.wikipedia.org/wiki/Wikipedia:Text_editor_support#Vim
" Last Change: 2024 Jul 14
" Credits: [[User:Unforgettableid]] [[User:Aepd87]], [[User:Danny373]], [[User:Ingo Karkat]], et al.
"
" Published on Wikipedia in 2003-04 and declared authorless.
"
" Based on the HTML syntax file. Probably too closely based, in fact.
" There may well be name collisions everywhere, but ignorance is bliss,
" so they say.
"

if exists("b:current_syntax")
  finish
endif

syntax case ignore
syntax spell toplevel

" Mark illegal characters
sy match htmlError "[<>&]"

" Tags
sy region  htmlString   contained start=+"+                        end=+"+ contains=htmlSpecialChar,@htmlPreproc
sy region  htmlString   contained start=+'+                        end=+'+ contains=htmlSpecialChar,@htmlPreproc
sy match   htmlValue    contained "=[\t ]*[^'" \t>][^ \t>]*"hs=s+1         contains=@htmlPreproc
sy region  htmlEndTag             start=+</+                       end=+>+ contains=htmlTagN,htmlTagError
sy region  htmlTag                start=+<[^/]+                    end=+>+ contains=htmlTagN,htmlString,htmlArg,htmlValue,htmlTagError,htmlEvent,htmlCssDefinition,@htmlPreproc,@htmlArgCluster
sy match   htmlTagN     contained +<\s*[-a-zA-Z0-9]\++hs=s+1               contains=htmlTagName,htmlSpecialTagName,@htmlTagNameCluster
sy match   htmlTagN     contained +</\s*[-a-zA-Z0-9]\++hs=s+2              contains=htmlTagName,htmlSpecialTagName,@htmlTagNameCluster
sy match   htmlTagError contained "[^>]<"ms=s+1

" Allowed HTML tag names
sy keyword htmlTagName contained big blockquote br caption center cite code
sy keyword htmlTagName contained dd del div dl dt font hr ins li
sy keyword htmlTagName contained ol p pre rb rp rt ruby s small span strike sub
sy keyword htmlTagName contained sup table td th tr tt ul var
sy match   htmlTagName contained "\<\(b\|i\|u\|h[1-6]\|em\|strong\)\>"
" Allowed Wiki tag names
sy keyword htmlTagName contained math nowiki references source syntaxhighlight

" Allowed arg names
sy keyword htmlArg contained align lang dir width height nowrap bgcolor clear
sy keyword htmlArg contained noshade cite datetime size face color type start
sy keyword htmlArg contained value compact summary border frame rules
sy keyword htmlArg contained cellspacing cellpadding valign char charoff
sy keyword htmlArg contained colgroup col span abbr axis headers scope rowspan
sy keyword htmlArg contained colspan id class name style title

" Special characters
sy match htmlSpecialChar "&#\=[0-9A-Za-z]\{1,8};"

" Comments
sy region htmlComment                start=+<!+                end=+>+     contains=htmlCommentPart,htmlCommentError
sy match  htmlCommentError contained "[^><!]"
sy region htmlCommentPart  contained start=+--+                end=+--\s*+ contains=@htmlPreProc
sy region htmlComment                start=+<!DOCTYPE+ keepend end=+>+

if !exists("html_no_rendering")
  sy cluster htmlTop contains=@Spell,htmlTag,htmlEndTag,htmlSpecialChar,htmlPreProc,htmlComment,htmlLink,@htmlPreproc

  sy region htmlBold                          start="<b\>"      end="</b>"me=e-4      contains=@htmlTop,htmlBoldUnderline,htmlBoldItalic
  sy region htmlBold                          start="<strong\>" end="</strong>"me=e-9 contains=@htmlTop,htmlBoldUnderline,htmlBoldItalic
  sy region htmlBoldUnderline       contained start="<u\>"      end="</u>"me=e-4      contains=@htmlTop,htmlBoldUnderlineItalic
  sy region htmlBoldItalic          contained start="<i\>"      end="</i>"me=e-4      contains=@htmlTop,htmlBoldItalicUnderline
  sy region htmlBoldItalic          contained start="<em\>"     end="</em>"me=e-5     contains=@htmlTop,htmlBoldItalicUnderline
  sy region htmlBoldUnderlineItalic contained start="<i\>"      end="</i>"me=e-4      contains=@htmlTop
  sy region htmlBoldUnderlineItalic contained start="<em\>"     end="</em>"me=e-5     contains=@htmlTop
  sy region htmlBoldItalicUnderline contained start="<u\>"      end="</u>"me=e-4      contains=@htmlTop,htmlBoldUnderlineItalic

  sy region htmlUnderline                     start="<u\>"      end="</u>"me=e-4      contains=@htmlTop,htmlUnderlineBold,htmlUnderlineItalic
  sy region htmlUnderlineBold       contained start="<b\>"      end="</b>"me=e-4      contains=@htmlTop,htmlUnderlineBoldItalic
  sy region htmlUnderlineBold       contained start="<strong\>" end="</strong>"me=e-9 contains=@htmlTop,htmlUnderlineBoldItalic
  sy region htmlUnderlineItalic     contained start="<i\>"      end="</i>"me=e-4      contains=@htmlTop,htmlUnderlineItalicBold
  sy region htmlUnderlineItalic     contained start="<em\>"     end="</em>"me=e-5     contains=@htmlTop,htmlUnderlineItalicBold
  sy region htmlUnderlineItalicBold contained start="<b\>"      end="</b>"me=e-4      contains=@htmlTop
  sy region htmlUnderlineItalicBold contained start="<strong\>" end="</strong>"me=e-9 contains=@htmlTop
  sy region htmlUnderlineBoldItalic contained start="<i\>"      end="</i>"me=e-4      contains=@htmlTop
  sy region htmlUnderlineBoldItalic contained start="<em\>"     end="</em>"me=e-5     contains=@htmlTop

  sy region htmlItalic                        start="<i\>"      end="</i>"me=e-4      contains=@htmlTop,htmlItalicBold,htmlItalicUnderline
  sy region htmlItalic                        start="<em\>"     end="</em>"me=e-5     contains=@htmlTop
  sy region htmlItalicBold          contained start="<b\>"      end="</b>"me=e-4      contains=@htmlTop,htmlItalicBoldUnderline
  sy region htmlItalicBold          contained start="<strong\>" end="</strong>"me=e-9 contains=@htmlTop,htmlItalicBoldUnderline
  sy region htmlItalicBoldUnderline contained start="<u\>"      end="</u>"me=e-4      contains=@htmlTop
  sy region htmlItalicUnderline     contained start="<u\>"      end="</u>"me=e-4      contains=@htmlTop,htmlItalicUnderlineBold
  sy region htmlItalicUnderlineBold contained start="<b\>"      end="</b>"me=e-4      contains=@htmlTop
  sy region htmlItalicUnderlineBold contained start="<strong\>" end="</strong>"me=e-9 contains=@htmlTop

  sy region htmlH1    start="<h1\>"    end="</h1>"me=e-5    contains=@htmlTop
  sy region htmlH2    start="<h2\>"    end="</h2>"me=e-5    contains=@htmlTop
  sy region htmlH3    start="<h3\>"    end="</h3>"me=e-5    contains=@htmlTop
  sy region htmlH4    start="<h4\>"    end="</h4>"me=e-5    contains=@htmlTop
  sy region htmlH5    start="<h5\>"    end="</h5>"me=e-5    contains=@htmlTop
  sy region htmlH6    start="<h6\>"    end="</h6>"me=e-5    contains=@htmlTop
endif


" No htmlTop and wikiPre inside HTML preformatted areas, because
" MediaWiki renders everything in there literally (HTML tags and
" entities, too): <pre> tags work as the combination of <nowiki> and
" the standard HTML <pre> tag: the content will preformatted, and it
" will not be parsed, but shown as in the wikitext source.
"
" With wikiPre, indented lines would be rendered differently from
" unindented lines.
sy match htmlPreTag       /<pre\>[^>]*>/         contains=htmlTag
sy match htmlPreEndTag    /<\/pre>/       contains=htmlEndTag
sy match wikiNowikiTag    /<nowiki>/      contains=htmlTag
sy match wikiNowikiEndTag /<\/nowiki>/    contains=htmlEndTag
sy match wikiSourceTag    /<source\s\+[^>]\+>/ contains=htmlTag
sy match wikiSourceEndTag /<\/source>/    contains=htmlEndTag
sy match wikiSyntaxHLTag    /<syntaxhighlight\s\+[^>]\+>/ contains=htmlTag
sy match wikiSyntaxHLEndTag /<\/syntaxhighlight>/    contains=htmlEndTag

" Note: Cannot use 'start="<pre>"rs=e', so still have the <pre> tag
" highlighted correctly via separate sy-match. Unfortunately, this will
" also highlight <pre> tags inside the preformatted region.
sy region htmlPre    start="<pre\>[^>]*>"                 end="<\/pre>"me=e-6    contains=htmlPreTag
sy region wikiNowiki start="<nowiki>"              end="<\/nowiki>"me=e-9 contains=wikiNowikiTag
sy region wikiSource start="<source\s\+[^>]\+>"         keepend end="<\/source>"me=e-9 contains=wikiSourceTag
sy region wikiSyntaxHL start="<syntaxhighlight\s\+[^>]\+>" keepend end="<\/syntaxhighlight>"me=e-18 contains=wikiSyntaxHLTag

sy include @TeX syntax/tex.vim
unlet b:current_syntax
sy region wikiTeX matchgroup=htmlTag start="<math>" end="<\/math>"  contains=@texMathZoneGroup,wikiNowiki,wikiNowikiEndTag
sy region wikiRef matchgroup=htmlTag start="<ref>"  end="<\/ref>"   contains=wikiNowiki,wikiNowikiEndTag

sy cluster wikiText contains=wikiLink,wikiTemplate,wikiNowiki,wikiNowikiEndTag,wikiItalic,wikiBold,wikiBoldAndItalic

" Tables
sy cluster wikiTableFormat contains=wikiTemplate,htmlString,htmlArg,htmlValue
sy region wikiTable matchgroup=wikiTableSeparator start="{|" end="|}" contains=wikiTableHeaderLine,wikiTableCaptionLine,wikiTableNewRow,wikiTableHeadingCell,wikiTableNormalCell,@wikiText
sy match  wikiTableSeparator /^!/ contained
sy match  wikiTableSeparator /^|/ contained
sy match  wikiTableSeparator /^|[+-]/ contained
sy match  wikiTableSeparator /||/ contained
sy match  wikiTableSeparator /!!/ contained
sy match  wikiTableFormatEnd /[!|]/ contained
sy match  wikiTableHeadingCell /\(^!\|!!\)\([^!|]*|\)\?.*/ contains=wikiTableSeparator,@wikiText,wikiTableHeadingFormat
" Require at least one '=' in the format, to avoid spurious matches (e.g.
" the | in [[foo|bar]] might be taken as the final |, indicating the beginning
" of the cell). The same is done for wikiTableNormalFormat below.
sy match  wikiTableHeadingFormat /\%(^!\|!!\)[^!|]\+=[^!|]\+\([!|]\)\(\1\)\@!/me=e-1 contains=@wikiTableFormat,wikiTableSeparator nextgroup=wikiTableFormatEnd
sy match  wikiTableNormalCell /\(^|\|||\)\([^|]*|\)\?.*/ contains=wikiTableSeparator,@wikiText,wikiTableNormalFormat
sy match  wikiTableNormalFormat /\(^|\|||\)[^|]\+=[^|]\+||\@!/me=e-1 contains=@wikiTableFormat,wikiTableSeparator nextgroup=wikiTableFormatEnd
sy match  wikiTableHeaderLine /\(^{|\)\@<=.*$/ contained contains=@wikiTableFormat
sy match  wikiTableCaptionLine /^|+.*$/ contained contains=wikiTableSeparator,@wikiText
sy match  wikiTableNewRow /^|-.*$/ contained contains=wikiTableSeparator,@wikiTableFormat

sy cluster wikiTop contains=@Spell,wikiLink,wikiNowiki,wikiNowikiEndTag

sy region wikiItalic        start=+'\@<!'''\@!+ end=+''+    oneline contains=@wikiTop,wikiItalicBold
sy region wikiBold          start=+'''+         end=+'''+   oneline contains=@wikiTop,wikiBoldItalic
sy region wikiBoldAndItalic start=+'''''+       end=+'''''+ oneline contains=@wikiTop

sy region wikiBoldItalic contained start=+'\@<!'''\@!+ end=+''+  oneline contains=@wikiTop
sy region wikiItalicBold contained start=+'''+         end=+'''+ oneline contains=@wikiTop

sy region wikiH1 start="^="      end="="      oneline contains=@wikiTop
sy region wikiH2 start="^=="     end="=="     oneline contains=@wikiTop
sy region wikiH3 start="^==="    end="==="    oneline contains=@wikiTop
sy region wikiH4 start="^===="   end="===="   oneline contains=@wikiTop
sy region wikiH5 start="^====="  end="====="  oneline contains=@wikiTop
sy region wikiH6 start="^======" end="======" oneline contains=@wikiTop

sy region wikiLink start="\[\[" end="\]\]\(s\|'s\|es\|ing\|\)" oneline contains=wikiLink,wikiNowiki,wikiNowikiEndTag

sy region wikiLink start="https\?://" end="\W*\_s"me=s-1 oneline
sy region wikiLink start="\[http:"   end="\]" oneline contains=wikiNowiki,wikiNowikiEndTag
sy region wikiLink start="\[https:"  end="\]" oneline contains=wikiNowiki,wikiNowikiEndTag
sy region wikiLink start="\[ftp:"    end="\]" oneline contains=wikiNowiki,wikiNowikiEndTag
sy region wikiLink start="\[gopher:" end="\]" oneline contains=wikiNowiki,wikiNowikiEndTag
sy region wikiLink start="\[news:"   end="\]" oneline contains=wikiNowiki,wikiNowikiEndTag
sy region wikiLink start="\[mailto:" end="\]" oneline contains=wikiNowiki,wikiNowikiEndTag

sy match  wikiTemplateName /{{[^{|}<>\[\]]\+/hs=s+2 contained
sy region wikiTemplate start="{{" end="}}" keepend extend contains=wikiNowiki,wikiNowikiEndTag,wikiTemplateName,wikiTemplateParam,wikiTemplate,wikiLink
sy region wikiTemplateParam start="{{{\s*\d" end="}}}" extend contains=wikiTemplateName

sy match wikiParaFormatChar /^[\:|\*|;|#]\+/
sy match wikiParaFormatChar /^-----*/
sy match wikiPre            /^\ .*$/         contains=wikiNowiki,wikiNowikiEndTag

" HTML highlighting

hi def link htmlTag            Function
hi def link htmlEndTag         Identifier
hi def link htmlArg            Type
hi def link htmlTagName        htmlStatement
hi def link htmlSpecialTagName Exception
hi def link htmlValue          String
hi def link htmlSpecialChar    Special

if !exists("html_no_rendering")
  hi def link htmlTitle Title
  hi def link htmlH1    htmlTitle
  hi def link htmlH2    htmlTitle
  hi def link htmlH3    htmlTitle
  hi def link htmlH4    htmlTitle
  hi def link htmlH5    htmlTitle
  hi def link htmlH6    htmlTitle

  hi def link htmlPreProc          PreProc
  hi def link htmlHead             htmlPreProc
  hi def link htmlPreProcAttrName  htmlPreProc
  hi def link htmlPreStmt          htmlPreProc

  hi def link htmlSpecial          Special
  hi def link htmlCssDefinition    htmlSpecial
  hi def link htmlEvent            htmlSpecial
  hi def link htmlSpecialChar      htmlSpecial

  hi def link htmlComment          Comment
  hi def link htmlCommentPart      htmlComment
  hi def link htmlCssStyleComment  htmlComment

  hi def link htmlString           String
  hi def link htmlPreAttr          htmlString
  hi def link htmlValue            htmlString

  hi def link htmlError            Error
  hi def link htmlBadArg           htmlError
  hi def link htmlBadTag           htmlError
  hi def link htmlCommentError     htmlError
  hi def link htmlPreError         htmlError
  hi def link htmlPreProcAttrError htmlError
  hi def link htmlTagError         htmlError

  hi def link htmlStatement        Statement

  hi def link htmlConstant         Constant

  hi def link htmlBoldItalicUnderline htmlBoldUnderlineItalic
  hi def link htmlUnderlineItalicBold htmlBoldUnderlineItalic
  hi def link htmlUnderlineBoldItalic htmlBoldUnderlineItalic
  hi def link htmlItalicBoldUnderline htmlBoldUnderlineItalic
  hi def link htmlItalicUnderlineBold htmlBoldUnderlineItalic

  hi def link htmlItalicBold          htmlBoldItalic
  hi def link htmlItalicUnderline     htmlUnderlineItalic
  hi def link htmlUnderlineBold       htmlBoldUnderline

  hi def link htmlLink Underlined

  if !exists("html_style_rendering")
    hi def htmlBold                term=bold                  cterm=bold                  gui=bold
    hi def htmlBoldUnderline       term=bold,underline        cterm=bold,underline        gui=bold,underline
    hi def htmlBoldItalic          term=bold,italic           cterm=bold,italic           gui=bold,italic
    hi def htmlBoldUnderlineItalic term=bold,italic,underline cterm=bold,italic,underline gui=bold,italic,underline
    hi def htmlUnderline           term=underline             cterm=underline             gui=underline
    hi def htmlUnderlineItalic     term=italic,underline      cterm=italic,underline      gui=italic,underline
    hi def htmlItalic              term=italic                cterm=italic                gui=italic
  endif
endif

" Wiki highlighting

hi def link wikiItalic        htmlItalic
hi def link wikiBold          htmlBold
hi def link wikiBoldItalic    htmlBoldItalic
hi def link wikiItalicBold    htmlBoldItalic
hi def link wikiBoldAndItalic htmlBoldItalic

hi def link wikiH1 htmlTitle
hi def link wikiH2 htmlTitle
hi def link wikiH3 htmlTitle
hi def link wikiH4 htmlTitle
hi def link wikiH5 htmlTitle
hi def link wikiH6 htmlTitle

hi def link wikiLink           htmlLink
hi def link wikiTemplate       htmlSpecial
hi def link wikiTemplateParam  htmlSpecial
hi def link wikiTemplateName   Type
hi def link wikiParaFormatChar htmlSpecial
hi def link wikiPre            htmlConstant
hi def link wikiRef            htmlComment

hi def link htmlPre            wikiPre
hi def link wikiSource         wikiPre
hi def link wikiSyntaxHL       wikiPre

hi def link wikiTableSeparator Statement
hi def link wikiTableFormatEnd wikiTableSeparator
hi def link wikiTableHeadingCell htmlBold

let b:current_syntax = "mediawiki"
