" Vim completion script
" Language:	Java Script
" Maintainer:	Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change:	2006 Apr 30

function! javascriptcomplete#CompleteJS(findstart, base)
  if a:findstart
	" locate the start of the word
	let line = getline('.')
	let start = col('.') - 1
	let curline = line('.')
	let compl_begin = col('.') - 2
	" Bit risky but JS is rather limited language and local chars shouldn't
	" fint way into names
	while start >= 0 && line[start - 1] =~ '\k'
		let start -= 1
	endwhile
	let b:compl_context = getline('.')[0:compl_begin]
	return start
  else
	" Initialize base return lists
	let res = []
	let res2 = []
	" a:base is very short - we need context
	" Shortcontext is context without a:base, useful for checking if we are
	" looking for objects and for what objects we are looking for
	let context = b:compl_context
	let shortcontext = substitute(context, a:base.'$', '', '')
	unlet! b:compl_context

	if exists("b:jsrange")
		let file = getline(b:jsrange[0],b:jsrange[1])
		unlet! b:jsrange

		if len(b:js_extfiles) > 0
			let file = b:js_extfiles + file
		endif

	else
		let file = getline(1, '$')
	endif


	" Completion of properties, methods, etc. {{{
	if shortcontext =~ '\.$'
		" Complete methods and properties for objects
		" DOM separate
		let doms = ['style.']
		" Arrays
		let arrayprop = ['constructor', 'index', 'input', 'length', 'prototype']
		let arraymeth = ['concat', 'join', 'pop', 'push', 'reverse', 'shift',
					\ 'splice', 'sort', 'toSource', 'toString', 'unshift', 'valueOf',
					\ 'watch', 'unwatch']
		call map(arraymeth, 'v:val."("')
		let arrays = arrayprop + arraymeth

		" Boolean - complete subset of array values
		" properties - constructor, prototype
		" methods    - toSource, toString, valueOf

		" Date
		" properties - constructor, prototype
		let datemeth = ['getDate', 'getDay', 'getFullYear', 'getHours', 'getMilliseconds',
					\ 'getMinutes', 'getMonth', 'getSeconds', 'getTime', 'getTimezoneOffset',
					\ 'getUTCDate', 'getUTCDay', 'getUTCFullYear', 'getUTCHours', 'getUTCMilliseconds',
					\ 'getUTCMinutes', 'getUTCMonth', 'getUTCSeconds',
					\ 'getYear', 'parse', 'parse',
					\ 'setDate', 'setDay', 'setFullYear', 'setHours', 'setMilliseconds',
					\ 'setMinutes', 'setMonth', 'setSeconds',
					\ 'setUTCDate', 'setUTCDay', 'setUTCFullYear', 'setUTCHours', 'setUTCMilliseconds',
					\ 'setUTCMinutes', 'setUTCMonth', 'setUTCSeconds', 'setYear', 'setTime',
					\ 'toGMTString', 'toLocaleString', 'toLocaleDateString', 'toLocaleTimeString',
					\ 'toSource', 'toString', 'toUTCString', 'UTC', 'valueOf', 'watch', 'unwatch']
		call map(datemeth, 'v:val."("')
		let dates = datemeth

		" Function
		let funcprop = ['arguments', 'arguments.callee', 'arguments.caller', 'arguments.length',
					\ 'arity', 'constructor', 'length', 'prototype']
		let funcmeth = ['apply', 'call', 'toSource', 'toString', 'valueOf']
		call map(funcmeth, 'v:val."("')
		let funcs = funcprop + funcmeth

		" Math
		let mathprop = ['E', 'LN2', 'LN10', 'LOG2E', 'LOG10E', 'PI', 'SQRT1_2', 'SQRT']
		let mathmeth = ['abs', 'acos', 'asin', 'atan', 'atan2', 'ceil', 'cos', 'exp', 'floor',
					\ 'log', 'max', 'min', 'pow', 'random', 'round', 'sin', 'sqrt', 'tan',
					\ 'watch', 'unwatch']
		call map(mathmeth, 'v:val."("')
		let maths = mathprop + mathmeth

		" Number
		let numbprop = ['MAX_VALUE', 'MIN_VALUE', 'NaN', 'NEGATIVE_INFINITY', 'POSITIVE_INFINITY', 
					\ 'constructor', 'prototype']
		let numbmeth = ['toExponential', 'toFixed', 'toPrecision', 'toSource', 'toString', 'valueOf',
					\ 'watch', 'unwatch']
		call map(numbmeth, 'v:val."("')
		let numbs = numbprop + numbmeth

		" Object
		let objeprop = ['constructor', 'prototype']
		let objemeth = ['eval', 'toSource', 'toString', 'unwatch', 'watch', 'valueOf']
		call map(objemeth, 'v:val."("')
		let objes = objeprop + objemeth

		" RegExp
		let regeprop = ['constructor', 'global', 'ignoreCase', 'lastIndex', 'multiline', 'source', 'prototype']
		let regemeth = ['exec', 'test', 'toSource', 'toString', 'watch', 'unwatch']
		call map(regemeth, 'v:val."("')
		let reges = regeprop + regemeth

		" String
		let striprop = ['constructor', 'length', 'prototype']
		let strimeth = ['anchor', 'big', 'blink', 'bold', 'charAt', 'charCodeAt', 'concat',
					\ 'fixed', 'fontcolor', 'fontsize', 'fromCharCode', 'indexOf', 'italics',
					\ 'lastIndexOf', 'link', 'match', 'replace', 'search', 'slice', 'small',
					\ 'split', 'strike', 'sub', 'substr', 'substring', 'sup', 'toLowerCase',
					\ 'toSource', 'toString', 'toUpperCase', 'watch', 'unwatch']
		call map(strimeth, 'v:val."("')
		let stris = striprop + strimeth

		" User created properties
		let user_props1 = filter(copy(file), 'v:val =~ "this\\.\\k"')
		let juser_props1 = join(user_props1, ' ')
		let user_props1 = split(juser_props1, '\zethis\.')
		unlet! juser_props1
		call map(user_props1, 'matchstr(v:val, "this\\.\\zs\\k\\+\\ze")')

		let user_props2 = filter(copy(file), 'v:val =~ "\\.prototype\\.\\k"')
		let juser_props2 = join(user_props2, ' ')
		let user_props2 = split(juser_props2, '\zeprototype\.')
		unlet! juser_props2
		call map(user_props2, 'matchstr(v:val, "prototype\\.\\zs\\k\\+\\ze")')
		let user_props = user_props1 + user_props2

		" HTML DOM properties
		" Anchors - anchor.
		let anchprop = ['accessKey', 'charset', 'coords', 'href', 'hreflang', 'id', 'innerHTML',
					\ 'name', 'rel', 'rev', 'shape', 'tabIndex', 'target', 'type', 'onBlur', 'onFocus']
		let anchmeth = ['blur', 'focus']
		call map(anchmeth, 'v:val."("')
		let anths = anchprop + anchmeth
		" Area - area.
		let areaprop = ['accessKey', 'alt', 'coords', 'hash', 'host', 'hostname', 'href', 'id',
					\ 'noHref', 'pathname', 'port', 'protocol', 'search', 'shape', 'tabIndex', 'target']
		let areameth = ['onClick', 'onDblClick', 'onMouseOut', 'onMouseOver']
		call map(areameth, 'v:val."("')
		let areas = areaprop + areameth
		" Base - base.
		let baseprop = ['href', 'id', 'target']
		let bases = baseprop
		" Body - body.
		let bodyprop = ['aLink', 'background', 'gbColor', 'id', 'link', 'scrollLeft', 'scrollTop',
					\ 'text', 'vLink']
		let bodys = bodyprop
		" Document - document.
		let docuprop = ['anchors', 'applets', 'childNodes', 'embeds', 'forms', 'images', 'links', 'stylesheets',
					\ 'body', 'cookie', 'documentElement', 'domain', 'lastModified', 'referrer', 'title', 'URL']
		let documeth = ['close', 'createAttribute', 'createElement', 'createTextNode', 'focus', 'getElementById',
					\ 'getElementsByName', 'getElementsByTagName', 'open', 'write', 'writeln',
					\ 'onClick', 'onDblClick', 'onFocus', 'onKeyDown', 'onKeyPress', 'onKeyUp',
					\ 'onMouseDown', 'onMouseMove', 'onMouseOut', 'onMouseOver', 'onMouseUp', 'onResize']
		call map(documeth, 'v:val."("')
		let docuxprop = ['attributes', 'childNodes', 'doctype', 'documentElement', 'firstChild',
					\ 'implementation', 'namespaceURI', 'nextSibling', 'nodeName', 'nodeType',
					\ 'nodeValue', 'ownerDocument', 'parentNode', 'previousSibling']
		let docuxmeth = ['createAttribute', 'createCDATASection',
					\ 'createComment', 'createDocument', 'createDocumentFragment',
					\ 'createElement', 'createEntityReference', 'createProcessingInstruction',
					\ 'createTextNode']
		call map(docuxmeth, 'v:val."("')
		let docus = docuprop + docuxprop + documeth + docuxmeth
		" Form - form.
		let formprop = ['elements', 'acceptCharset', 'action', 'encoding', 'enctype', 'id', 'length',
					\ 'method', 'name', 'tabIndex', 'target']
		let formmeth = ['reset', 'submit', 'onReset', 'onSubmit']
		call map(formmeth, 'v:val."("')
		let forms = formprop + formmeth
		" Frame - frame.
		let framprop = ['contentDocument', 'frameBorder', 'id', 'longDesc', 'marginHeight', 'marginWidth',
					\ 'name', 'noResize', 'scrolling', 'src']
		let frammeth = ['blur', 'focus']
		call map(frammeth, 'v:val."("')
		let frams = framprop + frammeth
		" Frameset - frameset.
		let fsetprop = ['cols', 'id', 'rows']
		let fsetmeth = ['blur', 'focus']
		call map(fsetmeth, 'v:val."("')
		let fsets = fsetprop + fsetmeth
		" History - history.
		let histprop = ['length']
		let histmeth = ['back', 'forward', 'go']
		call map(histmeth, 'v:val."("')
		let hists = histprop + histmeth
		" Iframe - iframe.
		let ifraprop = ['align', 'frameBorder', 'height', 'id', 'longDesc', 'marginHeight', 'marginWidth',
					\ 'name', 'scrolling', 'src', 'width']
		let ifras = ifraprop
		" Image - image.
		let imagprop = ['align', 'alt', 'border', 'complete', 'height', 'hspace', 'id', 'isMap', 'longDesc',
					\ 'lowSrc', 'name', 'src', 'useMap', 'vspace', 'width']
		let imagmeth = ['onAbort', 'onError', 'onLoad']
		call map(imagmeth, 'v:val."("')
		let imags = histprop + imagmeth
		" Button - accessible only by other properties
		let buttprop = ['accessKey', 'disabled', 'form', 'id', 'name', 'tabIndex', 'type', 'value']
		let buttmeth = ['blur', 'click', 'focus', 'onBlur', 'onClick', 'onFocus', 'onMouseDown', 'onMouseUp']
		call map(buttmeth, 'v:val."("')
		let butts = buttprop + buttmeth
		" Checkbox - accessible only by other properties
		let checprop = ['accept', 'accessKey', 'align', 'alt', 'checked', 'defaultChecked', 
					\ 'disabled', 'form', 'id', 'name', 'tabIndex', 'type', 'value'] 
		let checmeth = ['blur', 'click', 'focus', 'onBlur', 'onClick', 'onFocus', 'onMouseDown', 'onMouseUp']
		call map(checmeth, 'v:val."("')
		let checs = checprop + checmeth
		" File upload - accessible only by other properties
		let fileprop = ['accept', 'accessKey', 'align', 'alt', 'defaultValue', 
					\ 'disabled', 'form', 'id', 'name', 'tabIndex', 'type', 'value'] 
		let filemeth = ['blur', 'focus', 'onBlur', 'onClick', 'onFocus', 'onMouseDown', 'onMouseUp']
		call map(filemeth, 'v:val."("')
		let files = fileprop + filemeth
		" Hidden - accessible only by other properties
		let hiddprop = ['defaultValue', 'form', 'id', 'name', 'type', 'value'] 
		let hidds = hiddprop
		" Password - accessible only by other properties
		let passprop = ['accept', 'accessKey', 'defaultValue', 
					\ 'disabled', 'form', 'id', 'maxLength', 'name', 'readOnly', 'size', 'tabIndex', 
					\ 'type', 'value'] 
		let passmeth = ['blur', 'click', 'focus', 'select', 'onBlur', 'onFocus', 'onKeyDown', 
					\ 'onKeyPress', 'onKeyUp']
		call map(passmeth, 'v:val."("')
		let passs = passprop + passmeth
		" Radio - accessible only by other properties
		let radiprop = ['accept', 'accessKey', 'align', 'alt', 'checked', 'defaultChecked', 
					\ 'disabled', 'form', 'id', 'name', 'tabIndex', 'type', 'value'] 
		let radimeth = ['blur', 'click', 'focus', 'select', 'onBlur', 'onFocus']
		call map(radimeth, 'v:val."("')
		let radis = radiprop + radimeth
		" Reset - accessible only by other properties
		let reseprop = ['accept', 'accessKey', 'align', 'alt', 'defaultValue', 
					\ 'disabled', 'form', 'id', 'name', 'size', 'tabIndex', 'type', 'value'] 
		let resemeth = ['blur', 'click', 'focus', 'select', 'onBlur', 'onFocus']
		call map(resemeth, 'v:val."("')
		let reses = reseprop + resemeth
		" Submit - accessible only by other properties
		let submprop = ['accept', 'accessKey', 'align', 'alt', 'defaultValue', 
					\ 'disabled', 'form', 'id', 'name', 'size', 'tabIndex', 'type', 'value'] 
		let submmeth = ['blur', 'click', 'focus', 'select', 'onClick', 'onSelectStart']
		call map(submmeth, 'v:val."("')
		let subms = submprop + submmeth
		" Text - accessible only by other properties
		let textprop = ['accept', 'accessKey', 'align', 'alt', 'defaultValue', 
					\ 'disabled', 'form', 'id', 'maxLength', 'name', 'readOnly', 
					\ 'size', 'tabIndex', 'type', 'value'] 
		let textmeth = ['blur', 'focus', 'select', 'onBlur', 'onChange', 'onFocus', 'onKeyDown',
					\ 'onKeyPress', 'onKeyUp', 'onSelect']
		call map(textmeth, 'v:val."("')
		let texts = textprop + textmeth
		" Link - link.
		let linkprop = ['charset', 'disabled', 'href', 'hreflang', 'id', 'media',
					\ 'rel', 'rev', 'target', 'type']
		let linkmeth = ['onLoad']
		call map(linkmeth, 'v:val."("')
		let links = linkprop + linkmeth
		" Location - location.
		let locaprop = ['href', 'hash', 'host', 'hostname', 'pathname', 'port', 'protocol',
					\ 'search']
		let locameth = ['assign', 'reload', 'replace']
		call map(locameth, 'v:val."("')
		let locas = locaprop + locameth
		" Meta - meta.
		let metaprop = ['charset', 'content', 'disabled', 'httpEquiv', 'name', 'scheme']
		let metas = metaprop
		" Navigator - navigator.
		let naviprop = ['plugins', 'appCodeName', 'appName', 'appVersion', 'cookieEnabled',
					\ 'platform', 'userAgent']
		let navimeth = ['javaEnabled', 'taintEnabled']
		call map(navimeth, 'v:val."("')
		let navis = naviprop + navimeth
		" Object - object.
		let objeprop = ['align', 'archive', 'border', 'code', 'codeBase', 'codeType', 'data',
					\ 'declare', 'form', 'height', 'hspace', 'id', 'name', 'standby', 'tabIndex',
					\ 'type', 'useMap', 'vspace', 'width']
		let objes = objeprop
		" Option - accessible only by other properties
		let optiprop = ['defaultSelected', 
					\ 'disabled', 'form', 'id', 'index', 'label', 'selected', 'text', 'value']
		let optis = optiprop
		" Screen - screen.
		let screprop = ['availHeight', 'availWidth', 'colorDepth', 'height', 'width']
		let scres = screprop
		" Select - accessible only by other properties
		let seleprop = ['options', 'disabled', 'form', 'id', 'length', 'multiple', 'name', 
					\ 'selectedIndex', 'size', 'tabIndex', 'type', 'value'] 
		let selemeth = ['blur', 'focus', 'remove', 'onBlur', 'onChange', 'onFocus']
		call map(selemeth, 'v:val."("')
		let seles = seleprop + selemeth
		" Style - style.
		let stylprop = ['background', 'backgroundAttachment', 'backgroundColor', 'backgroundImage',
					\ 'backgroundPosition', 'backgroundRepeat',
					\ 'border', 'borderBottom', 'borderLeft', 'borderRight', 'borderTop',
					\ 'borderBottomColor', 'borderLeftColor', 'borderRightColor', 'borderTopColor',
					\ 'borderBottomStyle', 'borderLeftStyle', 'borderRightStyle', 'borderTopStyle',
					\ 'borderBottomWidth', 'borderLeftWidth', 'borderRightWidth', 'borderTopWidth',
					\ 'borderColor', 'borderStyle', 'borderWidth', 'margin', 'marginBottom',
					\ 'marginLeft', 'marginRight', 'marginTop', 'outline', 'outlineStyle', 'outlineWidth',
					\ 'outlineColor', 'outlineStyle', 'outlineWidth', 'padding', 'paddingBottom',
					\ 'paddingLeft', 'paddingRight', 'paddingTop',
					\ 'clear', 'clip', 'clipBottom', 'clipLeft', 'clipRight', 'clipTop', 'content',
					\ 'counterIncrement', 'counterReset', 'cssFloat', 'cursor', 'direction',
					\ 'display', 'markerOffset', 'marks', 'maxHeight', 'maxWidth', 'minHeight',
					\ 'minWidth', 'overflow', 'overflowX', 'overflowY', 'verticalAlign', 'visibility',
					\ 'width',
					\ 'listStyle', 'listStyleImage', 'listStylePosition', 'listStyleType',
					\ 'cssText', 'bottom', 'height', 'left', 'position', 'right', 'top', 'width', 'zindex',
					\ 'orphans', 'widows', 'page', 'pageBreakAfter', 'pageBreakBefore', 'pageBreakInside',
					\ 'borderCollapse', 'borderSpacing', 'captionSide', 'emptyCells', 'tableLayout',
					\ 'color', 'font', 'fontFamily', 'fontSize', 'fontSizeAdjust', 'fontStretch',
					\ 'fontStyle', 'fontVariant', 'fontWeight', 'letterSpacing', 'lineHeight', 'quotes',
					\ 'textAlign', 'textIndent', 'textShadow', 'textTransform', 'textUnderlinePosition',
					\ 'unicodeBidi', 'whiteSpace', 'wordSpacing']
		let styls = stylprop
		" Table - table.
		let tablprop = ['rows', 'tBodies', 'align', 'bgColor', 'border', 'caption', 'cellPadding',
					\ 'cellSpacing', 'frame', 'height', 'rules', 'summary', 'tFoot', 'tHead', 'width']
		let tablmeth = ['createCaption', 'createTFoot', 'createTHead', 'deleteCaption', 'deleteRow',
					\ 'deleteTFoot', 'deleteTHead', 'insertRow']
		call map(tablmeth, 'v:val."("')
		let tabls = tablprop + tablmeth
		" Table data - TableData.
		let tdatprop = ['abbr', 'align', 'axis', 'bgColor', 'cellIndex', 'ch', 'chOff',
					\ 'colSpan', 'headers', 'noWrap', 'rowSpan', 'scope', 'vAlign', 'width']
		let tdats = tdatprop
		" Table row - TableRow.
		let trowprop = ['cells', 'align', 'bgColor', 'ch', 'chOff', 'rowIndex', 'sectionRowIndex',
					\ 'vAlign']
		let trowmeth = ['deleteCell', 'insertCell']
		call map(trowmeth, 'v:val."("')
		let trows = trowprop + trowmeth
		" Textarea - accessible only by other properties
		let tareprop = ['accessKey', 'cols', 'defaultValue', 
					\ 'disabled', 'form', 'id', 'name', 'readOnly', 'rows', 
					\ 'tabIndex', 'type', 'value', 'selectionStart', 'selectionEnd'] 
		let taremeth = ['blur', 'focus', 'select', 'onBlur', 'onChange', 'onFocus']
		call map(taremeth, 'v:val."("')
		let tares = tareprop + taremeth
		" Window - window.
		let windprop = ['frames', 'closed', 'defaultStatus', 'encodeURI', 'event', 'history',
					\ 'length', 'location', 'name', 'onload', 'opener', 'parent', 'screen', 'self',
					\ 'status', 'top', 'XMLHttpRequest', 'ActiveXObject']
		let windmeth = ['alert', 'blur', 'clearInterval', 'clearTimeout', 'close', 'confirm', 'focus',
					\ 'moveBy', 'moveTo', 'open', 'print', 'prompt', 'scrollBy', 'scrollTo', 'setInterval',
					\ 'setTimeout']
		call map(windmeth, 'v:val."("')
		let winds = windprop + windmeth
		" XMLHttpRequest - access by new xxx()
		let xmlhprop = ['onreadystatechange', 'readyState', 'responseText', 'responseXML',
					\ 'status', 'statusText', 'parseError']
		let xmlhmeth = ['abort', 'getAllResponseHeaders', 'getResponseHeaders', 'open',
					\ 'send', 'setRequestHeader']
		call map(xmlhmeth, 'v:val."("')
		let xmlhs = xmlhprop + xmlhmeth

		" XML DOM
		" Attributes - element.attributes[x].
		let xdomattrprop = ['name', 'specified', 'value']
		" Element - anyelement.
		let xdomelemprop = ['attributes', 'childNodes', 'firstChild', 'lastChild', 
					\ 'namespaceURI', 'nextSibling', 'nodeName', 'nodeType', 'nodeValue',
					\ 'ownerDocument', 'parentNode', 'prefix', 'previousSibling', 'tagName']
		let xdomelemmeth = ['appendChild', 'cloneNode', 'getAttribute', 'getAttributeNode',
					\ 'getElementsByTagName', 'hasChildNodes', 'insertBefore', 'normalize',
					\ 'removeAttribute', 'removeAttributeNode', 'removeChild', 'replaceChild',
					\ 'setAttribute', 'setAttributeNode']
		call map(xdomelemmeth, 'v:val."("')
		let xdomelems = xdomelemprop + xdomelemmeth
		" Node - anynode.
		let xdomnodeprop = ['attributes', 'childNodes', 'firstChild', 'lastChild', 
					\ 'namespaceURI', 'nextSibling', 'nodeName', 'nodeType', 'nodeValue',
					\ 'ownerDocument', 'parentNode', 'prefix', 'previousSibling']
		let xdomnodemeth = ['appendChild', 'cloneNode',
					\ 'hasChildNodes', 'insertBefore', 'removeChild', 'replaceChild']
		call map(xdomnodemeth, 'v:val."("')
		let xdomnodes = xdomnodeprop + xdomnodemeth
		" NodeList 
		let xdomnliss = ['length', 'item(']
		" Error - parseError.
		let xdomerror = ['errorCode', 'reason', 'line', 'linepos', 'srcText', 'url', 'filepos']

		" Find object type declaration to reduce number of suggestions. {{{
		" 1. Get object name
		" 2. Find object declaration line
		" 3. General declaration follows "= new Type" syntax, additional else
		"    for regexp "= /re/"
		" 4. Make correction for Microsoft.XMLHTTP ActiveXObject
		" 5. Repeat for external files
		let object = matchstr(shortcontext, '\zs\k\+\ze\(\[.\{-}\]\)\?\.$')
		if len(object) > 0
			let decl_line = search(object.'.\{-}=\s*new\s*', 'bn')
			if decl_line > 0
				let object_type = matchstr(getline(decl_line), object.'.\{-}=\s*new\s*\zs\k\+\ze')
				if object_type == 'ActiveXObject' && matchstr(getline(decl_line), object.'.\{-}=\s*new\s*ActiveXObject\s*(.Microsoft\.XMLHTTP.)') != ''
						let object_type = 'XMLHttpRequest'
				endif
			else
				let decl_line = search('var\s*'.object.'\s*=\s*\/', 'bn')
				if decl_line > 0
					let object_type = 'RegExp'
				endif
			endif
			" We didn't find var declaration in current file but we may have
			" something in external files.
			if decl_line == 0 && exists("b:js_extfiles")
				let dext_line = filter(copy(b:js_extfiles), 'v:val =~ "'.object.'.\\{-}=\\s*new\\s*"')
				if len(dext_line) > 0
					let object_type = matchstr(dext_line[-1], object.'.\{-}=\s*new\s*\zs\k\+\ze')
					if object_type == 'ActiveXObject' && matchstr(dext_line[-1], object.'.\{-}=\s*new\s*ActiveXObject\s*(.Microsoft\.XMLHTTP.)') != ''
							let object_type = 'XMLHttpRequest'
					endif
				else
					let dext_line = filter(copy(b:js_extfiles), 'v:val =~ "var\s*'.object.'\\s*=\\s*\\/"')
					if len(dext_line) > 0
						let object_type = 'RegExp'
					endif
				endif
			endif
		endif
		" }}}

		if !exists('object_type')
			let object_type = ''
		endif

		if object_type == 'Date'
			let values = dates
		elseif object_type == 'Image'
			let values = imags
		elseif object_type == 'Array'
			let values = arrays
		elseif object_type == 'Boolean'
			" TODO: a bit more than real boolean
			let values = arrays
		elseif object_type == 'XMLHttpRequest'
			let values = xmlhs
		elseif object_type == 'String'
			let values = stris
		elseif object_type == 'RegExp'
			let values = reges
		elseif object_type == 'Math'
			let values = maths
		endif

		if !exists('values')
		" List of properties
		if shortcontext =~ 'Math\.$'
			let values = maths
		elseif shortcontext =~ 'anchors\(\[.\{-}\]\)\?\.$'
			let values = anths
		elseif shortcontext =~ 'area\.$'
			let values = areas
		elseif shortcontext =~ 'base\.$'
			let values = bases
		elseif shortcontext =~ 'body\.$'
			let values = bodys
		elseif shortcontext =~ 'document\.$'
			let values = docus
		elseif shortcontext =~ 'forms\(\[.\{-}\]\)\?\.$'
			let values = forms
		elseif shortcontext =~ 'frameset\.$'
			let values = fsets
		elseif shortcontext =~ 'history\.$'
			let values = hists
		elseif shortcontext =~ 'iframe\.$'
			let values = ifras
		elseif shortcontext =~ 'images\(\[.\{-}\]\)\?\.$'
			let values = imags
		elseif shortcontext =~ 'links\(\[.\{-}\]\)\?\.$'
			let values = links
		elseif shortcontext =~ 'location\.$'
			let values = locas
		elseif shortcontext =~ 'meta\.$'
			let values = metas
		elseif shortcontext =~ 'navigator\.$'
			let values = navis
		elseif shortcontext =~ 'object\.$'
			let values = objes
		elseif shortcontext =~ 'screen\.$'
			let values = scres
		elseif shortcontext =~ 'style\.$'
			let values = styls
		elseif shortcontext =~ 'table\.$'
			let values = tabls
		elseif shortcontext =~ 'TableData\.$'
			let values = tdats
		elseif shortcontext =~ 'TableRow\.$'
			let values = trows
		elseif shortcontext =~ 'window\.$'
			let values = winds
		elseif shortcontext =~ 'parseError\.$'
			let values = xdomerror
		elseif shortcontext =~ 'attributes\[\d\+\]\.$'
			let values = xdomattrprop
		else
			let values = user_props + arrays + dates + funcs + maths + numbs + objes + reges + stris
			let values += doms + anths + areas + bases + bodys + docus + forms + frams + fsets + hists
			let values += ifras + imags + links + locas + metas + navis + objes + scres
			let values += tabls + trows + tares + winds
			let values += xdomnodes + xdomnliss + xdomelems
		endif
		endif

		for m in values
			if m =~? '^'.a:base
				call add(res, m)
			elseif m =~? a:base
				call add(res2, m)
			endif
		endfor

		unlet! values
		return res + res2

	endif
	" }}}

	" Get variables data.
	let variables = filter(copy(file), 'v:val =~ "var\\s"')
	call map(variables, 'matchstr(v:val, ".\\{-}var\\s\\+\\zs.*\\ze")')
	call map(variables, 'substitute(v:val, ";\\|$", ",", "g")')
	let vars = []
	" This loop (and next one) is necessary to get variable names from
	" constructs like: var var1, var2, var3 = "something";
	for i in range(len(variables))
		let comma_separated = split(variables[i], ',\s*')
		call map(comma_separated, 'matchstr(v:val, "\\k\\+")')
		let vars += comma_separated
	endfor

	let variables = sort(vars)
	unlet! vars

	" Add "no var" variables.
	let undeclared_variables = filter(copy(file), 'v:val =~ "^\\s*\\k\\+\\s*="')
	let u_vars = []
	for i in range(len(undeclared_variables))
		let  split_equal = split(undeclared_variables[i], '\s*=')
		call map(split_equal, 'matchstr(v:val, "\\k\\+$")')
		let u_vars += split_equal
	endfor

	let variables += sort(u_vars)
	unlet! u_vars

	" Get functions
	let functions = filter(copy(file), 'v:val =~ "^\\s*function\\s"')
	let arguments = copy(functions)
	call map(functions, 'matchstr(v:val, "^\\s*function\\s\\+\\zs\\k\\+")')
	call map(functions, 'v:val."("')
	let functions = sort(functions)

	" Create table to keep arguments for additional 'menu' info
	let b:js_menuinfo = {}
	for i in arguments
		let g:ia = i
		let f_elements = matchlist(i, 'function\s\+\(\k\+\)\s*(\(.\{-}\))')
		if len(f_elements) == 3
			let b:js_menuinfo[f_elements[1].'('] = f_elements[2]
		endif
	endfor

	" Get functions arguments
	call map(arguments, 'matchstr(v:val, "function.\\{-}(\\zs.\\{-}\\ze)")')
	let jargs = join(arguments, ',')
	let jargs = substitute(jargs, '\s', '', 'g')
	let arguments = split(jargs, ',')
	let arguments = sort(arguments)

	" Built-in functions
	let builtin = ['alert(', 'confirm(']

	" Top-level HTML DOM objects
	let htmldom = ['document', 'anchor', 'area', 'base', 'body', 'document', 'event', 'form', 'frame', 'frameset', 'history', 'iframe', 'image', 'input', 'link', 'location', 'meta', 'navigator', 'object', 'option', 'screen', 'select', 'table', 'tableData', 'tableHeader', 'tableRow', 'textarea', 'window']
	call map(htmldom, 'v:val."."')

	" Top-level properties
	let properties = ['decodeURI', 'decodeURIComponent', 'encodeURI', 'encodeURIComponent',
				\ 'eval', 'Infinity', 'isFinite', 'isNaN', 'NaN', 'Number', 'parseFloat',
				\ 'parseInt', 'String', 'undefined', 'escape', 'unescape']

	" Keywords
	let keywords = ["Array", "Boolean", "Date", "Function", "Math", "Number", "Object", "RegExp", "String", "XMLHttpRequest", "ActiveXObject", "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue", "debugger", "default", "delete", "do", "double ", "else", "enum", "export", "extends", "false", "final", "finally", "float", "for", "function", "goto", "if", "implements", "import", "in ", "instanceof", "int", "interface", "long", "native", "new", "null", "package", "private", "protected", "public", "return", "short", "static", "super ", "switch", "synchronized", "this", "throw", "throws", "transient", "true", "try", "typeof", "var", "void", "volatile", "while", "with"]

	let values = variables + functions + htmldom + arguments + builtin + properties + keywords

	for m in values
		if m =~? '^'.a:base
			call add(res, m)
		elseif m =~? a:base
			call add(res2, m)
		endif
	endfor

	let menu = res + res2
	let final_menu = []
	for i in range(len(menu))
		let item = menu[i]
		if item =~ '($'
			let kind = 'f'
			if has_key(b:js_menuinfo, item)
				let m_info = b:js_menuinfo[item]
			else
				let m_info = ''
			endif
		else
			let kind = 'v'
			let m_info = ''
		endif
		let final_menu += [{'word':item, 'menu':m_info, 'kind':kind}]
	endfor
	let g:fm = final_menu
	return final_menu

endfunction

" vim:set foldmethod=marker:
