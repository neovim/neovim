" Runs the specified healthchecks.
" Runs all discovered healthchecks if a:plugin_names is empty.
function! health#check(plugin_names) abort
  let healthchecks = empty(a:plugin_names)
        \ ? s:discover_healthchecks()
        \ : s:get_healthcheck(a:plugin_names)

  " Create buffer and open in a tab, unless this is the default buffer when Nvim starts.
  let emptybuf = (bufnr('$') == 1 && empty(getline(1)) && 1 == line('$'))
  execute (emptybuf ? 'buffer' : 'tab sbuffer') nvim_create_buf(v:true, v:true)
  if bufexists('health://')
    bwipe health://
  endif
  file health://
  setfiletype checkhealth

  if empty(healthchecks)
    call setline(1, 'ERROR: No healthchecks found.')
  else
    redraw|echo 'Running healthchecks...'
    for name in sort(keys(healthchecks))
      let [func, type] = healthchecks[name]
      let s:output = []
      try
        if func == ''
          throw 'healthcheck_not_found'
        endif
        eval type == 'v' ? call(func, []) : luaeval(func)
        " in the event the healthcheck doesn't return anything
        " (the plugin author should avoid this possibility)
        if len(s:output) == 0
          throw 'healthcheck_no_return_value'
        endif
      catch
        let s:output = []  " Clear the output
        if v:exception =~# 'healthcheck_not_found'
          call health#report_error('No healthcheck found for "'.name.'" plugin.')
        elseif v:exception =~# 'healthcheck_no_return_value'
          call health#report_error('The healthcheck report for "'.name.'" plugin is empty.')
        else
          call health#report_error(printf(
                \ "Failed to run healthcheck for \"%s\" plugin. Exception:\n%s\n%s",
                \ name, v:throwpoint, v:exception))
        endif
      endtry
      let header = [repeat('=', 78), name .. ': ' .. func, '']
      " remove empty line after header from report_start
      let s:output = s:output[0] == '' ? s:output[1:] : s:output
      let s:output = header + s:output + ['']
      call append('$', s:output)
      redraw
    endfor
  endif

  " Clear the 'Running healthchecks...' message.
  redraw|echo ''
endfunction

function! s:collect_output(output)
  let s:output += split(a:output, "\n", 1)
endfunction

" Starts a new report.
function! health#report_start(name) abort
  call s:collect_output(printf("\n%s ~", a:name))
endfunction

" Indents lines *except* line 1 of a string if it contains newlines.
function! s:indent_after_line1(s, columns) abort
  let lines = split(a:s, "\n", 0)
  if len(lines) < 2  " We do not indent line 1, so nothing to do.
    return a:s
  endif
  for i in range(1, len(lines)-1)  " Indent lines after the first.
    let lines[i] = substitute(lines[i], '^\s*', repeat(' ', a:columns), 'g')
  endfor
  return join(lines, "\n")
endfunction

" Changes ':h clipboard' to ':help |clipboard|'.
function! s:help_to_link(s) abort
  return substitute(a:s, '\v:h%[elp] ([^|][^"\r\n ]+)', ':help |\1|', 'g')
endfunction

" Format a message for a specific report item.
" a:1: Optional advice (string or list)
function! s:format_report_message(status, msg, ...) abort " {{{
  let output = '- ' .. a:status .. (empty(a:status) ? '' : ' ') .. s:indent_after_line1(a:msg, 2)

  " Optional parameters
  if a:0 > 0
    let advice = type(a:1) == type('') ? [a:1] : a:1
    if type(advice) != type([])
      throw 'a:1: expected String or List'
    endif

    " Report each suggestion
    if !empty(advice)
      let output .= "\n  - ADVICE:"
      for suggestion in advice
        let output .= "\n    - " . s:indent_after_line1(suggestion, 6)
      endfor
    endif
  endif

  return s:help_to_link(output)
endfunction " }}}

" Reports a message as a listitem in the current section.
function! health#report_info(msg) abort " {{{
  call s:collect_output(s:format_report_message('', a:msg))
endfunction " }}}

" Reports a successful healthcheck.
function! health#report_ok(msg) abort " {{{
  call s:collect_output(s:format_report_message('OK', a:msg))
endfunction " }}}

" Reports a health warning.
" a:1: Optional advice (string or list)
function! health#report_warn(msg, ...) abort " {{{
  if a:0 > 0
    call s:collect_output(s:format_report_message('WARNING', a:msg, a:1))
  else
    call s:collect_output(s:format_report_message('WARNING', a:msg))
  endif
endfunction " }}}

" Reports a failed healthcheck.
" a:1: Optional advice (string or list)
function! health#report_error(msg, ...) abort " {{{
  if a:0 > 0
    call s:collect_output(s:format_report_message('ERROR', a:msg, a:1))
  else
    call s:collect_output(s:format_report_message('ERROR', a:msg))
  endif
endfunction " }}}

" From a path return a list [{name}, {func}, {type}] representing a healthcheck
function! s:filepath_to_healthcheck(path) abort
  if a:path =~# 'vim$'
    let name =  matchstr(a:path, '\zs[^\/]*\ze\.vim$')
    let func = 'health#'.name.'#check'
    let type = 'v'
  else
   let base_path = substitute(a:path,
         \ '.*lua[\/]\(.\{-}\)[\/]health\([\/]init\)\?\.lua$',
         \ '\1', '')
   let name = substitute(base_path, '[\/]', '.', 'g')
   let func = 'require("'.name.'.health").check()'
   let type = 'l'
 endif
  return [name, func, type]
endfunction

function! s:discover_healthchecks() abort
  return s:get_healthcheck('*')
endfunction

" Returns Dictionary {name: [func, type], ..} representing healthchecks
function! s:get_healthcheck(plugin_names) abort
  let health_list = s:get_healthcheck_list(a:plugin_names)
  let healthchecks = {}
  for c in health_list
    let normalized_name = substitute(c[0], '-', '_', 'g')
    let existent = get(healthchecks, normalized_name, [])
    " Prefer Lua over vim entries
    if existent != [] && existent[2] == 'l'
      continue
    else
      let healthchecks[normalized_name] = c
    endif
  endfor
  let output = {}
  for v in values(healthchecks)
    let output[v[0]] = v[1:]
  endfor
  try
    " vim.health is not a healthcheck, skip it
    call remove(output, 'vim')
  catch
  endtry
  return output
endfunction

" Returns list of lists [ [{name}, {func}, {type}] ] representing healthchecks
function! s:get_healthcheck_list(plugin_names) abort
  let healthchecks = []
  let plugin_names = type('') == type(a:plugin_names)
        \ ? split(a:plugin_names, ' ', v:false)
        \ : a:plugin_names
  for p in plugin_names
    " support vim/lsp/health{/init/}.lua as :checkhealth vim.lsp
    let p = substitute(p, '\.', '/', 'g')
    let p = substitute(p, '*$', '**', 'g')  " find all submodule e.g vim*
    let paths = nvim_get_runtime_file('autoload/health/'.p.'.vim', v:true)
          \ + nvim_get_runtime_file('lua/**/'.p.'/health/init.lua', v:true)
          \ + nvim_get_runtime_file('lua/**/'.p.'/health.lua', v:true)
    if len(paths) == 0
      let healthchecks += [[p, '', '']]  " healthcheck not found
    else
      let healthchecks += map(uniq(sort(paths)),
            \'<SID>filepath_to_healthcheck(v:val)')
    end
  endfor
  return healthchecks
endfunction
