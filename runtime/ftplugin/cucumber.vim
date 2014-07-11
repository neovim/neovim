" Vim filetype plugin
" Language:	Cucumber
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2013 Jun 01

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif
let b:did_ftplugin = 1

let s:keepcpo= &cpo
set cpo&vim

setlocal formatoptions-=t formatoptions+=croql
setlocal comments=:# commentstring=#\ %s
setlocal omnifunc=CucumberComplete

let b:undo_ftplugin = "setl fo< com< cms< ofu<"

let b:cucumber_root = expand('%:p:h:s?.*[\/]\%(features\|stories\)\zs[\/].*??')

if !exists("g:no_plugin_maps") && !exists("g:no_cucumber_maps")
  nnoremap <silent><buffer> <C-]>       :<C-U>exe <SID>jump('edit',v:count)<CR>
  nnoremap <silent><buffer> [<C-D>      :<C-U>exe <SID>jump('edit',v:count)<CR>
  nnoremap <silent><buffer> ]<C-D>      :<C-U>exe <SID>jump('edit',v:count)<CR>
  nnoremap <silent><buffer> <C-W>]      :<C-U>exe <SID>jump('split',v:count)<CR>
  nnoremap <silent><buffer> <C-W><C-]>  :<C-U>exe <SID>jump('split',v:count)<CR>
  nnoremap <silent><buffer> <C-W>d      :<C-U>exe <SID>jump('split',v:count)<CR>
  nnoremap <silent><buffer> <C-W><C-D>  :<C-U>exe <SID>jump('split',v:count)<CR>
  nnoremap <silent><buffer> <C-W>}      :<C-U>exe <SID>jump('pedit',v:count)<CR>
  nnoremap <silent><buffer> [d          :<C-U>exe <SID>jump('pedit',v:count)<CR>
  nnoremap <silent><buffer> ]d          :<C-U>exe <SID>jump('pedit',v:count)<CR>
  let b:undo_ftplugin .=
        \ "|sil! nunmap <buffer> <C-]>" .
        \ "|sil! nunmap <buffer> [<C-D>" .
        \ "|sil! nunmap <buffer> ]<C-D>" .
        \ "|sil! nunmap <buffer> <C-W>]" .
        \ "|sil! nunmap <buffer> <C-W><C-]>" .
        \ "|sil! nunmap <buffer> <C-W>d" .
        \ "|sil! nunmap <buffer> <C-W><C-D>" .
        \ "|sil! nunmap <buffer> <C-W>}" .
        \ "|sil! nunmap <buffer> [d" .
        \ "|sil! nunmap <buffer> ]d"
endif

function! s:jump(command,count)
  let steps = s:steps('.')
  if len(steps) == 0 || len(steps) < a:count
    return 'echoerr "No matching step found"'
  elseif len(steps) > 1 && !a:count
    return 'echoerr "Multiple matching steps found"'
  else
    let c = a:count ? a:count-1 : 0
    return a:command.' +'.steps[c][1].' '.escape(steps[c][0],' %#')
  endif
endfunction

function! s:allsteps()
  let step_pattern = '\C^\s*\K\k*\>\s*(\=\s*\zs\S.\{-\}\ze\s*)\=\s*\%(do\|{\)\s*\%(|[^|]*|\s*\)\=\%($\|#\)'
  let steps = []
  for file in split(glob(b:cucumber_root.'/**/*.rb'),"\n")
    let lines = readfile(file)
    let num = 0
    for line in lines
      let num += 1
      if line =~ step_pattern
        let type = matchstr(line,'\w\+')
        let steps += [[file,num,type,matchstr(line,step_pattern)]]
      endif
    endfor
  endfor
  return steps
endfunction

function! s:steps(lnum)
  let c = match(getline(a:lnum), '\S') + 1
  while synIDattr(synID(a:lnum,c,1),'name') !~# '^$\|Region$'
    let c = c + 1
  endwhile
  let step = matchstr(getline(a:lnum)[c-1 : -1],'^\s*\zs.\{-\}\ze\s*$')
  return filter(s:allsteps(),'s:stepmatch(v:val[3],step)')
endfunction

function! s:stepmatch(receiver,target)
  if a:receiver =~ '^[''"].*[''"]$'
    let pattern = '^'.escape(substitute(a:receiver[1:-2],'$\w\+','(.*)','g'),'/').'$'
  elseif a:receiver =~ '^/.*/$'
    let pattern = a:receiver[1:-2]
  elseif a:receiver =~ '^%r..*.$'
    let pattern = escape(a:receiver[3:-2],'/')
  else
    return 0
  endif
  try
    let vimpattern = substitute(substitute(pattern,'\\\@<!(?:','%(','g'),'\\\@<!\*?','{-}','g')
    if a:target =~# '\v'.vimpattern
      return 1
    endif
  catch
  endtry
  if has("ruby") && pattern !~ '\\\@<!#{'
    ruby VIM.command("return #{if (begin; Kernel.eval('/'+VIM.evaluate('pattern')+'/'); rescue SyntaxError; end) === VIM.evaluate('a:target') then 1 else 0 end}")
  else
    return 0
  endif
endfunction

function! s:bsub(target,pattern,replacement)
  return  substitute(a:target,'\C\\\@<!'.a:pattern,a:replacement,'g')
endfunction

function! CucumberComplete(findstart,base) abort
  let indent = indent('.')
  let group = synIDattr(synID(line('.'),indent+1,1),'name')
  let type = matchstr(group,'\Ccucumber\zs\%(Given\|When\|Then\)')
  let e = matchend(getline('.'),'^\s*\S\+\s')
  if type == '' || col('.') < col('$') || e < 0
    return -1
  endif
  if a:findstart
    return e
  endif
  let steps = []
  for step in s:allsteps()
    if step[2] ==# type
      if step[3] =~ '^[''"]'
        let steps += [step[3][1:-2]]
      elseif step[3] =~ '^/\^.*\$/$'
        let pattern = step[3][2:-3]
        let pattern = substitute(pattern,'\C^(?:|I )','I ','')
        let pattern = s:bsub(pattern,'\\[Sw]','w')
        let pattern = s:bsub(pattern,'\\d','1')
        let pattern = s:bsub(pattern,'\\[sWD]',' ')
        let pattern = s:bsub(pattern,'\[\^\\\="\]','_')
        let pattern = s:bsub(pattern,'[[:alnum:]. _-][?*]?\=','')
        let pattern = s:bsub(pattern,'\[\([^^]\).\{-\}\]','\1')
        let pattern = s:bsub(pattern,'+?\=','')
        let pattern = s:bsub(pattern,'(\([[:alnum:]. -]\{-\}\))','\1')
        let pattern = s:bsub(pattern,'\\\([[:punct:]]\)','\1')
        if pattern !~ '[\\()*?]'
          let steps += [pattern]
        endif
      endif
    endif
  endfor
  call filter(steps,'strpart(v:val,0,strlen(a:base)) ==# a:base')
  return sort(steps)
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:set sts=2 sw=2:
