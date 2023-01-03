" Generated vim file by vim9jit. Please do not edit
let s:PATH = expand("<script>")
let s:LUA_PATH = fnamemodify(s:PATH, ":r") . ".lua"
let s:NVIM_MODULE = luaeval(printf('require("_vim9script").autoload("%s")', s:LUA_PATH))

function! ccomplete#Complete(findstart, abase) abort
 return s:NVIM_MODULE.Complete(a:findstart, a:abase)
endfunction
