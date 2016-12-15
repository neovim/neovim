  func! Afoo()
    let x = 14
    func! s:Abar()
      return x
    endfunc
  endfunc
  call Afoo()
