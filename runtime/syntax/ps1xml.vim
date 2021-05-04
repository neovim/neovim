" Vim syntax file
" Language:    Windows PowerShell
" URL:         https://github.com/PProvost/vim-ps1
" Last Change: 2013 Jun 24

if exists("b:current_syntax")
	finish
endif

let s:ps1xml_cpo_save = &cpo
set cpo&vim

doau syntax xml
unlet b:current_syntax

syn case ignore
syn include @ps1xmlScriptBlock <sfile>:p:h/ps1.vim
unlet b:current_syntax

syn region ps1xmlScriptBlock
      \ matchgroup=xmlTag     start="<Script>"
      \ matchgroup=xmlEndTag  end="</Script>"
      \ fold
      \ contains=@ps1xmlScriptBlock
      \ keepend
syn region ps1xmlScriptBlock
      \ matchgroup=xmlTag     start="<ScriptBlock>"
      \ matchgroup=xmlEndTag  end="</ScriptBlock>"
      \ fold
      \ contains=@ps1xmlScriptBlock
      \ keepend
syn region ps1xmlScriptBlock
      \ matchgroup=xmlTag     start="<GetScriptBlock>"
      \ matchgroup=xmlEndTag  end="</GetScriptBlock>"
      \ fold
      \ contains=@ps1xmlScriptBlock
      \ keepend
syn region ps1xmlScriptBlock
      \ matchgroup=xmlTag     start="<SetScriptBlock>"
      \ matchgroup=xmlEndTag  end="</SetScriptBlock>"
      \ fold
      \ contains=@ps1xmlScriptBlock
      \ keepend

syn cluster xmlRegionHook add=ps1xmlScriptBlock

let b:current_syntax = "ps1xml"

let &cpo = s:ps1xml_cpo_save
unlet s:ps1xml_cpo_save

