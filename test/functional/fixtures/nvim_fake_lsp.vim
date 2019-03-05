func! OnEvent(id, data, event)
  let l:payload = json_decode(a:data[2])
  
  if l:payload['method'] ==# "meta/setResponses"
    let l:response = luaeval('require("fake_lsp").setResponses(_A)', l:payload)
    "let l:response.result = v:null
    "let l:response = { 'jsonrpc': '2.0', 'id': l:payload['id'], 'result': { 'a': 'b'} }
    let l:str = json_encode(l:response)
    call chansend(a:id, "Content-Length: ".strlen(l:str)."\r\n\r\n".l:str)
  elseif has_key(l:payload, "id")
    let l:str = json_encode(luaeval('require("fake_lsp").onEvent(_A)', l:payload))
    call chansend(a:id, "Content-Length: ".strlen(l:str)."\r\n\r\n".l:str)
  endif
endfunc

set rtp+=./runtime
call stdioopen({'on_stdin': 'OnEvent'})
