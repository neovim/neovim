" Vim filetype plugin file
" Language:	Zimbu
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2025 Jun 08
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>
" Note:	Zimbu was the programming language invented by Bram,
"	but it seems to be lost by now

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< cms< ofu< efm< tw< et< sts< sw<"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set completion with CTRL-X CTRL-O to autoloaded function.
if exists('&ofu')
  setlocal ofu=ccomplete#Complete
endif

" Set 'comments' to format dashed lists in comments.
" And to keep Zudocu comment characters.
setlocal comments=sO:#\ -,mO:#\ \ ,exO:#/,s:/*,m:\ ,ex:*/,:#=,:#-,:#%,:#
setlocal commentstring=#\ %s

setlocal errorformat^=%f\ line\ %l\ col\ %c:\ %m,ERROR:\ %m

" When the matchit plugin is loaded, this makes the % command skip parens and
" braces in comments.
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\(^\s*\)\@<=\(MODULE\|CLASS\|INTERFACE\|BITS\|ENUM\|SHARED\|FUNC\|REPLACE\|DEFINE\|PROC\|EQUAL\|MAIN\|IF\|GENERATE_IF\|WHILE\|REPEAT\|WITH\|DO\|FOR\|SWITCH\|TRY\)\>\|{\s*$:\(^\s*\)\@<=\(ELSE\|ELSEIF\|GENERATE_ELSE\|GENERATE_ELSEIF\|CATCH\|FINALLY\)\>:\(^\s*\)\@<=\(}\|\<UNTIL\>\)'
  let b:match_skip = 's:comment\|string\|zimbuchar'
  let b:undo_ftplugin ..= " | unlet! b:match_words b:match_skip"
endif

setlocal tw=78
setlocal et sts=2 sw=2

" Does replace when a dot, space or closing brace is typed.
func! GCUpperDot(what)
  if v:char != ' ' && v:char != "\r" && v:char != "\x1b" && v:char != '.' && v:char != ')' && v:char != '}' && v:char != ','
    " no space or dot after the typed text
    let g:got_char = v:char
    return a:what
  endif
  return GCUpperCommon(a:what)
endfunc

" Does not replace when a dot is typed.
func! GCUpper(what)
  if v:char != ' ' && v:char != "\r" && v:char != "\x1b" && v:char != ')' && v:char != ','
    " no space or other "terminating" character after the typed text
    let g:got_char = v:char
    return a:what
  endif
  return GCUpperCommon(a:what)
endfunc

" Only replaces when a space is typed.
func! GCUpperSpace(what)
  if v:char != ' '
    " no space after the typed text
    let g:got_char = v:char
    return a:what
  endif
  return GCUpperCommon(a:what)
endfunc

func! GCUpperCommon(what)
  let col = col(".") - strlen(a:what)
  if col > 1 && getline('.')[col - 2] != ' '
    " no space before the typed text
    let g:got_char = 999
    return a:what
  endif
  let synName = synIDattr(synID(line("."), col(".") - 2, 1), "name")
  if synName =~ 'Comment\|String\|zimbuCregion\|\<c'
    " inside a comment or C code
    let g:got_char = 777
    return a:what
  endif
    let g:got_char = 1111
  return toupper(a:what)
endfunc

iabbr <buffer> <expr> alias GCUpperSpace("alias")
iabbr <buffer> <expr> arg GCUpperDot("arg")
iabbr <buffer> <expr> break GCUpper("break")
iabbr <buffer> <expr> case GCUpperSpace("case")
iabbr <buffer> <expr> catch GCUpperSpace("catch")
iabbr <buffer> <expr> check GCUpperDot("check")
iabbr <buffer> <expr> class GCUpperSpace("class")
iabbr <buffer> <expr> interface GCUpperSpace("interface")
iabbr <buffer> <expr> implements GCUpperSpace("implements")
iabbr <buffer> <expr> shared GCUpperSpace("shared")
iabbr <buffer> <expr> continue GCUpper("continue")
iabbr <buffer> <expr> default GCUpper("default")
iabbr <buffer> <expr> extends GCUpper("extends")
iabbr <buffer> <expr> do GCUpper("do")
iabbr <buffer> <expr> else GCUpper("else")
iabbr <buffer> <expr> elseif GCUpperSpace("elseif")
iabbr <buffer> <expr> enum GCUpperSpace("enum")
iabbr <buffer> <expr> exit GCUpper("exit")
iabbr <buffer> <expr> false GCUpper("false")
iabbr <buffer> <expr> fail GCUpper("fail")
iabbr <buffer> <expr> finally GCUpper("finally")
iabbr <buffer> <expr> for GCUpperSpace("for")
iabbr <buffer> <expr> func GCUpperSpace("func")
iabbr <buffer> <expr> if GCUpperSpace("if")
iabbr <buffer> <expr> import GCUpperSpace("import")
iabbr <buffer> <expr> in GCUpperSpace("in")
iabbr <buffer> <expr> io GCUpperDot("io")
iabbr <buffer> <expr> main GCUpper("main")
iabbr <buffer> <expr> module GCUpperSpace("module")
iabbr <buffer> <expr> new GCUpper("new")
iabbr <buffer> <expr> nil GCUpper("nil")
iabbr <buffer> <expr> ok GCUpper("ok")
iabbr <buffer> <expr> proc GCUpperSpace("proc")
iabbr <buffer> <expr> proceed GCUpper("proceed")
iabbr <buffer> <expr> return GCUpper("return")
iabbr <buffer> <expr> step GCUpperSpace("step")
iabbr <buffer> <expr> switch GCUpperSpace("switch")
iabbr <buffer> <expr> sys GCUpperDot("sys")
iabbr <buffer> <expr> this GCUpperDot("this")
iabbr <buffer> <expr> throw GCUpperSpace("throw")
iabbr <buffer> <expr> try GCUpper("try")
iabbr <buffer> <expr> to GCUpperSpace("to")
iabbr <buffer> <expr> true GCUpper("true")
iabbr <buffer> <expr> until GCUpperSpace("until")
iabbr <buffer> <expr> while GCUpperSpace("while")
iabbr <buffer> <expr> repeat GCUpper("repeat")

let b:undo_ftplugin ..=
      \ " | iunabbr <buffer> alias" ..
      \ " | iunabbr <buffer> arg" ..
      \ " | iunabbr <buffer> break" ..
      \ " | iunabbr <buffer> case" ..
      \ " | iunabbr <buffer> catch" ..
      \ " | iunabbr <buffer> check" ..
      \ " | iunabbr <buffer> class" ..
      \ " | iunabbr <buffer> interface" ..
      \ " | iunabbr <buffer> implements" ..
      \ " | iunabbr <buffer> shared" ..
      \ " | iunabbr <buffer> continue" ..
      \ " | iunabbr <buffer> default" ..
      \ " | iunabbr <buffer> extends" ..
      \ " | iunabbr <buffer> do" ..
      \ " | iunabbr <buffer> else" ..
      \ " | iunabbr <buffer> elseif" ..
      \ " | iunabbr <buffer> enum" ..
      \ " | iunabbr <buffer> exit" ..
      \ " | iunabbr <buffer> false" ..
      \ " | iunabbr <buffer> fail" ..
      \ " | iunabbr <buffer> finally" ..
      \ " | iunabbr <buffer> for" ..
      \ " | iunabbr <buffer> func" ..
      \ " | iunabbr <buffer> if" ..
      \ " | iunabbr <buffer> import" ..
      \ " | iunabbr <buffer> in" ..
      \ " | iunabbr <buffer> io" ..
      \ " | iunabbr <buffer> main" ..
      \ " | iunabbr <buffer> module" ..
      \ " | iunabbr <buffer> new" ..
      \ " | iunabbr <buffer> nil" ..
      \ " | iunabbr <buffer> ok" ..
      \ " | iunabbr <buffer> proc" ..
      \ " | iunabbr <buffer> proceed" ..
      \ " | iunabbr <buffer> return" ..
      \ " | iunabbr <buffer> step" ..
      \ " | iunabbr <buffer> switch" ..
      \ " | iunabbr <buffer> sys" ..
      \ " | iunabbr <buffer> this" ..
      \ " | iunabbr <buffer> throw" ..
      \ " | iunabbr <buffer> try" ..
      \ " | iunabbr <buffer> to" ..
      \ " | iunabbr <buffer> true" ..
      \ " | iunabbr <buffer> until" ..
      \ " | iunabbr <buffer> while" ..
      \ " | iunabbr <buffer> repeat"

if !exists("no_plugin_maps") && !exists("no_zimbu_maps")
  nnoremap <silent> <buffer> [[ m`:call ZimbuGoStartBlock()<CR>
  nnoremap <silent> <buffer> ]] m`:call ZimbuGoEndBlock()<CR>
  let b:undo_ftplugin ..=
	\ " | silent! exe 'nunmap <buffer> [['" ..
	\ " | silent! exe 'nunmap <buffer> ]]'"
endif

" Using a function makes sure the search pattern is restored
func! ZimbuGoStartBlock()
  ?^\s*\(FUNC\|PROC\|MAIN\|ENUM\|CLASS\|INTERFACE\)\>
endfunc
func! ZimbuGoEndBlock()
  /^\s*\(FUNC\|PROC\|MAIN\|ENUM\|CLASS\|INTERFACE\)\>
endfunc


let &cpo = s:cpo_save
unlet s:cpo_save
