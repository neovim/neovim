" Vim completion script
" Language:	CSS 2.1
" Maintainer:	Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change:	2007 May 5

	let s:values = split("azimuth background background-attachment background-color background-image background-position background-repeat border bottom border-collapse border-color border-spacing border-style border-top border-right border-bottom border-left border-top-color border-right-color border-bottom-color border-left-color  border-top-style border-right-style border-bottom-style border-left-style border-top-width border-right-width border-bottom-width border-left-width border-width caption-side clear clip color content counter-increment counter-reset cue cue-after cue-before cursor display direction elevation empty-cells float font font-family font-size font-style font-variant font-weight height left letter-spacing line-height list-style list-style-image list-style-position list-style-type margin margin-right margin-left margin-top margin-bottom max-height max-width min-height min-width orphans outline outline-color outline-style outline-width overflow padding padding-top padding-right padding-bottom padding-left page-break-after page-break-before page-break-inside pause pause-after pause-before pitch pitch-range play-during position quotes right richness speak speak-header speak-numeral speak-punctuation speech-rate stress table-layout text-align text-decoration text-indent text-transform top unicode-bidi vertical-align visibility voice-family volume white-space width widows word-spacing z-index")

function! csscomplete#CompleteCSS(findstart, base)

if a:findstart
	" We need whole line to proper checking
	let line = getline('.')
	let start = col('.') - 1
	let compl_begin = col('.') - 2
	while start >= 0 && line[start - 1] =~ '\%(\k\|-\)'
		let start -= 1
	endwhile
	let b:compl_context = line[0:compl_begin]
	return start
endif

" There are few chars important for context:
" ^ ; : { } /* */
" Where ^ is start of line and /* */ are comment borders
" Depending on their relative position to cursor we will know what should
" be completed. 
" 1. if nearest are ^ or { or ; current word is property
" 2. if : it is value (with exception of pseudo things)
" 3. if } we are outside of css definitions
" 4. for comments ignoring is be the easiest but assume they are the same
"    as 1. 
" 5. if @ complete at-rule
" 6. if ! complete important
if exists("b:compl_context")
	let line = b:compl_context
	unlet! b:compl_context
else
	let line = a:base
endif

let res = []
let res2 = []
let borders = {}

" Check last occurrence of sequence

let openbrace  = strridx(line, '{')
let closebrace = strridx(line, '}')
let colon      = strridx(line, ':')
let semicolon  = strridx(line, ';')
let opencomm   = strridx(line, '/*')
let closecomm  = strridx(line, '*/')
let style      = strridx(line, 'style\s*=')
let atrule     = strridx(line, '@')
let exclam     = strridx(line, '!')

if openbrace > -1
	let borders[openbrace] = "openbrace"
endif
if closebrace > -1
	let borders[closebrace] = "closebrace"
endif
if colon > -1
	let borders[colon] = "colon"
endif
if semicolon > -1
	let borders[semicolon] = "semicolon"
endif
if opencomm > -1
	let borders[opencomm] = "opencomm"
endif
if closecomm > -1
	let borders[closecomm] = "closecomm"
endif
if style > -1
	let borders[style] = "style"
endif
if atrule > -1
	let borders[atrule] = "atrule"
endif
if exclam > -1
	let borders[exclam] = "exclam"
endif


if len(borders) == 0 || borders[max(keys(borders))] =~ '^\%(openbrace\|semicolon\|opencomm\|closecomm\|style\)$'
	" Complete properties


	let entered_property = matchstr(line, '.\{-}\zs[a-zA-Z-]*$')

	for m in s:values
		if m =~? '^'.entered_property
			call add(res, m . ':')
		elseif m =~? entered_property
			call add(res2, m . ':')
		endif
	endfor

	return res + res2

elseif borders[max(keys(borders))] == 'colon'
	" Get name of property
	let prop = tolower(matchstr(line, '\zs[a-zA-Z-]*\ze\s*:[^:]\{-}$'))

	if prop == 'azimuth'
		let values = ["left-side", "far-left", "left", "center-left", "center", "center-right", "right", "far-right", "right-side", "behind", "leftwards", "rightwards"]
	elseif prop == 'background-attachment'
		let values = ["scroll", "fixed"]
	elseif prop == 'background-color'
		let values = ["transparent", "rgb(", "#"]
	elseif prop == 'background-image'
		let values = ["url(", "none"]
	elseif prop == 'background-position'
		let vals = matchstr(line, '.*:\s*\zs.*')
		if vals =~ '^\%([a-zA-Z]\+\)\?$'
			let values = ["top", "center", "bottom"]
		elseif vals =~ '^[a-zA-Z]\+\s\+\%([a-zA-Z]\+\)\?$'
			let values = ["left", "center", "right"]
		else
			return []
		endif
	elseif prop == 'background-repeat'
		let values = ["repeat", "repeat-x", "repeat-y", "no-repeat"]
	elseif prop == 'background'
		let values = ["url(", "scroll", "fixed", "transparent", "rgb(", "#", "none", "top", "center", "bottom" , "left", "right", "repeat", "repeat-x", "repeat-y", "no-repeat"]
	elseif prop == 'border-collapse'
		let values = ["collapse", "separate"]
	elseif prop == 'border-color'
		let values = ["rgb(", "#", "transparent"]
	elseif prop == 'border-spacing'
		return []
	elseif prop == 'border-style'
		let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
	elseif prop =~ 'border-\%(top\|right\|bottom\|left\)$'
		let vals = matchstr(line, '.*:\s*\zs.*')
		if vals =~ '^\%([a-zA-Z0-9.]\+\)\?$'
			let values = ["thin", "thick", "medium"]
		elseif vals =~ '^[a-zA-Z0-9.]\+\s\+\%([a-zA-Z]\+\)\?$'
			let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
		elseif vals =~ '^[a-zA-Z0-9.]\+\s\+[a-zA-Z]\+\s\+\%([a-zA-Z(]\+\)\?$'
			let values = ["rgb(", "#", "transparent"]
		else
			return []
		endif
	elseif prop =~ 'border-\%(top\|right\|bottom\|left\)-color'
		let values = ["rgb(", "#", "transparent"]
	elseif prop =~ 'border-\%(top\|right\|bottom\|left\)-style'
		let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
	elseif prop =~ 'border-\%(top\|right\|bottom\|left\)-width'
		let values = ["thin", "thick", "medium"]
	elseif prop == 'border-width'
		let values = ["thin", "thick", "medium"]
	elseif prop == 'border'
		let vals = matchstr(line, '.*:\s*\zs.*')
		if vals =~ '^\%([a-zA-Z0-9.]\+\)\?$'
			let values = ["thin", "thick", "medium"]
		elseif vals =~ '^[a-zA-Z0-9.]\+\s\+\%([a-zA-Z]\+\)\?$'
			let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
		elseif vals =~ '^[a-zA-Z0-9.]\+\s\+[a-zA-Z]\+\s\+\%([a-zA-Z(]\+\)\?$'
			let values = ["rgb(", "#", "transparent"]
		else
			return []
		endif
	elseif prop == 'bottom'
		let values = ["auto"]
	elseif prop == 'caption-side'
		let values = ["top", "bottom"]
	elseif prop == 'clear'
		let values = ["none", "left", "right", "both"]
	elseif prop == 'clip'
		let values = ["auto", "rect("]
	elseif prop == 'color'
		let values = ["rgb(", "#"]
	elseif prop == 'content'
		let values = ["normal", "attr(", "open-quote", "close-quote", "no-open-quote", "no-close-quote"]
	elseif prop =~ 'counter-\%(increment\|reset\)$'
		let values = ["none"]
	elseif prop =~ '^\%(cue-after\|cue-before\|cue\)$'
		let values = ["url(", "none"]
	elseif prop == 'cursor'
		let values = ["url(", "auto", "crosshair", "default", "pointer", "move", "e-resize", "ne-resize", "nw-resize", "n-resize", "se-resize", "sw-resize", "s-resize", "w-resize", "text", "wait", "help", "progress"]
	elseif prop == 'direction'
		let values = ["ltr", "rtl"]
	elseif prop == 'display'
		let values = ["inline", "block", "list-item", "run-in", "inline-block", "table", "inline-table", "table-row-group", "table-header-group", "table-footer-group", "table-row", "table-column-group", "table-column", "table-cell", "table-caption", "none"]
	elseif prop == 'elevation'
		let values = ["below", "level", "above", "higher", "lower"]
	elseif prop == 'empty-cells'
		let values = ["show", "hide"]
	elseif prop == 'float'
		let values = ["left", "right", "none"]
	elseif prop == 'font-family'
		let values = ["sans-serif", "serif", "monospace", "cursive", "fantasy"]
	elseif prop == 'font-size'
		 let values = ["xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large", "larger", "smaller"]
	elseif prop == 'font-style'
		let values = ["normal", "italic", "oblique"]
	elseif prop == 'font-variant'
		let values = ["normal", "small-caps"]
	elseif prop == 'font-weight'
		let values = ["normal", "bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900"]
	elseif prop == 'font'
		let values = ["normal", "italic", "oblique", "small-caps", "bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900", "xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large", "larger", "smaller", "sans-serif", "serif", "monospace", "cursive", "fantasy", "caption", "icon", "menu", "message-box", "small-caption", "status-bar"]
	elseif prop =~ '^\%(height\|width\)$'
		let values = ["auto"]
	elseif prop =~ '^\%(left\|rigth\)$'
		let values = ["auto"]
	elseif prop == 'letter-spacing'
		let values = ["normal"]
	elseif prop == 'line-height'
		let values = ["normal"]
	elseif prop == 'list-style-image'
		let values = ["url(", "none"]
	elseif prop == 'list-style-position'
		let values = ["inside", "outside"]
	elseif prop == 'list-style-type'
		let values = ["disc", "circle", "square", "decimal", "decimal-leading-zero", "lower-roman", "upper-roman", "lower-latin", "upper-latin", "none"]
	elseif prop == 'list-style'
		return []
	elseif prop == 'margin'
		let values = ["auto"]
	elseif prop =~ 'margin-\%(right\|left\|top\|bottom\)$'
		let values = ["auto"]
	elseif prop == 'max-height'
		let values = ["auto"]
	elseif prop == 'max-width'
		let values = ["none"]
	elseif prop == 'min-height'
		let values = ["none"]
	elseif prop == 'min-width'
		let values = ["none"]
	elseif prop == 'orphans'
		return []
	elseif prop == 'outline-color'
		let values = ["rgb(", "#"]
	elseif prop == 'outline-style'
		let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
	elseif prop == 'outline-width'
		let values = ["thin", "thick", "medium"]
	elseif prop == 'outline'
		let vals = matchstr(line, '.*:\s*\zs.*')
		if vals =~ '^\%([a-zA-Z0-9,()#]\+\)\?$'
			let values = ["rgb(", "#"]
		elseif vals =~ '^[a-zA-Z0-9,()#]\+\s\+\%([a-zA-Z]\+\)\?$'
			let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
		elseif vals =~ '^[a-zA-Z0-9,()#]\+\s\+[a-zA-Z]\+\s\+\%([a-zA-Z(]\+\)\?$'
			let values = ["thin", "thick", "medium"]
		else
			return []
		endif
	elseif prop == 'overflow'
		let values = ["visible", "hidden", "scroll", "auto"]
	elseif prop == 'padding'
		return []
	elseif prop =~ 'padding-\%(top\|right\|bottom\|left\)$'
		return []
	elseif prop =~ 'page-break-\%(after\|before\)$'
		let values = ["auto", "always", "avoid", "left", "right"]
	elseif prop == 'page-break-inside'
		let values = ["auto", "avoid"]
	elseif prop =~ 'pause-\%(after\|before\)$'
		return []
	elseif prop == 'pause'
		return []
	elseif prop == 'pitch-range'
		return []
	elseif prop == 'pitch'
		let values = ["x-low", "low", "medium", "high", "x-high"]
	elseif prop == 'play-during'
		let values = ["url(", "mix", "repeat", "auto", "none"]
	elseif prop == 'position'
		let values = ["static", "relative", "absolute", "fixed"]
	elseif prop == 'quotes'
		let values = ["none"]
	elseif prop == 'richness'
		return []
	elseif prop == 'speak-header'
		let values = ["once", "always"]
	elseif prop == 'speak-numeral'
		let values = ["digits", "continuous"]
	elseif prop == 'speak-punctuation'
		let values = ["code", "none"]
	elseif prop == 'speak'
		let values = ["normal", "none", "spell-out"]
	elseif prop == 'speech-rate'
		let values = ["x-slow", "slow", "medium", "fast", "x-fast", "faster", "slower"]
	elseif prop == 'stress'
		return []
	elseif prop == 'table-layout'
		let values = ["auto", "fixed"]
	elseif prop == 'text-align'
		let values = ["left", "right", "center", "justify"]
	elseif prop == 'text-decoration'
		let values = ["none", "underline", "overline", "line-through", "blink"]
	elseif prop == 'text-indent'
		return []
	elseif prop == 'text-transform'
		let values = ["capitalize", "uppercase", "lowercase", "none"]
	elseif prop == 'top'
		let values = ["auto"]
	elseif prop == 'unicode-bidi'
		let values = ["normal", "embed", "bidi-override"]
	elseif prop == 'vertical-align'
		let values = ["baseline", "sub", "super", "top", "text-top", "middle", "bottom", "text-bottom"]
	elseif prop == 'visibility'
		let values = ["visible", "hidden", "collapse"]
	elseif prop == 'voice-family'
		return []
	elseif prop == 'volume'
		let values = ["silent", "x-soft", "soft", "medium", "loud", "x-loud"]
	elseif prop == 'white-space'
		let values = ["normal", "pre", "nowrap", "pre-wrap", "pre-line"]
	elseif prop == 'widows'
		return []
	elseif prop == 'word-spacing'
		let values = ["normal"]
	elseif prop == 'z-index'
		let values = ["auto"]
	else
		" If no property match it is possible we are outside of {} and
		" trying to complete pseudo-(class|element)
		let element = tolower(matchstr(line, '\zs[a-zA-Z1-6]*\ze:[^:[:space:]]\{-}$'))
		if stridx(',a,abbr,acronym,address,area,b,base,bdo,big,blockquote,body,br,button,caption,cite,code,col,colgroup,dd,del,dfn,div,dl,dt,em,fieldset,form,head,h1,h2,h3,h4,h5,h6,hr,html,i,img,input,ins,kbd,label,legend,li,link,map,meta,noscript,object,ol,optgroup,option,p,param,pre,q,samp,script,select,small,span,strong,style,sub,sup,table,tbody,td,textarea,tfoot,th,thead,title,tr,tt,ul,var,', ','.element.',') > -1
			let values = ["first-child", "link", "visited", "hover", "active", "focus", "lang", "first-line", "first-letter", "before", "after"]
		else
			return []
		endif
	endif

	" Complete values
	let entered_value = matchstr(line, '.\{-}\zs[a-zA-Z0-9#,.(_-]*$')

	for m in values
		if m =~? '^'.entered_value
			call add(res, m)
		elseif m =~? entered_value
			call add(res2, m)
		endif
	endfor

	return res + res2

elseif borders[max(keys(borders))] == 'closebrace'

	return []

elseif borders[max(keys(borders))] == 'exclam'

	" Complete values
	let entered_imp = matchstr(line, '.\{-}!\s*\zs[a-zA-Z ]*$')

	let values = ["important"]

	for m in values
		if m =~? '^'.entered_imp
			call add(res, m)
		endif
	endfor

	return res

elseif borders[max(keys(borders))] == 'atrule'

	let afterat = matchstr(line, '.*@\zs.*')

	if afterat =~ '\s'

		let atrulename = matchstr(line, '.*@\zs[a-zA-Z-]\+\ze')

		if atrulename == 'media'
			let values = ["screen", "tty", "tv", "projection", "handheld", "print", "braille", "aural", "all"]

			let entered_atruleafter = matchstr(line, '.*@media\s\+\zs.*$')

		elseif atrulename == 'import'
			let entered_atruleafter = matchstr(line, '.*@import\s\+\zs.*$')

			if entered_atruleafter =~ "^[\"']"
				let filestart = matchstr(entered_atruleafter, '^.\zs.*')
				let files = split(glob(filestart.'*'), '\n')
				let values = map(copy(files), '"\"".v:val')

			elseif entered_atruleafter =~ "^url("
				let filestart = matchstr(entered_atruleafter, "^url([\"']\\?\\zs.*")
				let files = split(glob(filestart.'*'), '\n')
				let values = map(copy(files), '"url(".v:val')
				
			else
				let values = ['"', 'url(']

			endif

		else
			return []

		endif

		for m in values
			if m =~? '^'.entered_atruleafter
				call add(res, m)
			elseif m =~? entered_atruleafter
				call add(res2, m)
			endif
		endfor

		return res + res2

	endif

	let values = ["charset", "page", "media", "import", "font-face"]

	let entered_atrule = matchstr(line, '.*@\zs[a-zA-Z-]*$')

	for m in values
		if m =~? '^'.entered_atrule
			call add(res, m .' ')
		elseif m =~? entered_atrule
			call add(res2, m .' ')
		endif
	endfor

	return res + res2

endif

return []

endfunction
