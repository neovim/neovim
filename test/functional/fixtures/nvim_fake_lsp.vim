func! OnEvent(id, data, event)
  let l:payload = json_decode(a:data[2])

  if has_key(l:payload, "id")
    let l:str = json_encode(luaeval('require("fake_lsp").onEvent(_A)', l:payload))
    call chansend(a:id, "Content-Length: ".strlen(l:str)."\r\n\r\n".l:str)
  endif
endfunc

call stdioopen({'on_stdin': 'OnEvent'})
