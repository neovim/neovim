" Compatibility wrappers for the Lua matchit implementation.

function matchit#Match_wrapper(word, forward, mode) range
  return v:lua.require('nvim.matchit').match_wrapper(a:word, a:forward, a:mode)
endfunction

function matchit#Match_debug()
  return v:lua.require('nvim.matchit').match_debug()
endfunction

function matchit#MultiMatch(spflag, mode)
  return v:lua.require('nvim.matchit').multi_match(a:spflag, a:mode)
endfunction
