" Vim syntax file
" Language:	skhd configuration file
" Maintainer:	Kiyoon Kim <https://github.com/kiyoon>
" Last Change:	2025 Jan 22

if exists("b:current_syntax")
  finish
endif

" Comments: whole line from '#'
syn match skhdComment /^\s*#.*/

" Modifiers (shift, ctrl, alt, cmd, fn)
syn keyword skhdModifier
      \ alt lalt ralt
      \ shift lshift rshift
      \ cmd lcmd rcmd
      \ ctrl lctrl rctrl
      \ fn hyper meh
      \ option super
" highlight the '+' and '-' and ':' separators
syn match skhdOperator /->/
syn match skhdOperator /[+:\-;<>,\[\]@~]/

" Hex keycode form: 0x3C etc
syn match skhdKeycode /\v0x[0-9A-Fa-f]+/

" Keys (a–z, digits, function‐keys, arrows…)
syn keyword skhdKey
      \ return tab space backspace escape delete
      \ home end pageup pagedown insert
      \ left right up down
      \ sound_up sound_down mute play previous next rewind fast
      \ brightness_up brightness_down illumination_up illumination_down
syn match skhdKey /\vf([1-9]|1[0-9]|20)\>/
syn match skhdKey /\v\<[A-Za-z0-9]\>/

" The yabai command and its subcommands
syn match skhdCommand /\<yabai\>\|\<open\>/
syn match skhdSubCmd   /\<window\>\|\<space\>\|\<display\>/

" ───────────────────────────────────────────────────────────────────
"  Treat anything after a single “:” (not double‑colon) as bash
" ───────────────────────────────────────────────────────────────────
" load Vim’s built‑in shell rules
syntax include @bash syntax/bash.vim

" After `:` (not `::`) is a bash command, but not when it is preceded by a `\`
syn region skhdBash
      \ matchgroup=skhdOperator
      \ start=/\v(^|[^:])\zs:\s*/
      \ end=/\v\s*$\ze/
      \ skip=/\v\\\s*$/
      \ keepend
      \ contains=@bash

" ────────────────────────────────────────────────────────────────
"  Key‑map group definitions and switches
" ────────────────────────────────────────────────────────────────
" In skhd, you can define groups and assign hotkeys to them as follows:
" 1. Group‑definition lines that start with :: <group>
" 2. Switch operator (<)
" 3. Target group names after the ;

" Lines like `:: default` or `:: passthrough`
"   match the whole thing as a GroupDef, but capture the group name
syn match   skhdGroupDef    /^::\s*\w\+/
syn match   skhdGroupName   /::\s*\zs\w\+/

" The `<` switch token in lines like
"   passthrough < cmd + shift + alt - b ; default
syn match   skhdSwitch      /<\s*/

" The target (or “fall‑through”) group after the semicolon
"   ... ; default
syn match   skhdTargetGroup /;\s*\zs\w\+/


" ------------------------------------------------------------
" Application-specific bindings block: <keysym> [ ... ]
" ------------------------------------------------------------

" The whole block. This avoids grabbing .blacklist by requiring the line be just '[' at end.
syn region skhdProcMapBlock
      \ matchgroup=skhdProcMapDelim
      \ start=/\v\[\s*$/
      \ end=/^\s*\]\s*$/
      \ keepend
      \ transparent
      \ contains=skhdProcMapApp,skhdProcMapWildcard,skhdProcMapUnbind,skhdOperator,skhdComment,skhdBash,skhdString

" App name on the left side:  "Google Chrome" :
syn match skhdProcMapApp /^\s*\zs"[^"]*"\ze\s*:\s*/ contained

" Wildcard entry:  * :
syn match skhdProcMapWildcard /^\s*\zs\*\ze\s*:\s*/ contained

" Unbind operator on the right side:  "App" ~   or   * ~
syn match skhdProcMapUnbind /\v^\s*(\"[^"]*\"|\*)\s*\zs\~\ze\s*$/ contained

syn keyword skhdDirective .load .blacklist
syn match skhdLoadLine /^\s*\.load\>\s\+/ contains=skhdDirective

syn region skhdBlacklistBlock
      \ start=/^\s*\.blacklist\>\s*\[\s*$/
      \ end=/^\s*\]\s*$/
      \ keepend
      \ contains=skhdDirective,skhdComment,skhdString

syn region skhdString start=/"/ skip=/\\"/ end=/"/

" ────────────────────────────────────────────────────────────────
"  Linking to standard Vim highlight groups
" ────────────────────────────────────────────────────────────────
hi def link skhdComment    Comment
hi def link skhdHeadline   Title
hi def link skhdModifier   Keyword
hi def link skhdOperator   Operator
hi def link skhdWildcard     Special
hi def link skhdKey        Identifier
hi def link skhdKeycode      Number
hi def link skhdCommand    Function
hi def link skhdSubCmd     Statement
hi def link skhdGroupDef      Label
hi def link skhdGroupName     Identifier
hi def link skhdSwitch        Operator
hi def link skhdTargetGroup   Type
hi def link skhdString String

hi def link skhdProcMapDelim   Operator
hi def link skhdProcMapApp     Type
hi def link skhdProcMapWildcard Special
hi def link skhdProcMapUnbind  Special

hi def link skhdDirective PreProc

let b:current_syntax = "skhd"
