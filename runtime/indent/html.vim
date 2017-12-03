" Vim indent script for HTML
" Header: "{{{
" Maintainer:	Bram Moolenaar
" Original Author: Andy Wokula <anwoku@yahoo.de>
" Last Change:	2017 Jun 13
" Version:	1.0
" Description:	HTML indent script with cached state for faster indenting on a
"		range of lines.
"		Supports template systems through hooks.
"		Supports Closure stylesheets.
"
" Credits:
"	indent/html.vim (2006 Jun 05) from J. Zellner
"	indent/css.vim (2006 Dec 20) from N. Weibull
"
" History:
" 2014 June	(v1.0) overhaul (Bram)
" 2012 Oct 21	(v0.9) added support for shiftwidth()
" 2011 Sep 09	(v0.8) added HTML5 tags (thx to J. Zuckerman)
" 2008 Apr 28	(v0.6) revised customization
" 2008 Mar 09	(v0.5) fixed 'indk' issue (thx to C.J. Robinson)
"}}}

" Init Folklore, check user settings (2nd time ++)
if exists("b:did_indent") "{{{
  finish
endif

" Load the Javascript indent script first, it defines GetJavascriptIndent().
" Undo the rest.
" Load base python indent.
if !exists('*GetJavascriptIndent')
  runtime! indent/javascript.vim
endif
let b:did_indent = 1

setlocal indentexpr=HtmlIndent()
setlocal indentkeys=o,O,<Return>,<>>,{,},!^F

" Needed for % to work when finding start/end of a tag.
setlocal matchpairs+=<:>

let b:undo_indent = "setlocal inde< indk<"

" b:hi_indent keeps state to speed up indenting consecutive lines.
let b:hi_indent = {"lnum": -1}

"""""" Code below this is loaded only once. """""
if exists("*HtmlIndent") && !exists('g:force_reload_html')
  call HtmlIndent_CheckUserSettings()
  finish
endif

" Allow for line continuation below.
let s:cpo_save = &cpo
set cpo-=C
"}}}

" Check and process settings from b:html_indent and g:html_indent... variables.
" Prefer using buffer-local settings over global settings, so that there can
" be defaults for all HTML files and exceptions for specific types of HTML
" files.
func! HtmlIndent_CheckUserSettings()
  "{{{
  let inctags = ''
  if exists("b:html_indent_inctags")
    let inctags = b:html_indent_inctags
  elseif exists("g:html_indent_inctags")
    let inctags = g:html_indent_inctags
  endif
  let b:hi_tags = {}
  if len(inctags) > 0
    call s:AddITags(b:hi_tags, split(inctags, ","))
  endif

  let autotags = ''
  if exists("b:html_indent_autotags")
    let autotags = b:html_indent_autotags
  elseif exists("g:html_indent_autotags")
    let autotags = g:html_indent_autotags
  endif
  let b:hi_removed_tags = {}
  if len(autotags) > 0
    call s:RemoveITags(b:hi_removed_tags, split(autotags, ","))
  endif

  " Syntax names indicating being inside a string of an attribute value.
  let string_names = []
  if exists("b:html_indent_string_names")
    let string_names = b:html_indent_string_names
  elseif exists("g:html_indent_string_names")
    let string_names = g:html_indent_string_names
  endif
  let b:hi_insideStringNames = ['htmlString']
  if len(string_names) > 0
    for s in string_names
      call add(b:hi_insideStringNames, s)
    endfor
  endif

  " Syntax names indicating being inside a tag.
  let tag_names = []
  if exists("b:html_indent_tag_names")
    let tag_names = b:html_indent_tag_names
  elseif exists("g:html_indent_tag_names")
    let tag_names = g:html_indent_tag_names
  endif
  let b:hi_insideTagNames = ['htmlTag', 'htmlScriptTag']
  if len(tag_names) > 0
    for s in tag_names
      call add(b:hi_insideTagNames, s)
    endfor
  endif

  let indone = {"zero": 0
              \,"auto": "indent(prevnonblank(v:lnum-1))"
              \,"inc": "b:hi_indent.blocktagind + shiftwidth()"}

  let script1 = ''
  if exists("b:html_indent_script1")
    let script1 = b:html_indent_script1
  elseif exists("g:html_indent_script1")
    let script1 = g:html_indent_script1
  endif
  if len(script1) > 0
    let b:hi_js1indent = get(indone, script1, indone.zero)
  else
    let b:hi_js1indent = 0
  endif

  let style1 = ''
  if exists("b:html_indent_style1")
    let style1 = b:html_indent_style1
  elseif exists("g:html_indent_style1")
    let style1 = g:html_indent_style1
  endif
  if len(style1) > 0
    let b:hi_css1indent = get(indone, style1, indone.zero)
  else
    let b:hi_css1indent = 0
  endif

  if !exists('b:html_indent_line_limit')
    if exists('g:html_indent_line_limit')
      let b:html_indent_line_limit = g:html_indent_line_limit
    else
      let b:html_indent_line_limit = 200
    endif
  endif
endfunc "}}}

" Init Script Vars
"{{{
let b:hi_lasttick = 0
let b:hi_newstate = {}
let s:countonly = 0
 "}}}

" Fill the s:indent_tags dict with known tags.
" The key is "tagname" or "/tagname".  {{{
" The value is:
" 1   opening tag
" 2   "pre"
" 3   "script"
" 4   "style"
" 5   comment start
" 6   conditional comment start
" -1  closing tag
" -2  "/pre"
" -3  "/script"
" -4  "/style"
" -5  comment end
" -6  conditional comment end
let s:indent_tags = {}
let s:endtags = [0,0,0,0,0,0,0]   " long enough for the highest index
"}}}

" Add a list of tag names for a pair of <tag> </tag> to "tags".
func! s:AddITags(tags, taglist)
  "{{{
  for itag in a:taglist
    let a:tags[itag] = 1
    let a:tags['/' . itag] = -1
  endfor
endfunc "}}}

" Take a list of tag name pairs that are not to be used as tag pairs.
func! s:RemoveITags(tags, taglist)
  "{{{
  for itag in a:taglist
    let a:tags[itag] = 1
    let a:tags['/' . itag] = 1
  endfor
endfunc "}}}

" Add a block tag, that is a tag with a different kind of indenting.
func! s:AddBlockTag(tag, id, ...)
  "{{{
  if !(a:id >= 2 && a:id < len(s:endtags))
    echoerr 'AddBlockTag ' . a:id
    return
  endif
  let s:indent_tags[a:tag] = a:id
  if a:0 == 0
    let s:indent_tags['/' . a:tag] = -a:id
    let s:endtags[a:id] = "</" . a:tag . ">"
  else
    let s:indent_tags[a:1] = -a:id
    let s:endtags[a:id] = a:1
  endif
endfunc "}}}

" Add known tag pairs.
" Self-closing tags and tags that are sometimes {{{
" self-closing (e.g., <p>) are not here (when encountering </p> we can find
" the matching <p>, but not the other way around).
" Old HTML tags:
call s:AddITags(s:indent_tags, [
    \ 'a', 'abbr', 'acronym', 'address', 'b', 'bdo', 'big',
    \ 'blockquote', 'body', 'button', 'caption', 'center', 'cite', 'code',
    \ 'colgroup', 'del', 'dfn', 'dir', 'div', 'dl', 'em', 'fieldset', 'font',
    \ 'form', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'html',
    \ 'i', 'iframe', 'ins', 'kbd', 'label', 'legend', 'li',
    \ 'map', 'menu', 'noframes', 'noscript', 'object', 'ol',
    \ 'optgroup', 'q', 's', 'samp', 'select', 'small', 'span', 'strong', 'sub',
    \ 'sup', 'table', 'textarea', 'title', 'tt', 'u', 'ul', 'var', 'th', 'td',
    \ 'tr', 'tbody', 'tfoot', 'thead'])

" New HTML5 elements:
call s:AddITags(s:indent_tags, [
    \ 'area', 'article', 'aside', 'audio', 'bdi', 'canvas',
    \ 'command', 'data', 'datalist', 'details', 'embed', 'figcaption',
    \ 'figure', 'footer', 'header', 'keygen', 'mark', 'meter', 'nav', 'output',
    \ 'progress', 'rp', 'rt', 'ruby', 'section', 'source', 'summary', 'svg', 
    \ 'time', 'track', 'video', 'wbr'])

" Tags added for web components:
call s:AddITags(s:indent_tags, [
    \ 'content', 'shadow', 'template'])
"}}}

" Add Block Tags: these contain alien content
"{{{
call s:AddBlockTag('pre', 2)
call s:AddBlockTag('script', 3)
call s:AddBlockTag('style', 4)
call s:AddBlockTag('<!--', 5, '-->')
call s:AddBlockTag('<!--[', 6, '![endif]-->')
"}}}

" Return non-zero when "tagname" is an opening tag, not being a block tag, for
" which there should be a closing tag.  Can be used by scripts that include
" HTML indenting.
func! HtmlIndent_IsOpenTag(tagname)
  "{{{
  if get(s:indent_tags, a:tagname) == 1
    return 1
  endif
  return get(b:hi_tags, a:tagname) == 1
endfunc "}}}

" Get the value for "tagname", taking care of buffer-local tags.
func! s:get_tag(tagname)
  "{{{
  let i = get(s:indent_tags, a:tagname)
  if (i == 1 || i == -1) && get(b:hi_removed_tags, a:tagname) != 0
    return 0
  endif
  if i == 0
    let i = get(b:hi_tags, a:tagname)
  endif
  return i
endfunc "}}}

" Count the number of start and end tags in "text".
func! s:CountITags(text)
  "{{{
  " Store the result in s:curind and s:nextrel.
  let s:curind = 0  " relative indent steps for current line [unit &sw]:
  let s:nextrel = 0  " relative indent steps for next line [unit &sw]:
  let s:block = 0		" assume starting outside of a block
  let s:countonly = 1	" don't change state
  call substitute(a:text, '<\zs/\=\w\+\(-\w\+\)*\>\|<!--\[\|\[endif\]-->\|<!--\|-->', '\=s:CheckTag(submatch(0))', 'g')
  let s:countonly = 0
endfunc "}}}

" Count the number of start and end tags in text.
func! s:CountTagsAndState(text)
  "{{{
  " Store the result in s:curind and s:nextrel.  Update b:hi_newstate.block.
  let s:curind = 0  " relative indent steps for current line [unit &sw]:
  let s:nextrel = 0  " relative indent steps for next line [unit &sw]:

  let s:block = b:hi_newstate.block
  let tmp = substitute(a:text, '<\zs/\=\w\+\(-\w\+\)*\>\|<!--\[\|\[endif\]-->\|<!--\|-->', '\=s:CheckTag(submatch(0))', 'g')
  if s:block == 3
    let b:hi_newstate.scripttype = s:GetScriptType(matchstr(tmp, '\C.*<SCRIPT\>\zs[^>]*'))
  endif
  let b:hi_newstate.block = s:block
endfunc "}}}

" Used by s:CountITags() and s:CountTagsAndState().
func! s:CheckTag(itag)
  "{{{
  " Returns an empty string or "SCRIPT".
  " a:itag can be "tag" or "/tag" or "<!--" or "-->"
  if (s:CheckCustomTag(a:itag))
    return ""
  endif
  let ind = s:get_tag(a:itag)
  if ind == -1
    " closing tag
    if s:block != 0
      " ignore itag within a block
      return ""
    endif
    if s:nextrel == 0
      let s:curind -= 1
    else
      let s:nextrel -= 1
    endif
  elseif ind == 1
    " opening tag
    if s:block != 0
      return ""
    endif
    let s:nextrel += 1
  elseif ind != 0
    " block-tag (opening or closing)
    return s:CheckBlockTag(a:itag, ind)
  " else ind==0 (other tag found): keep indent
  endif
  return ""
endfunc "}}}

" Used by s:CheckTag(). Returns an empty string or "SCRIPT".
func! s:CheckBlockTag(blocktag, ind)
  "{{{
  if a:ind > 0
    " a block starts here
    if s:block != 0
      " already in a block (nesting) - ignore
      " especially ignore comments after other blocktags
      return ""
    endif
    let s:block = a:ind		" block type
    if s:countonly
      return ""
    endif
    let b:hi_newstate.blocklnr = v:lnum
    " save allover indent for the endtag
    let b:hi_newstate.blocktagind = b:hi_indent.baseindent + (s:nextrel + s:curind) * shiftwidth()
    if a:ind == 3
      return "SCRIPT"    " all except this must be lowercase
      " line is to be checked again for the type attribute
    endif
  else
    let s:block = 0
    " we get here if starting and closing a block-tag on the same line
  endif
  return ""
endfunc "}}}

" Used by s:CheckTag().
func! s:CheckCustomTag(ctag)
  "{{{
  " Returns 1 if ctag is the tag for a custom element, 0 otherwise.
  " a:ctag can be "tag" or "/tag" or "<!--" or "-->"
  let pattern = '\%\(\w\+-\)\+\w\+'
  if match(a:ctag, pattern) == -1
    return 0
  endif
  if matchstr(a:ctag, '\/\ze.\+') == "/"
    " closing tag
    if s:block != 0
      " ignore ctag within a block
      return 1
    endif
    if s:nextrel == 0
      let s:curind -= 1
    else
      let s:nextrel -= 1
    endif
  else
    " opening tag
    if s:block != 0
      return 1
    endif
    let s:nextrel += 1
  endif
  return 1
endfunc "}}}

" Return the <script> type: either "javascript" or ""
func! s:GetScriptType(str)
  "{{{
  if a:str == "" || a:str =~ "java"
    return "javascript"
  else
    return ""
  endif
endfunc "}}}

" Look back in the file, starting at a:lnum - 1, to compute a state for the
" start of line a:lnum.  Return the new state.
func! s:FreshState(lnum)
  "{{{
  " A state is to know ALL relevant details about the
  " lines 1..a:lnum-1, initial calculating (here!) can be slow, but updating is
  " fast (incremental).
  " TODO: this should be split up in detecting the block type and computing the
  " indent for the block type, so that when we do not know the indent we do
  " not need to clear the whole state and re-detect the block type again.
  " State:
  "	lnum		last indented line == prevnonblank(a:lnum - 1)
  "	block = 0	a:lnum located within special tag: 0:none, 2:<pre>,
  "			3:<script>, 4:<style>, 5:<!--, 6:<!--[
  "	baseindent	use this indent for line a:lnum as a start - kind of
  "			autoindent (if block==0)
  "	scripttype = ''	type attribute of a script tag (if block==3)
  "	blocktagind	indent for current opening (get) and closing (set)
  "			blocktag (if block!=0)
  "	blocklnr	lnum of starting blocktag (if block!=0)
  "	inattr		line {lnum} starts with attributes of a tag
  let state = {}
  let state.lnum = prevnonblank(a:lnum - 1)
  let state.scripttype = ""
  let state.blocktagind = -1
  let state.block = 0
  let state.baseindent = 0
  let state.blocklnr = 0
  let state.inattr = 0

  if state.lnum == 0
    return state
  endif

  " Heuristic:
  " remember startline state.lnum
  " look back for <pre, </pre, <script, </script, <style, </style tags
  " remember stopline
  " if opening tag found,
  "	assume a:lnum within block
  " else
  "	look back in result range (stopline, startline) for comment
  "	    \ delimiters (<!--, -->)
  "	if comment opener found,
  "	    assume a:lnum within comment
  "	else
  "	    assume usual html for a:lnum
  "	    if a:lnum-1 has a closing comment
  "		look back to get indent of comment opener
  " FI

  " look back for a blocktag
  let stopline2 = v:lnum + 1
  if has_key(b:hi_indent, 'block') && b:hi_indent.block > 5
    let [stopline2, stopcol2] = searchpos('<!--', 'bnW')
  endif
  let [stopline, stopcol] = searchpos('\c<\zs\/\=\%(pre\>\|script\>\|style\>\)', "bnW")
  if stopline > 0 && stopline < stopline2
    " ugly ... why isn't there searchstr()
    let tagline = tolower(getline(stopline))
    let blocktag = matchstr(tagline, '\/\=\%(pre\>\|script\>\|style\>\)', stopcol - 1)
    if blocktag[0] != "/"
      " opening tag found, assume a:lnum within block
      let state.block = s:indent_tags[blocktag]
      if state.block == 3
        let state.scripttype = s:GetScriptType(matchstr(tagline, '\>[^>]*', stopcol))
      endif
      let state.blocklnr = stopline
      " check preceding tags in the line:
      call s:CountITags(tagline[: stopcol-2])
      let state.blocktagind = indent(stopline) + (s:curind + s:nextrel) * shiftwidth()
      return state
    elseif stopline == state.lnum
      " handle special case: previous line (= state.lnum) contains a
      " closing blocktag which is preceded by line-noise;
      " blocktag == "/..."
      let swendtag = match(tagline, '^\s*</') >= 0
      if !swendtag
        let [bline, bcol] = searchpos('<'.blocktag[1:].'\>', "bnW")
        call s:CountITags(tolower(getline(bline)[: bcol-2]))
        let state.baseindent = indent(bline) + (s:curind + s:nextrel) * shiftwidth()
        return state
      endif
    endif
  endif
  if stopline > stopline2
    let stopline = stopline2
    let stopcol = stopcol2
  endif

  " else look back for comment
  let [comlnum, comcol, found] = searchpos('\(<!--\[\)\|\(<!--\)\|-->', 'bpnW', stopline)
  if found == 2 || found == 3
    " comment opener found, assume a:lnum within comment
    let state.block = (found == 3 ? 5 : 6)
    let state.blocklnr = comlnum
    " check preceding tags in the line:
    call s:CountITags(tolower(getline(comlnum)[: comcol-2]))
    if found == 2
      let state.baseindent = b:hi_indent.baseindent
    endif
    let state.blocktagind = indent(comlnum) + (s:curind + s:nextrel) * shiftwidth()
    return state
  endif

  " else within usual HTML
  let text = tolower(getline(state.lnum))

  " Check a:lnum-1 for closing comment (we need indent from the opening line).
  " Not when other tags follow (might be --> inside a string).
  let comcol = stridx(text, '-->')
  if comcol >= 0 && match(text, '[<>]', comcol) <= 0
    call cursor(state.lnum, comcol + 1)
    let [comlnum, comcol] = searchpos('<!--', 'bW')
    if comlnum == state.lnum
      let text = text[: comcol-2]
    else
      let text = tolower(getline(comlnum)[: comcol-2])
    endif
    call s:CountITags(text)
    let state.baseindent = indent(comlnum) + (s:curind + s:nextrel) * shiftwidth()
    " TODO check tags that follow "-->"
    return state
  endif

  " Check if the previous line starts with end tag.
  let swendtag = match(text, '^\s*</') >= 0

  " If previous line ended in a closing tag, line up with the opening tag.
  if !swendtag && text =~ '</\w\+\s*>\s*$'
    call cursor(state.lnum, 99999)
    normal! F<
    let start_lnum = HtmlIndent_FindStartTag()
    if start_lnum > 0
      let state.baseindent = indent(start_lnum)
      if col('.') > 2
        " check for tags before the matching opening tag.
        let text = getline(start_lnum)
        let swendtag = match(text, '^\s*</') >= 0
        call s:CountITags(text[: col('.') - 2])
        let state.baseindent += s:nextrel * shiftwidth()
        if !swendtag
          let state.baseindent += s:curind * shiftwidth()
        endif
      endif
      return state
    endif
  endif

  " Else: no comments. Skip backwards to find the tag we're inside.
  let [state.lnum, found] = HtmlIndent_FindTagStart(state.lnum)
  " Check if that line starts with end tag.
  let text = getline(state.lnum)
  let swendtag = match(text, '^\s*</') >= 0
  call s:CountITags(tolower(text))
  let state.baseindent = indent(state.lnum) + s:nextrel * shiftwidth()
  if !swendtag
    let state.baseindent += s:curind * shiftwidth()
  endif
  return state
endfunc "}}}

" Indent inside a <pre> block: Keep indent as-is.
func! s:Alien2()
  "{{{
  return -1
endfunc "}}}

" Return the indent inside a <script> block for javascript.
func! s:Alien3()
  "{{{
  let lnum = prevnonblank(v:lnum - 1)
  while lnum > 1 && getline(lnum) =~ '^\s*/[/*]'
    " Skip over comments to avoid that cindent() aligns with the <script> tag
    let lnum = prevnonblank(lnum - 1)
  endwhile
  if lnum == b:hi_indent.blocklnr
    " indent for the first line after <script>
    return eval(b:hi_js1indent)
  endif
  if b:hi_indent.scripttype == "javascript"
    return GetJavascriptIndent()
  else
    return -1
  endif
endfunc "}}}

" Return the indent inside a <style> block.
func! s:Alien4()
  "{{{
  if prevnonblank(v:lnum-1) == b:hi_indent.blocklnr
    " indent for first content line
    return eval(b:hi_css1indent)
  endif
  return s:CSSIndent()
endfunc "}}}

" Indending inside a <style> block.  Returns the indent.
func! s:CSSIndent()
  "{{{
  " This handles standard CSS and also Closure stylesheets where special lines
  " start with @.
  " When the line starts with '*' or the previous line starts with "/*"
  " and does not end in "*/", use C indenting to format the comment.
  " Adopted $VIMRUNTIME/indent/css.vim
  let curtext = getline(v:lnum)
  if curtext =~ '^\s*[*]'
        \ || (v:lnum > 1 && getline(v:lnum - 1) =~ '\s*/\*'
        \     && getline(v:lnum - 1) !~ '\*/\s*$')
    return cindent(v:lnum)
  endif

  let min_lnum = b:hi_indent.blocklnr
  let prev_lnum = s:CssPrevNonComment(v:lnum - 1, min_lnum)
  let [prev_lnum, found] = HtmlIndent_FindTagStart(prev_lnum)
  if prev_lnum <= min_lnum
    " Just below the <style> tag, indent for first content line after comments.
    return eval(b:hi_css1indent)
  endif

  " If the current line starts with "}" align with it's match.
  if curtext =~ '^\s*}'
    call cursor(v:lnum, 1)
    try
      normal! %
      " Found the matching "{", align with it after skipping unfinished lines.
      let align_lnum = s:CssFirstUnfinished(line('.'), min_lnum)
      return indent(align_lnum)
    catch
      " can't find it, try something else, but it's most likely going to be
      " wrong
    endtry
  endif

  " add indent after {
  let brace_counts = HtmlIndent_CountBraces(prev_lnum)
  let extra = brace_counts.c_open * shiftwidth()

  let prev_text = getline(prev_lnum)
  let below_end_brace = prev_text =~ '}\s*$'

  " Search back to align with the first line that's unfinished.
  let align_lnum = s:CssFirstUnfinished(prev_lnum, min_lnum)

  " Handle continuation lines if aligning with previous line and not after a
  " "}".
  if extra == 0 && align_lnum == prev_lnum && !below_end_brace
    let prev_hasfield = prev_text =~ '^\s*[a-zA-Z0-9-]\+:'
    let prev_special = prev_text =~ '^\s*\(/\*\|@\)'
    if curtext =~ '^\s*\(/\*\|@\)'
      " if the current line is not a comment or starts with @ (used by template
      " systems) reduce indent if previous line is a continuation line
      if !prev_hasfield && !prev_special
        let extra = -shiftwidth()
      endif
    else
      let cur_hasfield = curtext =~ '^\s*[a-zA-Z0-9-]\+:'
      let prev_unfinished = s:CssUnfinished(prev_text)
      if !cur_hasfield && (prev_hasfield || prev_unfinished)
        " Continuation line has extra indent if the previous line was not a
        " continuation line.
        let extra = shiftwidth()
        " Align with @if
        if prev_text =~ '^\s*@if '
          let extra = 4
        endif
      elseif cur_hasfield && !prev_hasfield && !prev_special
        " less indent below a continuation line
        let extra = -shiftwidth()
      endif
    endif
  endif

  if below_end_brace
    " find matching {, if that line starts with @ it's not the start of a rule
    " but something else from a template system
    call cursor(prev_lnum, 1)
    call search('}\s*$')
    try
      normal! %
      " Found the matching "{", align with it.
      let align_lnum = s:CssFirstUnfinished(line('.'), min_lnum)
      let special = getline(align_lnum) =~ '^\s*@'
    catch
      let special = 0
    endtry
    if special
      " do not reduce indent below @{ ... }
      if extra < 0
        let extra += shiftwidth()
      endif
    else
      let extra -= (brace_counts.c_close - (prev_text =~ '^\s*}')) * shiftwidth()
    endif
  endif

  " if no extra indent yet...
  if extra == 0
    if brace_counts.p_open > brace_counts.p_close
      " previous line has more ( than ): add a shiftwidth
      let extra = shiftwidth()
    elseif brace_counts.p_open < brace_counts.p_close
      " previous line has more ) than (: subtract a shiftwidth
      let extra = -shiftwidth()
    endif
  endif

  return indent(align_lnum) + extra
endfunc "}}}

" Inside <style>: Whether a line is unfinished.
func! s:CssUnfinished(text)
  "{{{
  return a:text =~ '\s\(||\|&&\|:\)\s*$'
endfunc "}}}

" Search back for the first unfinished line above "lnum".
func! s:CssFirstUnfinished(lnum, min_lnum)
  "{{{
  let align_lnum = a:lnum
  while align_lnum > a:min_lnum && s:CssUnfinished(getline(align_lnum - 1))
    let align_lnum -= 1
  endwhile
  return align_lnum
endfunc "}}}

" Find the non-empty line at or before "lnum" that is not a comment.
func! s:CssPrevNonComment(lnum, stopline)
  "{{{
  " caller starts from a line a:lnum + 1 that is not a comment
  let lnum = prevnonblank(a:lnum)
  while 1
    let ccol = match(getline(lnum), '\*/')
    if ccol < 0
      " No comment end thus it's something else.
      return lnum
    endif
    call cursor(lnum, ccol + 1)
    " Search back for the /* that starts the comment
    let lnum = search('/\*', 'bW', a:stopline)
    if indent(".") == virtcol(".") - 1
      " The  found /* is at the start of the line. Now go back to the line
      " above it and again check if it is a comment.
      let lnum = prevnonblank(lnum - 1)
    else
      " /* is after something else, thus it's not a comment line.
      return lnum
    endif
  endwhile
endfunc "}}}

" Check the number of {} and () in line "lnum". Return a dict with the counts.
func! HtmlIndent_CountBraces(lnum)
  "{{{
  let brs = substitute(getline(a:lnum), '[''"].\{-}[''"]\|/\*.\{-}\*/\|/\*.*$\|[^{}()]', '', 'g')
  let c_open = 0
  let c_close = 0
  let p_open = 0
  let p_close = 0
  for brace in split(brs, '\zs')
    if brace == "{"
      let c_open += 1
    elseif brace == "}"
      if c_open > 0
        let c_open -= 1
      else
        let c_close += 1
      endif
    elseif brace == '('
      let p_open += 1
    elseif brace == ')'
      if p_open > 0
        let p_open -= 1
      else
        let p_close += 1
      endif
    endif
  endfor
  return {'c_open': c_open,
        \ 'c_close': c_close,
        \ 'p_open': p_open,
        \ 'p_close': p_close}
endfunc "}}}

" Return the indent for a comment: <!-- -->
func! s:Alien5()
  "{{{
  let curtext = getline(v:lnum)
  if curtext =~ '^\s*\zs-->'
    " current line starts with end of comment, line up with comment start.
    call cursor(v:lnum, 0)
    let lnum = search('<!--', 'b')
    if lnum > 0
      " TODO: what if <!-- is not at the start of the line?
      return indent(lnum)
    endif

    " Strange, can't find it.
    return -1
  endif

  let prevlnum = prevnonblank(v:lnum - 1)
  let prevtext = getline(prevlnum)
  let idx = match(prevtext, '^\s*\zs<!--')
  if idx >= 0
    " just below comment start, add a shiftwidth
    return idx + shiftwidth()
  endif

  " Some files add 4 spaces just below a TODO line.  It's difficult to detect
  " the end of the TODO, so let's not do that.

  " Align with the previous non-blank line.
  return indent(prevlnum)
endfunc "}}}

" Return the indent for conditional comment: <!--[ ![endif]-->
func! s:Alien6()
  "{{{
  let curtext = getline(v:lnum)
  if curtext =~ '\s*\zs<!\[endif\]-->'
    " current line starts with end of comment, line up with comment start.
    let lnum = search('<!--', 'bn')
    if lnum > 0
      return indent(lnum)
    endif
  endif
  return b:hi_indent.baseindent + shiftwidth()
endfunc "}}}

" When the "lnum" line ends in ">" find the line containing the matching "<".
func! HtmlIndent_FindTagStart(lnum)
  "{{{
  " Avoids using the indent of a continuation line.
  " Moves the cursor.
  " Return two values:
  " - the matching line number or "lnum".
  " - a flag indicating whether we found the end of a tag.
  " This method is global so that HTML-like indenters can use it.
  " To avoid matching " > " or " < " inside a string require that the opening
  " "<" is followed by a word character and the closing ">" comes after a
  " non-white character.
  let idx = match(getline(a:lnum), '\S>\s*$')
  if idx > 0
    call cursor(a:lnum, idx)
    let lnum = searchpair('<\w', '' , '\S>', 'bW', '', max([a:lnum - b:html_indent_line_limit, 0]))
    if lnum > 0
      return [lnum, 1]
    endif
  endif
  return [a:lnum, 0]
endfunc "}}}

" Find the unclosed start tag from the current cursor position.
func! HtmlIndent_FindStartTag()
  "{{{
  " The cursor must be on or before a closing tag.
  " If found, positions the cursor at the match and returns the line number.
  " Otherwise returns 0.
  let tagname = matchstr(getline('.')[col('.') - 1:], '</\zs\w\+\ze')
  let start_lnum = searchpair('<' . tagname . '\>', '', '</' . tagname . '\>', 'bW')
  if start_lnum > 0
    return start_lnum
  endif
  return 0
endfunc "}}}

" Moves the cursor from a "<" to the matching ">".
func! HtmlIndent_FindTagEnd()
  "{{{
  " Call this with the cursor on the "<" of a start tag.
  " This will move the cursor to the ">" of the matching end tag or, when it's
  " a self-closing tag, to the matching ">".
  " Limited to look up to b:html_indent_line_limit lines away.
  let text = getline('.')
  let tagname = matchstr(text, '\w\+\|!--', col('.'))
  if tagname == '!--'
    call search('--\zs>')
  elseif s:get_tag('/' . tagname) != 0
    " tag with a closing tag, find matching "</tag>"
    call searchpair('<' . tagname, '', '</' . tagname . '\zs>', 'W', '', line('.') + b:html_indent_line_limit)
  else
    " self-closing tag, find the ">"
    call search('\S\zs>')
  endif
endfunc "}}}

" Indenting inside a start tag. Return the correct indent or -1 if unknown.
func! s:InsideTag(foundHtmlString)
  "{{{
  if a:foundHtmlString
    " Inside an attribute string.
    " Align with the previous line or use an external function.
    let lnum = v:lnum - 1
    if lnum > 1
      if exists('b:html_indent_tag_string_func')
        return b:html_indent_tag_string_func(lnum)
      endif
      return indent(lnum)
    endif
  endif

  " Should be another attribute: " attr="val".  Align with the previous
  " attribute start.
  let lnum = v:lnum
  while lnum > 1
    let lnum -= 1
    let text = getline(lnum)
    " Find a match with one of these, align with "attr":
    "       attr=
    "  <tag attr=
    "  text<tag attr=
    "  <tag>text</tag>text<tag attr=
    " For long lines search for the first match, finding the last match
    " gets very slow.
    if len(text) < 300
      let idx = match(text, '.*\s\zs[_a-zA-Z0-9-]\+="')
    else
      let idx = match(text, '\s\zs[_a-zA-Z0-9-]\+="')
    endif
    if idx > 0
      " Found the attribute.  TODO: assumes spaces, no Tabs.
      return idx
    endif
  endwhile
  return -1
endfunc "}}}

" THE MAIN INDENT FUNCTION. Return the amount of indent for v:lnum.
func! HtmlIndent()
  "{{{
  if prevnonblank(v:lnum - 1) < 1
    " First non-blank line has no indent.
    return 0
  endif

  let curtext = tolower(getline(v:lnum))
  let indentunit = shiftwidth()

  let b:hi_newstate = {}
  let b:hi_newstate.lnum = v:lnum

  " When syntax HL is enabled, detect we are inside a tag.  Indenting inside
  " a tag works very differently. Do not do this when the line starts with
  " "<", it gets the "htmlTag" ID but we are not inside a tag then.
  if curtext !~ '^\s*<'
    normal! ^
    let stack = synstack(v:lnum, col('.'))  " assumes there are no tabs
    let foundHtmlString = 0
    for synid in reverse(stack)
      let name = synIDattr(synid, "name")
      if index(b:hi_insideStringNames, name) >= 0
        let foundHtmlString = 1
      elseif index(b:hi_insideTagNames, name) >= 0
        " Yes, we are inside a tag.
        let indent = s:InsideTag(foundHtmlString)
        if indent >= 0
          " Do not keep the state. TODO: could keep the block type.
          let b:hi_indent.lnum = 0
          return indent
        endif
      endif
    endfor
  endif

  " does the line start with a closing tag?
  let swendtag = match(curtext, '^\s*</') >= 0

  if prevnonblank(v:lnum - 1) == b:hi_indent.lnum && b:hi_lasttick == b:changedtick - 1
    " use state (continue from previous line)
  else
    " start over (know nothing)
    let b:hi_indent = s:FreshState(v:lnum)
  endif

  if b:hi_indent.block >= 2
    " within block
    let endtag = s:endtags[b:hi_indent.block]
    let blockend = stridx(curtext, endtag)
    if blockend >= 0
      " block ends here
      let b:hi_newstate.block = 0
      " calc indent for REST OF LINE (may start more blocks):
      call s:CountTagsAndState(strpart(curtext, blockend + strlen(endtag)))
      if swendtag && b:hi_indent.block != 5
        let indent = b:hi_indent.blocktagind + s:curind * indentunit
        let b:hi_newstate.baseindent = indent + s:nextrel * indentunit
      else
        let indent = s:Alien{b:hi_indent.block}()
        let b:hi_newstate.baseindent = b:hi_indent.blocktagind + s:nextrel * indentunit
      endif
    else
      " block continues
      " indent this line with alien method
      let indent = s:Alien{b:hi_indent.block}()
    endif
  else
    " not within a block - within usual html
    let b:hi_newstate.block = b:hi_indent.block
    if swendtag
      " The current line starts with an end tag, align with its start tag.
      call cursor(v:lnum, 1)
      let start_lnum = HtmlIndent_FindStartTag()
      if start_lnum > 0
        " check for the line starting with something inside a tag:
        " <sometag               <- align here
        "    attr=val><open>     not here
        let text = getline(start_lnum)
        let angle = matchstr(text, '[<>]')
        if angle == '>'
          call cursor(start_lnum, 1)
          normal! f>%
          let start_lnum = line('.')
          let text = getline(start_lnum)
        endif

        let indent = indent(start_lnum)
        if col('.') > 2
          let swendtag = match(text, '^\s*</') >= 0
          call s:CountITags(text[: col('.') - 2])
          let indent += s:nextrel * shiftwidth()
          if !swendtag
            let indent += s:curind * shiftwidth()
          endif
        endif
      else
        " not sure what to do
        let indent = b:hi_indent.baseindent
      endif
      let b:hi_newstate.baseindent = indent
    else
      call s:CountTagsAndState(curtext)
      let indent = b:hi_indent.baseindent
      let b:hi_newstate.baseindent = indent + (s:curind + s:nextrel) * indentunit
    endif
  endif

  let b:hi_lasttick = b:changedtick
  call extend(b:hi_indent, b:hi_newstate, "force")
  return indent
endfunc "}}}

" Check user settings when loading this script the first time.
call HtmlIndent_CheckUserSettings()

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: fdm=marker ts=8 sw=2 tw=78
