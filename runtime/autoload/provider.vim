" Common functionality for providers

let s:stderr = {}

function! provider#stderr_collector(chan_id, data, event) dict
   let stderr = get(s:stderr, a:chan_id, [''])
   let stderr[-1] .= a:data[0]
   call extend(stderr, a:data[1:])
   let s:stderr[a:chan_id] = stderr
endfunction

function! provider#clear_stderr(chan_id)
   silent! call delete(s:stderr, a:chan_id)
endfunction

function! provider#get_stderr(chan_id)
   return get(s:stderr, a:chan_id, [])
endfunction
