" Vim completion script
" Language: CSS
"           Based on MDN CSS Reference at 2016 Jan <https://developer.mozilla.org/en-US/docs/Web/CSS/Reference>
"           plus CSS Speech Module <http://www.w3.org/TR/css3-speech/>
" Maintainer: Kao, Wei-Ko(othree) ( othree AT gmail DOT com )
" Original Author: Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change: 2018 Jul 02

let s:values = split("all additive-symbols align-content align-items align-self animation animation-delay animation-direction animation-duration animation-fill-mode animation-iteration-count animation-name animation-play-state animation-timing-function backface-visibility background background-attachment background-blend-mode background-clip background-color background-image background-origin background-position background-repeat background-size block-size border border-block-end border-block-end-color border-block-end-style border-block-end-width border-block-start border-block-start-color border-block-start-style border-block-start-width border-bottom border-bottom-color border-bottom-left-radius border-bottom-right-radius border-bottom-style border-bottom-width border-collapse border-color border-image border-image-outset border-image-repeat border-image-slice border-image-source border-image-width border-inline-end border-inline-end-color border-inline-end-style border-inline-end-width border-inline-start border-inline-start-color border-inline-start-style border-inline-start-width border-left border-left-color border-left-style border-left-width border-radius border-right border-right-color border-right-style border-right-width border-spacing border-style border-top border-top-color border-top-left-radius border-top-right-radius border-top-style border-top-width border-width bottom box-decoration-break box-shadow box-sizing break-after break-before break-inside caption-side clear clip clip-path color columns column-count column-fill column-gap column-rule column-rule-color column-rule-style column-rule-width column-span column-width content counter-increment counter-reset cue cue-before cue-after cursor direction display empty-cells fallback filter flex flex-basis flex-direction flex-flow flex-grow flex-shrink flex-wrap float font font-family font-feature-settings font-kerning font-language-override font-size font-size-adjust font-stretch font-style font-synthesis font-variant font-variant-alternates font-variant-caps font-variant-east-asian font-variant-ligatures font-variant-numeric font-variant-position font-weight grid grid-area grid-auto-columns grid-auto-flow grid-auto-position grid-auto-rows grid-column grid-column-start grid-column-end grid-row grid-row-start grid-row-end grid-template grid-template-areas grid-template-rows grid-template-columns height hyphens image-rendering image-resolution image-orientation ime-mode inline-size isolation justify-content left letter-spacing line-break line-height list-style list-style-image list-style-position list-style-type margin margin-block-end margin-block-start margin-bottom margin-inline-end margin-inline-start margin-left margin-right margin-top marks mask mask-type max-block-size max-height max-inline-size max-width max-zoom min-block-size min-height min-inline-size min-width min-zoom mix-blend-mode negative object-fit object-position offset-block-end offset-block-start offset-inline-end offset-inline-start opacity order orientation orphans outline outline-color outline-offset outline-style outline-width overflow overflow-wrap overflow-x overflow-y pad padding padding-block-end padding-block-start padding-bottom padding-inline-end padding-inline-start padding-left padding-right padding-top page-break-after page-break-before page-break-inside pause-before pause-after pause perspective perspective-origin pointer-events position prefix quotes range resize rest rest-before rest-after right ruby-align ruby-merge ruby-position scroll-behavior scroll-snap-coordinate scroll-snap-destination scroll-snap-points-x scroll-snap-points-y scroll-snap-type scroll-snap-type-x scroll-snap-type-y shape-image-threshold shape-margin shape-outside speak speak-as suffix symbols system table-layout tab-size text-align text-align-last text-combine-upright text-decoration text-decoration-color text-decoration-line text-emphasis text-emphasis-color text-emphasis-position text-emphasis-style text-indent text-orientation text-overflow text-rendering text-shadow text-transform text-underline-position top touch-action transform transform-box transform-origin transform-style transition transition-delay transition-duration transition-property transition-timing-function unicode-bidi unicode-range user-zoom vertical-align visibility voice-balance voice-duration voice-family voice-pitch voice-rate voice-range voice-stress voice-volume white-space widows width will-change word-break word-spacing word-wrap writing-mode z-index zoom")


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
    let line = getline('.')
    let compl_begin = col('.') - 2
    let after = line[compl_begin:]
    let line = b:compl_context
    unlet! b:compl_context
  else
    let line = a:base
    let after = ''
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

    let wide_keywords = ["initial", "inherit", "unset"]
    let color_values = ["transparent", "rgb(", "rgba(", "hsl(", "hsla(", "#"]
    let border_style_values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
    let border_width_values = ["thin", "thick", "medium"]
    let list_style_type_values = ["decimal", "decimal-leading-zero", "arabic-indic", "armenian", "upper-armenian", "lower-armenian", "bengali", "cambodian", "khmer", "cjk-decimal", "devanagari", "georgian", "gujarati", "gurmukhi", "hebrew", "kannada", "lao", "malayalam", "mongolian", "myanmar", "oriya", "persian", "lower-roman", "upper-roman", "tamil", "telugu", "thai", "tibetan", "lower-alpha", "lower-latin", "upper-alpha", "upper-latin", "cjk-earthly-branch", "cjk-heavenly-stem", "lower-greek", "hiragana", "hiragana-iroha", "katakana", "katakana-iroha", "disc", "circle", "square", "disclosure-open", "disclosure-closed"]
    let timing_functions = ["cubic-bezier(", "steps(", "linear", "ease", "ease-in", "ease-in-out", "ease-out", "step-start", "step-end"]

    if prop == 'all'
      let values = []
    elseif prop == 'additive-symbols'
      let values = []
    elseif prop == 'align-content'
      let values = ["flex-start", "flex-end", "center", "space-between", "space-around", "stretch"]
    elseif prop == 'align-items'
      let values = ["flex-start", "flex-end", "center", "baseline", "stretch"]
    elseif prop == 'align-self'
      let values = ["auto", "flex-start", "flex-end", "center", "baseline", "stretch"]
    elseif prop == 'animation'
      let values = timing_functions + ["normal", "reverse", "alternate", "alternate-reverse"] + ["none", "forwards", "backwards", "both"] + ["running", "paused"]
    elseif prop == 'animation-delay'
      let values = []
    elseif prop == 'animation-direction'
      let values = ["normal", "reverse", "alternate", "alternate-reverse"]
    elseif prop == 'animation-duration'
      let values = []
    elseif prop == 'animation-fill-mode'
      let values = ["none", "forwards", "backwards", "both"]
    elseif prop == 'animation-iteration-count'
      let values = []
    elseif prop == 'animation-name'
      let values = []
    elseif prop == 'animation-play-state'
      let values = ["running", "paused"]
    elseif prop == 'animation-timing-function'
      let values = timing_functions
    elseif prop == 'background-attachment'
      let values = ["scroll", "fixed"]
    elseif prop == 'background-color'
      let values = color_values
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
    elseif prop == 'background-size'
      let values = ["auto", "contain", "cover"]
    elseif prop == 'background'
      let values = ["scroll", "fixed"] + color_values + ["url(", "none"] + ["top", "center", "bottom", "left", "right"] + ["repeat", "repeat-x", "repeat-y", "no-repeat"] + ["auto", "contain", "cover"]
    elseif prop =~ 'border\%(-top\|-right\|-bottom\|-left\|-block-start\|-block-end\)\?$'
      let vals = matchstr(line, '.*:\s*\zs.*')
      if vals =~ '^\%([a-zA-Z0-9.]\+\)\?$'
        let values = border_width_values
      elseif vals =~ '^[a-zA-Z0-9.]\+\s\+\%([a-zA-Z]\+\)\?$'
        let values = border_style_values
      elseif vals =~ '^[a-zA-Z0-9.]\+\s\+[a-zA-Z]\+\s\+\%([a-zA-Z(]\+\)\?$'
        let values = color_values
      else
        return []
      endif
    elseif prop =~ 'border-\%(top\|right\|bottom\|left\|block-start\|block-end\)-color'
      let values = color_values
    elseif prop =~ 'border-\%(top\|right\|bottom\|left\|block-start\|block-end\)-style'
      let values = border_style_values
    elseif prop =~ 'border-\%(top\|right\|bottom\|left\|block-start\|block-end\)-width'
      let values = border_width_values
    elseif prop == 'border-color'
      let values = color_values
    elseif prop == 'border-style'
      let values = border_style_values
    elseif prop == 'border-width'
      let values = border_width_values
    elseif prop == 'bottom'
      let values = ["auto"]
    elseif prop == 'box-decoration-break'
      let values = ["slice", "clone"]
    elseif prop == 'box-shadow'
      let values = ["inset"]
    elseif prop == 'box-sizing'
      let values = ["border-box", "content-box"]
    elseif prop =~ 'break-\%(before\|after\)'
      let values = ["auto", "always", "avoid", "left", "right", "page", "column", "region", "recto", "verso", "avoid-page", "avoid-column", "avoid-region"]
    elseif prop == 'break-inside'
      let values = ["auto", "avoid", "avoid-page", "avoid-column", "avoid-region"]
    elseif prop == 'caption-side'
      let values = ["top", "bottom"]
    elseif prop == 'clear'
      let values = ["none", "left", "right", "both"]
    elseif prop == 'clip'
      let values = ["auto", "rect("]
    elseif prop == 'clip-path'
      let values = ["fill-box", "stroke-box", "view-box", "none"]
    elseif prop == 'color'
      let values = color_values
    elseif prop == 'columns'
      let values = []
    elseif prop == 'column-count'
      let values = ['auto']
    elseif prop == 'column-fill'
      let values = ['auto', 'balance']
    elseif prop == 'column-rule-color'
      let values = color_values
    elseif prop == 'column-rule-style'
      let values = border_style_values
    elseif prop == 'column-rule-width'
      let values = border_width_values
    elseif prop == 'column-rule'
      let vals = matchstr(line, '.*:\s*\zs.*')
      if vals =~ '^\%([a-zA-Z0-9.]\+\)\?$'
        let values = border_width_values
      elseif vals =~ '^[a-zA-Z0-9.]\+\s\+\%([a-zA-Z]\+\)\?$'
        let values = border_style_values
      elseif vals =~ '^[a-zA-Z0-9.]\+\s\+[a-zA-Z]\+\s\+\%([a-zA-Z(]\+\)\?$'
        let values = color_values
      else
        return []
      endif
    elseif prop == 'column-span'
      let values = ["none", "all"]
    elseif prop == 'column-width'
      let values = ["auto"]
    elseif prop == 'content'
      let values = ["normal", "attr(", "open-quote", "close-quote", "no-open-quote", "no-close-quote"]
    elseif prop =~ 'counter-\%(increment\|reset\)$'
      let values = ["none"]
    elseif prop =~ 'cue\%(-after\|-before\)\=$'
      let values = ["url("]
    elseif prop == 'cursor'
      let values = ["url(", "auto", "crosshair", "default", "pointer", "move", "e-resize", "ne-resize", "nw-resize", "n-resize", "se-resize", "sw-resize", "s-resize", "w-resize", "text", "wait", "help", "progress"]
    elseif prop == 'direction'
      let values = ["ltr", "rtl"]
    elseif prop == 'display'
      let values = ["inline", "block", "list-item", "inline-list-item", "run-in", "inline-block", "table", "inline-table", "table-row-group", "table-header-group", "table-footer-group", "table-row", "table-column-group", "table-column", "table-cell", "table-caption", "none", "flex", "inline-flex", "grid", "inline-grid", "ruby", "ruby-base", "ruby-text", "ruby-base-container", "ruby-text-container", "contents"]
    elseif prop == 'elevation'
      let values = ["below", "level", "above", "higher", "lower"]
    elseif prop == 'empty-cells'
      let values = ["show", "hide"]
    elseif prop == 'fallback'
      let values = list_style_type_values
    elseif prop == 'filter'
      let values = ["blur(", "brightness(", "contrast(", "drop-shadow(", "grayscale(", "hue-rotate(", "invert(", "opacity(", "sepia(", "saturate("]
    elseif prop == 'flex-basis'
      let values = ["auto", "content"]
    elseif prop == 'flex-flow'
      let values = ["row", "row-reverse", "column", "column-reverse", "nowrap", "wrap", "wrap-reverse"]
    elseif prop == 'flex-grow'
      let values = []
    elseif prop == 'flex-shrink'
      let values = []
    elseif prop == 'flex-wrap'
      let values = ["nowrap", "wrap", "wrap-reverse"]
    elseif prop == 'flex'
      let values = ["nowrap", "wrap", "wrap-reverse"] + ["row", "row-reverse", "column", "column-reverse", "nowrap", "wrap", "wrap-reverse"] + ["auto", "content"]
    elseif prop == 'float'
      let values = ["left", "right", "none"]
    elseif prop == 'font-family'
      let values = ["sans-serif", "serif", "monospace", "cursive", "fantasy"]
    elseif prop == 'font-feature-settings'
      let values = ["normal", '"aalt"', '"abvf"', '"abvm"', '"abvs"', '"afrc"', '"akhn"', '"blwf"', '"blwm"', '"blws"', '"calt"', '"case"', '"ccmp"', '"cfar"', '"cjct"', '"clig"', '"cpct"', '"cpsp"', '"cswh"', '"curs"', '"cv', '"c2pc"', '"c2sc"', '"dist"', '"dlig"', '"dnom"', '"dtls"', '"expt"', '"falt"', '"fin2"', '"fin3"', '"fina"', '"flac"', '"frac"', '"fwid"', '"half"', '"haln"', '"halt"', '"hist"', '"hkna"', '"hlig"', '"hngl"', '"hojo"', '"hwid"', '"init"', '"isol"', '"ital"', '"jalt"', '"jp78"', '"jp83"', '"jp90"', '"jp04"', '"kern"', '"lfbd"', '"liga"', '"ljmo"', '"lnum"', '"locl"', '"ltra"', '"ltrm"', '"mark"', '"med2"', '"medi"', '"mgrk"', '"mkmk"', '"mset"', '"nalt"', '"nlck"', '"nukt"', '"numr"', '"onum"', '"opbd"', '"ordn"', '"ornm"', '"palt"', '"pcap"', '"pkna"', '"pnum"', '"pref"', '"pres"', '"pstf"', '"psts"', '"pwid"', '"qwid"', '"rand"', '"rclt"', '"rkrf"', '"rlig"', '"rphf"', '"rtbd"', '"rtla"', '"rtlm"', '"ruby"', '"salt"', '"sinf"', '"size"', '"smcp"', '"smpl"', '"ss01"', '"ss02"', '"ss03"', '"ss04"', '"ss05"', '"ss06"', '"ss07"', '"ss08"', '"ss09"', '"ss10"', '"ss11"', '"ss12"', '"ss13"', '"ss14"', '"ss15"', '"ss16"', '"ss17"', '"ss18"', '"ss19"', '"ss20"', '"ssty"', '"stch"', '"subs"', '"sups"', '"swsh"', '"titl"', '"tjmo"', '"tnam"', '"tnum"', '"trad"', '"twid"', '"unic"', '"valt"', '"vatu"', '"vert"', '"vhal"', '"vjmo"', '"vkna"', '"vkrn"', '"vpal"', '"vrt2"', '"zero"']
    elseif prop == 'font-kerning'
      let values = ["auto", "normal", "none"]
    elseif prop == 'font-language-override'
      let values = ["normal"]
    elseif prop == 'font-size'
      let values = ["xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large", "larger", "smaller"]
    elseif prop == 'font-size-adjust'
      let values = []
    elseif prop == 'font-stretch'
      let values = ["normal", "ultra-condensed", "extra-condensed", "condensed", "semi-condensed", "semi-expanded", "expanded", "extra-expanded", "ultra-expanded"]
    elseif prop == 'font-style'
      let values = ["normal", "italic", "oblique"]
    elseif prop == 'font-synthesis'
      let values = ["none", "weight", "style"]
    elseif prop == 'font-variant-alternates'
      let values = ["normal", "historical-forms", "stylistic(", "styleset(", "character-variant(", "swash(", "ornaments(", "annotation("]
    elseif prop == 'font-variant-caps'
      let values = ["normal", "small-caps", "all-small-caps", "petite-caps", "all-petite-caps", "unicase", "titling-caps"]
    elseif prop == 'font-variant-asian'
      let values = ["normal", "ruby", "jis78", "jis83", "jis90", "jis04", "simplified", "traditional"]
    elseif prop == 'font-variant-ligatures'
      let values = ["normal", "none", "common-ligatures", "no-common-ligatures", "discretionary-ligatures", "no-discretionary-ligatures", "historical-ligatures", "no-historical-ligatures", "contextual", "no-contextual"]
    elseif prop == 'font-variant-numeric'
      let values = ["normal", "ordinal", "slashed-zero", "lining-nums", "oldstyle-nums", "proportional-nums", "tabular-nums", "diagonal-fractions", "stacked-fractions"]
    elseif prop == 'font-variant-position'
      let values = ["normal", "sub", "super"]
    elseif prop == 'font-variant'
      let values = ["normal", "historical-forms", "stylistic(", "styleset(", "character-variant(", "swash(", "ornaments(", "annotation("] + ["small-caps", "all-small-caps", "petite-caps", "all-petite-caps", "unicase", "titling-caps"] + ["ruby", "jis78", "jis83", "jis90", "jis04", "simplified", "traditional"] + ["none", "common-ligatures", "no-common-ligatures", "discretionary-ligatures", "no-discretionary-ligatures", "historical-ligatures", "no-historical-ligatures", "contextual", "no-contextual"] + ["ordinal", "slashed-zero", "lining-nums", "oldstyle-nums", "proportional-nums", "tabular-nums", "diagonal-fractions", "stacked-fractions"] + ["sub", "super"]
    elseif prop == 'font-weight'
      let values = ["normal", "bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900"]
    elseif prop == 'font'
      let values = ["normal", "italic", "oblique", "small-caps", "bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900", "xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large", "larger", "smaller", "sans-serif", "serif", "monospace", "cursive", "fantasy", "caption", "icon", "menu", "message-box", "small-caption", "status-bar"]
    elseif prop =~ '^\%(height\|width\)$'
      let values = ["auto", "border-box", "content-box", "max-content", "min-content", "available", "fit-content"]
    elseif prop =~ '^\%(left\|right\)$'
      let values = ["auto"]
    elseif prop == 'image-rendering'
      let values = ["auto", "crisp-edges", "pixelated"]
    elseif prop == 'image-orientation'
      let values = ["from-image", "flip"]
    elseif prop == 'ime-mode'
      let values = ["auto", "normal", "active", "inactive", "disabled"]
    elseif prop == 'inline-size'
      let values = ["auto", "border-box", "content-box", "max-content", "min-content", "available", "fit-content"]
    elseif prop == 'isolation'
      let values = ["auto", "isolate"]
    elseif prop == 'justify-content'
      let values = ["flex-start", "flex-end", "center", "space-between", "space-around"]
    elseif prop == 'letter-spacing'
      let values = ["normal"]
    elseif prop == 'line-break'
      let values = ["auto", "loose", "normal", "strict"]
    elseif prop == 'line-height'
      let values = ["normal"]
    elseif prop == 'list-style-image'
      let values = ["url(", "none"]
    elseif prop == 'list-style-position'
      let values = ["inside", "outside"]
    elseif prop == 'list-style-type'
      let values = list_style_type_values
    elseif prop == 'list-style'
      let values = list_style_type_values + ["inside", "outside"] + ["url(", "none"]
    elseif prop == 'margin'
      let values = ["auto"]
    elseif prop =~ 'margin-\%(right\|left\|top\|bottom\|block-start\|block-end\|inline-start\|inline-end\)$'
      let values = ["auto"]
    elseif prop == 'marks'
      let values = ["crop", "cross", "none"]
    elseif prop == 'mask'
      let values = ["url("]
    elseif prop == 'mask-type'
      let values = ["luminance", "alpha"]
    elseif prop == '\%(max\|min\)-\%(block\|inline\)-size'
      let values = ["auto", "border-box", "content-box", "max-content", "min-content", "available", "fit-content"]
    elseif prop == '\%(max\|min\)-\%(height\|width\)'
      let values = ["auto", "border-box", "content-box", "max-content", "min-content", "available", "fit-content"]
    elseif prop == '\%(max\|min\)-zoom'
      let values = ["auto"]
    elseif prop == 'mix-blend-mode'
      let values = ["normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity"]
    elseif prop == 'opacity'
      let values = []
    elseif prop == 'orientation'
      let values = ["auto", "portrait", "landscape"]
    elseif prop == 'orphans'
      let values = []
    elseif prop == 'outline-offset'
      let values = []
    elseif prop == 'outline-color'
      let values = color_values
    elseif prop == 'outline-style'
      let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
    elseif prop == 'outline-width'
      let values = ["thin", "thick", "medium"]
    elseif prop == 'outline'
      let vals = matchstr(line, '.*:\s*\zs.*')
      if vals =~ '^\%([a-zA-Z0-9,()#]\+\)\?$'
        let values = color_values
      elseif vals =~ '^[a-zA-Z0-9,()#]\+\s\+\%([a-zA-Z]\+\)\?$'
        let values = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
      elseif vals =~ '^[a-zA-Z0-9,()#]\+\s\+[a-zA-Z]\+\s\+\%([a-zA-Z(]\+\)\?$'
        let values = ["thin", "thick", "medium"]
      else
        return []
      endif
    elseif prop == 'overflow-wrap'
      let values = ["normal", "break-word"]
    elseif prop =~ 'overflow\%(-x\|-y\)\='
      let values = ["visible", "hidden", "scroll", "auto"]
    elseif prop == 'pad'
      let values = []
    elseif prop == 'padding'
      let values = []
    elseif prop =~ 'padding-\%(top\|right\|bottom\|left\|inline-start\|inline-end\|block-start\|block-end\)$'
      let values = []
    elseif prop =~ 'page-break-\%(after\|before\)$'
      let values = ["auto", "always", "avoid", "left", "right", "recto", "verso"]
    elseif prop == 'page-break-inside'
      let values = ["auto", "avoid"]
    elseif prop =~ 'pause\%(-after\|-before\)\=$'
      let values = ["none", "x-weak", "weak", "medium", "strong", "x-strong"]
    elseif prop == 'perspective'
      let values = ["none"]
    elseif prop == 'perspective-origin'
      let values = ["top", "bottom", "left", "center", " right"]
    elseif prop == 'pointer-events'
      let values = ["auto", "none", "visiblePainted", "visibleFill", "visibleStroke", "visible", "painted", "fill", "stroke", "all"]
    elseif prop == 'position'
      let values = ["static", "relative", "absolute", "fixed", "sticky"]
    elseif prop == 'prefix'
      let values = []
    elseif prop == 'quotes'
      let values = ["none"]
    elseif prop == 'range'
      let values = ["auto", "infinite"]
    elseif prop == 'resize'
      let values = ["none", "both", "horizontal", "vertical"]
    elseif prop =~ 'rest\%(-after\|-before\)\=$'
      let values = ["none", "x-weak", "weak", "medium", "strong", "x-strong"]
    elseif prop == 'ruby-align'
      let values = ["start", "center", "space-between", "space-around"]
    elseif prop == 'ruby-merge'
      let values = ["separate", "collapse", "auto"]
    elseif prop == 'ruby-position'
      let values = ["over", "under", "inter-character"]
    elseif prop == 'scroll-behavior'
      let values = ["auto", "smooth"]
    elseif prop == 'scroll-snap-coordinate'
      let values = ["none"]
    elseif prop == 'scroll-snap-destination'
      return []
    elseif prop == 'scroll-snap-points-\%(x\|y\)$'
      let values = ["none", "repeat("]
    elseif prop == 'scroll-snap-type\%(-x\|-y\)\=$'
      let values = ["none", "mandatory", "proximity"]
    elseif prop == 'shape-image-threshold'
      let values = []
    elseif prop == 'shape-margin'
      let values = []
    elseif prop == 'shape-outside'
      let values = ["margin-box", "border-box", "padding-box", "content-box", 'inset(', 'circle(', 'ellipse(', 'polygon(', 'url(']
    elseif prop == 'speak'
      let values = ["auto", "none", "normal"]
    elseif prop == 'speak-as'
      let values = ["auto", "normal", "spell-out", "digits"]
    elseif prop == 'src'
      let values = ["url("]
    elseif prop == 'suffix'
      let values = []
    elseif prop == 'symbols'
      let values = []
    elseif prop == 'system'
      let vals = matchstr(line, '.*:\s*\zs.*')
      if vals =~ '^extends'
        let values = list_style_type_values
      else
        let values = ["cyclic", "numeric", "alphabetic", "symbolic", "additive", "fixed", "extends"]
      endif
    elseif prop == 'table-layout'
      let values = ["auto", "fixed"]
    elseif prop == 'tab-size'
      let values = []
    elseif prop == 'text-align'
      let values = ["start", "end", "left", "right", "center", "justify", "match-parent"]
    elseif prop == 'text-align-last'
      let values = ["auto", "start", "end", "left", "right", "center", "justify"]
    elseif prop == 'text-combine-upright'
      let values = ["none", "all", "digits"]
    elseif prop == 'text-decoration-line'
      let values = ["none", "underline", "overline", "line-through", "blink"]
    elseif prop == 'text-decoration-color'
      let values = color_values
    elseif prop == 'text-decoration-style'
      let values = ["solid", "double", "dotted", "dashed", "wavy"]
    elseif prop == 'text-decoration'
      let values = ["none", "underline", "overline", "line-through", "blink"] + ["solid", "double", "dotted", "dashed", "wavy"] + color_values
    elseif prop == 'text-emphasis-color'
      let values = color_values
    elseif prop == 'text-emphasis-position'
      let values = ["over", "under", "left", "right"]
    elseif prop == 'text-emphasis-style'
      let values = ["none", "filled", "open", "dot", "circle", "double-circle", "triangle", "sesame"]
    elseif prop == 'text-emphasis'
      let values = color_values + ["over", "under", "left", "right"] + ["none", "filled", "open", "dot", "circle", "double-circle", "triangle", "sesame"]
    elseif prop == 'text-indent'
      let values = ["hanging", "each-line"]
    elseif prop == 'text-orientation'
      let values = ["mixed", "upright", "sideways", "sideways-right", "use-glyph-orientation"]
    elseif prop == 'text-overflow'
      let values = ["clip", "ellipsis"]
    elseif prop == 'text-rendering'
      let values = ["auto", "optimizeSpeed", "optimizeLegibility", "geometricPrecision"]
    elseif prop == 'text-shadow'
      let values = color_values
    elseif prop == 'text-transform'
      let values = ["capitalize", "uppercase", "lowercase", "full-width", "none"]
    elseif prop == 'text-underline-position'
      let values = ["auto", "under", "left", "right"]
    elseif prop == 'touch-action'
      let values = ["auto", "none", "pan-x", "pan-y", "manipulation", "pan-left", "pan-right", "pan-top", "pan-down"]
    elseif prop == 'transform'
      let values = ["matrix(", "translate(", "translateX(", "translateY(", "scale(", "scaleX(", "scaleY(", "rotate(", "skew(", "skewX(", "skewY(", "matrix3d(", "translate3d(", "translateZ(", "scale3d(", "scaleZ(", "rotate3d(", "rotateX(", "rotateY(", "rotateZ(", "perspective("]
    elseif prop == 'transform-box'
      let values = ["border-box", "fill-box", "view-box"]
    elseif prop == 'transform-origin'
      let values = ["left", "center", "right", "top", "bottom"]
    elseif prop == 'transform-style'
      let values = ["flat", "preserve-3d"]
    elseif prop == 'top'
      let values = ["auto"]
    elseif prop == 'transition-property'
      let values = ["all", "none"] + s:values
    elseif prop == 'transition-duration'
      let values = []
    elseif prop == 'transition-delay'
      let values = []
    elseif prop == 'transition-timing-function'
      let values = timing_functions
    elseif prop == 'transition'
      let values = ["all", "none"] + s:values + timing_functions
    elseif prop == 'unicode-bidi'
      let values = ["normal", "embed", "isolate", "bidi-override", "isolate-override", "plaintext"]
    elseif prop == 'unicode-range'
      let values = ["U+"]
    elseif prop == 'user-zoom'
      let values = ["zoom", "fixed"]
    elseif prop == 'vertical-align'
      let values = ["baseline", "sub", "super", "top", "text-top", "middle", "bottom", "text-bottom"]
    elseif prop == 'visibility'
      let values = ["visible", "hidden", "collapse"]
    elseif prop == 'voice-volume'
      let values = ["silent", "x-soft", "soft", "medium", "loud", "x-loud"]
    elseif prop == 'voice-balance'
      let values = ["left", "center", "right", "leftwards", "rightwards"]
    elseif prop == 'voice-family'
      let values = []
    elseif prop == 'voice-rate'
      let values = ["normal", "x-slow", "slow", "medium", "fast", "x-fast"]
    elseif prop == 'voice-pitch'
      let values = ["absolute", "x-low", "low", "medium", "high", "x-high"]
    elseif prop == 'voice-range'
      let values = ["absolute", "x-low", "low", "medium", "high", "x-high"]
    elseif prop == 'voice-stress'
      let values = ["normal", "strong", "moderate", "none", "reduced "]
    elseif prop == 'voice-duration'
      let values = ["auto"]
    elseif prop == 'white-space'
      let values = ["normal", "pre", "nowrap", "pre-wrap", "pre-line"]
    elseif prop == 'widows'
      let values = []
    elseif prop == 'will-change'
      let values = ["auto", "scroll-position", "contents"] + s:values
    elseif prop == 'word-break'
      let values = ["normal", "break-all", "keep-all"]
    elseif prop == 'word-spacing'
      let values = ["normal"]
    elseif prop == 'word-wrap'
      let values = ["normal", "break-word"]
    elseif prop == 'writing-mode'
      let values = ["horizontal-tb", "vertical-rl", "vertical-lr", "sideways-rl", "sideways-lr"]
    elseif prop == 'z-index'
      let values = ["auto"]
    elseif prop == 'zoom'
      let values = ["auto"]
    else
      " If no property match it is possible we are outside of {} and
      " trying to complete pseudo-(class|element)
      let element = tolower(matchstr(line, '\zs[a-zA-Z1-6]*\ze:[^:[:space:]]\{-}$'))
      if stridx('a,abbr,address,area,article,aside,audio,b,base,bdi,bdo,bgsound,blockquote,body,br,button,canvas,caption,center,cite,code,col,colgroup,command,content,data,datalist,dd,del,details,dfn,dialog,div,dl,dt,element,em,embed,fieldset,figcaption,figure,font,footer,form,frame,frameset,head,header,hgroup,hr,html,i,iframe,image,img,input,ins,isindex,kbd,keygen,label,legend,li,link,main,map,mark,menu,menuitem,meta,meter,nav,nobr,noframes,noscript,object,ol,optgroup,option,output,p,param,picture,pre,progress,q,rp,rt,rtc,ruby,s,samp,script,section,select,shadow,small,source,span,strong,style,sub,summary,sup,table,tbody,td,template,textarea,tfoot,th,thead,time,title,tr,track,u,ul,var,video,wbr', ','.element.',') > -1
        let values = ["active", "any", "checked", "default", "dir(", "disabled", "empty", "enabled", "first", "first-child", "first-of-type", "fullscreen", "focus", "hover", "indeterminate", "in-range", "invalid", "lang(", "last-child", "last-of-type", "left", "link", "not(", "nth-child(", "nth-last-child(", "nth-last-of-type(", "nth-of-type(", "only-child", "only-of-type", "optional", "out-of-range", "read-only", "read-write", "required", "right", "root", "scope", "target", "valid", "visited", "first-line", "first-letter", "before", "after", "selection", "backdrop"]
      else
        return []
      endif
    endif

    let values = wide_keywords + values
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
        let entered_atruleafter = matchstr(line, '.*@media\s\+\zs.*$')

        if entered_atruleafter =~ "([^)]*$"
          let entered_atruleafter = matchstr(entered_atruleafter, '(\s*\zs[^)]*$')
          let values = ["max-width", "min-width", "width", "max-height", "min-height", "height", "max-aspect-ration", "min-aspect-ration", "aspect-ratio", "orientation", "max-resolution", "min-resolution", "resolution", "scan", "grid", "update-frequency", "overflow-block", "overflow-inline", "max-color", "min-color", "color", "max-color-index", "min-color-index", "color-index", "monochrome", "inverted-colors", "pointer", "hover", "any-pointer", "any-hover", "light-level", "scripting"]
        else
          let values = ["screen", "print", "speech", "all", "not", "and", "("]
        endif

      elseif atrulename == 'supports'
        let entered_atruleafter = matchstr(line, '.*@supports\s\+\zs.*$')

        if entered_atruleafter =~ "([^)]*$"
          let entered_atruleafter = matchstr(entered_atruleafter, '(\s*\zs.*$')
          let values = s:values
        else
          let values = ["("]
        endif

      elseif atrulename == 'charset'
        let entered_atruleafter = matchstr(line, '.*@charset\s\+\zs.*$')
        let values = [
          \ '"UTF-8";', '"ANSI_X3.4-1968";', '"ISO_8859-1:1987";', '"ISO_8859-2:1987";', '"ISO_8859-3:1988";', '"ISO_8859-4:1988";', '"ISO_8859-5:1988";', 
          \ '"ISO_8859-6:1987";', '"ISO_8859-7:1987";', '"ISO_8859-8:1988";', '"ISO_8859-9:1989";', '"ISO-8859-10";', '"ISO_6937-2-add";', '"JIS_X0201";', 
          \ '"JIS_Encoding";', '"Shift_JIS";', '"Extended_UNIX_Code_Packed_Format_for_Japanese";', '"Extended_UNIX_Code_Fixed_Width_for_Japanese";',
          \ '"BS_4730";', '"SEN_850200_C";', '"IT";', '"ES";', '"DIN_66003";', '"NS_4551-1";', '"NF_Z_62-010";', '"ISO-10646-UTF-1";', '"ISO_646.basic:1983";',
          \ '"INVARIANT";', '"ISO_646.irv:1983";', '"NATS-SEFI";', '"NATS-SEFI-ADD";', '"NATS-DANO";', '"NATS-DANO-ADD";', '"SEN_850200_B";', '"KS_C_5601-1987";',
          \ '"ISO-2022-KR";', '"EUC-KR";', '"ISO-2022-JP";', '"ISO-2022-JP-2";', '"JIS_C6220-1969-jp";', '"JIS_C6220-1969-ro";', '"PT";', '"greek7-old";', 
          \ '"latin-greek";', '"NF_Z_62-010_(1973)";', '"Latin-greek-1";', '"ISO_5427";', '"JIS_C6226-1978";', '"BS_viewdata";', '"INIS";', '"INIS-8";', 
          \ '"INIS-cyrillic";', '"ISO_5427:1981";', '"ISO_5428:1980";', '"GB_1988-80";', '"GB_2312-80";', '"NS_4551-2";', '"videotex-suppl";', '"PT2";', 
          \ '"ES2";', '"MSZ_7795.3";', '"JIS_C6226-1983";', '"greek7";', '"ASMO_449";', '"iso-ir-90";', '"JIS_C6229-1984-a";', '"JIS_C6229-1984-b";', 
          \ '"JIS_C6229-1984-b-add";', '"JIS_C6229-1984-hand";', '"JIS_C6229-1984-hand-add";', '"JIS_C6229-1984-kana";', '"ISO_2033-1983";', 
          \ '"ANSI_X3.110-1983";', '"T.61-7bit";', '"T.61-8bit";', '"ECMA-cyrillic";', '"CSA_Z243.4-1985-1";', '"CSA_Z243.4-1985-2";', '"CSA_Z243.4-1985-gr";', 
          \ '"ISO_8859-6-E";', '"ISO_8859-6-I";', '"T.101-G2";', '"ISO_8859-8-E";', '"ISO_8859-8-I";', '"CSN_369103";', '"JUS_I.B1.002";', '"IEC_P27-1";', 
          \ '"JUS_I.B1.003-serb";', '"JUS_I.B1.003-mac";', '"greek-ccitt";', '"NC_NC00-10:81";', '"ISO_6937-2-25";', '"GOST_19768-74";', '"ISO_8859-supp";', 
          \ '"ISO_10367-box";', '"latin-lap";', '"JIS_X0212-1990";', '"DS_2089";', '"us-dk";', '"dk-us";', '"KSC5636";', '"UNICODE-1-1-UTF-7";', '"ISO-2022-CN";', 
          \ '"ISO-2022-CN-EXT";', '"ISO-8859-13";', '"ISO-8859-14";', '"ISO-8859-15";', '"ISO-8859-16";', '"GBK";', '"GB18030";', '"OSD_EBCDIC_DF04_15";', 
          \ '"OSD_EBCDIC_DF03_IRV";', '"OSD_EBCDIC_DF04_1";', '"ISO-11548-1";', '"KZ-1048";', '"ISO-10646-UCS-2";', '"ISO-10646-UCS-4";', '"ISO-10646-UCS-Basic";',
          \ '"ISO-10646-Unicode-Latin1";', '"ISO-10646-J-1";', '"ISO-Unicode-IBM-1261";', '"ISO-Unicode-IBM-1268";', '"ISO-Unicode-IBM-1276";', 
          \ '"ISO-Unicode-IBM-1264";', '"ISO-Unicode-IBM-1265";', '"UNICODE-1-1";', '"SCSU";', '"UTF-7";', '"UTF-16BE";', '"UTF-16LE";', '"UTF-16";', '"CESU-8";', 
          \ '"UTF-32";', '"UTF-32BE";', '"UTF-32LE";', '"BOCU-1";', '"ISO-8859-1-Windows-3.0-Latin-1";', '"ISO-8859-1-Windows-3.1-Latin-1";', 
          \ '"ISO-8859-2-Windows-Latin-2";', '"ISO-8859-9-Windows-Latin-5";', '"hp-roman8";', '"Adobe-Standard-Encoding";', '"Ventura-US";', 
          \ '"Ventura-International";', '"DEC-MCS";', '"IBM850";', '"PC8-Danish-Norwegian";', '"IBM862";', '"PC8-Turkish";', '"IBM-Symbols";', '"IBM-Thai";', 
          \ '"HP-Legal";', '"HP-Pi-font";', '"HP-Math8";', '"Adobe-Symbol-Encoding";', '"HP-DeskTop";', '"Ventura-Math";', '"Microsoft-Publishing";', 
          \ '"Windows-31J";', '"GB2312";', '"Big5";', '"macintosh";', '"IBM037";', '"IBM038";', '"IBM273";', '"IBM274";', '"IBM275";', '"IBM277";', '"IBM278";', 
          \ '"IBM280";', '"IBM281";', '"IBM284";', '"IBM285";', '"IBM290";', '"IBM297";', '"IBM420";', '"IBM423";', '"IBM424";', '"IBM437";', '"IBM500";', '"IBM851";', 
          \ '"IBM852";', '"IBM855";', '"IBM857";', '"IBM860";', '"IBM861";', '"IBM863";', '"IBM864";', '"IBM865";', '"IBM868";', '"IBM869";', '"IBM870";', '"IBM871";', 
          \ '"IBM880";', '"IBM891";', '"IBM903";', '"IBM904";', '"IBM905";', '"IBM918";', '"IBM1026";', '"EBCDIC-AT-DE";', '"EBCDIC-AT-DE-A";', '"EBCDIC-CA-FR";', 
          \ '"EBCDIC-DK-NO";', '"EBCDIC-DK-NO-A";', '"EBCDIC-FI-SE";', '"EBCDIC-FI-SE-A";', '"EBCDIC-FR";', '"EBCDIC-IT";', '"EBCDIC-PT";', '"EBCDIC-ES";', 
          \ '"EBCDIC-ES-A";', '"EBCDIC-ES-S";', '"EBCDIC-UK";', '"EBCDIC-US";', '"UNKNOWN-8BIT";', '"MNEMONIC";', '"MNEM";', '"VISCII";', '"VIQR";', '"KOI8-R";', 
          \ '"HZ-GB-2312";', '"IBM866";', '"IBM775";', '"KOI8-U";', '"IBM00858";', '"IBM00924";', '"IBM01140";', '"IBM01141";', '"IBM01142";', '"IBM01143";', 
          \ '"IBM01144";', '"IBM01145";', '"IBM01146";', '"IBM01147";', '"IBM01148";', '"IBM01149";', '"Big5-HKSCS";', '"IBM1047";', '"PTCP154";', '"Amiga-1251";', 
          \ '"KOI7-switched";', '"BRF";', '"TSCII";', '"windows-1250";', '"windows-1251";', '"windows-1252";', '"windows-1253";', '"windows-1254";', '"windows-1255";', 
          \ '"windows-1256";', '"windows-1257";', '"windows-1258";', '"TIS-620";']

      elseif atrulename == 'namespace'
        let entered_atruleafter = matchstr(line, '.*@namespace\s\+\zs.*$')
        let values = ["url("]

      elseif atrulename == 'document'
        let entered_atruleafter = matchstr(line, '.*@document\s\+\zs.*$')
        let values = ["url(", "url-prefix(", "domain(", "regexp("]

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
          if entered_atruleafter =~? '^"' && m =~? '^"'
            let m = m[1:]
          endif
          if b:after =~? '"' && stridx(m, '"') > -1
            let m = m[0:stridx(m, '"')-1]
          endif 
          call add(res, m)
        elseif m =~? entered_atruleafter
          if m =~? '^"'
            let m = m[1:]
          endif
          call add(res2, m)
        endif
      endfor

      return res + res2

    endif

    let values = ["charset", "page", "media", "import", "font-face", "namespace", "supports", "keyframes", "viewport", "document"]

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
