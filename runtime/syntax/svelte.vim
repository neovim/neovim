" Vim syntax file
" Language: Svelte
" Maintainer: 231tr0n
" Last Change: 2026 Sep 03

" Quit if a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" Svelte is HTML-ish markup with embedded { } expressions, CSS and
" JavaScript/TypeScript.  Rather than reusing html.vim's keyword-based tag and
" attribute lists (which would also make <class>/<style> keywords that shadow
" the class:/style: directives), the markup below is defined generically with
" matches, like typescriptreact.vim does for TSX.

" Embedded scripting languages: JavaScript for <script>, TypeScript for
" <script lang="ts"> and CSS for <style>.  Defining them here makes the file
" self-contained; nothing is pulled in from html.vim.
" TypeScript must be included before JavaScript: the include scripts set
" b:current_syntax and bail out early when it is already set, so clear it
" after each include.
syntax include @svelteTypeScript syntax/typescript.vim
unlet! b:current_syntax
syntax include @svelteJavaScript syntax/javascript.vim
unlet! b:current_syntax
syntax include @svelteCSS syntax/css.vim
unlet! b:current_syntax

" Generic markup: tags, end tags, attribute names, values and strings.  The
" tag and attribute name groups are matches, not keywords, so they never
" shadow the svelteDirective (which is longer and therefore wins).
syntax region svelteTag start=+<[^/!?]+ end=+>+ fold
      \ contains=svelteTagN,svelteString,svelteArg,svelteValue,svelteComponent
syntax region svelteEndTag start=+</+ end=+>+ fold
      \ contains=svelteTagN
syntax match svelteTagN contained +<\s*[-a-zA-Z0-9]\++hs=s+1
      \ contains=svelteTagName
syntax match svelteTagN contained +</\s*[-a-zA-Z0-9]\++hs=s+2
      \ contains=svelteTagName
syntax match svelteTagName contained "\%#=1\<[a-zA-Z_][a-zA-Z0-9:_-]*\>"
syntax match svelteArg contained "\%#=1\<[a-zA-Z_][a-zA-Z0-9_-]*\>"
syntax match svelteArg contained "\%#=1\<data-\h\%(\w\|[-.]\)*\>"
syntax match svelteArg contained "\%#=1\<aria-\h\%(\w\|[-.]\)*\>"
syntax match svelteEqual contained "="
syntax match svelteValue contained "=[\t ]*[^'" \t>][^ \t>]*"hs=s+1
syntax region svelteString contained start=+"+ skip=+\\"+ end=+"+ contains=@sveltePreProc
syntax region svelteString contained start=+'+ skip=+\\'+ end=+'+ contains=@sveltePreProc

" <script> holds JavaScript, <script lang="ts"> holds TypeScript and
" <style> holds CSS.  They are defined after the generic tag so that they win
" over svelteTag and the whole region (including its content) is recognized.
syntax region svelteScriptJS matchgroup=svelteScriptTag
      \ start=+<script\>\_[^>]*>+ keepend
      \ end=+</script\_[^>]*>+me=s-1
      \ contains=@svelteJavaScript,sveltePreProc,svelteScriptTag,@sveltePreProc
syntax region svelteScriptTS matchgroup=svelteScriptTag
      \ start=+<script\_[^>]*lang=["']ts["']>+ keepend
      \ end=+</script\_[^>]*>+me=s-1
      \ contains=@svelteTypeScript,sveltePreProc,svelteScriptTag,@sveltePreProc
syntax region svelteStyle matchgroup=svelteStyleTag
      \ start=+<style\>\_[^>]*>+ keepend
      \ end=+</style\_[^>]*>+me=s-1
      \ contains=@svelteCSS,svelteStyleTag,@sveltePreProc

" <script> / <style> opening tags.  These also count as svelteTag so that any
" svelte-specific markup inside the tag is recognized.
syntax region svelteScriptTag contained start=+<script+ end=+>+ fold
      \ contains=svelteTagN,svelteString,svelteArg,svelteValue
syntax region svelteStyleTag contained start=+<style+ end=+>+ fold
      \ contains=svelteTagN,svelteString,svelteArg,svelteValue

" HTML-style comment markers inside <script> / <style> and expression blocks.
syntax match sveltePreProc contained "\%(<!--\|-->\)"

" Svelte special component elements: <svelte:head>, <svelte:window>, ...
syntax match svelteComponent "\v<svelte:(head|body|window|document|options|element|boundary|component|fragment|self)>" containedin=svelteTagN

" Svelte 5 runes (and store auto-subscriptions) inside <script> blocks.
" Also matches dot-notation rune variants: $state.raw, $derived.by,
" $effect.pre, $effect.tracking, $effect.pending, $effect.root, $props.id
syntax match svelteRune "\$\w\+\%(\.\w\+\)\?" containedin=svelteScriptJS,svelteScriptTS

" Interpolation and expressions: { expr }
" Only match inside tags or attribute values, not inside <script> blocks, where
" { are JavaScript block delimiters.
syntax region svelteMustache matchgroup=svelteBraces
      \ start=+\v\{+ end=+\v\}+
      \ containedin=svelteTag,svelteValue,svelteString keepend

" Control-flow and special blocks.  Covers both legacy Svelte and Svelte 5:
"   {#if} {:else} {/if} {#each} {:then} {:catch} {/each}
"   {#await} {#key} {#snippet} {@html} {@const} {@debug} {@render}
syntax region svelteBlock matchgroup=svelteKeyword
      \ start=+\v\{[#/:@]\w*+ end=+\v\}+ containedin=svelteTag,svelteValue keepend

" Element directives:
"   on:click bind:value class:active use:foo transition:fade in:/out:/animate:
"   let:item slot: style:  (modifiers via "|": on:click|once)
syntax match svelteDirective
      \ "\v(on|bind|class|use|transition|in|out|animate|let|slot|style):[a-zA-Z0-9_-]+(\|[a-zA-Z0-9_-]+)*"
      \ containedin=svelteTag contained

highlight default link svelteTag Function
highlight default link svelteEndTag Identifier
highlight default link svelteTagName Statement
highlight default link svelteArg Type
highlight default link svelteEqual NONE
highlight default link svelteValue String
highlight default link svelteString String
highlight default link svelteScriptTag Function
highlight default link svelteStyleTag Function
highlight default link sveltePreProc Comment
highlight default link svelteComponent svelteTagName
highlight default link svelteRune Statement
highlight default link svelteBraces Delimiter
highlight default link svelteKeyword Statement
highlight default link svelteDirective Type

let b:current_syntax = "svelte"
