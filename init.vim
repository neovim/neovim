funct Omni_test(findstart, base)
  if a:findstart
    return col(".") - 1
  endif
  return [#{word: "one", info: "1info"}, #{word: "two", info: "2info"}, #{word: "three"}]
endfunc
set omnifunc=Omni_test
set completeopt=menu,popup

let s:count = 0
funct Set_info()
  let comp_info = complete_info()
  if comp_info['selected'] == 2
    let l:str = s:count == 0 ? "3info" : "4info"
    let s:count = s:count + 1
    call nvim_complete_set(comp_info['selected'], {"info": l:str})
  endif
endfunc
autocmd CompleteChanged * call Set_info()
