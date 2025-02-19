" Generated vim file by vim9jit. Please do not edit
let s:path = expand("<script>")
let s:lua_path = fnamemodify(s:path, ":r") . ".lua"
let s:nvim_module = luaeval('require("_vim9script").autoload(_A)', s:lua_path)

function! ccomplete#Complete(findstart, abase) abort
 return s:nvim_module.Complete(a:findstart, a:abase)
endfunction
