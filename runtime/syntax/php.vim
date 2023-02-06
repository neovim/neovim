" Vim syntax file
" Language: php PHP 3/4/5/7/8
" Maintainer: Tyson Andre <tysonandre775@hotmail.com>
" Last Change: Sep 18, 2021
" URL: https://github.com/TysonAndre/php-vim-syntax
" Former Maintainers: 
"         Jason Woofenden <jason@jasonwoof.com>
"         Peter Hodge <toomuchphp-vim@yahoo.com>
"         Debian VIM Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
"
" Note: If you are using a colour terminal with dark background, you will
"       probably find the 'elflord' colorscheme is much better for PHP's syntax
"       than the default colourscheme, because elflord's colours will better
"       highlight the break-points (Statements) in your code.
"
" Note: This embeds a modified copy of the html.vim with (mostly) different symbols,
" in order to implement php_htmlInStrings=2 can work as expected and correctly parse
" `<?php $phpStartTag = '<?php';`.
"
" Credits for the original version of html.vim prior to modifications
"
"   Previous Maintainer Jorge Maldonado Ventura <jorgesumle@freakspot.net>
"   Previous Maintainer Claudio Fleiner <claudio@fleiner.com>
"   Repository          https://notabug.org/jorgesumle/vim-html-syntax
"   Last Change         2021 Mar 02
"			Included patch #7900 to fix comments
"			Included patch #7916 to fix a few more things
"
" Options:
"   Set to anything to enable:
"     php_sql_query           SQL syntax highlighting inside strings
"     php_htmlInStrings       HTML syntax highlighting inside strings
" 
"                             By setting this to 2, this will use a local copy of
"                             HTML syntax highlighting instead of the official
"                             HTML syntax highlighting, and properly highlight
"                             `<?php $startTag = '<?php';`.
"                             This may become the new default in the future.
" 
"                             By setting this to 3 (or any unrecognized value), 
"                             this will use the official installed top level html syntax highlighting rules.
"     php_baselib             highlighting baselib functions
"     php_asp_tags            highlighting ASP-style short tags
"     php_parent_error_close  highlighting parent error ] or )
"     php_parent_error_open   skipping an php end tag, if there exists
"                               an open ( or [ without a closing one
"     php_oldStyle            use old colorstyle
"     php_noShortTags         don't sync <? ?> as php
"   Set to a specific value:
"     php_folding = 1         fold classes and functions
"     php_folding = 2         fold all { } regions
"     php_sync_method = x  where x is an integer:
"                       -1  sync by search ( default )
"                       >0  sync at least x lines backwards
"                       0   sync from start
"   Set to 0 to _disable_:      (Added by Peter Hodge On June 9, 2006)
"     php_special_functions = 0      highlight functions with abnormal behaviour
"     php_alt_comparisons = 0        comparison operators in an alternate colour
"     php_alt_assignByReference = 0  '= &' in an alternate colour
"
"
" Note:
" Setting php_folding=1 will match a closing } by comparing the indent
" before the class or function keyword with the indent of a matching }.
" Setting php_folding=2 will match all of pairs of {,} ( see known
" bugs ii )

" Known Bugs:
"  - setting  php_parent_error_close  on  and  php_parent_error_open  off
"    has these two leaks:
"     i) A closing ) or ] inside a string matches to the last open ( or [
"        before the string, when the closing ) or ] is on the same line
"        where the string started. In this case a following ) or ] after
"        the string would be highlighted as an error, what is incorrect.
"    ii) Same problem if you are setting php_folding = 2 with a closing
"        } inside an string on the first line of this string.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'php'
endif

" Start of copy of html for embedding in strings with  {{{
" This is a clone of https://notabug.org/jorgesumle/vim-html-syntax
" from 2021 Mar 02 with changed symbols and modifications to rules. See the Note in the file header.
"
" The default behavior of php_htmlInStrings causes a bug
" when you're working with code that contains the string literal `'<?php'`.
" E.g. code that reads php files or generates the contents of php files or 
" generates snippets to `eval()`.
" 
" When php_htmlInStrings was set to any value,
" it would cause the html syntax rules to be embedded inside of the string
" contents.
" 
" However, php.vim extends html.vim by allowing the php start tag to be
" included, meaning that this is parsed as `<?php';`, i.e. the start of a
" new string literal.
" 
" Work around that by using a different set of rules that don't allow
" embedding php in most places (phpInnerHtmlPreProc).
" 
" The default behavior may be changed to this in the future for constants other
" than 2 or 3 if there are no issues.
"
" Many, but not all syntax rules were changed from html* to phpInnerHtml*
if exists("php_htmlInStrings") && php_htmlInStrings==2
  " mark illegal characters
  syn match phpInnerHtmlError contained "[<>&]"

  " tags
  syn region  phpInnerHtmlString   contained start=+"+ end=+"+ contains=phpInnerHtmlSpecialChar,javaScriptExpression,@phpInnerHtmlPreproc
  syn region  phpInnerHtmlString   contained start=+'+ end=+'+ contains=phpInnerHtmlSpecialChar,javaScriptExpression,@phpInnerHtmlPreproc
  syn match   phpInnerHtmlValue    contained "=[\t ]*[^'" \t>][^ \t>]*"hs=s+1   contains=javaScriptExpression,@phpInnerHtmlPreproc
  syn region  phpInnerHtmlEndTag   contained start=+</+      end=+>+ contains=phpInnerHtmlTagN,phpInnerHtmlTagError
  syn region  phpInnerHtmlTag      contained start=+<[^/]+   end=+>+ fold contains=phpInnerHtmlTagN,phpInnerHtmlString,htmlArg,phpInnerHtmlValue,phpInnerHtmlTagError,phpInnerHtmlEvent,phpInnerHtmlCssDefinition,@phpInnerHtmlPreproc,@phpInnerHtmlArgCluster
  syn match   phpInnerHtmlTagN     contained +<\s*[-a-zA-Z0-9]\++hs=s+1 contains=htmlTagName,htmlSpecialTagName,@phpInnerHtmlTagNameCluster
  syn match   phpInnerHtmlTagN     contained +</\s*[-a-zA-Z0-9]\++hs=s+2 contains=htmlTagName,htmlSpecialTagName,@phpInnerHtmlTagNameCluster
  syn match   phpInnerHtmlTagError contained "[^>]<"ms=s+1


  " special characters
  syn match phpInnerHtmlSpecialChar "&#\=[0-9A-Za-z]\{1,8};"

  " Comments (the real ones or the old netscape ones)
  if exists("html_wrong_comments")
    syn region phpInnerHtmlComment        start=+<!--+    end=+--\s*>+    contains=@Spell
  else
    " The HTML 5.2 syntax 8.2.4.41: bogus comment is parser error; browser skips until next &gt
    syn region phpInnerHtmlComment        start=+<!+      end=+>+         contains=phpInnerHtmlCommentError keepend
    " Idem 8.2.4.42,51: Comment starts with <!-- and ends with -->
    " Idem 8.2.4.43,44: Except <!--> and <!---> are parser errors
    " Idem 8.2.4.52: dash-dash-bang (--!>) is error ignored by parser, also closes comment
    syn region phpInnerHtmlComment matchgroup=phpInnerHtmlComment start=+<!--\%(-\?>\)\@!+        end=+--!\?>+    contains=phpInnerHtmlCommentNested,@phpInnerHtmlPreProc,@Spell keepend
    " Idem 8.2.4.49: nested comment is parser error, except <!--> is all right
    syn match phpInnerHtmlCommentNested contained "<!-->\@!"
    syn match phpInnerHtmlCommentError  contained "[^><!]"
  endif
  syn region phpInnerHtmlComment  start=+<!DOCTYPE+       end=+>+ keepend

  " server-parsed commands
  syn region phpInnerHtmlPreProc start=+<!--#+ end=+-->+ contains=phpInnerHtmlPreStmt,phpInnerHtmlPreError,phpInnerHtmlPreAttr
  syn match phpInnerHtmlPreStmt contained "<!--#\(config\|echo\|exec\|fsize\|flastmod\|include\|printenv\|set\|if\|elif\|else\|endif\|geoguide\)\>"
  syn match phpInnerHtmlPreError contained "<!--#\S*"ms=s+4
  syn match phpInnerHtmlPreAttr contained "\w\+=[^"]\S\+" contains=phpInnerHtmlPreProcAttrError,phpInnerHtmlPreProcAttrName
  syn region phpInnerHtmlPreAttr contained start=+\w\+="+ skip=+\\\\\|\\"+ end=+"+ contains=phpInnerHtmlPreProcAttrName keepend
  syn match phpInnerHtmlPreProcAttrError contained "\w\+="he=e-1
  syn match phpInnerHtmlPreProcAttrName contained "\(expr\|errmsg\|sizefmt\|timefmt\|var\|cgi\|cmd\|file\|virtual\|value\)="he=e-1

  if !exists("html_no_rendering")
    " rendering
    syn cluster phpInnerHtmlTop contains=@Spell,phpInnerHtmlTag,phpInnerHtmlEndTag,phpInnerHtmlSpecialChar,phpInnerHtmlPreProc,phpInnerHtmlComment,phpInnerHtmlLink,javaScript,@phpInnerHtmlPreproc

    syn region phpInnerHtmlStrike start="<del\>" end="</del\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlStrike start="<strike\>" end="</strike\_s*>"me=s-1 contains=@phpInnerHtmlTop

    syn region phpInnerHtmlBold start="<b\>" end="</b\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlBoldUnderline,phpInnerHtmlBoldItalic
    syn region phpInnerHtmlBold start="<strong\>" end="</strong\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlBoldUnderline,phpInnerHtmlBoldItalic
    syn region phpInnerHtmlBoldUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlBoldUnderlineItalic
    syn region phpInnerHtmlBoldItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlBoldItalicUnderline
    syn region phpInnerHtmlBoldItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlBoldItalicUnderline
    syn region phpInnerHtmlBoldUnderlineItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlBoldUnderlineItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlBoldItalicUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlBoldUnderlineItalic

    syn region phpInnerHtmlUnderline start="<u\>" end="</u\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlUnderlineBold,phpInnerHtmlUnderlineItalic
    syn region phpInnerHtmlUnderlineBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlUnderlineBoldItalic
    syn region phpInnerHtmlUnderlineBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlUnderlineBoldItalic
    syn region phpInnerHtmlUnderlineItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlUnderlineItalicBold
    syn region phpInnerHtmlUnderlineItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlUnderlineItalicBold
    syn region phpInnerHtmlUnderlineItalicBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlUnderlineItalicBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlUnderlineBoldItalic contained start="<i\>" end="</i\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlUnderlineBoldItalic contained start="<em\>" end="</em\_s*>"me=s-1 contains=@phpInnerHtmlTop

    syn region phpInnerHtmlItalic start="<i\>" end="</i\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlItalicBold,phpInnerHtmlItalicUnderline
    syn region phpInnerHtmlItalic start="<em\>" end="</em\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlItalicBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlItalicBoldUnderline
    syn region phpInnerHtmlItalicBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlItalicBoldUnderline
    syn region phpInnerHtmlItalicBoldUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlItalicUnderline contained start="<u\>" end="</u\_s*>"me=s-1 contains=@phpInnerHtmlTop,phpInnerHtmlItalicUnderlineBold
    syn region phpInnerHtmlItalicUnderlineBold contained start="<b\>" end="</b\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlItalicUnderlineBold contained start="<strong\>" end="</strong\_s*>"me=s-1 contains=@phpInnerHtmlTop

    syn match phpInnerHtmlLeadingSpace "^\s\+" contained
    syn region phpInnerHtmlLink start="<a\>\_[^>]*\<href\>" end="</a\_s*>"me=s-1 contains=@Spell,phpInnerHtmlTag,phpInnerHtmlEndTag,phpInnerHtmlSpecialChar,phpInnerHtmlPreProc,phpInnerHtmlComment,phpInnerHtmlLeadingSpace,phpInnerJavaScript,@phpInnerHtmlPreproc
    syn region phpInnerHtmlH1 start="<h1\>" end="</h1\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlH2 start="<h2\>" end="</h2\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlH3 start="<h3\>" end="</h3\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlH4 start="<h4\>" end="</h4\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlH5 start="<h5\>" end="</h5\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlH6 start="<h6\>" end="</h6\_s*>"me=s-1 contains=@phpInnerHtmlTop
    syn region phpInnerHtmlHead start="<head\>" end="</head\_s*>"me=s-1 end="<body\>"me=s-1 end="<h[1-6]\>"me=s-1 contains=phpInnerHtmlTag,phpInnerHtmlEndTag,phpInnerHtmlSpecialChar,phpInnerHtmlPreProc,phpInnerHtmlComment,phpInnerHtmlLink,phpInnerHtmlTitle,phpInnerJavaScript,phpInnerCssStyle,@phpInnerHtmlPreproc
    syn region phpInnerHtmlTitle start="<title\>" end="</title\_s*>"me=s-1 contains=phpInnerHtmlTag,phpInnerHtmlEndTag,phpInnerHtmlSpecialChar,phpInnerHtmlPreProc,phpInnerHtmlComment,phpInnerJavaScript,@phpInnerHtmlPreproc
  endif

  if main_syntax != 'java' || exists("javascript")
    " JAVA SCRIPT
    " For example, $phpVar = '<img onload="foo()" />';
    syn include @phpInnerHtmlJavaScript syntax/javascript.vim
    unlet b:current_syntax
    syn region  phpInnerHtmlScriptTag     contained start=+<script+ end=+>+ fold contains=phpInnerHtmlTagN,phpInnerHtmlString,phpInnerHtmlArg,phpInnerHtmlValue,phpInnerHtmlTagError,phpInnerHtmlEvent
    hi def link phpInnerHtmlScriptTag phpInnerHtmlTag

    " phpInnerHtml events (i.e. arguments that include phpInnerJavascript commands)
    if exists("html_extended_events")
      syn region phpInnerHtmlEvent        contained start=+\<on\a\+\s*=[\t ]*'+ end=+'+ contains=phpInnerHtmlEventSQ
      syn region phpInnerHtmlEvent        contained start=+\<on\a\+\s*=[\t ]*"+ end=+"+ contains=phpInnerHtmlEventDQ
    else
      syn region phpInnerHtmlEvent        contained start=+\<on\a\+\s*=[\t ]*'+ end=+'+ keepend contains=phpInnerHtmlEventSQ
      syn region phpInnerHtmlEvent        contained start=+\<on\a\+\s*=[\t ]*"+ end=+"+ keepend contains=phpInnerHtmlEventDQ
    endif
    syn region phpInnerHtmlEventSQ        contained start=+'+ms=s+1 end=+'+me=s-1 contains=@phpInnerHtmlJavaScript
    syn region phpInnerHtmlEventDQ        contained start=+"+ms=s+1 end=+"+me=s-1 contains=@phpInnerHtmlJavaScript
    hi def link phpInnerHtmlEventSQ phpInnerHtmlEvent
    hi def link phpInnerHtmlEventDQ phpInnerHtmlEvent

    " a phpInnerJavascript expression is used as an arg value
    " syn region  phpInnerJavaScriptExpression contained start=+&{+ keepend end=+};+ contains=@phpInnerHtmlJavaScript,@phpInnerHtmlPreproc
  endif

  syn cluster phpInnerHtmlJavaScript      add=@phpInnerHtmlPreproc

  " The default highlighting.
  " NOTE: For now, this deliberately copies the definitions from html rather than link
  " to the corresponding html tag name. If html is refactored to rename any 
  " keywords then html highlighting would unexpectedly be cleared.
  hi def link phpInnerHtmlTag                     Function
  hi def link phpInnerHtmlEndTag                  Identifier
  hi def link phpInnerHtmlArg                     Type
  hi def link phpInnerHtmlValue                   String
  hi def link phpInnerHtmlSpecialChar             Special

  if !exists("html_no_rendering")
    hi def link phpInnerHtmlH1                      Title
    hi def link phpInnerHtmlH2                      phpInnerHtmlH1
    hi def link phpInnerHtmlH3                      phpInnerHtmlH2
    hi def link phpInnerHtmlH4                      phpInnerHtmlH3
    hi def link phpInnerHtmlH5                      phpInnerHtmlH4
    hi def link phpInnerHtmlH6                      phpInnerHtmlH5
    hi def link phpInnerHtmlHead                    PreProc
    hi def link phpInnerHtmlTitle                   Title
    hi def link phpInnerHtmlBoldItalicUnderline     phpInnerHtmlBoldUnderlineItalic
    hi def link phpInnerHtmlUnderlineBold           phpInnerHtmlBoldUnderline
    hi def link phpInnerHtmlUnderlineItalicBold     phpInnerHtmlBoldUnderlineItalic
    hi def link phpInnerHtmlUnderlineBoldItalic     phpInnerHtmlBoldUnderlineItalic
    hi def link phpInnerHtmlItalicUnderline         phpInnerHtmlUnderlineItalic
    hi def link phpInnerHtmlItalicBold              phpInnerHtmlBoldItalic
    hi def link phpInnerHtmlItalicBoldUnderline     phpInnerHtmlBoldUnderlineItalic
    hi def link phpInnerHtmlItalicUnderlineBold     phpInnerHtmlBoldUnderlineItalic
    hi def link phpInnerHtmlLink                    Underlined
    hi def link phpInnerHtmlLeadingSpace            None
    if !exists("html_my_rendering")
      hi def phpInnerHtmlBold                term=bold cterm=bold gui=bold
      hi def phpInnerHtmlBoldUnderline       term=bold,underline cterm=bold,underline gui=bold,underline
      hi def phpInnerHtmlBoldItalic          term=bold,italic cterm=bold,italic gui=bold,italic
      hi def phpInnerHtmlBoldUnderlineItalic term=bold,italic,underline cterm=bold,italic,underline gui=bold,italic,underline
      hi def phpInnerHtmlUnderline           term=underline cterm=underline gui=underline
      hi def phpInnerHtmlUnderlineItalic     term=italic,underline cterm=italic,underline gui=italic,underline
      hi def phpInnerHtmlItalic              term=italic cterm=italic gui=italic
      if v:version > 800 || v:version == 800 && has("patch1038")
          hi def phpInnerHtmlStrike              term=strikethrough cterm=strikethrough gui=strikethrough
      else
          hi def phpInnerHtmlStrike              term=underline cterm=underline gui=underline
      endif
    endif
  endif

  hi def link phpInnerHtmlPreStmt            PreProc
  hi def link phpInnerHtmlPreError           Error
  hi def link phpInnerHtmlPreProc            PreProc
  hi def link phpInnerHtmlPreAttr            String
  hi def link phpInnerHtmlPreProcAttrName    PreProc
  hi def link phpInnerHtmlPreProcAttrError   Error
  hi def link phpInnerHtmlString             String
  hi def link phpInnerHtmlStatement          Statement
  hi def link phpInnerHtmlComment            Comment
  hi def link phpInnerHtmlCommentNested      phpInnerHtmlError
  hi def link phpInnerHtmlCommentError       phpInnerHtmlError
  hi def link phpInnerHtmlTagError           phpInnerHtmlError
  hi def link phpInnerHtmlEvent              phpInnerJavaScript
  hi def link phpInnerHtmlError              Error

  hi def link phpInnerJavaScript             Special
  hi def link phpInnerJavaScriptExpression   phpInnerJavaScript
  hi def link phpInnerHtmlCssStyleComment    Comment
  hi def link phpInnerHtmlCssDefinition      Special
endif


runtime! syntax/html.vim
unlet b:current_syntax

" accept old options
if !exists("php_sync_method")
  if exists("php_minlines")
    let php_sync_method=php_minlines
  else
    let php_sync_method=-1
  endif
endif

if exists("php_parentError") && !exists("php_parent_error_open") && !exists("php_parent_error_close")
  let php_parent_error_close=1
  let php_parent_error_open=1
endif

" End of copy of html syntax for embedding in php strings }}}

syn cluster htmlPreproc add=phpRegion,phpRegionAsp,phpRegionSc

syn include @sqlTop syntax/sql.vim
syn sync clear
unlet b:current_syntax
syn cluster sqlTop remove=sqlString,sqlComment
if exists( "php_sql_query")
  syn cluster phpAddStrings contains=@sqlTop
endif

if exists( "php_htmlInStrings")
  if php_htmlInStrings==2
    syn cluster phpAddStrings add=@phpInnerHtmlTop
  else
    syn cluster phpAddStrings add=@htmlTop
  endif
endif

" make sure we can use \ at the beginning of the line to do a continuation
let s:cpo_save = &cpo
set cpo&vim

syn case match

" Env Variables
syn keyword phpEnvVar GATEWAY_INTERFACE SERVER_NAME SERVER_SOFTWARE SERVER_PROTOCOL REQUEST_METHOD QUERY_STRING DOCUMENT_ROOT HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ENCODING HTTP_ACCEPT_LANGUAGE HTTP_CONNECTION HTTP_HOST HTTP_REFERER HTTP_USER_AGENT REMOTE_ADDR REMOTE_PORT SCRIPT_FILENAME SERVER_ADMIN SERVER_PORT SERVER_SIGNATURE PATH_TRANSLATED SCRIPT_NAME REQUEST_URI contained

" Internal Variables
syn keyword phpIntVar GLOBALS PHP_ERRMSG PHP_SELF HTTP_GET_VARS HTTP_POST_VARS HTTP_COOKIE_VARS HTTP_POST_FILES HTTP_ENV_VARS HTTP_SERVER_VARS HTTP_SESSION_VARS HTTP_RAW_POST_DATA HTTP_STATE_VARS _GET _POST _COOKIE _FILES _SERVER _ENV _SERVER _REQUEST _SESSION contained

" Constants
syn keyword phpCoreConstant PHP_VERSION PHP_OS DEFAULT_INCLUDE_PATH PEAR_INSTALL_DIR PEAR_EXTENSION_DIR PHP_EXTENSION_DIR PHP_BINDIR PHP_LIBDIR PHP_DATADIR PHP_SYSCONFDIR PHP_LOCALSTATEDIR PHP_CONFIG_FILE_PATH PHP_OUTPUT_HANDLER_START PHP_OUTPUT_HANDLER_CONT PHP_OUTPUT_HANDLER_END contained

" Predefined constants
" Generated by: curl -q https://www.php.net/manual/en/errorfunc.constants.php | grep -oP 'E_\w+' | sort -u
syn keyword phpCoreConstant E_ALL E_COMPILE_ERROR E_COMPILE_WARNING E_CORE_ERROR E_CORE_WARNING E_DEPRECATED E_ERROR E_NOTICE E_PARSE E_RECOVERABLE_ERROR E_STRICT E_USER_DEPRECATED E_USER_ERROR E_USER_NOTICE E_USER_WARNING E_WARNING contained

syn case ignore

syn keyword phpConstant __LINE__ __FILE__ __FUNCTION__ __METHOD__ __CLASS__ __DIR__ __NAMESPACE__ __TRAIT__ contained


" Function and Methods ripped from php_manual_de.tar.gz Jan 2003 and amended later with common bundled extensions

syn keyword phpFunctions apc_cache_info apc_clear_cache apc_store apc_fetch apc_enabled apc_delete apc_add apc_sma_info apc_inc apc_dec apc_cas apc_exists contained
syn keyword phpFunctions apcu_add apcu_cache_info apcu_cas apcu_clear_cache apcu_dec apcu_delete apcu_enabled apcu_entry apcu_exists apcu_fetch apcu_inc apcu_key_info apcu_sma_info apcu_store contained
syn keyword phpFunctions apache_child_terminate apache_get_modules apache_get_version apache_getenv apache_lookup_uri apache_note apache_request_headers apache_response_headers apache_setenv ascii2ebcdic ebcdic2ascii getallheaders virtual contained
syn keyword phpFunctions array_change_key_case array_chunk array_column array_combine array_count_values array_diff_assoc array_diff_key array_diff_uassoc array_diff_ukey array_diff array_fill_keys array_fill array_filter array_flip array_intersect_assoc array_intersect_key array_intersect_uassoc array_intersect_ukey array_intersect array_key_exists array_keys array_map array_merge_recursive array_merge array_multisort array_pad array_pop array_product array_push array_rand array_reduce array_replace_recursive array_replace array_reverse array_search array_shift array_slice array_splice array_sum array_udiff_assoc array_udiff_uassoc array_udiff array_uintersect_assoc array_uintersect_uassoc array_uintersect array_unique array_unshift array_values array_walk_recursive array_walk arsort asort count current each end in_array key_exists key krsort ksort natcasesort natsort next pos prev range reset rsort shuffle sizeof sort uasort uksort usort contained
syn keyword phpFunctions aspell_check aspell_new aspell_suggest contained
syn keyword phpFunctions bcadd bccomp bcdiv bcmod bcmul bcpow bcpowmod bcscale bcsqrt bcsub contained
syn keyword phpFunctions bzclose bzcompress bzdecompress bzerrno bzerror bzerrstr bzflush bzopen bzread bzwrite contained
syn keyword phpFunctions cal_days_in_month cal_from_jd cal_info cal_to_jd easter_date easter_days frenchtojd gregoriantojd jddayofweek jdmonthname jdtofrench jdtogregorian jdtojewish jdtojulian jdtounix jewishtojd juliantojd unixtojd contained
syn keyword phpFunctions ccvs_add ccvs_auth ccvs_command ccvs_count ccvs_delete ccvs_done ccvs_init ccvs_lookup ccvs_new ccvs_report ccvs_return ccvs_reverse ccvs_sale ccvs_status ccvs_textvalue ccvs_void contained
syn keyword phpFunctions call_user_method_array call_user_method class_exists get_class_methods get_class_vars get_class get_declared_classes get_object_vars get_parent_class is_a is_subclass_of method_exists contained
syn keyword phpFunctions com VARIANT com_addref com_get com_invoke com_isenum com_load_typelib com_load com_propget com_propput com_propset com_release com_set contained
syn keyword phpFunctions cpdf_add_annotation cpdf_add_outline cpdf_arc cpdf_begin_text cpdf_circle cpdf_clip cpdf_close cpdf_closepath_fill_stroke cpdf_closepath_stroke cpdf_closepath cpdf_continue_text cpdf_curveto cpdf_end_text cpdf_fill_stroke cpdf_fill cpdf_finalize_page cpdf_finalize cpdf_global_set_document_limits cpdf_import_jpeg cpdf_lineto cpdf_moveto cpdf_newpath cpdf_open cpdf_output_buffer cpdf_page_init cpdf_place_inline_image cpdf_rect cpdf_restore cpdf_rlineto cpdf_rmoveto cpdf_rotate_text cpdf_rotate cpdf_save_to_file cpdf_save cpdf_scale cpdf_set_action_url cpdf_set_char_spacing cpdf_set_creator cpdf_set_current_page cpdf_set_font_directories cpdf_set_font_map_file cpdf_set_font cpdf_set_horiz_scaling cpdf_set_keywords cpdf_set_leading cpdf_set_page_animation cpdf_set_subject cpdf_set_text_matrix cpdf_set_text_pos cpdf_set_text_rendering cpdf_set_text_rise cpdf_set_title cpdf_set_viewer_preferences cpdf_set_word_spacing cpdf_setdash cpdf_setflat cpdf_setgray_fill cpdf_setgray_stroke cpdf_setgray cpdf_setlinecap cpdf_setlinejoin cpdf_setlinewidth cpdf_setmiterlimit cpdf_setrgbcolor_fill cpdf_setrgbcolor_stroke cpdf_setrgbcolor cpdf_show_xy cpdf_show cpdf_stringwidth cpdf_stroke cpdf_text cpdf_translate contained
syn keyword phpFunctions crack_check crack_closedict crack_getlastmessage crack_opendict contained
syn keyword phpFunctions ctype_alnum ctype_alpha ctype_cntrl ctype_digit ctype_graph ctype_lower ctype_print ctype_punct ctype_space ctype_upper ctype_xdigit contained
syn keyword phpFunctions curl_close curl_errno curl_error curl_exec curl_getinfo curl_init curl_multi_add_handle curl_multi_close curl_multi_exec curl_multi_getcontent curl_multi_info_read curl_multi_init curl_multi_remove_handle curl_multi_select curl_setopt curl_version curl_copy_handle curl_escape curl_file_create curl_multi_errno curl_multi_setopt curl_multi_strerror curl_pause curl_reset curl_setopt_array curl_share_close curl_share_errno curl_share_init curl_share_setopt curl_share_strerror curl_strerror curl_unescape contained
syn keyword phpFunctions cybercash_base64_decode cybercash_base64_encode cybercash_decr cybercash_encr contained
syn keyword phpFunctions cyrus_authenticate cyrus_bind cyrus_close cyrus_connect cyrus_query cyrus_unbind contained
syn keyword phpFunctions checkdate date getdate gettimeofday gmdate gmmktime gmstrftime localtime microtime mktime strftime strtotime time date_add date_create date_create_from_format date_create_immutable date_create_immutable_from_format date_date_set date_default_timezone_get date_default_timezone_set date_diff date_format date_get_last_errors date_interval_create_from_date_string date_interval_format date_isodate_set date_modify date_offset_get date_parse date_parse_from_format date_sub date_sun_info date_sunrise date_sunset date_time_set date_timestamp_get date_timestamp_set date_timezone_get date_timezone_set idate timezone_abbreviations_list timezone_identifiers_list timezone_location_get timezone_name_from_abbr timezone_name_get timezone_offset_get timezone_open timezone_transitions_get timezone_version_get contained
syn keyword phpFunctions dba_close dba_delete dba_exists dba_fetch dba_firstkey dba_handlers dba_insert dba_key_split dba_list dba_nextkey dba_open dba_optimize dba_popen dba_replace dba_sync contained
syn keyword phpFunctions dbase_add_record dbase_close dbase_create dbase_delete_record dbase_get_header_info dbase_get_record_with_names dbase_get_record dbase_numfields dbase_numrecords dbase_open dbase_pack dbase_replace_record contained
syn keyword phpFunctions dblist dbmclose dbmdelete dbmexists dbmfetch dbmfirstkey dbminsert dbmnextkey dbmopen dbmreplace contained
syn keyword phpFunctions dbplus_add dbplus_aql dbplus_chdir dbplus_close dbplus_curr dbplus_errcode dbplus_errno dbplus_find dbplus_first dbplus_flush dbplus_freealllocks dbplus_freelock dbplus_freerlocks dbplus_getlock dbplus_getunique dbplus_info dbplus_last dbplus_lockrel dbplus_next dbplus_open dbplus_prev dbplus_rchperm dbplus_rcreate dbplus_rcrtexact dbplus_rcrtlike dbplus_resolve dbplus_restorepos dbplus_rkeys dbplus_ropen dbplus_rquery dbplus_rrename dbplus_rsecindex dbplus_runlink dbplus_rzap dbplus_savepos dbplus_setindex dbplus_setindexbynumber dbplus_sql dbplus_tcl dbplus_tremove dbplus_undo dbplus_undoprepare dbplus_unlockrel dbplus_unselect dbplus_update dbplus_xlockrel dbplus_xunlockrel contained
syn keyword phpFunctions dbx_close dbx_compare dbx_connect dbx_error dbx_escape_string dbx_fetch_row dbx_query dbx_sort contained
syn keyword phpFunctions dio_close dio_fcntl dio_open dio_read dio_seek dio_stat dio_tcsetattr dio_truncate dio_write contained
syn keyword phpFunctions chdir chroot dir closedir getcwd opendir readdir rewinddir scandir contained
syn keyword phpFunctions dom_import_simplexml contained
syn keyword phpFunctions domxml_new_doc domxml_open_file domxml_open_mem domxml_version domxml_xmltree domxml_xslt_stylesheet_doc domxml_xslt_stylesheet_file domxml_xslt_stylesheet xpath_eval_expression xpath_eval xpath_new_context xptr_eval xptr_new_context contained
syn keyword phpMethods name specified value create_attribute create_cdata_section create_comment create_element_ns create_element create_entity_reference create_processing_instruction create_text_node doctype document_element dump_file dump_mem get_element_by_id get_elements_by_tagname html_dump_mem xinclude entities internal_subset name notations public_id system_id get_attribute_node get_attribute get_elements_by_tagname has_attribute remove_attribute set_attribute tagname add_namespace append_child append_sibling attributes child_nodes clone_node dump_node first_child get_content has_attributes has_child_nodes insert_before is_blank_node last_child next_sibling node_name node_type node_value owner_document parent_node prefix previous_sibling remove_child replace_child replace_node set_content set_name set_namespace unlink_node data target process result_dump_file result_dump_mem contained
syn keyword phpFunctions dotnet_load contained
syn keyword phpFunctions debug_backtrace debug_print_backtrace error_log error_reporting restore_error_handler set_error_handler trigger_error user_error contained
syn keyword phpFunctions enchant_broker_describe enchant_broker_dict_exists enchant_broker_free enchant_broker_free_dict enchant_broker_get_dict_path enchant_broker_get_error enchant_broker_init enchant_broker_list_dicts enchant_broker_request_dict enchant_broker_request_pwl_dict enchant_broker_set_dict_path enchant_broker_set_ordering enchant_dict_add enchant_dict_add_to_personal enchant_dict_add_to_session enchant_dict_check enchant_dict_describe enchant_dict_get_error enchant_dict_is_added enchant_dict_is_in_session enchant_dict_quick_check enchant_dict_store_replacement enchant_dict_suggest contained
syn keyword phpFunctions escapeshellarg escapeshellcmd exec passthru proc_close proc_get_status proc_nice proc_open proc_terminate shell_exec system contained
syn keyword phpFunctions fam_cancel_monitor fam_close fam_monitor_collection fam_monitor_directory fam_monitor_file fam_next_event fam_open fam_pending fam_resume_monitor fam_suspend_monitor contained
syn keyword phpFunctions fbsql_affected_rows fbsql_autocommit fbsql_change_user fbsql_close fbsql_commit fbsql_connect fbsql_create_blob fbsql_create_clob fbsql_create_db fbsql_data_seek fbsql_database_password fbsql_database fbsql_db_query fbsql_db_status fbsql_drop_db fbsql_errno fbsql_error fbsql_fetch_array fbsql_fetch_assoc fbsql_fetch_field fbsql_fetch_lengths fbsql_fetch_object fbsql_fetch_row fbsql_field_flags fbsql_field_len fbsql_field_name fbsql_field_seek fbsql_field_table fbsql_field_type fbsql_free_result fbsql_get_autostart_info fbsql_hostname fbsql_insert_id fbsql_list_dbs fbsql_list_fields fbsql_list_tables fbsql_next_result fbsql_num_fields fbsql_num_rows fbsql_password fbsql_pconnect fbsql_query fbsql_read_blob fbsql_read_clob fbsql_result fbsql_rollback fbsql_select_db fbsql_set_lob_mode fbsql_set_transaction fbsql_start_db fbsql_stop_db fbsql_tablename fbsql_username fbsql_warnings contained
syn keyword phpFunctions fdf_add_doc_javascript fdf_add_template fdf_close fdf_create fdf_enum_values fdf_errno fdf_error fdf_get_ap fdf_get_attachment fdf_get_encoding fdf_get_file fdf_get_flags fdf_get_opt fdf_get_status fdf_get_value fdf_get_version fdf_header fdf_next_field_name fdf_open_string fdf_open fdf_remove_item fdf_save_string fdf_save fdf_set_ap fdf_set_encoding fdf_set_file fdf_set_flags fdf_set_javascript_action fdf_set_opt fdf_set_status fdf_set_submit_form_action fdf_set_target_frame fdf_set_value fdf_set_version contained
syn keyword phpFunctions filepro_fieldcount filepro_fieldname filepro_fieldtype filepro_fieldwidth filepro_retrieve filepro_rowcount filepro contained
syn keyword phpFunctions filter_has_var filter_id filter_input filter_input_array filter_list filter_var filter_var_array contained
syn keyword phpFunctions basename chgrp chmod chown clearstatcache copy delete dirname disk_free_space disk_total_space diskfreespace fclose feof fflush fgetc fgetcsv fgets fgetss file_exists file_get_contents file_put_contents file fileatime filectime filegroup fileinode filemtime fileowner fileperms filesize filetype flock fnmatch fopen fpassthru fputs fread fscanf fseek fstat ftell ftruncate fwrite glob is_dir is_executable is_file is_link is_readable is_uploaded_file is_writable is_writeable link linkinfo lstat mkdir move_uploaded_file parse_ini_file pathinfo pclose popen readfile readlink realpath rename rewind rmdir set_file_buffer stat symlink tempnam tmpfile touch umask unlink contained
syn keyword phpFunctions fribidi_log2vis contained
syn keyword phpFunctions ftp_alloc ftp_cdup ftp_chdir ftp_chmod ftp_close ftp_connect ftp_delete ftp_exec ftp_fget ftp_fput ftp_get_option ftp_get ftp_login ftp_mdtm ftp_mkdir ftp_nb_continue ftp_nb_fget ftp_nb_fput ftp_nb_get ftp_nb_put ftp_nlist ftp_pasv ftp_put ftp_pwd ftp_quit ftp_raw ftp_rawlist ftp_rename ftp_rmdir ftp_set_option ftp_site ftp_size ftp_ssl_connect ftp_systype ftp_append ftp_mlsd contained
syn keyword phpFunctions call_user_func_array call_user_func create_function func_get_arg func_get_args func_num_args function_exists get_defined_functions register_shutdown_function register_tick_function unregister_tick_function contained
syn keyword phpFunctions bind_textdomain_codeset bindtextdomain dcgettext dcngettext dgettext dngettext gettext ngettext textdomain _ contained
syn keyword phpFunctions gmp_abs gmp_add gmp_and gmp_clrbit gmp_cmp gmp_com gmp_div_q gmp_div_qr gmp_div_r gmp_div gmp_divexact gmp_fact gmp_gcd gmp_gcdext gmp_hamdist gmp_init gmp_intval gmp_invert gmp_jacobi gmp_legendre gmp_mod gmp_mul gmp_neg gmp_or gmp_perfect_square gmp_popcount gmp_pow gmp_powm gmp_prob_prime gmp_random gmp_scan0 gmp_scan1 gmp_setbit gmp_sign gmp_sqrt gmp_sqrtrem gmp_sqrtrm gmp_strval gmp_sub gmp_xor gmp_binomial gmp_export gmp_import gmp_kronecker gmp_lcm gmp_nextprime gmp_perfect_power gmp_random_bits gmp_random_range gmp_random_seed gmp_root gmp_rootrem gmp_testbit contained
syn keyword phpFunctions hash hash_algos hash_copy hash_equals hash_file hash_final hash_hkdf hash_hmac hash_hmac_algos hash_hmac_file hash_init hash_pbkdf2 hash_update hash_update_file hash_update_stream contained
syn keyword phpFunctions header headers_list headers_sent setcookie contained
syn keyword phpFunctions hw_api_attribute hwapi_hgcsp hw_api_content hw_api_object contained
syn keyword phpMethods key langdepvalue value values checkin checkout children mimetype read content copy dbstat dcstat dstanchors dstofsrcanchors count reason find ftstat hwstat identify info insert insertanchor insertcollection insertdocument link lock move assign attreditable count insert remove title value object objectbyanchor parents description type remove replace setcommitedversion srcanchors srcsofdst unlock user userlist contained
syn keyword phpFunctions hw_Array2Objrec hw_changeobject hw_Children hw_ChildrenObj hw_Close hw_Connect hw_connection_info hw_cp hw_Deleteobject hw_DocByAnchor hw_DocByAnchorObj hw_Document_Attributes hw_Document_BodyTag hw_Document_Content hw_Document_SetContent hw_Document_Size hw_dummy hw_EditText hw_Error hw_ErrorMsg hw_Free_Document hw_GetAnchors hw_GetAnchorsObj hw_GetAndLock hw_GetChildColl hw_GetChildCollObj hw_GetChildDocColl hw_GetChildDocCollObj hw_GetObject hw_GetObjectByQuery hw_GetObjectByQueryColl hw_GetObjectByQueryCollObj hw_GetObjectByQueryObj hw_GetParents hw_GetParentsObj hw_getrellink hw_GetRemote hw_getremotechildren hw_GetSrcByDestObj hw_GetText hw_getusername hw_Identify hw_InCollections hw_Info hw_InsColl hw_InsDoc hw_insertanchors hw_InsertDocument hw_InsertObject hw_mapid hw_Modifyobject hw_mv hw_New_Document hw_objrec2array hw_Output_Document hw_pConnect hw_PipeDocument hw_Root hw_setlinkroot hw_stat hw_Unlock hw_Who contained
syn keyword phpFunctions ibase_add_user ibase_affected_rows ibase_blob_add ibase_blob_cancel ibase_blob_close ibase_blob_create ibase_blob_echo ibase_blob_get ibase_blob_import ibase_blob_info ibase_blob_open ibase_close ibase_commit_ret ibase_commit ibase_connect ibase_delete_user ibase_drop_db ibase_errcode ibase_errmsg ibase_execute ibase_fetch_assoc ibase_fetch_object ibase_fetch_row ibase_field_info ibase_free_event_handler ibase_free_query ibase_free_result ibase_gen_id ibase_modify_user ibase_name_result ibase_num_fields ibase_num_params ibase_param_info ibase_pconnect ibase_prepare ibase_query ibase_rollback_ret ibase_rollback ibase_set_event_handler ibase_timefmt ibase_trans ibase_wait_event contained
syn keyword phpFunctions iconv_get_encoding iconv_mime_decode_headers iconv_mime_decode iconv_mime_encode iconv_set_encoding iconv_strlen iconv_strpos iconv_strrpos iconv_substr iconv ob_iconv_handler contained
syn keyword phpFunctions ifx_affected_rows ifx_blobinfile_mode ifx_byteasvarchar ifx_close ifx_connect ifx_copy_blob ifx_create_blob ifx_create_char ifx_do ifx_error ifx_errormsg ifx_fetch_row ifx_fieldproperties ifx_fieldtypes ifx_free_blob ifx_free_char ifx_free_result ifx_get_blob ifx_get_char ifx_getsqlca ifx_htmltbl_result ifx_nullformat ifx_num_fields ifx_num_rows ifx_pconnect ifx_prepare ifx_query ifx_textasvarchar ifx_update_blob ifx_update_char ifxus_close_slob ifxus_create_slob ifxus_free_slob ifxus_open_slob ifxus_read_slob ifxus_seek_slob ifxus_tell_slob ifxus_write_slob contained
syn keyword phpFunctions igbinary_serialize igbinary_unserialize contained
syn keyword phpFunctions exif_imagetype exif_read_data exif_thumbnail gd_info getimagesize image_type_to_mime_type image2wbmp imagealphablending imageantialias imagearc imagechar imagecharup imagecolorallocate imagecolorallocatealpha imagecolorat imagecolorclosest imagecolorclosestalpha imagecolorclosesthwb imagecolordeallocate imagecolorexact imagecolorexactalpha imagecolormatch imagecolorresolve imagecolorresolvealpha imagecolorset imagecolorsforindex imagecolorstotal imagecolortransparent imagecopy imagecopymerge imagecopymergegray imagecopyresampled imagecopyresized imagecreate imagecreatefromgd2 imagecreatefromgd2part imagecreatefromgd imagecreatefromgif imagecreatefromjpeg imagecreatefrompng imagecreatefromstring imagecreatefromwbmp imagecreatefromxbm imagecreatefromxpm imagecreatetruecolor imagedashedline imagedestroy imageellipse imagefill imagefilledarc imagefilledellipse imagefilledpolygon imagefilledrectangle imagefilltoborder imagefontheight imagefontwidth imageftbbox imagefttext imagegammacorrect imagegd2 imagegd imagegif imageinterlace imageistruecolor imagejpeg imageline imageloadfont imagepalettecopy imagepng imagepolygon imagepsbbox imagepscopyfont imagepsencodefont imagepsextendfont imagepsfreefont imagepsloadfont imagepsslantfont imagepstext imagerectangle imagerotate imagesavealpha imagesetbrush imagesetpixel imagesetstyle imagesetthickness imagesettile imagestring imagestringup imagesx imagesy imagetruecolortopalette imagettfbbox imagettftext imagetypes imagewbmp iptcembed iptcparse jpeg2wbmp png2wbmp read_exif_data exif_tagname imageaffine imageaffinematrixconcat imageaffinematrixget imagebmp imageconvolution imagecreatefrombmp imagecreatefromtga imagecrop imagecropauto imagefilter imageflip imagegetclip imagegetinterpolation imagelayereffect imageopenpolygon imagepalettetotruecolor imageresolution imagescale imagesetclip imagesetinterpolation imagexbm contained
syn keyword phpFunctions imap_8bit imap_alerts imap_append imap_base64 imap_binary imap_body imap_bodystruct imap_check imap_clearflag_full imap_close imap_createmailbox imap_delete imap_deletemailbox imap_errors imap_expunge imap_fetch_overview imap_fetchbody imap_fetchheader imap_fetchstructure imap_get_quota imap_get_quotaroot imap_getacl imap_getmailboxes imap_getsubscribed imap_header imap_headerinfo imap_headers imap_last_error imap_list imap_listmailbox imap_listscan imap_listsubscribed imap_lsub imap_mail_compose imap_mail_copy imap_mail_move imap_mail imap_mailboxmsginfo imap_mime_header_decode imap_msgno imap_num_msg imap_num_recent imap_open imap_ping imap_qprint imap_renamemailbox imap_reopen imap_rfc822_parse_adrlist imap_rfc822_parse_headers imap_rfc822_write_address imap_scanmailbox imap_search imap_set_quota imap_setacl imap_setflag_full imap_sort imap_status imap_subscribe imap_thread imap_timeout imap_uid imap_undelete imap_unsubscribe imap_utf7_decode imap_utf7_encode imap_utf8 contained
syn keyword phpFunctions assert_options assert dl extension_loaded get_cfg_var get_current_user get_defined_constants get_extension_funcs get_include_path get_included_files get_loaded_extensions get_magic_quotes_gpc get_magic_quotes_runtime get_required_files getenv getlastmod getmygid getmyinode getmypid getmyuid getopt getrusage ini_alter ini_get_all ini_get ini_restore ini_set main memory_get_usage php_ini_scanned_files php_logo_guid php_sapi_name php_uname phpcredits phpinfo phpversion putenv restore_include_path set_include_path set_magic_quotes_runtime set_time_limit version_compare zend_logo_guid zend_version contained
syn keyword phpFunctions ingres_autocommit ingres_close ingres_commit ingres_connect ingres_fetch_array ingres_fetch_object ingres_fetch_row ingres_field_length ingres_field_name ingres_field_nullable ingres_field_precision ingres_field_scale ingres_field_type ingres_num_fields ingres_num_rows ingres_pconnect ingres_query ingres_rollback contained
syn keyword phpFunctions collator_asort collator_compare collator_create collator_get_attribute collator_get_error_code collator_get_error_message collator_get_locale collator_get_sort_key collator_get_strength collator_set_attribute collator_set_strength collator_sort collator_sort_with_sort_keys datefmt_create datefmt_format datefmt_format_object datefmt_get_calendar datefmt_get_calendar_object datefmt_get_datetype datefmt_get_error_code datefmt_get_error_message datefmt_get_locale datefmt_get_pattern datefmt_get_timetype datefmt_get_timezone datefmt_get_timezone_id datefmt_is_lenient datefmt_localtime datefmt_parse datefmt_set_calendar datefmt_set_lenient datefmt_set_pattern datefmt_set_timezone grapheme_extract grapheme_stripos grapheme_stristr grapheme_strlen grapheme_strpos grapheme_strripos grapheme_strrpos grapheme_strstr grapheme_substr idn_to_ascii idn_to_utf8 intl_error_name intl_get_error_code intl_get_error_message intl_is_failure intlcal_add intlcal_after intlcal_before intlcal_clear intlcal_create_instance intlcal_equals intlcal_field_difference intlcal_from_date_time intlcal_get intlcal_get_actual_maximum intlcal_get_actual_minimum intlcal_get_available_locales intlcal_get_day_of_week_type intlcal_get_error_code intlcal_get_error_message intlcal_get_first_day_of_week intlcal_get_greatest_minimum intlcal_get_keyword_values_for_locale intlcal_get_least_maximum intlcal_get_locale intlcal_get_maximum intlcal_get_minimal_days_in_first_week intlcal_get_minimum intlcal_get_now intlcal_get_repeated_wall_time_option intlcal_get_skipped_wall_time_option intlcal_get_time intlcal_get_time_zone intlcal_get_type intlcal_get_weekend_transition intlcal_in_daylight_time intlcal_is_equivalent_to intlcal_is_lenient intlcal_is_set intlcal_is_weekend intlcal_roll intlcal_set intlcal_set_first_day_of_week intlcal_set_lenient intlcal_set_minimal_days_in_first_week intlcal_set_repeated_wall_time_option intlcal_set_skipped_wall_time_option intlcal_set_time intlcal_set_time_zone intlcal_to_date_time intlgregcal_create_instance intlgregcal_get_gregorian_change intlgregcal_is_leap_year intlgregcal_set_gregorian_change intltz_count_equivalent_ids intltz_create_default intltz_create_enumeration intltz_create_time_zone intltz_create_time_zone_id_enumeration intltz_from_date_time_zone intltz_get_canonical_id intltz_get_display_name intltz_get_dst_savings intltz_get_equivalent_id intltz_get_error_code intltz_get_error_message intltz_get_id_for_windows_id intltz_get_windows_id intltz_get_gmt intltz_get_id intltz_get_offset intltz_get_raw_offset intltz_get_region intltz_get_tz_data_version intltz_get_unknown intltz_has_same_rules intltz_to_date_time_zone intltz_use_daylight_time locale_accept_from_http locale_canonicalize locale_compose locale_filter_matches locale_get_all_variants locale_get_default locale_get_display_language locale_get_display_name locale_get_display_region locale_get_display_script locale_get_display_variant locale_get_keywords locale_get_primary_language locale_get_region locale_get_script locale_lookup locale_parse locale_set_default msgfmt_create msgfmt_format msgfmt_format_message msgfmt_get_error_code msgfmt_get_error_message msgfmt_get_locale msgfmt_get_pattern msgfmt_parse msgfmt_parse_message msgfmt_set_pattern normalizer_get_raw_decomposition normalizer_is_normalized normalizer_normalize numfmt_create numfmt_format numfmt_format_currency numfmt_get_attribute numfmt_get_error_code numfmt_get_error_message numfmt_get_locale numfmt_get_pattern numfmt_get_symbol numfmt_get_text_attribute numfmt_parse numfmt_parse_currency numfmt_set_attribute numfmt_set_pattern numfmt_set_symbol numfmt_set_text_attribute resourcebundle_count resourcebundle_create resourcebundle_get resourcebundle_get_error_code resourcebundle_get_error_message resourcebundle_locales transliterator_create transliterator_create_from_rules transliterator_create_inverse transliterator_get_error_code transliterator_get_error_message transliterator_list_ids transliterator_transliterate contained
syn keyword phpFunctions ircg_channel_mode ircg_disconnect ircg_fetch_error_msg ircg_get_username ircg_html_encode ircg_ignore_add ircg_ignore_del ircg_is_conn_alive ircg_join ircg_kick ircg_lookup_format_messages ircg_msg ircg_nick ircg_nickname_escape ircg_nickname_unescape ircg_notice ircg_part ircg_pconnect ircg_register_format_messages ircg_set_current ircg_set_file ircg_set_on_die ircg_topic ircg_whois contained
syn keyword phpFunctions java_last_exception_clear java_last_exception_get contained
syn keyword phpFunctions json_decode json_encode json_last_error json_last_error_msg contained
syn keyword phpFunctions ldap_8859_to_t61 ldap_add ldap_bind ldap_close ldap_compare ldap_connect ldap_count_entries ldap_delete ldap_dn2ufn ldap_err2str ldap_errno ldap_error ldap_explode_dn ldap_first_attribute ldap_first_entry ldap_first_reference ldap_free_result ldap_get_attributes ldap_get_dn ldap_get_entries ldap_get_option ldap_get_values_len ldap_get_values ldap_list ldap_mod_add ldap_mod_del ldap_mod_replace ldap_modify ldap_next_attribute ldap_next_entry ldap_next_reference ldap_parse_reference ldap_parse_result ldap_read ldap_rename ldap_search ldap_set_option ldap_set_rebind_proc ldap_sort ldap_start_tls ldap_t61_to_8859 ldap_unbind contained
syn keyword phpFunctions libxml_clear_errors libxml_disable_entity_loader libxml_get_errors libxml_get_last_error libxml_set_external_entity_loader libxml_set_streams_context libxml_use_internal_errors contained
syn keyword phpFunctions lzf_compress lzf_decompress lzf_optimized_for contained
syn keyword phpFunctions ezmlm_hash mail contained
syn keyword phpFunctions mailparse_determine_best_xfer_encoding mailparse_msg_create mailparse_msg_extract_part_file mailparse_msg_extract_part mailparse_msg_free mailparse_msg_get_part_data mailparse_msg_get_part mailparse_msg_get_structure mailparse_msg_parse_file mailparse_msg_parse mailparse_rfc822_parse_addresses mailparse_stream_encode mailparse_uudecode_all contained
syn keyword phpFunctions abs acos acosh asin asinh atan2 atan atanh base_convert bindec ceil cos cosh decbin dechex decoct deg2rad exp expm1 floor fmod getrandmax hexdec hypot is_finite is_infinite is_nan lcg_value log10 log1p log max min mt_getrandmax mt_rand mt_srand octdec pi pow rad2deg rand round sin sinh sqrt srand tan tanh contained
syn keyword phpFunctions array_key_first array_key_last boolval cli_get_process_title cli_set_process_title convert_uudecode convert_uuencode debug_zval_dump error_clear_last error_get_last forward_static_call forward_static_call_array fputcsv get_headers gethostname getimagesizefromstring header_register_callback header_remove hex2bin hrtime htmlspecialchars_decode http_response_code image_type_to_extension inet_ntop inet_pton intdiv is_countable is_iterable lcfirst lchgrp lchown memory_get_peak_usage net_get_interfaces parse_ini_string password_algos password_get_info password_hash password_needs_rehash password_verify php_ini_loaded_file php_strip_whitespace quoted_printable_encode random_bytes random_int realpath_cache_get realpath_cache_size setrawcookie str_getcsv stream_bucket_append stream_bucket_make_writeable stream_bucket_new stream_bucket_prepend stream_context_get_default stream_context_get_params stream_context_set_default stream_filter_remove stream_is_local stream_isatty stream_resolve_include_path stream_set_chunk_size stream_set_read_buffer stream_socket_enable_crypto stream_socket_pair stream_socket_shutdown stream_supports_lock stream_wrapper_restore stream_wrapper_unregister strpbrk strptime sys_get_temp_dir sys_getloadavg time_nanosleep time_sleep_until vfprintf contained
 
syn keyword phpFunctions mb_convert_case mb_convert_encoding mb_convert_kana mb_convert_variables mb_decode_mimeheader mb_decode_numericentity mb_detect_encoding mb_detect_order mb_encode_mimeheader mb_encode_numericentity mb_ereg_match mb_ereg_replace mb_ereg_search_getpos mb_ereg_search_getregs mb_ereg_search_init mb_ereg_search_pos mb_ereg_search_regs mb_ereg_search_setpos mb_ereg_search mb_ereg mb_eregi_replace mb_eregi mb_get_info mb_http_input mb_http_output mb_internal_encoding mb_language mb_output_handler mb_parse_str mb_preferred_mime_name mb_regex_encoding mb_regex_set_options mb_send_mail mb_split mb_strcut mb_strimwidth mb_strlen mb_strpos mb_strrpos mb_strtolower mb_strtoupper mb_strwidth mb_substitute_character mb_substr_count mb_substr mb_check_encoding mb_chr mb_encoding_aliases mb_ereg_replace_callback mb_list_encodings mb_ord mb_scrub mb_str_split mb_stripos mb_stristr mb_strrchr mb_strrichr mb_strripos mb_strstr mbereg mbereg_match mbereg_replace mbereg_search mbereg_search_getpos mbereg_search_getregs mbereg_search_init mbereg_search_pos mbereg_search_regs mbereg_search_setpos mberegi mberegi_replace mbregex_encoding mbsplit contained
syn keyword phpFunctions mcal_append_event mcal_close mcal_create_calendar mcal_date_compare mcal_date_valid mcal_day_of_week mcal_day_of_year mcal_days_in_month mcal_delete_calendar mcal_delete_event mcal_event_add_attribute mcal_event_init mcal_event_set_alarm mcal_event_set_category mcal_event_set_class mcal_event_set_description mcal_event_set_end mcal_event_set_recur_daily mcal_event_set_recur_monthly_mday mcal_event_set_recur_monthly_wday mcal_event_set_recur_none mcal_event_set_recur_weekly mcal_event_set_recur_yearly mcal_event_set_start mcal_event_set_title mcal_expunge mcal_fetch_current_stream_event mcal_fetch_event mcal_is_leap_year mcal_list_alarms mcal_list_events mcal_next_recurrence mcal_open mcal_popen mcal_rename_calendar mcal_reopen mcal_snooze mcal_store_event mcal_time_valid mcal_week_of_year contained
syn keyword phpFunctions mcrypt_cbc mcrypt_cfb mcrypt_create_iv mcrypt_decrypt mcrypt_ecb mcrypt_enc_get_algorithms_name mcrypt_enc_get_block_size mcrypt_enc_get_iv_size mcrypt_enc_get_key_size mcrypt_enc_get_modes_name mcrypt_enc_get_supported_key_sizes mcrypt_enc_is_block_algorithm_mode mcrypt_enc_is_block_algorithm mcrypt_enc_is_block_mode mcrypt_enc_self_test mcrypt_encrypt mcrypt_generic_deinit mcrypt_generic_end mcrypt_generic_init mcrypt_generic mcrypt_get_block_size mcrypt_get_cipher_name mcrypt_get_iv_size mcrypt_get_key_size mcrypt_list_algorithms mcrypt_list_modes mcrypt_module_close mcrypt_module_get_algo_block_size mcrypt_module_get_algo_key_size mcrypt_module_get_supported_key_sizes mcrypt_module_is_block_algorithm_mode mcrypt_module_is_block_algorithm mcrypt_module_is_block_mode mcrypt_module_open mcrypt_module_self_test mcrypt_ofb mdecrypt_generic contained
syn keyword phpFunctions mcve_adduser mcve_adduserarg mcve_bt mcve_checkstatus mcve_chkpwd mcve_chngpwd mcve_completeauthorizations mcve_connect mcve_connectionerror mcve_deleteresponse mcve_deletetrans mcve_deleteusersetup mcve_deluser mcve_destroyconn mcve_destroyengine mcve_disableuser mcve_edituser mcve_enableuser mcve_force mcve_getcell mcve_getcellbynum mcve_getcommadelimited mcve_getheader mcve_getuserarg mcve_getuserparam mcve_gft mcve_gl mcve_gut mcve_initconn mcve_initengine mcve_initusersetup mcve_iscommadelimited mcve_liststats mcve_listusers mcve_maxconntimeout mcve_monitor mcve_numcolumns mcve_numrows mcve_override mcve_parsecommadelimited mcve_ping mcve_preauth mcve_preauthcompletion mcve_qc mcve_responseparam mcve_return mcve_returncode mcve_returnstatus mcve_sale mcve_setblocking mcve_setdropfile mcve_setip mcve_setssl_files mcve_setssl mcve_settimeout mcve_settle mcve_text_avs mcve_text_code mcve_text_cv mcve_transactionauth mcve_transactionavs mcve_transactionbatch mcve_transactioncv mcve_transactionid mcve_transactionitem mcve_transactionssent mcve_transactiontext mcve_transinqueue mcve_transnew mcve_transparam mcve_transsend mcve_ub mcve_uwait mcve_verifyconnection mcve_verifysslcert mcve_void contained
syn keyword phpFunctions mhash_count mhash_get_block_size mhash_get_hash_name mhash_keygen_s2k mhash contained
syn keyword phpFunctions mime_content_type finfo_buffer finfo_close finfo_file finfo_open finfo_set_flags contained
syn keyword phpFunctions ming_setcubicthreshold ming_setscale ming_useswfversion SWFAction SWFBitmap swfbutton_keypress SWFbutton SWFDisplayItem SWFFill SWFFont SWFGradient SWFMorph SWFMovie SWFShape SWFSprite SWFText SWFTextField contained
syn keyword phpMethods getHeight getWidth addAction addShape setAction setdown setHit setOver setUp addColor move moveTo multColor remove Rotate rotateTo scale scaleTo setDepth setName setRatio skewX skewXTo skewY skewYTo moveTo rotateTo scaleTo skewXTo skewYTo getwidth addEntry getshape1 getshape2 add nextframe output remove save setbackground setdimension setframes setrate streammp3 addFill drawCurve drawCurveTo drawLine drawLineTo movePen movePenTo setLeftFill setLine setRightFill add nextframe remove setframes addString getWidth moveTo setColor setFont setHeight setSpacing addstring align setbounds setcolor setFont setHeight setindentation setLeftMargin setLineSpacing setMargins setname setrightMargin contained
syn keyword phpFunctions connection_aborted connection_status connection_timeout constant define defined die eval exit get_browser highlight_file highlight_string ignore_user_abort pack show_source sleep uniqid unpack usleep contained
syn keyword phpFunctions udm_add_search_limit udm_alloc_agent udm_api_version udm_cat_list udm_cat_path udm_check_charset udm_check_stored udm_clear_search_limits udm_close_stored udm_crc32 udm_errno udm_error udm_find udm_free_agent udm_free_ispell_data udm_free_res udm_get_doc_count udm_get_res_field udm_get_res_param udm_load_ispell_data udm_open_stored udm_set_agent_param contained
syn keyword phpFunctions msession_connect msession_count msession_create msession_destroy msession_disconnect msession_find msession_get_array msession_get msession_getdata msession_inc msession_list msession_listvar msession_lock msession_plugin msession_randstr msession_set_array msession_set msession_setdata msession_timeout msession_uniq msession_unlock contained
syn keyword phpFunctions msql_affected_rows msql_close msql_connect msql_create_db msql_createdb msql_data_seek msql_dbname msql_drop_db msql_dropdb msql_error msql_fetch_array msql_fetch_field msql_fetch_object msql_fetch_row msql_field_seek msql_fieldflags msql_fieldlen msql_fieldname msql_fieldtable msql_fieldtype msql_free_result msql_freeresult msql_list_dbs msql_list_fields msql_list_tables msql_listdbs msql_listfields msql_listtables msql_num_fields msql_num_rows msql_numfields msql_numrows msql_pconnect msql_query msql_regcase msql_result msql_select_db msql_selectdb msql_tablename msql contained
syn keyword phpFunctions mssql_bind mssql_close mssql_connect mssql_data_seek mssql_execute mssql_fetch_array mssql_fetch_assoc mssql_fetch_batch mssql_fetch_field mssql_fetch_object mssql_fetch_row mssql_field_length mssql_field_name mssql_field_seek mssql_field_type mssql_free_result mssql_free_statement mssql_get_last_message mssql_guid_string mssql_init mssql_min_error_severity mssql_min_message_severity mssql_next_result mssql_num_fields mssql_num_rows mssql_pconnect mssql_query mssql_result mssql_rows_affected mssql_select_db contained
syn keyword phpFunctions muscat_close muscat_get muscat_give muscat_setup_net muscat_setup contained
syn keyword phpFunctions mysql_affected_rows mysql_change_user mysql_client_encoding mysql_close mysql_connect mysql_create_db mysql_data_seek mysql_db_name mysql_db_query mysql_drop_db mysql_errno mysql_error mysql_escape_string mysql_fetch_array mysql_fetch_assoc mysql_fetch_field mysql_fetch_lengths mysql_fetch_object mysql_fetch_row mysql_field_flags mysql_field_len mysql_field_name mysql_field_seek mysql_field_table mysql_field_type mysql_free_result mysql_get_client_info mysql_get_host_info mysql_get_proto_info mysql_get_server_info mysql_info mysql_insert_id mysql_list_dbs mysql_list_fields mysql_list_processes mysql_list_tables mysql_num_fields mysql_num_rows mysql_pconnect mysql_ping mysql_query mysql_real_escape_string mysql_result mysql_select_db mysql_stat mysql_tablename mysql_thread_id mysql_unbuffered_query contained
syn keyword phpFunctions mysqli_affected_rows mysqli_autocommit mysqli_bind_param mysqli_bind_result mysqli_change_user mysqli_character_set_name mysqli_close mysqli_commit mysqli_connect mysqli_data_seek mysqli_debug mysqli_disable_reads_from_master mysqli_disable_rpl_parse mysqli_dump_debug_info mysqli_enable_reads_from_master mysqli_enable_rpl_parse mysqli_errno mysqli_error mysqli_execute mysqli_fetch_array mysqli_fetch_assoc mysqli_fetch_field_direct mysqli_fetch_field mysqli_fetch_fields mysqli_fetch_lengths mysqli_fetch_object mysqli_fetch_row mysqli_fetch mysqli_field_count mysqli_field_seek mysqli_field_tell mysqli_free_result mysqli_get_client_info mysqli_get_host_info mysqli_get_proto_info mysqli_get_server_info mysqli_get_server_version mysqli_info mysqli_init mysqli_insert_id mysqli_kill mysqli_master_query mysqli_num_fields mysqli_num_rows mysqli_options mysqli_param_count mysqli_ping mysqli_prepare_result mysqli_prepare mysqli_profiler mysqli_query mysqli_read_query_result mysqli_real_connect mysqli_real_escape_string mysqli_real_query mysqli_reload mysqli_rollback mysqli_rpl_parse_enabled mysqli_rpl_probe mysqli_rpl_query_type mysqli_select_db mysqli_send_long_data mysqli_send_query mysqli_slave_query mysqli_ssl_set mysqli_stat mysqli_stmt_affected_rows mysqli_stmt_close mysqli_stmt_errno mysqli_stmt_error mysqli_stmt_store_result mysqli_store_result mysqli_thread_id mysqli_thread_safe mysqli_use_result mysqli_warning_count mysqli_begin_transaction mysqli_connect_errno mysqli_connect_error mysqli_error_list mysqli_escape_string mysqli_fetch_all mysqli_get_charset mysqli_get_client_stats mysqli_get_client_version mysqli_get_connection_stats mysqli_get_links_stats mysqli_get_warnings mysqli_more_results mysqli_multi_query mysqli_next_result mysqli_poll mysqli_reap_async_query mysqli_refresh mysqli_release_savepoint mysqli_report mysqli_savepoint mysqli_set_charset mysqli_set_opt mysqli_sqlstate mysqli_stmt_attr_get mysqli_stmt_attr_set mysqli_stmt_bind_param mysqli_stmt_bind_result mysqli_stmt_data_seek mysqli_stmt_error_list mysqli_stmt_execute mysqli_stmt_fetch mysqli_stmt_field_count mysqli_stmt_free_result mysqli_stmt_get_result mysqli_stmt_get_warnings mysqli_stmt_init mysqli_stmt_insert_id mysqli_stmt_more_results mysqli_stmt_next_result mysqli_stmt_num_rows mysqli_stmt_param_count mysqli_stmt_prepare mysqli_stmt_reset mysqli_stmt_result_metadata mysqli_stmt_send_long_data mysqli_stmt_sqlstate contained
syn keyword phpFunctions ncurses_addch ncurses_addchnstr ncurses_addchstr ncurses_addnstr ncurses_addstr ncurses_assume_default_colors ncurses_attroff ncurses_attron ncurses_attrset ncurses_baudrate ncurses_beep ncurses_bkgd ncurses_bkgdset ncurses_border ncurses_bottom_panel ncurses_can_change_color ncurses_cbreak ncurses_clear ncurses_clrtobot ncurses_clrtoeol ncurses_color_content ncurses_color_set ncurses_curs_set ncurses_def_prog_mode ncurses_def_shell_mode ncurses_define_key ncurses_del_panel ncurses_delay_output ncurses_delch ncurses_deleteln ncurses_delwin ncurses_doupdate ncurses_echo ncurses_echochar ncurses_end ncurses_erase ncurses_erasechar ncurses_filter ncurses_flash ncurses_flushinp ncurses_getch ncurses_getmaxyx ncurses_getmouse ncurses_getyx ncurses_halfdelay ncurses_has_colors ncurses_has_ic ncurses_has_il ncurses_has_key ncurses_hide_panel ncurses_hline ncurses_inch ncurses_init_color ncurses_init_pair ncurses_init ncurses_insch ncurses_insdelln ncurses_insertln ncurses_insstr ncurses_instr ncurses_isendwin ncurses_keyok ncurses_keypad ncurses_killchar ncurses_longname ncurses_meta ncurses_mouse_trafo ncurses_mouseinterval ncurses_mousemask ncurses_move_panel ncurses_move ncurses_mvaddch ncurses_mvaddchnstr ncurses_mvaddchstr ncurses_mvaddnstr ncurses_mvaddstr ncurses_mvcur ncurses_mvdelch ncurses_mvgetch ncurses_mvhline ncurses_mvinch ncurses_mvvline ncurses_mvwaddstr ncurses_napms ncurses_new_panel ncurses_newpad ncurses_newwin ncurses_nl ncurses_nocbreak ncurses_noecho ncurses_nonl ncurses_noqiflush ncurses_noraw ncurses_pair_content ncurses_panel_above ncurses_panel_below ncurses_panel_window ncurses_pnoutrefresh ncurses_prefresh ncurses_putp ncurses_qiflush ncurses_raw ncurses_refresh ncurses_replace_panel ncurses_reset_prog_mode ncurses_reset_shell_mode ncurses_resetty ncurses_savetty ncurses_scr_dump ncurses_scr_init ncurses_scr_restore ncurses_scr_set ncurses_scrl ncurses_show_panel ncurses_slk_attr ncurses_slk_attroff ncurses_slk_attron ncurses_slk_attrset ncurses_slk_clear ncurses_slk_color ncurses_slk_init ncurses_slk_noutrefresh ncurses_slk_refresh ncurses_slk_restore ncurses_slk_set ncurses_slk_touch ncurses_standend ncurses_standout ncurses_start_color ncurses_termattrs ncurses_termname ncurses_timeout ncurses_top_panel ncurses_typeahead ncurses_ungetch ncurses_ungetmouse ncurses_update_panels ncurses_use_default_colors ncurses_use_env ncurses_use_extended_names ncurses_vidattr ncurses_vline ncurses_waddch ncurses_waddstr ncurses_wattroff ncurses_wattron ncurses_wattrset ncurses_wborder ncurses_wclear ncurses_wcolor_set ncurses_werase ncurses_wgetch ncurses_whline ncurses_wmouse_trafo ncurses_wmove ncurses_wnoutrefresh ncurses_wrefresh ncurses_wstandend ncurses_wstandout ncurses_wvline contained
syn keyword phpFunctions checkdnsrr closelog debugger_off debugger_on define_syslog_variables dns_check_record dns_get_mx dns_get_record fsockopen gethostbyaddr gethostbyname gethostbynamel getmxrr getprotobyname getprotobynumber getservbyname getservbyport ip2long long2ip openlog pfsockopen socket_get_status socket_set_blocking socket_set_timeout syslog contained
syn keyword phpFunctions yp_all yp_cat yp_err_string yp_errno yp_first yp_get_default_domain yp_master yp_match yp_next yp_order contained
syn keyword phpFunctions notes_body notes_copy_db notes_create_db notes_create_note notes_drop_db notes_find_note notes_header_info notes_list_msgs notes_mark_read notes_mark_unread notes_nav_create notes_search notes_unread notes_version contained
syn keyword phpFunctions nsapi_request_headers nsapi_response_headers nsapi_virtual contained
syn keyword phpFunctions aggregate_info aggregate_methods_by_list aggregate_methods_by_regexp aggregate_methods aggregate_properties_by_list aggregate_properties_by_regexp aggregate_properties aggregate aggregation_info deaggregate contained
syn keyword phpFunctions ocibindbyname ocicancel ocicloselob ocicollappend ocicollassign ocicollassignelem ocicollgetelem ocicollmax ocicollsize ocicolltrim ocicolumnisnull ocicolumnname ocicolumnprecision ocicolumnscale ocicolumnsize ocicolumntype ocicolumntyperaw ocicommit ocidefinebyname ocierror ociexecute ocifetch ocifetchinto ocifetchstatement ocifreecollection ocifreecursor ocifreedesc ocifreestatement ociinternaldebug ociloadlob ocilogoff ocilogon ocinewcollection ocinewcursor ocinewdescriptor ocinlogon ocinumcols ociparse ociplogon ociresult ocirollback ocirowcount ocisavelob ocisavelobfile ociserverversion ocisetprefetch ocistatementtype ociwritelobtofile ociwritetemporarylob contained
syn keyword phpFunctions odbc_autocommit odbc_binmode odbc_close_all odbc_close odbc_columnprivileges odbc_columns odbc_commit odbc_connect odbc_cursor odbc_data_source odbc_do odbc_error odbc_errormsg odbc_exec odbc_execute odbc_fetch_array odbc_fetch_into odbc_fetch_object odbc_fetch_row odbc_field_len odbc_field_name odbc_field_num odbc_field_precision odbc_field_scale odbc_field_type odbc_foreignkeys odbc_free_result odbc_gettypeinfo odbc_longreadlen odbc_next_result odbc_num_fields odbc_num_rows odbc_pconnect odbc_prepare odbc_primarykeys odbc_procedurecolumns odbc_procedures odbc_result_all odbc_result odbc_rollback odbc_setoption odbc_specialcolumns odbc_statistics odbc_tableprivileges odbc_tables contained
syn keyword phpFunctions opcache_reset opcache_invalidate opcache_compile_file opcache_is_script_cached opcache_get_configuration opcache_get_status contained
syn keyword phpFunctions openssl_cipher_iv_length openssl_cms_decrypt openssl_cms_encrypt openssl_cms_read openssl_cms_sign openssl_cms_verify openssl_csr_export_to_file openssl_csr_export openssl_csr_get_public_key openssl_csr_get_subject openssl_csr_new openssl_csr_sign openssl_decrypt openssl_dh_compute_key openssl_digest openssl_encrypt openssl_error_string openssl_free_key openssl_get_cert_locations openssl_get_cipher_methods openssl_get_md_methods openssl_get_privatekey openssl_get_publickey openssl_open openssl_pbkdf2 openssl_pkcs12_export_to_file openssl_pkcs12_export openssl_pkcs12_read openssl_pkcs7_decrypt openssl_pkcs7_encrypt openssl_pkcs7_sign openssl_pkcs7_verify openssl_pkey_export_to_file openssl_pkey_export openssl_pkey_free openssl_pkey_get_details openssl_pkey_get_private openssl_pkey_get_public openssl_pkey_new openssl_private_decrypt openssl_private_encrypt openssl_public_decrypt openssl_public_encrypt openssl_random_pseudo_bytes openssl_seal openssl_sign openssl_spki_export_challenge openssl_spki_export openssl_spki_new openssl_spki_verify openssl_verify openssl_x509_check_private_key openssl_x509_checkpurpose openssl_x509_export_to_file openssl_x509_export openssl_x509_fingerprint openssl_x509_free openssl_x509_parse openssl_x509_read openssl_get_curve_names openssl_pkcs7_read openssl_pkey_derive openssl_x509_verify contained
syn keyword phpFunctions ora_bind ora_close ora_columnname ora_columnsize ora_columntype ora_commit ora_commitoff ora_commiton ora_do ora_error ora_errorcode ora_exec ora_fetch_into ora_fetch ora_getcolumn ora_logoff ora_logon ora_numcols ora_numrows ora_open ora_parse ora_plogon ora_rollback contained
syn keyword phpFunctions flush ob_clean ob_end_clean ob_end_flush ob_flush ob_get_clean ob_get_contents ob_get_flush ob_get_length ob_get_level ob_get_status ob_gzhandler ob_implicit_flush ob_list_handlers ob_start output_add_rewrite_var output_reset_rewrite_vars contained
syn keyword phpFunctions overload contained
syn keyword phpFunctions ovrimos_close ovrimos_commit ovrimos_connect ovrimos_cursor ovrimos_exec ovrimos_execute ovrimos_fetch_into ovrimos_fetch_row ovrimos_field_len ovrimos_field_name ovrimos_field_num ovrimos_field_type ovrimos_free_result ovrimos_longreadlen ovrimos_num_fields ovrimos_num_rows ovrimos_prepare ovrimos_result_all ovrimos_result ovrimos_rollback contained
syn keyword phpFunctions pcntl_exec pcntl_fork pcntl_signal pcntl_waitpid pcntl_wexitstatus pcntl_wifexited pcntl_wifsignaled pcntl_wifstopped pcntl_wstopsig pcntl_wtermsig pcntl_alarm pcntl_async_signals pcntl_errno pcntl_get_last_error pcntl_getpriority pcntl_setpriority pcntl_signal_dispatch pcntl_signal_get_handler pcntl_sigprocmask pcntl_sigtimedwait pcntl_sigwaitinfo pcntl_strerror pcntl_unshare pcntl_wait pcntl_wifcontinued contained
syn keyword phpFunctions preg_filter preg_grep preg_last_error preg_last_error_msg preg_match_all preg_match preg_quote preg_replace_callback preg_replace_callback_array preg_replace preg_split contained
syn keyword phpFunctions pdo_drivers contained
syn keyword phpFunctions pdf_add_annotation pdf_add_bookmark pdf_add_launchlink pdf_add_locallink pdf_add_note pdf_add_outline pdf_add_pdflink pdf_add_thumbnail pdf_add_weblink pdf_arc pdf_arcn pdf_attach_file pdf_begin_page pdf_begin_pattern pdf_begin_template pdf_circle pdf_clip pdf_close_image pdf_close_pdi_page pdf_close_pdi pdf_close pdf_closepath_fill_stroke pdf_closepath_stroke pdf_closepath pdf_concat pdf_continue_text pdf_curveto pdf_delete pdf_end_page pdf_end_pattern pdf_end_template pdf_endpath pdf_fill_stroke pdf_fill pdf_findfont pdf_get_buffer pdf_get_font pdf_get_fontname pdf_get_fontsize pdf_get_image_height pdf_get_image_width pdf_get_majorversion pdf_get_minorversion pdf_get_parameter pdf_get_pdi_parameter pdf_get_pdi_value pdf_get_value pdf_initgraphics pdf_lineto pdf_makespotcolor pdf_moveto pdf_new pdf_open_CCITT pdf_open_file pdf_open_gif pdf_open_image_file pdf_open_image pdf_open_jpeg pdf_open_memory_image pdf_open_pdi_page pdf_open_pdi pdf_open_png pdf_open_tiff pdf_open pdf_place_image pdf_place_pdi_page pdf_rect pdf_restore pdf_rotate pdf_save pdf_scale pdf_set_border_color pdf_set_border_dash pdf_set_border_style pdf_set_char_spacing pdf_set_duration pdf_set_font pdf_set_horiz_scaling pdf_set_info_author pdf_set_info_creator pdf_set_info_keywords pdf_set_info_subject pdf_set_info_title pdf_set_info pdf_set_leading pdf_set_parameter pdf_set_text_matrix pdf_set_text_pos pdf_set_text_rendering pdf_set_text_rise pdf_set_value pdf_set_word_spacing pdf_setcolor pdf_setdash pdf_setflat pdf_setfont pdf_setgray_fill pdf_setgray_stroke pdf_setgray pdf_setlinecap pdf_setlinejoin pdf_setlinewidth pdf_setmatrix pdf_setmiterlimit pdf_setpolydash pdf_setrgbcolor_fill pdf_setrgbcolor_stroke pdf_setrgbcolor pdf_show_boxed pdf_show_xy pdf_show pdf_skew pdf_stringwidth pdf_stroke pdf_translate contained
syn keyword phpFunctions pfpro_cleanup pfpro_init pfpro_process_raw pfpro_process pfpro_version contained
syn keyword phpFunctions pg_affected_rows pg_cancel_query pg_client_encoding pg_close pg_connect pg_connection_busy pg_connection_reset pg_connection_status pg_convert pg_copy_from pg_copy_to pg_dbname pg_delete pg_end_copy pg_escape_bytea pg_escape_string pg_fetch_all pg_fetch_array pg_fetch_assoc pg_fetch_object pg_fetch_result pg_fetch_row pg_field_is_null pg_field_name pg_field_num pg_field_prtlen pg_field_size pg_field_type pg_free_result pg_get_notify pg_get_pid pg_get_result pg_host pg_insert pg_last_error pg_last_notice pg_last_oid pg_lo_close pg_lo_create pg_lo_export pg_lo_import pg_lo_open pg_lo_read_all pg_lo_read pg_lo_seek pg_lo_tell pg_lo_unlink pg_lo_write pg_meta_data pg_num_fields pg_num_rows pg_options pg_pconnect pg_ping pg_port pg_put_line pg_query pg_result_error pg_result_seek pg_result_status pg_select pg_send_query pg_set_client_encoding pg_trace pg_tty pg_unescape_bytea pg_untrace pg_update pg_clientencoding pg_cmdtuples pg_connect_poll pg_consume_input pg_errormessage pg_escape_identifier pg_escape_literal pg_exec pg_execute pg_fetch_all_columns pg_field_table pg_field_type_oid pg_fieldisnull pg_fieldname pg_fieldnum pg_fieldprtlen pg_fieldsize pg_fieldtype pg_flush pg_freeresult pg_getlastoid pg_lo_truncate pg_loclose pg_locreate pg_loexport pg_loimport pg_loopen pg_loread pg_loreadall pg_lounlink pg_lowrite pg_numfields pg_numrows pg_parameter_status pg_prepare pg_query_params pg_result pg_result_error_field pg_send_execute pg_send_prepare pg_send_query_params pg_set_error_verbosity pg_setclientencoding pg_socket pg_transaction_status pg_version contained
syn keyword phpFunctions posix_ctermid posix_get_last_error posix_getcwd posix_getegid posix_geteuid posix_getgid posix_getgrgid posix_getgrnam posix_getgroups posix_getlogin posix_getpgid posix_getpgrp posix_getpid posix_getppid posix_getpwnam posix_getpwuid posix_getrlimit posix_getsid posix_getuid posix_isatty posix_kill posix_mkfifo posix_setegid posix_seteuid posix_setgid posix_setpgid posix_setsid posix_setuid posix_strerror posix_times posix_ttyname posix_uname posix_access posix_errno posix_initgroups posix_mknod posix_setrlimit contained
syn keyword phpFunctions printer_abort printer_close printer_create_brush printer_create_dc printer_create_font printer_create_pen printer_delete_brush printer_delete_dc printer_delete_font printer_delete_pen printer_draw_bmp printer_draw_chord printer_draw_elipse printer_draw_line printer_draw_pie printer_draw_rectangle printer_draw_roundrect printer_draw_text printer_end_doc printer_end_page printer_get_option printer_list printer_logical_fontheight printer_open printer_select_brush printer_select_font printer_select_pen printer_set_option printer_start_doc printer_start_page printer_write contained
syn keyword phpFunctions pspell_add_to_personal pspell_add_to_session pspell_check pspell_clear_session pspell_config_create pspell_config_ignore pspell_config_mode pspell_config_personal pspell_config_repl pspell_config_runtogether pspell_config_save_repl pspell_new_config pspell_new_personal pspell_new pspell_save_wordlist pspell_store_replacement pspell_suggest pspell_config_data_dir pspell_config_dict_dir contained
syn keyword phpFunctions qdom_error qdom_tree contained
syn keyword phpFunctions readline_add_history readline_clear_history readline_completion_function readline_info readline_list_history readline_read_history readline_write_history readline readline_callback_handler_install readline_callback_handler_remove readline_callback_read_char readline_on_new_line readline_redisplay contained
syn keyword phpFunctions recode_file recode_string recode contained
syn keyword phpFunctions ereg_replace ereg eregi_replace eregi split spliti sql_regcase contained
syn keyword phpFunctions ftok msg_get_queue msg_queue_exists msg_receive msg_remove_queue msg_send msg_set_queue msg_stat_queue sem_acquire sem_get sem_release sem_remove shm_attach shm_detach shm_get_var shm_has_var shm_put_var shm_remove_var shm_remove contained
syn keyword phpFunctions sesam_affected_rows sesam_commit sesam_connect sesam_diagnostic sesam_disconnect sesam_errormsg sesam_execimm sesam_fetch_array sesam_fetch_result sesam_fetch_row sesam_field_array sesam_field_name sesam_free_result sesam_num_fields sesam_query sesam_rollback sesam_seek_row sesam_settransaction contained
syn keyword phpFunctions session_cache_expire session_cache_limiter session_decode session_destroy session_encode session_get_cookie_params session_id session_is_registered session_module_name session_name session_regenerate_id session_register session_save_path session_set_cookie_params session_set_save_handler session_start session_unregister session_unset session_write_close session_abort session_commit session_create_id session_gc session_register_shutdown session_reset session_status contained
syn keyword phpFunctions simplexml_import_dom simplexml_load_file simplexml_load_string contained
syn keyword phpFunctions shmop_close shmop_delete shmop_open shmop_read shmop_size shmop_write contained
syn keyword phpFunctions snmp_get_quick_print snmp_set_quick_print snmpget snmprealwalk snmpset snmpwalk snmpwalkoid contained
syn keyword phpFunctions is_soap_fault use_soap_error_handler contained
syn keyword phpFunctions socket_accept socket_bind socket_clear_error socket_close socket_connect socket_create_listen socket_create_pair socket_create socket_get_option socket_getpeername socket_getsockname socket_iovec_add socket_iovec_alloc socket_iovec_delete socket_iovec_fetch socket_iovec_free socket_iovec_set socket_last_error socket_listen socket_read socket_readv socket_recv socket_recvfrom socket_recvmsg socket_select socket_send socket_sendmsg socket_sendto socket_set_block socket_set_nonblock socket_set_option socket_shutdown socket_strerror socket_write socket_writev socket_addrinfo_bind socket_addrinfo_connect socket_addrinfo_explain socket_addrinfo_lookup socket_cmsg_space socket_export_stream socket_getopt socket_import_stream socket_setopt contained
syn keyword phpFunctions class_implements class_parents class_uses iterator_apply iterator_count iterator_to_array spl_autoload spl_autoload_call spl_autoload_extensions spl_autoload_functions spl_autoload_register spl_autoload_unregister spl_classes spl_object_hash spl_object_id contained
syn keyword phpFunctions sqlite_array_query sqlite_busy_timeout sqlite_changes sqlite_close sqlite_column sqlite_create_aggregate sqlite_create_function sqlite_current sqlite_error_string sqlite_escape_string sqlite_fetch_array sqlite_fetch_single sqlite_fetch_string sqlite_field_name sqlite_has_more sqlite_last_error sqlite_last_insert_rowid sqlite_libencoding sqlite_libversion sqlite_next sqlite_num_fields sqlite_num_rows sqlite_open sqlite_popen sqlite_query sqlite_rewind sqlite_seek sqlite_udf_decode_binary sqlite_udf_encode_binary sqlite_unbuffered_query contained
syn keyword phpFunctions stream_context_create stream_context_get_options stream_context_set_option stream_context_set_params stream_copy_to_stream stream_filter_append stream_filter_prepend stream_filter_register stream_get_contents stream_get_filters stream_get_line stream_get_meta_data stream_get_transports stream_get_wrappers stream_register_wrapper stream_select stream_set_blocking stream_set_timeout stream_set_write_buffer stream_socket_accept stream_socket_client stream_socket_get_name stream_socket_recvfrom stream_socket_sendto stream_socket_server stream_wrapper_register contained
syn keyword phpFunctions addcslashes addslashes bin2hex chop chr chunk_split convert_cyr_string count_chars crc32 crypt explode fprintf get_html_translation_table hebrev hebrevc html_entity_decode htmlentities htmlspecialchars implode join levenshtein localeconv ltrim md5_file md5 metaphone money_format nl_langinfo nl2br number_format ord parse_str print printf quoted_printable_decode quotemeta rtrim setlocale sha1_file sha1 similar_text soundex sprintf sscanf str_ireplace str_pad str_repeat str_replace str_rot13 str_shuffle str_split str_word_count strcasecmp strchr strcmp strcoll strcspn strip_tags stripcslashes stripos stripslashes stristr strlen strnatcasecmp strnatcmp strncasecmp strncmp strpos strrchr strrev strripos strrpos strspn strstr strtok strtolower strtoupper strtr substr_compare substr_count substr_replace substr trim ucfirst ucwords vprintf vsprintf wordwrap contained
syn keyword phpFunctions fdiv get_debug_type getdir str_contains str_ends_with str_starts_with
syn keyword phpFunctions swf_actiongeturl swf_actiongotoframe swf_actiongotolabel swf_actionnextframe swf_actionplay swf_actionprevframe swf_actionsettarget swf_actionstop swf_actiontogglequality swf_actionwaitforframe swf_addbuttonrecord swf_addcolor swf_closefile swf_definebitmap swf_definefont swf_defineline swf_definepoly swf_definerect swf_definetext swf_endbutton swf_enddoaction swf_endshape swf_endsymbol swf_fontsize swf_fontslant swf_fonttracking swf_getbitmapinfo swf_getfontinfo swf_getframe swf_labelframe swf_lookat swf_modifyobject swf_mulcolor swf_nextid swf_oncondition swf_openfile swf_ortho2 swf_ortho swf_perspective swf_placeobject swf_polarview swf_popmatrix swf_posround swf_pushmatrix swf_removeobject swf_rotate swf_scale swf_setfont swf_setframe swf_shapearc swf_shapecurveto3 swf_shapecurveto swf_shapefillbitmapclip swf_shapefillbitmaptile swf_shapefilloff swf_shapefillsolid swf_shapelinesolid swf_shapelineto swf_shapemoveto swf_showframe swf_startbutton swf_startdoaction swf_startshape swf_startsymbol swf_textwidth swf_translate swf_viewport contained
syn keyword phpFunctions sybase_affected_rows sybase_close sybase_connect sybase_data_seek sybase_deadlock_retry_count sybase_fetch_array sybase_fetch_assoc sybase_fetch_field sybase_fetch_object sybase_fetch_row sybase_field_seek sybase_free_result sybase_get_last_message sybase_min_client_severity sybase_min_error_severity sybase_min_message_severity sybase_min_server_severity sybase_num_fields sybase_num_rows sybase_pconnect sybase_query sybase_result sybase_select_db sybase_set_message_handler sybase_unbuffered_query contained
syn keyword phpFunctions tidy_access_count tidy_clean_repair tidy_config_count tidy_diagnose tidy_error_count tidy_get_body tidy_get_config tidy_get_error_buffer tidy_get_head tidy_get_html_ver tidy_get_html tidy_get_output tidy_get_release tidy_get_root tidy_get_status tidy_getopt tidy_is_xhtml tidy_load_config tidy_parse_file tidy_parse_string tidy_repair_file tidy_repair_string tidy_reset_config tidy_save_config tidy_set_encoding tidy_setopt tidy_warning_count tidy_is_xml tidy_get_opt_doc contained
syn keyword phpMethods attributes children get_attr get_nodes has_children has_siblings is_asp is_comment is_html is_jsp is_jste is_text is_xhtml is_xml next prev tidy_node contained
syn keyword phpFunctions token_get_all token_name contained
syn keyword phpFunctions base64_decode base64_encode get_meta_tags http_build_query parse_url rawurldecode rawurlencode urldecode urlencode contained
syn keyword phpFunctions doubleval empty floatval get_defined_vars get_resource_id get_resource_type gettype import_request_variables intval is_array is_bool is_callable is_double is_float is_int is_integer is_long is_null is_numeric is_object is_real is_resource is_scalar is_string isset print_r serialize settype strval unserialize unset var_dump var_export contained
syn keyword phpFunctions get_called_class property_exists interface_exists trait_exists class_alias get_mangled_object_vars set_exception_handler restore_exception_handler get_declared_traits get_declared_interfaces get_resources gc_mem_caches gc_collect_cycles gc_enabled gc_enable gc_disable gc_status contained
syn keyword phpFunctions vpopmail_add_alias_domain_ex vpopmail_add_alias_domain vpopmail_add_domain_ex vpopmail_add_domain vpopmail_add_user vpopmail_alias_add vpopmail_alias_del_domain vpopmail_alias_del vpopmail_alias_get_all vpopmail_alias_get vpopmail_auth_user vpopmail_del_domain_ex vpopmail_del_domain vpopmail_del_user vpopmail_error vpopmail_passwd vpopmail_set_user_quota contained
syn keyword phpFunctions w32api_deftype w32api_init_dtype w32api_invoke_function w32api_register_function w32api_set_call_method contained
syn keyword phpFunctions wddx_add_vars wddx_deserialize wddx_packet_end wddx_packet_start wddx_serialize_value wddx_serialize_vars contained
syn keyword phpFunctions utf8_decode utf8_encode xml_error_string xml_get_current_byte_index xml_get_current_column_number xml_get_current_line_number xml_get_error_code xml_parse_into_struct xml_parse xml_parser_create_ns xml_parser_create xml_parser_free xml_parser_get_option xml_parser_set_option xml_set_character_data_handler xml_set_default_handler xml_set_element_handler xml_set_end_namespace_decl_handler xml_set_external_entity_ref_handler xml_set_notation_decl_handler xml_set_object xml_set_processing_instruction_handler xml_set_start_namespace_decl_handler xml_set_unparsed_entity_decl_handler contained
syn keyword phpFunctions xmlrpc_decode_request xmlrpc_decode xmlrpc_encode_request xmlrpc_encode xmlrpc_get_type xmlrpc_parse_method_descriptions xmlrpc_server_add_introspection_data xmlrpc_server_call_method xmlrpc_server_create xmlrpc_server_destroy xmlrpc_server_register_introspection_callback xmlrpc_server_register_method xmlrpc_set_type xmlrpc_is_fault contained
syn keyword phpFunctions xmlwriter_end_attribute xmlwriter_end_cdata xmlwriter_end_comment xmlwriter_end_document xmlwriter_end_dtd xmlwriter_end_dtd_attlist xmlwriter_end_dtd_element xmlwriter_end_dtd_entity xmlwriter_end_element xmlwriter_end_pi xmlwriter_flush xmlwriter_full_end_element xmlwriter_open_memory xmlwriter_open_uri xmlwriter_output_memory xmlwriter_set_indent xmlwriter_set_indent_string xmlwriter_start_attribute xmlwriter_start_attribute_ns xmlwriter_start_cdata xmlwriter_start_comment xmlwriter_start_document xmlwriter_start_dtd xmlwriter_start_dtd_attlist xmlwriter_start_dtd_element xmlwriter_start_dtd_entity xmlwriter_start_element xmlwriter_start_element_ns xmlwriter_start_pi xmlwriter_text xmlwriter_write_attribute xmlwriter_write_attribute_ns xmlwriter_write_cdata xmlwriter_write_comment xmlwriter_write_dtd xmlwriter_write_dtd_attlist xmlwriter_write_dtd_element xmlwriter_write_dtd_entity xmlwriter_write_element xmlwriter_write_element_ns xmlwriter_write_pi xmlwriter_write_raw contained
syn keyword phpFunctions xslt_create xslt_errno xslt_error xslt_free xslt_output_process xslt_set_base xslt_set_encoding xslt_set_error_handler xslt_set_log xslt_set_sax_handler xslt_set_sax_handlers xslt_set_scheme_handler xslt_set_scheme_handlers contained
syn keyword phpFunctions yaz_addinfo yaz_ccl_conf yaz_ccl_parse yaz_close yaz_connect yaz_database yaz_element yaz_errno yaz_error yaz_es_result yaz_get_option yaz_hits yaz_itemorder yaz_present yaz_range yaz_record yaz_scan_result yaz_scan yaz_schema yaz_search yaz_set_option yaz_sort yaz_syntax yaz_wait contained
syn keyword phpFunctions zip_close zip_entry_close zip_entry_compressedsize zip_entry_compressionmethod zip_entry_filesize zip_entry_name zip_entry_open zip_entry_read zip_open zip_read contained
syn keyword phpFunctions gzclose gzcompress gzdeflate gzencode gzeof gzfile gzgetc gzgets gzgetss gzinflate gzopen gzpassthru gzputs gzread gzrewind gzseek gztell gzuncompress gzwrite readgzfile zlib_get_coding_type gzdecode zlib_encode zlib_decode deflate_init deflate_add inflate_init inflate_add inflate_get_status inflate_get_read_len contained

if exists( "php_baselib" )
  syn keyword phpMethods query next_record num_rows affected_rows nf f p np num_fields haltmsg seek link_id query_id metadata table_names nextid connect halt free register unregister is_registered delete url purl self_url pself_url hidden_session add_query padd_query reimport_get_vars reimport_post_vars reimport_cookie_vars set_container set_tokenname release_token put_headers get_id get_id put_id freeze thaw gc reimport_any_vars start url purl login_if is_authenticated auth_preauth auth_loginform auth_validatelogin auth_refreshlogin auth_registerform auth_doregister start check have_perm permsum perm_invalid contained
  syn keyword phpFunctions page_open page_close sess_load sess_save contained
endif

" Conditional
syn keyword phpConditional declare else enddeclare endswitch elseif endif if switch match contained

" Repeat
syn keyword phpRepeat as do endfor endforeach endwhile for foreach while contained

" Label
syn keyword phpLabel case default switch contained

" Statement
syn keyword phpStatement return break continue exit goto yield contained

" Keyword
syn keyword phpKeyword var const contained

" Type
syn keyword phpType void bool boolean int integer real double float string array object NULL callable iterable mixed never contained

" Structure
syn keyword phpStructure namespace extends implements instanceof parent self contained

" Operator
syn match phpOperator "[-=+%^&|*!.~?:]" contained display
syn match phpOperator "[-+*/%^&|.]=" contained display
syn match phpOperator "/[^*/]"me=e-1 contained display
syn match phpOperator "\$" contained display
syn match phpOperator "&&\|\<and\>" contained display
syn match phpOperator "||\|\<x\=or\>" contained display
syn match phpRelation "[!=<>]=" contained display
syn match phpRelation "[<>]" contained display
syn match phpRelation "<=>" contained display
" PHP 8.0 adds the nullsafe operator ?-> for property access and method calls.
syn match phpMemberSelector "?\?->" contained display
syn match phpVarSelector "\$" contained display

" Identifier
syn match phpIdentifier "$\h\w*" contained contains=phpEnvVar,phpIntVar,phpVarSelector display
syn match phpIdentifierSimply "${\h\w*}" contains=phpOperator,phpParent contained display
syn region phpIdentifierComplex matchgroup=phpParent start="{\$"rs=e-1 end="}" contains=phpIdentifier,phpMemberSelector,phpVarSelector,phpIdentifierComplexP contained extend
syn region phpIdentifierComplexP matchgroup=phpParent start="\[" end="]" contains=@phpClInside contained

" Interpolated indentifiers (inside strings)
  syn match phpBrackets "[][}{]" contained display
  " errors
    syn match phpInterpSimpleError "\[[^]]*\]" contained display " fallback (if nothing else matches)
    syn match phpInterpSimpleError "?\?->[^a-zA-Z_]" contained display
    " make sure these stay above the correct DollarCurlies so they don't take priority
    syn match phpInterpBogusDollarCurley "${[^}]*}" contained display " fallback (if nothing else matches)
  syn match phpInterpSimpleBracketsInner "\w\+" contained
  syn match phpInterpSimpleBracketsInner "\$\h\w*" contained
  syn match phpInterpSimpleBrackets "\[\$\?\h\w*]" contained contains=phpBrackets,phpInterpSimpleBracketsInner
  " -0x1 and -123 refer to the string offsets '-0x1' and '-123' of array keys
  " TODO: Support [1_2], [-0b1_10_1], etc (also literal strings).
  syn match phpInterpSimpleBrackets "\[-\?\d\+]" contained contains=phpBrackets,phpInterpSimpleBracketsInner
  syn match phpInterpSimpleBrackets "\[-\?0[xX]\x\+]" contained contains=phpBrackets,phpInterpSimpleBracketsInner
  syn match phpInterpSimpleBrackets "\[-\?0[bB][01]\+]" contained contains=phpBrackets,phpInterpSimpleBracketsInner
  syn match phpInterpSimple "\$\h\w*\(\[[^]]*\]\|?\?->\h\w*\)\?" contained contains=phpInterpSimpleBrackets,phpIdentifier,phpInterpSimpleError,phpMethods,phpMemberSelector display
  syn match phpInterpVarname "\h\w*" contained
  syn match phpInterpMethodName "\h\w*" contained " default color
  syn match phpInterpSimpleCurly "\${\h\w*}" contains=phpInterpVarname contained extend
  syn region phpInterpDollarCurley1Helper matchgroup=phpParent start="{" end="\[" contains=phpInterpVarname contained
  syn region phpInterpDollarCurly1 matchgroup=phpParent start="\${\h\w*\["rs=s+1 end="]}" contains=phpInterpDollarCurley1Helper,@phpClConst contained extend

  syn match phpInterpDollarCurley2Helper "{\h\w*?\?->" contains=phpBrackets,phpInterpVarname,phpMemberSelector contained

  syn region phpInterpDollarCurly2 matchgroup=phpParent start="\${\h\w*?\?->"rs=s+1 end="}" contains=phpInterpDollarCurley2Helper,phpInterpMethodName contained

  syn match phpInterpBogusDollarCurley "${\h\w*?\?->}" contained display
  syn match phpInterpBogusDollarCurley "${\h\w*\[]}" contained display

  syn region phpInterpComplex matchgroup=phpParent start="{\$"rs=e-1 end="}" contains=phpIdentifier,phpMemberSelector,phpVarSelector,phpIdentifierComplexP contained extend
  syn region phpIdentifierComplexP matchgroup=phpParent start="\[" end="]" contains=@phpClInside contained
  " define a cluster to get all interpolation syntaxes for double-quoted strings
  syn cluster phpInterpDouble contains=phpInterpSimple,phpInterpSimpleCurly,phpInterpDollarCurly1,phpInterpDollarCurly2,phpInterpBogusDollarCurley,phpInterpComplex

" Methods
syn match phpMethodsVar "?\?->\h\w*" contained contains=phpMethods,phpMemberSelector display

" Include
syn keyword phpInclude include require include_once require_once use contained

" Define
syn keyword phpDefine new clone contained

" Boolean
syn keyword phpBoolean true false contained

" Float
" Refer to: https://www.php.net/manual/en/language.types.float.php
syn match phpFloat "\%(\w\|\.\)\@<!\%(\d_\?\|\.\)*\d\%(\d\|_\|\.\)*\%([eE][+-]\=\%(\d\|_\|\.\)\+\)\=\%(\w\|\.\)\@!" contained contains=phpFloatError display
syn match phpFloatError "\%([eE.][0-9._+-]*\.\|__\|_\(\>\|[eE]\)\|\(\>\|[eE]\)_\)" contained display

" Number
syn match phpNumber "\%(\.\)\@<!\<\%([1-9]\d*\|0\|0[xX]\(\x_\?\)*\x\)\>\%(\.\)\@!" contained display
syn match phpNumber "\%(\.\)\@<!\<0\d\+\|0[oO]\d\+\>\%(\.\)\@!" contained contains=phpOctalError display
syn match phpBinaryError "[2-9]" contained display
syn match phpNumber "\%(\.\)\@<!\<0[bB]\(\d_\?\)*\d\>\%(\.\)\@!" contained contains=phpBinaryError display

" Backslash escapes
syn case match
" for double quotes and heredoc
syn match phpBackslashSequences "\\[fnrtv\\\"$]" contained display
syn match phpBackslashSequences "\\\d\{1,3}" contained contains=phpOctalError display
syn match phpBackslashSequences "\\x\x\{1,2}" contained display
" additional sequence for double quotes only
syn match phpBackslashDoubleQuote "\\[\"]" contained display
" for single quotes only
syn match phpBackslashSingleQuote "\\[\\']" contained display
syn case ignore


" Error
syn match phpOctalError "[89]" contained display
if exists("php_parent_error_close")
  syn match phpParentError "[)\]}]" contained display
endif

" Todo
syn keyword phpTodo todo fixme xxx contained

" Comment
if exists("php_parent_error_open")
  syn region phpComment start="/\*" end="\*/" contained contains=phpTodo,@Spell
else
  syn region phpComment start="/\*" end="\*/" contained contains=phpTodo,@Spell extend
endif
syn match phpComment "#.\{-}\(?>\|$\)\@=" contained contains=phpTodo,@Spell
syn match phpComment "//.\{-}\(?>\|$\)\@=" contained contains=phpTodo,@Spell

" String
if exists("php_parent_error_open")
  syn region phpStringDouble matchgroup=phpStringDouble start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@phpAddStrings,phpBackslashSequences,phpBackslashDoubleQuote,@phpInterpDouble,@Spell contained keepend
  syn region phpBacktick matchgroup=phpBacktick start=+`+ skip=+\\\\\|\\"+ end=+`+ contains=@phpAddStrings,phpIdentifier,phpBackslashSequences,phpIdentifierSimply,phpIdentifierComplex contained keepend
  syn region phpStringSingle matchgroup=phpStringSingle start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=@phpAddStrings,phpBackslashSingleQuote,@Spell contained keepend
else
  syn region phpStringDouble matchgroup=phpStringDouble start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@phpAddStrings,phpBackslashSequences,phpBackslashDoubleQuote,@phpInterpDouble,@Spell contained extend keepend
  syn region phpBacktick matchgroup=phpBacktick start=+`+ skip=+\\\\\|\\"+ end=+`+ contains=@phpAddStrings,phpIdentifier,phpBackslashSequences,phpIdentifierSimply,phpIdentifierComplex contained extend keepend
  syn region phpStringSingle matchgroup=phpStringSingle start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=@phpAddStrings,phpBackslashSingleQuote,@Spell contained keepend extend
endif

" HereDoc and NowDoc
syn case match

" HereDoc
syn region phpHereDoc matchgroup=Delimiter start="\(<<<\)\@<=\(\"\=\)\z(\I\i*\)\2$" end="^\s*\z1\>" contained contains=phpIdentifier,phpIdentifierSimply,phpIdentifierComplex,phpBackslashSequences,phpMethodsVar,@Spell keepend extend
" including HTML,JavaScript,SQL even if not enabled via options
syn region phpHereDoc matchgroup=Delimiter start="\(<<<\)\@<=\(\"\=\)\z(\(\I\i*\)\=\(html\)\c\(\i*\)\)\2$" end="^\s*\z1\>" contained contains=@htmlTop,phpIdentifier,phpIdentifierSimply,phpIdentifierComplex,phpBackslashSequences,phpMethodsVar,@Spell keepend extend
syn region phpHereDoc matchgroup=Delimiter start="\(<<<\)\@<=\(\"\=\)\z(\(\I\i*\)\=\(sql\)\c\(\i*\)\)\2$" end="^\s*\z1\>" contained contains=@sqlTop,phpIdentifier,phpIdentifierSimply,phpIdentifierComplex,phpBackslashSequences,phpMethodsVar,@Spell keepend extend
syn region phpHereDoc matchgroup=Delimiter start="\(<<<\)\@<=\(\"\=\)\z(\(\I\i*\)\=\(javascript\)\c\(\i*\)\)\2$" end="^\s*\z1\>" contained contains=@htmlJavascript,phpIdentifierSimply,phpIdentifier,phpIdentifierComplex,phpBackslashSequences,phpMethodsVar,@Spell keepend extend

" NowDoc
syn region phpNowDoc matchgroup=Delimiter start="\(<<<\)\@<='\z(\I\i*\)'$" end="^\s*\z1\>" contained contains=@Spell keepend extend
" including HTML,JavaScript,SQL even if not enabled via options
syn region phpNowDoc matchgroup=Delimiter start="\(<<<\)\@<='\z(\(\I\i*\)\=\(html\)\c\(\i*\)\)'$" end="^\s*\z1\>" contained contains=@htmlTop,@Spell keepend extend
syn region phpNowDoc matchgroup=Delimiter start="\(<<<\)\@<='\z(\(\I\i*\)\=\(sql\)\c\(\i*\)\)'$" end="^\s*\z1\>" contained contains=@sqlTop,@Spell keepend extend
syn region phpNowDoc matchgroup=Delimiter start="\(<<<\)\@<='\z(\(\I\i*\)\=\(javascript\)\c\(\i*\)\)'$" end="^\s*\z1\>" contained contains=@htmlJavascript,@Spell keepend extend
syn case ignore

" Parent
if exists("php_parent_error_close") || exists("php_parent_error_open")
  syn match phpParent "[{}]" contained
  syn region phpParent matchgroup=Delimiter start="(" end=")" contained contains=@phpClInside transparent
  syn region phpParent matchgroup=Delimiter start="#\?\[" end="\]" contained contains=@phpClInside transparent
  if !exists("php_parent_error_close")
    syn match phpParent "[\])]" contained
  endif
else
  syn match phpParent "[({[\]})]" contained
  syn match phpParent "#\[" contained
endif

syn cluster phpClConst contains=phpFunctions,phpIdentifier,phpConditional,phpRepeat,phpStatement,phpOperator,phpRelation,phpStringSingle,phpStringDouble,phpBacktick,phpNumber,phpFloat,phpKeyword,phpType,phpBoolean,phpStructure,phpMethodsVar,phpConstant,phpCoreConstant,phpException
syn cluster phpClInside contains=@phpClConst,phpComment,phpLabel,phpParent,phpParentError,phpInclude,phpHereDoc,phpNowDoc
syn cluster phpClFunction contains=@phpClInside,phpDefine,phpParentError,phpStorageClass
syn cluster phpClTop contains=@phpClFunction,phpFoldFunction,phpFoldClass,phpFoldInterface,phpFoldTry,phpFoldCatch

" Php Region
if exists("php_parent_error_open")
  if exists("php_noShortTags")
    syn region phpRegion matchgroup=Delimiter start="<?\(php\|=\)" end="?>" contains=@phpClTop
  else
    syn region phpRegion matchgroup=Delimiter start="<?\(php\)\=" end="?>" contains=@phpClTop
  endif
  syn region phpRegionSc matchgroup=Delimiter start=+<script language="php">+ end=+</script>+ contains=@phpClTop
  if exists("php_asp_tags")
    syn region phpRegionAsp matchgroup=Delimiter start="<%\(=\)\=" end="%>" contains=@phpClTop
  endif
else
  if exists("php_noShortTags")
    syn region phpRegion matchgroup=Delimiter start="<?\(php\|=\)" end="?>" contains=@phpClTop keepend
  else
    syn region phpRegion matchgroup=Delimiter start="<?\(php\)\=" end="?>" contains=@phpClTop keepend
  endif
  syn region phpRegionSc matchgroup=Delimiter start=+<script language="php">+ end=+</script>+ contains=@phpClTop keepend
  if exists("php_asp_tags")
    syn region phpRegionAsp matchgroup=Delimiter start="<%\(=\)\=" end="%>" contains=@phpClTop keepend
  endif
endif

" Fold
if exists("php_folding") && php_folding==1
" match one line constructs here and skip them at folding
  syn keyword phpSCKeyword abstract final private protected public static readonly contained
  syn keyword phpFCKeyword function contained
  syn keyword phpDefine fn contained
  syn keyword phpStorageClass global contained
  syn match phpDefine "\(\s\|^\)\(abstract\s\+\|final\s\+\|private\s\+\|protected\s\+\|public\s\+\|static\s\+\)*function\(\s\+.*[;}]\)\@=" contained contains=phpSCKeyword
  syn match phpStructure "\(\s\|^\)\(abstract\s\+\|final\s\+\)*\(trait\|class\)\(\s\+.*}\)\@=" contained
  syn match phpStructure "\(\s\|^\)\(interface\|enum\)\(\s\+.*}\)\@=" contained
  syn match phpException "\(\s\|^\)try\(\s\+.*}\)\@=" contained
  syn match phpException "\(\s\|^\)catch\(\s\+.*}\)\@=" contained
  syn match phpException "\(\s\|^\)finally\(\s\+.*}\)\@=" contained

  setlocal foldmethod=syntax
  syn region phpFoldHtmlInside matchgroup=Delimiter start="?>" end="<?\(php\)\=" contained transparent contains=@htmlTop
  syn region phpFoldFunction matchgroup=Storageclass start="^\z(\s*\)\(abstract\s\+\|final\s\+\|private\s\+\|protected\s\+\|public\s\+\|static\s\+\)*function\s\([^};]*$\)\@="rs=e-9 matchgroup=Delimiter end="^\z1}" contains=@phpClFunction,phpFoldHtmlInside,phpFCKeyword contained transparent fold extend
  syn region phpFoldFunction matchgroup=Define start="^function\s\([^};]*$\)\@=" matchgroup=Delimiter end="^}" contains=@phpClFunction,phpFoldHtmlInside contained transparent fold extend
  syn region phpFoldClass matchgroup=Structure start="^\z(\s*\)\(abstract\s\+\|final\s\+\)*\(trait\|class\|enum\)\s\+\([^}]*$\)\@=" matchgroup=Delimiter end="^\z1}" contains=@phpClFunction,phpFoldFunction,phpSCKeyword contained transparent fold extend
  syn region phpFoldInterface matchgroup=Structure start="^\z(\s*\)interface\s\+\([^}]*$\)\@=" matchgroup=Delimiter end="^\z1}" contains=@phpClFunction,phpFoldFunction contained transparent fold extend
  syn region phpFoldCatch matchgroup=Exception start="^\z(\s*\)catch\s\+\([^}]*$\)\@=" matchgroup=Delimiter end="^\z1}" contains=@phpClFunction,phpFoldFunction contained transparent fold extend
  syn region phpFoldTry matchgroup=Exception start="^\z(\s*\)try\s\+\([^}]*$\)\@=" matchgroup=Delimiter end="^\z1}" contains=@phpClFunction,phpFoldFunction contained transparent fold extend
else
  syn keyword phpDefine function fn contained
  syn keyword phpStructure abstract class trait interface enum contained
  syn keyword phpException catch throw try finally contained
  syn keyword phpStorageClass final global private protected public static readonly contained
  if exists("php_folding") && php_folding==2
    setlocal foldmethod=syntax
    syn region phpFoldHtmlInside matchgroup=Delimiter start="?>" end="<?\(php\)\=" contained transparent contains=@htmlTop
    syn region phpParent matchgroup=Delimiter start="{" end="}" contained contains=@phpClFunction,phpFoldHtmlInside transparent fold
  endif
endif

" ================================================================
" Peter Hodge - June 9, 2006
" Some of these changes (highlighting isset/unset/echo etc) are not so
" critical, but they make things more colourful. :-)

" different syntax highlighting for 'echo', 'print', 'switch', 'die' and 'list' keywords
" to better indicate what they are.
syntax keyword phpDefine echo print contained
syntax keyword phpStructure list contained
syntax keyword phpConditional switch contained
syntax keyword phpStatement die contained

" Highlighting for PHP's user-definable magic class methods
syntax keyword phpSpecialFunction containedin=ALLBUT,phpComment,phpStringDouble,phpStringSingle,phpIdentifier
  \ __construct __destruct __call __callStatic __get __set __isset __unset __sleep __wakeup __toString __invoke __set_state __clone __debugInfo __serialize __unserialize
" Highlighting for __autoload slightly different from line above
syntax keyword phpSpecialFunction containedin=ALLBUT,phpComment,phpStringDouble,phpStringSingle,phpIdentifier,phpMethodsVar
  \ __autoload
hi def link phpSpecialFunction phpOperator

" Highlighting for PHP5's built-in classes
" Note: Some of the names have inconsistent cases. 
" Those are probably the actual name in reflection and should not be changed in
" this file.
" (CURLFile and CurlShareHandle, XMLReader and XmlParser, etc)
syntax keyword phpClasses containedin=ALLBUT,phpComment,phpStringDouble,phpStringSingle,phpIdentifier,phpMethodsVar
  \ stdClass __PHP_Incomplete_Class php_user_filter AssertionError Directory ArrayObject
  \ Exception ErrorException LogicException BadFunctionCallException BadMethodCallException DomainException
  \ ArgumentCountError ArithmeticError ClosedGeneratorException Closure CompileError DivisionByZeroError Generator ParseError TypeError WeakReference
  \ RecursiveIteratorIterator IteratorIterator FilterIterator RecursiveFilterIterator ParentIterator LimitIterator
  \ CachingIterator RecursiveCachingIterator NoRewindIterator AppendIterator InfiniteIterator EmptyIterator
  \ ArrayIterator RecursiveArrayIterator DirectoryIterator RecursiveDirectoryIterator
  \ CallbackFilterIterator FilesystemIterator GlobIterator MultipleIterator RecursiveCallbackFilterIterator 
  \ RecursiveRegexIterator RecursiveTreeIterator RegexIterator SplDoublyLinkedList 
  \ SplFixedArray SplHeap SplMaxHeap SplMinHeap SplPriorityQueue SplQueue SplStack
  \ InvalidArgumentException LengthException OutOfRangeException RuntimeException OutOfBoundsException
  \ Attribute InternalIterator Stringable UnhandledMatchError ValueError WeakMap
  \ OverflowException RangeException UnderflowException UnexpectedValueException
  \ PDO PDOException PDOStatement PDORow
  \ Reflection ReflectionFunction ReflectionParameter ReflectionMethod ReflectionClass
  \ ReflectionObject ReflectionProperty ReflectionExtension ReflectionException
  \ ReflectionClassConstant ReflectionFunctionAbstract ReflectionGenerator ReflectionNamedType 
  \ ReflectionReference ReflectionType ReflectionZendExtension
  \ ReflectionAttribute ReflectionUnionType
  \ SplFileInfo SplFileObject SplTempFileObject SplObjectStorage
  \ XMLWriter LibXMLError XMLReader SimpleXMLElement SimpleXMLIterator
  \ XmlParser
  \ DeflateContext InflateContext
  \ DOMException DOMStringList DOMNameList DOMDomError DOMErrorHandler
  \ DOMImplementation DOMImplementationList DOMImplementationSource
  \ DOMNode DOMNameSpaceNode DOMDocumentFragment DOMDocument DOMNodeList DOMNamedNodeMap
  \ DOMCharacterData DOMAttr DOMElement DOMText DOMComment DOMTypeinfo DOMUserDataHandler
  \ DOMLocator DOMConfiguration DOMCdataSection DOMDocumentType DOMNotation DOMEntity
  \ DOMEntityReference DOMProcessingInstruction DOMStringExtend DOMXPath
  \ DOMChildNode DOMParentNode
  \ EnchantBroker EnchantDictionary 
  \ GdImage
  \ OpenSSLAsymmetricKey OpenSSLCertificate OpenSSLCertificateSigningRequest
  \ Shmop
  \ AddressInfo Socket
  \ SysvMessageQueue SysvSemaphore SysvSharedMemory
  \ PhpToken
  \ APCIterator APCuIterator
  \ CURLFile CurlHandle CurlMultiHandle CurlShareHandle
  \ DateInterval DatePeriod DateTime DateTimeImmutable DateTimeZone
  \ finfo
  \ GMP
  \ Collator IntlBreakIterator IntlCalendar IntlChar IntlCodePointBreakIterator IntlDateFormatter IntlException IntlGregorianCalendar IntlIterator IntlPartsIterator IntlRuleBasedBreakIterator IntlTimeZone Locale MessageFormatter Normalizer NumberFormatter ResourceBundle Spoofchecker Transliterator UConverter
  \ FFI CData CType ParserException
  \ HashContext
  \ JsonException
  \ Memcached MemcachedException
  \ mysqli mysqli_driver mysqli_result mysqli_sql_exception mysqli_stmt mysqli_warning
  \ SessionHandler
  \ SoapClient SoapFault SoapHeader SoapParam SoapServer SoapVar
  \ SQLite3 SQLite3Result SQLite3Stmt
  \ tidy tidyNode
  \ XSLTProcessor ZipArchive
  \ Phar PharData PharException PharFileInfo

hi def link phpClasses phpFunctions

" Highlighting for PHP's built-in interfaces
syntax keyword phpInterfaces containedin=ALLBUT,phpComment,phpStringDouble,phpStringSingle,phpIdentifier,phpMethodsVar
  \ Iterator IteratorAggregate RecursiveIterator OuterIterator SeekableIterator
  \ Traversable ArrayAccess Serializable Countable SplObserver SplSubject Reflector
  \ Throwable DateTimeInterface JsonSerializable SessionHandlerInterface SessionIdInterface SessionUpdateTimestampHandlerInterface

hi def link phpInterfaces phpConstant

" option defaults:
if ! exists('php_special_functions')
  let php_special_functions = 1
endif
if ! exists('php_alt_comparisons')
  let php_alt_comparisons = 1
endif
if ! exists('php_alt_assignByReference')
  let php_alt_assignByReference = 1
endif

if php_special_functions
  " Highlighting for PHP built-in functions which exhibit special behaviours
  " - isset()/unset()/empty() are not real functions.
  " - compact()/extract() directly manipulate variables in the local scope where
  "   regular functions would not be able to.
  " - eval() is the token 'make_your_code_twice_as_complex()' function for PHP.
  " - user_error()/trigger_error() can be overloaded by set_error_handler and also
  "   have the capacity to terminate your script when type is E_USER_ERROR.
  " - match(){} is not a function
  syntax keyword phpSpecialFunction containedin=ALLBUT,phpComment,phpStringDouble,phpStringSingle
  \ user_error trigger_error isset unset eval extract compact empty
endif

if php_alt_assignByReference
  " special highlighting for '=&' operator
  syntax match phpAssignByRef /=\s*&/ containedin=ALLBUT,phpComment,phpStringDouble,phpStringSingle
    hi def link phpAssignByRef Type
endif

if php_alt_comparisons
  " highlight comparison operators differently
  syntax match phpComparison "\v[=!]\=\=?" contained containedin=phpRegion
  syntax match phpComparison "\v[=<>-]@<![<>]\=?[<>]@!" contained containedin=phpRegion
  syntax match phpComparison "<=>" contained containedin=phpRegion

  " highlight the 'instanceof' operator as a comparison operator rather than a structure
  syntax case ignore
  syntax keyword phpComparison instanceof contained containedin=phpRegion

  hi def link phpComparison Statement
endif

" ================================================================

" Sync
if php_sync_method==-1
  if exists("php_noShortTags")
    syn sync match phpRegionSync grouphere phpRegion "^\s*<?\(php\|=\)\s*$"
  else
    syn sync match phpRegionSync grouphere phpRegion "^\s*<?\(php\)\=\s*$"
  endif
  syn sync match phpRegionSync grouphere phpRegionSc +^\s*<script language="php">\s*$+
  if exists("php_asp_tags")
    syn sync match phpRegionSync grouphere phpRegionAsp "^\s*<%\(=\)\=\s*$"
  endif
  syn sync match phpRegionSync grouphere NONE "^\s*?>\s*$"
  syn sync match phpRegionSync grouphere NONE "^\s*%>\s*$"
  syn sync match phpRegionSync grouphere phpRegion "function\s.*(.*\$"
  "syn sync match phpRegionSync grouphere NONE "/\i*>\s*$"
elseif php_sync_method>0
  exec "syn sync minlines=" . php_sync_method
else
  exec "syn sync fromstart"
endif

syntax match phpDocCustomTags "@[a-zA-Z]*\(\s\+\|\n\|\r\)" containedin=phpComment
syntax region phpDocTags start="{@\(example\|id\|internal\|inheritdoc\|link\|source\|toc\|tutorial\)" end="}" containedin=phpComment
syntax match phpDocTags "@\(abstract\|access\|api\|author\|category\|copyright\|deprecated\|example\|final\|global\|ignore\|internal\|license\|link\|method\|name\|package\|param\|property\(-write\|-read\)\?\|return\|see\|since\|source\|static\|staticvar\|subpackage\|tutorial\|uses\|used-by\|var\|version\|contributor\|modified\|filename\|description\|filesource\|throws\)\(\s\+\)\?" containedin=phpComment
syntax match phpDocTodo "@\(todo\|fixme\|xxx\)\(\s\+\)\?" containedin=phpComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link phpConstant Constant
hi def link phpCoreConstant Constant
hi def link phpComment Comment
hi def link phpDocTags PreProc
hi def link phpDocCustomTags Type
hi def link phpException Exception
hi def link phpBoolean Boolean
hi def link phpStorageClass StorageClass
hi def link phpSCKeyword StorageClass
hi def link phpFCKeyword Define
hi def link phpStructure Structure
hi def link phpStringSingle String
hi def link phpStringDouble String
hi def link phpBacktick String
hi def link phpNumber Number
hi def link phpFloat Float
hi def link phpMethods Function
hi def link phpFunctions Function
hi def link phpBaselib Function
hi def link phpRepeat Repeat
hi def link phpConditional Conditional
hi def link phpLabel Label
hi def link phpStatement Statement
hi def link phpKeyword Statement
hi def link phpType Type
hi def link phpInclude Include
hi def link phpDefine Define
hi def link phpBackslashSequences SpecialChar
hi def link phpBackslashDoubleQuote SpecialChar
hi def link phpBackslashSingleQuote SpecialChar
hi def link phpParent Delimiter
hi def link phpBrackets Delimiter
hi def link phpIdentifierConst Delimiter
hi def link phpParentError Error
hi def link phpOctalError Error
hi def link phpBinaryError Error
hi def link phpFloatError Error
hi def link phpInterpSimpleError Error
hi def link phpInterpBogusDollarCurley Error
hi def link phpInterpDollarCurly1 Error
hi def link phpInterpDollarCurly2 Error
hi def link phpInterpSimpleBracketsInner String
hi def link phpInterpSimpleCurly Delimiter
hi def link phpInterpVarname Identifier
hi def link phpTodo Todo
hi def link phpDocTodo Todo
hi def link phpMemberSelector Structure
if exists("php_oldStyle")
  hi def phpIntVar guifg=Red ctermfg=DarkRed
  hi def phpEnvVar guifg=Red ctermfg=DarkRed
  hi def phpOperator guifg=SeaGreen ctermfg=DarkGreen
  hi def phpVarSelector guifg=SeaGreen ctermfg=DarkGreen
  hi def phpRelation guifg=SeaGreen ctermfg=DarkGreen
  hi def phpIdentifier guifg=DarkGray ctermfg=Brown
  hi def phpIdentifierSimply guifg=DarkGray ctermfg=Brown
else
  hi def link phpIntVar Identifier
  hi def link phpEnvVar Identifier
  hi def link phpOperator Operator
  hi def link phpVarSelector Operator
  hi def link phpRelation Operator
  hi def link phpIdentifier Identifier
  hi def link phpIdentifierSimply Identifier
endif

let b:current_syntax = "php"

if main_syntax == 'php'
  unlet main_syntax
endif

" put cpoptions back the way we found it
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sts=2 sw=2 expandtab
