-- Test for regexp patterns with multi-byte support, using utf-8.
-- See test_regexp_latin.vim for the non-multi-byte tests.
-- A pattern that gives the expected result produces OK, so that we know it was
-- actually tried.

local n = require('test.functional.testnvim')()

local insert, source = n.insert, n.source
local clear, expect = n.clear, n.expect

describe('regex with multi-byte', function()
  setup(clear)

  it('is working', function()
    insert([[
      Results of test95:]])

    source([=[
      set nomore
      let tl = []

      call add(tl, [2, '[[:alpha:][=a=]]\+', '879 aiaãâaiuvna ', 'aiaãâaiuvna'])
      call add(tl, [2, '[[=a=]]\+', 'ddaãâbcd', 'aãâ'])								" equivalence classes
      call add(tl, [2, '[^ม ]\+', 'มม oijasoifjos ifjoisj f osij j มมมมม abcd', 'oijasoifjos'])
      call add(tl, [2, ' [^ ]\+', 'start มabcdม ', ' มabcdม'])
      call add(tl, [2, '[ม[:alpha:][=a=]]\+', '879 aiaãมâมaiuvna ', 'aiaãมâมaiuvna'])

      call add(tl, [2, '\p\+', 'ìa', 'ìa'])
      call add(tl, [2, '\p*', 'aあ', 'aあ'])

      call add(tl, [2, '\i\+', '&*¨xx ', 'xx'])
      call add(tl, [2, '\f\+', '&*fname ', 'fname'])

      call add(tl, [2, '.ม', 'xม่x yมy', 'yม'])
      call add(tl, [2, '.ม่', 'xม่x yมy', 'xม่'])
      call add(tl, [2, "\u05b9", " x\u05b9 ", "x\u05b9"])
      call add(tl, [2, ".\u05b9", " x\u05b9 ", "x\u05b9"])
      call add(tl, [2, "\u05b9\u05bb", " x\u05b9\u05bb ", "x\u05b9\u05bb"])
      call add(tl, [2, ".\u05b9\u05bb", " x\u05b9\u05bb ", "x\u05b9\u05bb"])
      call add(tl, [2, "\u05bb\u05b9", " x\u05b9\u05bb ", "x\u05b9\u05bb"])
      call add(tl, [2, ".\u05bb\u05b9", " x\u05b9\u05bb ", "x\u05b9\u05bb"])
      call add(tl, [2, "\u05b9", " y\u05bb x\u05b9 ", "x\u05b9"])
      call add(tl, [2, ".\u05b9", " y\u05bb x\u05b9 ", "x\u05b9"])
      call add(tl, [2, "\u05b9", " y\u05bb\u05b9 x\u05b9 ", "y\u05bb\u05b9"])
      call add(tl, [2, ".\u05b9", " y\u05bb\u05b9 x\u05b9 ", "y\u05bb\u05b9"])
      call add(tl, [1, "\u05b9\u05bb", " y\u05b9 x\u05b9\u05bb ", "x\u05b9\u05bb"])
      call add(tl, [2, ".\u05b9\u05bb", " y\u05bb x\u05b9\u05bb ", "x\u05b9\u05bb"])
      call add(tl, [2, "a", "ca\u0300t"])
      call add(tl, [2, "ca", "ca\u0300t"])
      call add(tl, [2, "a\u0300", "ca\u0300t", "a\u0300"])
      call add(tl, [2, 'a\%C', "ca\u0300t", "a\u0300"])
      call add(tl, [2, 'ca\%C', "ca\u0300t", "ca\u0300"])
      call add(tl, [2, 'ca\%Ct', "ca\u0300t", "ca\u0300t"])

      call add(tl, [2, 'ú\Z', 'x'])
      call add(tl, [2, 'יהוה\Z', 'יהוה', 'יהוה'])
      call add(tl, [2, 'יְהוָה\Z', 'יהוה', 'יהוה'])
      call add(tl, [2, 'יהוה\Z', 'יְהוָה', 'יְהוָה'])
      call add(tl, [2, 'יְהוָה\Z', 'יְהוָה', 'יְהוָה'])
      call add(tl, [2, 'יְ\Z', 'וְיַ', 'יַ'])
      call add(tl, [2, "ק\u200d\u05b9x\\Z", "xק\u200d\u05b9xy", "ק\u200d\u05b9x"])
      call add(tl, [2, "ק\u200d\u05b9x\\Z", "xק\u200dxy", "ק\u200dx"])
      call add(tl, [2, "ק\u200dx\\Z", "xק\u200d\u05b9xy", "ק\u200d\u05b9x"])
      call add(tl, [2, "ק\u200dx\\Z", "xק\u200dxy", "ק\u200dx"])
      call add(tl, [2, "\u05b9\\Z", "xyz"])
      call add(tl, [2, "\\Z\u05b9", "xyz"])
      call add(tl, [2, "\u05b9\\Z", "xy\u05b9z", "y\u05b9"])
      call add(tl, [2, "\\Z\u05b9", "xy\u05b9z", "y\u05b9"])
      call add(tl, [1, "\u05b9\\+\\Z", "xy\u05b9z\u05b9 ", "y\u05b9z\u05b9"])
      call add(tl, [1, "\\Z\u05b9\\+", "xy\u05b9z\u05b9 ", "y\u05b9z\u05b9"])

      call add(tl, [2, '[^[=a=]]\+', 'ddaãâbcd', 'dd'])

      for t in tl
        let re = t[0]
        let pat = t[1]
        let text = t[2]
        let matchidx = 3
        for engine in [0, 1, 2]
          if engine == 2 && re == 0 || engine == 1 && re == 1
            continue
          endif
          let &regexpengine = engine
          try
            let l = matchlist(text, pat)
          catch
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", caused an exception: \"' . v:exception . '\"'
          endtry
          if len(l) == 0 && len(t) > matchidx
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", did not match, expected: \"' . t[matchidx] . '\"'
          elseif len(l) > 0 && len(t) == matchidx
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", match: \"' . l[0] . '\", expected no match'
          elseif len(t) > matchidx && l[0] != t[matchidx]
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", match: \"' . l[0] . '\", expected: \"' . t[matchidx] . '\"'
          else
            $put ='OK ' . engine . ' - ' . pat
          endif
          if len(l) > 0
            for i in range(1, 9)
              if len(t) <= matchidx + i
                let e = ''
              else
                let e = t[matchidx + i]
              endif
              if l[i] != e
                $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", submatch ' . i . ': \"' . l[i] . '\", expected: \"' . e . '\"'
              endif
            endfor
            unlet i
          endif
        endfor
      endfor
      unlet t tl e l

      set regexpengine=1 ambiwidth=single
      $put ='eng 1 ambi single: ' . match(\"\u00EC\", '\p')

      set regexpengine=1 ambiwidth=double
      $put ='eng 1 ambi double: ' . match(\"\u00EC\", '\p')

      set regexpengine=2 ambiwidth=single
      $put ='eng 2 ambi single: ' . match(\"\u00EC\", '\p')

      set regexpengine=2 ambiwidth=double
      $put ='eng 2 ambi double: ' . match(\"\u00EC\", '\p')
    ]=])

    -- Assert buffer contents.
    expect([=[
      Results of test95:
      OK 0 - [[:alpha:][=a=]]\+
      OK 1 - [[:alpha:][=a=]]\+
      OK 2 - [[:alpha:][=a=]]\+
      OK 0 - [[=a=]]\+
      OK 1 - [[=a=]]\+
      OK 2 - [[=a=]]\+
      OK 0 - [^ม ]\+
      OK 1 - [^ม ]\+
      OK 2 - [^ม ]\+
      OK 0 -  [^ ]\+
      OK 1 -  [^ ]\+
      OK 2 -  [^ ]\+
      OK 0 - [ม[:alpha:][=a=]]\+
      OK 1 - [ม[:alpha:][=a=]]\+
      OK 2 - [ม[:alpha:][=a=]]\+
      OK 0 - \p\+
      OK 1 - \p\+
      OK 2 - \p\+
      OK 0 - \p*
      OK 1 - \p*
      OK 2 - \p*
      OK 0 - \i\+
      OK 1 - \i\+
      OK 2 - \i\+
      OK 0 - \f\+
      OK 1 - \f\+
      OK 2 - \f\+
      OK 0 - .ม
      OK 1 - .ม
      OK 2 - .ม
      OK 0 - .ม่
      OK 1 - .ม่
      OK 2 - .ม่
      OK 0 - ֹ
      OK 1 - ֹ
      OK 2 - ֹ
      OK 0 - .ֹ
      OK 1 - .ֹ
      OK 2 - .ֹ
      OK 0 - ֹֻ
      OK 1 - ֹֻ
      OK 2 - ֹֻ
      OK 0 - .ֹֻ
      OK 1 - .ֹֻ
      OK 2 - .ֹֻ
      OK 0 - ֹֻ
      OK 1 - ֹֻ
      OK 2 - ֹֻ
      OK 0 - .ֹֻ
      OK 1 - .ֹֻ
      OK 2 - .ֹֻ
      OK 0 - ֹ
      OK 1 - ֹ
      OK 2 - ֹ
      OK 0 - .ֹ
      OK 1 - .ֹ
      OK 2 - .ֹ
      OK 0 - ֹ
      OK 1 - ֹ
      OK 2 - ֹ
      OK 0 - .ֹ
      OK 1 - .ֹ
      OK 2 - .ֹ
      OK 0 - ֹֻ
      OK 2 - ֹֻ
      OK 0 - .ֹֻ
      OK 1 - .ֹֻ
      OK 2 - .ֹֻ
      OK 0 - a
      OK 1 - a
      OK 2 - a
      OK 0 - ca
      OK 1 - ca
      OK 2 - ca
      OK 0 - à
      OK 1 - à
      OK 2 - à
      OK 0 - a\%C
      OK 1 - a\%C
      OK 2 - a\%C
      OK 0 - ca\%C
      OK 1 - ca\%C
      OK 2 - ca\%C
      OK 0 - ca\%Ct
      OK 1 - ca\%Ct
      OK 2 - ca\%Ct
      OK 0 - ú\Z
      OK 1 - ú\Z
      OK 2 - ú\Z
      OK 0 - יהוה\Z
      OK 1 - יהוה\Z
      OK 2 - יהוה\Z
      OK 0 - יְהוָה\Z
      OK 1 - יְהוָה\Z
      OK 2 - יְהוָה\Z
      OK 0 - יהוה\Z
      OK 1 - יהוה\Z
      OK 2 - יהוה\Z
      OK 0 - יְהוָה\Z
      OK 1 - יְהוָה\Z
      OK 2 - יְהוָה\Z
      OK 0 - יְ\Z
      OK 1 - יְ\Z
      OK 2 - יְ\Z
      OK 0 - ק‍ֹx\Z
      OK 1 - ק‍ֹx\Z
      OK 2 - ק‍ֹx\Z
      OK 0 - ק‍ֹx\Z
      OK 1 - ק‍ֹx\Z
      OK 2 - ק‍ֹx\Z
      OK 0 - ק‍x\Z
      OK 1 - ק‍x\Z
      OK 2 - ק‍x\Z
      OK 0 - ק‍x\Z
      OK 1 - ק‍x\Z
      OK 2 - ק‍x\Z
      OK 0 - ֹ\Z
      OK 1 - ֹ\Z
      OK 2 - ֹ\Z
      OK 0 - \Zֹ
      OK 1 - \Zֹ
      OK 2 - \Zֹ
      OK 0 - ֹ\Z
      OK 1 - ֹ\Z
      OK 2 - ֹ\Z
      OK 0 - \Zֹ
      OK 1 - \Zֹ
      OK 2 - \Zֹ
      OK 0 - ֹ\+\Z
      OK 2 - ֹ\+\Z
      OK 0 - \Zֹ\+
      OK 2 - \Zֹ\+
      OK 0 - [^[=a=]]\+
      OK 1 - [^[=a=]]\+
      OK 2 - [^[=a=]]\+
      eng 1 ambi single: 0
      eng 1 ambi double: 0
      eng 2 ambi single: 0
      eng 2 ambi double: 0]=])
  end)
end)
