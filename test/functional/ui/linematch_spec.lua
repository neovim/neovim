local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')

local feed = t.feed
local clear = t.clear
local write_file = t.write_file

describe('Diff mode screen with 3 diffs open', function()
  local fname = 'Xtest-functional-diff-screen-1'
  local fname_2 = fname .. '.2'
  local fname_3 = fname .. '.3'
  local screen

  local reread = function()
    feed(':e<cr><c-w>w:e<cr><c-w>w:e<cr><c-w>w')
  end

  setup(function()
    clear()
    os.remove(fname)
    os.remove(fname_2)
    os.remove(fname_3)
  end)

  teardown(function()
    os.remove(fname)
    os.remove(fname_2)
    os.remove(fname_3)
  end)

  before_each(function()
    clear()
    feed(':set diffopt+=linematch:30<cr>')
    feed(':e ' .. fname .. '<cr>')
    feed(':vnew ' .. fname_2 .. '<cr>')
    feed(':vnew ' .. fname_3 .. '<cr>')
    feed(':windo diffthis<cr>')

    screen = Screen.new(100, 16)
    screen:attach()
    feed('<c-w>=')
    feed(':windo set nu!<cr>')
  end)

  describe(
    'setup the diff screen to look like a merge conflict with 3 files in diff mode',
    function()
      before_each(function()
        local f1 = [[

  common line
      AAA
      AAA
      AAA
      ]]
        local f2 = [[

  common line
  <<<<<<< HEAD
      AAA
      AAA
      AAA
  =======
      BBB
      BBB
      BBB
  >>>>>>> branch1
      ]]
        local f3 = [[

  common line
      BBB
      BBB
      BBB
      ]]

        write_file(fname, f1, false)
        write_file(fname_2, f2, false)
        write_file(fname_3, f3, false)
        reread()
      end)

      it('get from window 1', function()
        feed('1<c-w>w')
        feed(':2,6diffget screen-1.2<cr>')
        screen:expect([[
      {7:  }{8:  1 }^                           │{7:  }{8:  1 }                          │{7:  }{8:  1 }                           |
      {7:  }{8:  2 }common line                │{7:  }{8:  2 }common line               │{7:  }{8:  2 }common line                |
      {7:  }{8:  3 }{4:<<<<<<< HEAD               }│{7:  }{8:  3 }{4:<<<<<<< HEAD              }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  4 }    AAA                    │{7:  }{8:  4 }    AAA                   │{7:  }{8:  3 }    AAA                    |
      {7:  }{8:  5 }    AAA                    │{7:  }{8:  5 }    AAA                   │{7:  }{8:  4 }    AAA                    |
      {7:  }{8:  6 }    AAA                    │{7:  }{8:  6 }    AAA                   │{7:  }{8:  5 }    AAA                    |
      {7:  }{8:  7 }{4:=======                    }│{7:  }{8:  7 }{4:=======                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  8 }{4:    BBB                    }│{7:  }{8:  8 }{4:    BBB                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  9 }{4:    BBB                    }│{7:  }{8:  9 }{4:    BBB                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8: 10 }{4:    BBB                    }│{7:  }{8: 10 }{4:    BBB                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8: 11 }{4:>>>>>>> branch1            }│{7:  }{8: 11 }{4:>>>>>>> branch1           }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8: 12 }                           │{7:  }{8: 12 }                          │{7:  }{8:  6 }                           |
      {1:~                                }│{1:~                               }│{1:~                                }|*2
      {3:<-functional-diff-screen-1.3 [+]  }{2:<est-functional-diff-screen-1.2  Xtest-functional-diff-screen-1   }|
      :2,6diffget screen-1.2                                                                              |
      ]])
      end)

      it('get from window 2', function()
        feed('2<c-w>w')
        feed(':5,7diffget screen-1.3<cr>')
        screen:expect([[
      {7:  }{8:  1 }                           │{7:  }{8:  1 }^                          │{7:  }{8:  1 }                           |
      {7:  }{8:  2 }common line                │{7:  }{8:  2 }common line               │{7:  }{8:  2 }common line                |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  3 }{22:<<<<<<< HEAD              }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  4 }{4:    AAA                   }│{7:  }{8:  3 }{4:    AAA                    }|
      {7:  }{8:  3 }{4:    BBB                    }│{7:  }{8:  5 }{4:    BBB                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  4 }{4:    }{27:BBB}{4:                    }│{7:  }{8:  6 }{4:    }{27:BBB}{4:                   }│{7:  }{8:  4 }{4:    }{27:AAA}{4:                    }|
      {7:  }{8:  5 }{4:    }{27:BBB}{4:                    }│{7:  }{8:  7 }{4:    }{27:BBB}{4:                   }│{7:  }{8:  5 }{4:    }{27:AAA}{4:                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  8 }{22:>>>>>>> branch1           }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  6 }                           │{7:  }{8:  9 }                          │{7:  }{8:  6 }                           |
      {1:~                                }│{1:~                               }│{1:~                                }|*5
      {2:<test-functional-diff-screen-1.3  }{3:<functional-diff-screen-1.2 [+]  }{2:Xtest-functional-diff-screen-1   }|
      :5,7diffget screen-1.3                                                                              |
      ]])
      end)

      it('get from window 3', function()
        feed('3<c-w>w')
        feed(':5,6diffget screen-1.2<cr>')
        screen:expect([[
      {7:  }{8:  1 }                           │{7:  }{8:  1 }                          │{7:  }{8:  1 }^                           |
      {7:  }{8:  2 }common line                │{7:  }{8:  2 }common line               │{7:  }{8:  2 }common line                |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  3 }{22:<<<<<<< HEAD              }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  4 }{4:    AAA                   }│{7:  }{8:  3 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  5 }{4:    AAA                   }│{7:  }{8:  4 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  6 }{4:    AAA                   }│{7:  }{8:  5 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  7 }{4:=======                   }│{7:  }{8:  6 }{4:=======                    }|
      {7:  }{8:  3 }    BBB                    │{7:  }{8:  8 }    BBB                   │{7:  }{8:  7 }    BBB                    |
      {7:  }{8:  4 }    BBB                    │{7:  }{8:  9 }    BBB                   │{7:  }{8:  8 }    BBB                    |
      {7:  }{8:  5 }    BBB                    │{7:  }{8: 10 }    BBB                   │{7:  }{8:  9 }    BBB                    |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8: 11 }{4:>>>>>>> branch1           }│{7:  }{8: 10 }{4:>>>>>>> branch1            }|
      {7:  }{8:  6 }                           │{7:  }{8: 12 }                          │{7:  }{8: 11 }                           |
      {1:~                                }│{1:~                               }│{1:~                                }|*2
      {2:<test-functional-diff-screen-1.3  <est-functional-diff-screen-1.2  }{3:<st-functional-diff-screen-1 [+] }|
      :5,6diffget screen-1.2                                                                              |
      ]])
      end)

      it('put from window 2 - part', function()
        feed('2<c-w>w')
        feed(':6,8diffput screen-1<cr>')
        screen:expect([[
      {7:  }{8:  1 }                           │{7:  }{8:  1 }^                          │{7:  }{8:  1 }                           |
      {7:  }{8:  2 }common line                │{7:  }{8:  2 }common line               │{7:  }{8:  2 }common line                |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  3 }{22:<<<<<<< HEAD              }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  4 }{4:    AAA                   }│{7:  }{8:  3 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  5 }{4:    AAA                   }│{7:  }{8:  4 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  6 }{4:    AAA                   }│{7:  }{8:  5 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  7 }{4:=======                   }│{7:  }{8:  6 }{4:=======                    }|
      {7:  }{8:  3 }{4:    BBB                    }│{7:  }{8:  8 }{4:    BBB                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  4 }{4:    BBB                    }│{7:  }{8:  9 }{4:    BBB                   }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  5 }    BBB                    │{7:  }{8: 10 }    BBB                   │{7:  }{8:  7 }    BBB                    |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8: 11 }{22:>>>>>>> branch1           }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:  6 }                           │{7:  }{8: 12 }                          │{7:  }{8:  8 }                           |
      {1:~                                }│{1:~                               }│{1:~                                }|*2
      {2:<test-functional-diff-screen-1.3  }{3:<est-functional-diff-screen-1.2  }{2:<st-functional-diff-screen-1 [+] }|
      :6,8diffput screen-1                                                                                |
      ]])
      end)
      it('put from window 2 - part to end', function()
        feed('2<c-w>w')
        feed(':6,11diffput screen-1<cr>')
        screen:expect([[
      {7:  }{8:  1 }                           │{7:  }{8:  1 }^                          │{7:  }{8:  1 }                           |
      {7:  }{8:  2 }common line                │{7:  }{8:  2 }common line               │{7:  }{8:  2 }common line                |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  3 }{22:<<<<<<< HEAD              }│{7:  }{8:    }{23:---------------------------}|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  4 }{4:    AAA                   }│{7:  }{8:  3 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  5 }{4:    AAA                   }│{7:  }{8:  4 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  6 }{4:    AAA                   }│{7:  }{8:  5 }{4:    AAA                    }|
      {7:  }{8:    }{23:---------------------------}│{7:  }{8:  7 }{4:=======                   }│{7:  }{8:  6 }{4:=======                    }|
      {7:  }{8:  3 }    BBB                    │{7:  }{8:  8 }    BBB                   │{7:  }{8:  7 }    BBB                    |
      {7:  }{8:  4 }    BBB                    │{7:  }{8:  9 }    BBB                   │{7:  }{8:  8 }    BBB                    |
      {7:  }{8:  5 }    BBB                    │{7:  }{8: 10 }    BBB                   │{7:  }{8:  9 }    BBB                    |
      {7:  }{8:    }{23:---------------------------}│{7:  }{8: 11 }{4:>>>>>>> branch1           }│{7:  }{8: 10 }{4:>>>>>>> branch1            }|
      {7:  }{8:  6 }                           │{7:  }{8: 12 }                          │{7:  }{8: 11 }                           |
      {1:~                                }│{1:~                               }│{1:~                                }|*2
      {2:<test-functional-diff-screen-1.3  }{3:<est-functional-diff-screen-1.2  }{2:<st-functional-diff-screen-1 [+] }|
      :6,11diffput screen-1                                                                               |
      ]])
      end)
    end
  )
end)

describe('Diff mode screen with 2 diffs open', function()
  local fname = 'Xtest-functional-diff-screen-1'
  local fname_2 = fname .. '.2'
  local screen

  local reread = function()
    feed(':e<cr><c-w>w:e<cr><c-w>w:e<cr><c-w>w')
  end

  setup(function()
    clear()
    os.remove(fname)
    os.remove(fname_2)
  end)

  teardown(function()
    os.remove(fname)
    os.remove(fname_2)
  end)

  before_each(function()
    clear()
    feed(':e ' .. fname .. '<cr>')
    feed(':vnew ' .. fname_2 .. '<cr>')
    feed(':windo diffthis<cr>')

    screen = Screen.new(100, 20)
    screen:attach()
    feed('<c-w>=')
    feed(':windo set nu!<cr>')
  end)

  describe('setup a diff with 2 files and set linematch:30', function()
    before_each(function()
      feed(':set diffopt+=linematch:30<cr>')
      local f1 = [[

common line
common line

DEFabc
xyz
xyz
xyz
DEFabc
DEFabc
DEFabc
common line
common line
DEF
common line
DEF
something
      ]]
      local f2 = [[

common line
common line

ABCabc
ABCabc
ABCabc
ABCabc
common line
common line
common line
something
      ]]
      write_file(fname, f1, false)
      write_file(fname_2, f2, false)
      reread()
    end)

    it('get from window 1 from line 5 to 9', function()
      feed('1<c-w>w')
      feed(':5,9diffget<cr>')
      screen:expect([[
      {7:+ }{8:  1 }{13:^+--  7 lines: common line··················}│{7:+ }{8:  1 }{13:+--  7 lines: common line···················}|
      {7:  }{8:  8 }xyz                                        │{7:  }{8:  8 }xyz                                         |
      {7:  }{8:  9 }DEFabc                                     │{7:  }{8:  9 }DEFabc                                      |
      {7:  }{8: 10 }DEFabc                                     │{7:  }{8: 10 }DEFabc                                      |
      {7:  }{8: 11 }DEFabc                                     │{7:  }{8: 11 }DEFabc                                      |
      {7:  }{8: 12 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 13 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 14 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 15 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 16 }                                           │{7:  }{8: 18 }                                            |
      {1:~                                                }│{1:~                                                 }|*6
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :5,9diffget                                                                                         |
      ]])
    end)
    it('get from window 2 from line 5 to 10', function()
      feed('2<c-w>w')
      feed(':5,10diffget<cr>')
      screen:expect([[
      {7:- }{8:  1 }                                           │{7:- }{8:  1 }^                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }ABCabc                                     │{7:  }{8:  5 }ABCabc                                      |
      {7:  }{8:  6 }ABCabc                                     │{7:  }{8:  6 }ABCabc                                      |
      {7:  }{8:  7 }ABCabc                                     │{7:  }{8:  7 }ABCabc                                      |
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8:  8 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8:  9 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 10 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 11 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 13 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 14 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 15 }                                            |
      {1:~                                                }│{1:~                                                 }|*3
      {2:Xtest-functional-diff-screen-1.2                  }{3:Xtest-functional-diff-screen-1 [+]                }|
      :5,10diffget                                                                                        |
      ]])
    end)
    it('get all from window 2', function()
      feed('2<c-w>w')
      feed(':4,17diffget<cr>')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }^                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }ABCabc                                     │{7:  }{8:  5 }ABCabc                                      |
      {7:  }{8:  6 }ABCabc                                     │{7:  }{8:  6 }ABCabc                                      |
      {7:  }{8:  7 }ABCabc                                     │{7:  }{8:  7 }ABCabc                                      |
      {7:  }{8:  8 }ABCabc                                     │{7:  }{8:  8 }ABCabc                                      |
      {7:  }{8:  9 }common line                                │{7:  }{8:  9 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 10 }common line                                 |
      {7:  }{8: 11 }common line                                │{7:  }{8: 11 }common line                                 |
      {7:  }{8: 12 }something                                  │{7:  }{8: 12 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 13 }                                            |
      {1:~                                                }│{1:~                                                 }|*5
      {2:Xtest-functional-diff-screen-1.2                  }{3:Xtest-functional-diff-screen-1 [+]                }|
      :4,17diffget                                                                                        |
      ]])
    end)
    it('get all from window 1', function()
      feed('1<c-w>w')
      feed(':4,12diffget<cr>')
      screen:expect([[
      {7:  }{8:  1 }^                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }DEFabc                                     │{7:  }{8:  5 }DEFabc                                      |
      {7:  }{8:  6 }xyz                                        │{7:  }{8:  6 }xyz                                         |
      {7:  }{8:  7 }xyz                                        │{7:  }{8:  7 }xyz                                         |
      {7:  }{8:  8 }xyz                                        │{7:  }{8:  8 }xyz                                         |
      {7:  }{8:  9 }DEFabc                                     │{7:  }{8:  9 }DEFabc                                      |
      {7:  }{8: 10 }DEFabc                                     │{7:  }{8: 10 }DEFabc                                      |
      {7:  }{8: 11 }DEFabc                                     │{7:  }{8: 11 }DEFabc                                      |
      {7:  }{8: 12 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 13 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8: 14 }DEF                                        │{7:  }{8: 14 }DEF                                         |
      {7:  }{8: 15 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8: 16 }DEF                                        │{7:  }{8: 16 }DEF                                         |
      {7:  }{8: 17 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 18 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :4,12diffget                                                                                        |
      ]])
    end)
    it('get from window 1 using do 1 line 5', function()
      feed('1<c-w>w')
      feed('5gg')
      feed('do')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }^DEFabc                                     │{7:  }{8:  5 }DEFabc                                      |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('get from window 1 using do 2 line 6', function()
      feed('1<c-w>w')
      feed('6gg')
      feed('do')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }^DEFabc                                     │{7:  }{8:  9 }DEFabc                                      |
      {7:  }{8:  7 }DEFabc                                     │{7:  }{8: 10 }DEFabc                                      |
      {7:  }{8:  8 }DEFabc                                     │{7:  }{8: 11 }DEFabc                                      |
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('get from window 1 using do 2 line 7', function()
      feed('1<c-w>w')
      feed('7gg')
      feed('do')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }DEFabc                                     │{7:  }{8:  9 }DEFabc                                      |
      {7:  }{8:  7 }^DEFabc                                     │{7:  }{8: 10 }DEFabc                                      |
      {7:  }{8:  8 }DEFabc                                     │{7:  }{8: 11 }DEFabc                                      |
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('get from window 1 using do 2 line 11', function()
      feed('1<c-w>w')
      feed('11gg')
      feed('do')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8: 11 }DEF                                        │{7:  }{8: 14 }DEF                                         |
      {7:  }{8: 12 }^common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 13 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 14 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('get from window 1 using do 2 line 12', function()
      feed('1<c-w>w')
      feed('12gg')
      feed('do')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8: 12 }DEF                                        │{7:  }{8: 16 }DEF                                         |
      {7:  }{8: 13 }^something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 14 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 1 using dp 1 line 5', function()
      feed('1<c-w>w')
      feed('5gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }^ABCabc                                     │{7:  }{8:  5 }ABCabc                                      |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1 [+]                }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 1 using dp 2 line 6', function()
      feed('1<c-w>w')
      feed('6gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }^ABCabc                                     │{7:  }{8:  9 }ABCabc                                      |
      {7:  }{8:  7 }ABCabc                                     │{7:  }{8: 10 }ABCabc                                      |
      {7:  }{8:  8 }ABCabc                                     │{7:  }{8: 11 }ABCabc                                      |
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1 [+]                }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 1 using dp 2 line 7', function()
      feed('1<c-w>w')
      feed('7gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }ABCabc                                     │{7:  }{8:  9 }ABCabc                                      |
      {7:  }{8:  7 }^ABCabc                                     │{7:  }{8: 10 }ABCabc                                      |
      {7:  }{8:  8 }ABCabc                                     │{7:  }{8: 11 }ABCabc                                      |
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1 [+]                }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 1 using dp 2 line 11', function()
      feed('1<c-w>w')
      feed('11gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8: 11 }^common line                                │{7:  }{8: 14 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 15 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 16 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 17 }                                            |
      {1:~                                                }│{1:~                                                 }|
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1 [+]                }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 1 using dp 2 line 12', function()
      feed('1<c-w>w')
      feed('12gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8: 12 }^something                                  │{7:  }{8: 16 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 17 }                                            |
      {1:~                                                }│{1:~                                                 }|
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1 [+]                }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 2 using dp line 6', function()
      feed('2<c-w>w')
      feed('6gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  6 }xyz                                        │{7:  }{8:  6 }^xyz                                         |
      {7:  }{8:  7 }xyz                                        │{7:  }{8:  7 }xyz                                         |
      {7:  }{8:  8 }xyz                                        │{7:  }{8:  8 }xyz                                         |
      {7:  }{8:  9 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8: 10 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8: 11 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8: 12 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 13 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 14 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 15 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 16 }                                           │{7:  }{8: 18 }                                            |
      {2:Xtest-functional-diff-screen-1.2 [+]              }{3:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 2 using dp line 8', function()
      feed('2<c-w>w')
      feed('8gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  6 }xyz                                        │{7:  }{8:  6 }xyz                                         |
      {7:  }{8:  7 }xyz                                        │{7:  }{8:  7 }xyz                                         |
      {7:  }{8:  8 }xyz                                        │{7:  }{8:  8 }^xyz                                         |
      {7:  }{8:  9 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8: 10 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8: 11 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8: 12 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 13 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 14 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 15 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 16 }                                           │{7:  }{8: 18 }                                            |
      {2:Xtest-functional-diff-screen-1.2 [+]              }{3:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 2 using dp line 9', function()
      feed('2<c-w>w')
      feed('9gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }DEFabc                                     │{7:  }{8:  9 }^DEFabc                                      |
      {7:  }{8:  7 }DEFabc                                     │{7:  }{8: 10 }DEFabc                                      |
      {7:  }{8:  8 }DEFabc                                     │{7:  }{8: 11 }DEFabc                                      |
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 16 }{22:DEF                                         }|
      {7:  }{8: 12 }something                                  │{7:  }{8: 17 }something                                   |
      {7:  }{8: 13 }                                           │{7:  }{8: 18 }                                            |
      {2:Xtest-functional-diff-screen-1.2 [+]              }{3:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
    it('put from window 2 using dp line 17', function()
      feed('2<c-w>w')
      feed('17gg')
      feed('dp')
      screen:expect([[
      {7:  }{8:  1 }                                           │{7:  }{8:  1 }                                            |
      {7:  }{8:  2 }common line                                │{7:  }{8:  2 }common line                                 |
      {7:  }{8:  3 }common line                                │{7:  }{8:  3 }common line                                 |
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {7:  }{8:  5 }{27:ABC}{4:abc                                     }│{7:  }{8:  5 }{27:DEF}{4:abc                                      }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  6 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  7 }{22:xyz                                         }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  8 }{22:xyz                                         }|
      {7:  }{8:  6 }{27:ABC}{4:abc                                     }│{7:  }{8:  9 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  7 }{27:ABC}{4:abc                                     }│{7:  }{8: 10 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  8 }{27:ABC}{4:abc                                     }│{7:  }{8: 11 }{27:DEF}{4:abc                                      }|
      {7:  }{8:  9 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 10 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8: 14 }{22:DEF                                         }|
      {7:  }{8: 11 }common line                                │{7:  }{8: 15 }common line                                 |
      {7:  }{8: 12 }DEF                                        │{7:  }{8: 16 }DEF                                         |
      {7:  }{8: 13 }something                                  │{7:  }{8: 17 }^something                                   |
      {7:  }{8: 14 }                                           │{7:  }{8: 18 }                                            |
      {2:Xtest-functional-diff-screen-1.2 [+]              }{3:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
  end)
  describe('setup a diff with 2 files and set linematch:30', function()
    before_each(function()
      feed(':set diffopt+=linematch:30<cr>')
      local f1 = [[
// abc d
// d
// d
      ]]
      local f2 = [[

abc d
d
      ]]
      write_file(fname, f1, false)
      write_file(fname_2, f2, false)
      reread()
    end)

    it('display results', function()
      screen:expect([[
      {7:  }{8:  1 }{22:^                                           }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  2 }{4:abc d                                      }│{7:  }{8:  1 }{27:// }{4:abc d                                    }|
      {7:  }{8:  3 }{4:d                                          }│{7:  }{8:  2 }{27:// }{4:d                                        }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  3 }{22:// d                                        }|
      {7:  }{8:  4 }                                           │{7:  }{8:  4 }                                            |
      {1:~                                                }│{1:~                                                 }|*13
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
  end)
  describe('setup a diff with 2 files and set linematch:30, with ignore white', function()
    before_each(function()
      feed(':set diffopt+=linematch:30<cr>:set diffopt+=iwhiteall<cr>')
      local f1 = [[
void testFunction () {
  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
    }
  }
}
      ]]
      local f2 = [[
void testFunction () {
  // for (int j = 0; j < 10; i++) {
  // }
}
      ]]
      write_file(fname, f1, false)
      write_file(fname_2, f2, false)
      reread()
    end)

    it('display results', function()
      screen:expect([[
      {7:  }{8:  1 }^void testFunction () {                     │{7:  }{8:  1 }void testFunction () {                      |
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  2 }{22:  for (int i = 0; i < 10; i++) {            }|
      {7:  }{8:  2 }{4:  }{27:// for (int j = 0; j < 10; i}{4:++) {        }│{7:  }{8:  3 }{4:    }{27:for (int j = 0; j < 10; j}{4:++) {          }|
      {7:  }{8:  3 }{4:  }{27:// }{4:}                                     }│{7:  }{8:  4 }{4:    }                                       }|
      {7:  }{8:    }{23:-------------------------------------------}│{7:  }{8:  5 }{22:  }                                         }|
      {7:  }{8:  4 }}                                          │{7:  }{8:  6 }}                                           |
      {7:  }{8:  5 }                                           │{7:  }{8:  7 }                                            |
      {1:~                                                }│{1:~                                                 }|*11
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
  end)
  describe('a diff that would result in multiple groups before grouping optimization', function()
    before_each(function()
      feed(':set diffopt+=linematch:30<cr>')
      local f1 = [[
!A
!B
!C
      ]]
      local f2 = [[
?Z
?A
?B
?C
?A
?B
?B
?C
      ]]
      write_file(fname, f1, false)
      write_file(fname_2, f2, false)
      reread()
    end)

    it('display results', function()
      screen:expect([[
      {7:  }{8:  1 }{22:^?Z                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  2 }{27:?}{4:A                                         }│{7:  }{8:  1 }{27:!}{4:A                                          }|
      {7:  }{8:  3 }{27:?}{4:B                                         }│{7:  }{8:  2 }{27:!}{4:B                                          }|
      {7:  }{8:  4 }{27:?}{4:C                                         }│{7:  }{8:  3 }{27:!}{4:C                                          }|
      {7:  }{8:  5 }{22:?A                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  6 }{22:?B                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  7 }{22:?B                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  8 }{22:?C                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  9 }                                           │{7:  }{8:  4 }                                            |
      {1:~                                                }│{1:~                                                 }|*9
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
  end)
  describe('a diff that would result in multiple groups before grouping optimization', function()
    before_each(function()
      feed(':set diffopt+=linematch:30<cr>')
      local f1 = [[
!A
!B
!C
      ]]
      local f2 = [[
?A
?Z
?B
?C
?A
?B
?C
?C
      ]]
      write_file(fname, f1, false)
      write_file(fname_2, f2, false)
      reread()
    end)

    it('display results', function()
      screen:expect([[
      {7:  }{8:  1 }{22:^?A                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  2 }{22:?Z                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  3 }{22:?B                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  4 }{22:?C                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  5 }{27:?}{4:A                                         }│{7:  }{8:  1 }{27:!}{4:A                                          }|
      {7:  }{8:  6 }{27:?}{4:B                                         }│{7:  }{8:  2 }{27:!}{4:B                                          }|
      {7:  }{8:  7 }{27:?}{4:C                                         }│{7:  }{8:  3 }{27:!}{4:C                                          }|
      {7:  }{8:  8 }{22:?C                                         }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  9 }                                           │{7:  }{8:  4 }                                            |
      {1:~                                                }│{1:~                                                 }|*9
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
    end)
  end)
  describe('setup a diff with 2 files and set linematch:10', function()
    before_each(function()
      feed(':set diffopt+=linematch:10<cr>')
      local f1 = [[
common line
HIL

aABCabc
aABCabc
aABCabc
aABCabc
common line
HIL
common line
something
      ]]
      local f2 = [[
common line
DEF
GHI
something

aDEFabc
xyz
xyz
xyz
aDEFabc
aDEFabc
aDEFabc
common line
DEF
GHI
something else
common line
something
      ]]
      write_file(fname, f1, false)
      write_file(fname_2, f2, false)
      reread()
    end)

    it(
      'enable linematch for the longest diff block by increasing the number argument passed to linematch',
      function()
        feed('1<c-w>w')
        -- linematch is disabled for the longest diff because it's combined line length is over 10
        screen:expect([[
      {7:  }{8:  1 }^common line                                │{7:  }{8:  1 }common line                                 |
      {7:  }{8:  2 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  3 }{27:GHI}{4:                                        }│{7:  }{8:  2 }{27:HIL}{4:                                         }|
      {7:  }{8:  4 }{22:something                                  }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  5 }                                           │{7:  }{8:  3 }                                            |
      {7:  }{8:  6 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  4 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8:  7 }{27:xyz}{4:                                        }│{7:  }{8:  5 }{27:aABCabc}{4:                                     }|
      {7:  }{8:  8 }{27:xyz}{4:                                        }│{7:  }{8:  6 }{27:aABCabc}{4:                                     }|
      {7:  }{8:  9 }{27:xyz}{4:                                        }│{7:  }{8:  7 }{27:aABCabc}{4:                                     }|
      {7:  }{8: 10 }{22:aDEFabc                                    }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 11 }{22:aDEFabc                                    }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 12 }{22:aDEFabc                                    }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 13 }common line                                │{7:  }{8:  8 }common line                                 |
      {7:  }{8: 14 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 15 }{27:GHI}{4:                                        }│{7:  }{8:  9 }{27:HIL}{4:                                         }|
      {7:  }{8: 16 }{22:something else                             }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 17 }common line                                │{7:  }{8: 10 }common line                                 |
      {7:  }{8: 18 }something                                  │{7:  }{8: 11 }something                                   |
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1                    }|
      :e                                                                                                  |
      ]])
        -- enable it by increasing the number
        feed(':set diffopt-=linematch:10<cr>')
        feed(':set diffopt+=linematch:30<cr>')
        screen:expect([[
      {7:  }{8:  1 }^common line                                │{7:  }{8:  1 }common line                                 |
      {7:  }{8:  2 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  3 }{27:GHI}{4:                                        }│{7:  }{8:  2 }{27:HIL}{4:                                         }|
      {7:  }{8:  4 }{22:something                                  }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  5 }                                           │{7:  }{8:  3 }                                            |
      {7:  }{8:  6 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  4 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8:  7 }{22:xyz                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  8 }{22:xyz                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  9 }{22:xyz                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 10 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  5 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8: 11 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  6 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8: 12 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  7 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8: 13 }common line                                │{7:  }{8:  8 }common line                                 |
      {7:  }{8: 14 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 15 }{27:GHI}{4:                                        }│{7:  }{8:  9 }{27:HIL}{4:                                         }|
      {7:  }{8: 16 }{22:something else                             }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 17 }common line                                │{7:  }{8: 10 }common line                                 |
      {7:  }{8: 18 }something                                  │{7:  }{8: 11 }something                                   |
      {3:Xtest-functional-diff-screen-1.2                  }{2:Xtest-functional-diff-screen-1                    }|
      :set diffopt+=linematch:30                                                                          |
      ]])
      end
    )
    it('get all from second window', function()
      feed('2<c-w>w')
      feed(':1,12diffget<cr>')
      screen:expect([[
      {7:  }{8:  1 }common line                                │{7:  }{8:  1 }^common line                                 |
      {7:  }{8:  2 }DEF                                        │{7:  }{8:  2 }DEF                                         |
      {7:  }{8:  3 }GHI                                        │{7:  }{8:  3 }GHI                                         |
      {7:  }{8:  4 }something                                  │{7:  }{8:  4 }something                                   |
      {7:  }{8:  5 }                                           │{7:  }{8:  5 }                                            |
      {7:  }{8:  6 }aDEFabc                                    │{7:  }{8:  6 }aDEFabc                                     |
      {7:  }{8:  7 }xyz                                        │{7:  }{8:  7 }xyz                                         |
      {7:  }{8:  8 }xyz                                        │{7:  }{8:  8 }xyz                                         |
      {7:  }{8:  9 }xyz                                        │{7:  }{8:  9 }xyz                                         |
      {7:  }{8: 10 }aDEFabc                                    │{7:  }{8: 10 }aDEFabc                                     |
      {7:  }{8: 11 }aDEFabc                                    │{7:  }{8: 11 }aDEFabc                                     |
      {7:  }{8: 12 }aDEFabc                                    │{7:  }{8: 12 }aDEFabc                                     |
      {7:  }{8: 13 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8: 14 }DEF                                        │{7:  }{8: 14 }DEF                                         |
      {7:  }{8: 15 }GHI                                        │{7:  }{8: 15 }GHI                                         |
      {7:  }{8: 16 }something else                             │{7:  }{8: 16 }something else                              |
      {7:  }{8: 17 }common line                                │{7:  }{8: 17 }common line                                 |
      {7:  }{8: 18 }something                                  │{7:  }{8: 18 }something                                   |
      {2:Xtest-functional-diff-screen-1.2                  }{3:Xtest-functional-diff-screen-1 [+]                }|
      :1,12diffget                                                                                        |
      ]])
    end)
    it('get all from first window', function()
      feed('1<c-w>w')
      feed(':1,19diffget<cr>')
      screen:expect([[
      {7:  }{8:  1 }^common line                                │{7:  }{8:  1 }common line                                 |
      {7:  }{8:  2 }HIL                                        │{7:  }{8:  2 }HIL                                         |
      {7:  }{8:  3 }                                           │{7:  }{8:  3 }                                            |
      {7:  }{8:  4 }aABCabc                                    │{7:  }{8:  4 }aABCabc                                     |
      {7:  }{8:  5 }aABCabc                                    │{7:  }{8:  5 }aABCabc                                     |
      {7:  }{8:  6 }aABCabc                                    │{7:  }{8:  6 }aABCabc                                     |
      {7:  }{8:  7 }aABCabc                                    │{7:  }{8:  7 }aABCabc                                     |
      {7:  }{8:  8 }common line                                │{7:  }{8:  8 }common line                                 |
      {7:  }{8:  9 }HIL                                        │{7:  }{8:  9 }HIL                                         |
      {7:  }{8: 10 }common line                                │{7:  }{8: 10 }common line                                 |
      {7:  }{8: 11 }something                                  │{7:  }{8: 11 }something                                   |
      {7:  }{8: 12 }                                           │{7:  }{8: 12 }                                            |
      {1:~                                                }│{1:~                                                 }|*6
      {3:Xtest-functional-diff-screen-1.2 [+]              }{2:Xtest-functional-diff-screen-1                    }|
      :1,19diffget                                                                                        |
      ]])
    end)
    it(
      'get part of the non linematched diff block in window 2 line 7 - 8 (non line matched block)',
      function()
        feed('2<c-w>w')
        feed(':7,8diffget<cr>')
        screen:expect([[
      {7:  }{8:  1 }common line                                │{7:  }{8:  1 }^common line                                 |
      {7:  }{8:  2 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  3 }{27:GHI}{4:                                        }│{7:  }{8:  2 }{27:HIL}{4:                                         }|
      {7:  }{8:  4 }{22:something                                  }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  5 }                                           │{7:  }{8:  3 }                                            |
      {7:  }{8:  6 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  4 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8:  7 }{27:xyz}{4:                                        }│{7:  }{8:  5 }{27:aABCabc}{4:                                     }|
      {7:  }{8:  8 }{27:xyz}{4:                                        }│{7:  }{8:  6 }{27:aABCabc}{4:                                     }|
      {7:  }{8:  9 }xyz                                        │{7:  }{8:  7 }xyz                                         |
      {7:  }{8: 10 }aDEFabc                                    │{7:  }{8:  8 }aDEFabc                                     |
      {7:  }{8: 11 }aDEFabc                                    │{7:  }{8:  9 }aDEFabc                                     |
      {7:  }{8: 12 }aDEFabc                                    │{7:  }{8: 10 }aDEFabc                                     |
      {7:  }{8: 13 }common line                                │{7:  }{8: 11 }common line                                 |
      {7:  }{8: 14 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 15 }{27:GHI}{4:                                        }│{7:  }{8: 12 }{27:HIL}{4:                                         }|
      {7:  }{8: 16 }{22:something else                             }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 17 }common line                                │{7:  }{8: 13 }common line                                 |
      {7:  }{8: 18 }something                                  │{7:  }{8: 14 }something                                   |
      {2:Xtest-functional-diff-screen-1.2                  }{3:Xtest-functional-diff-screen-1 [+]                }|
      :7,8diffget                                                                                         |
      ]])
      end
    )
    it(
      'get part of the non linematched diff block in window 2 line 8 - 10 (line matched block)',
      function()
        feed('2<c-w>w')
        feed(':8,10diffget<cr>')
        screen:expect([[
      {7:  }{8:  1 }common line                                │{7:  }{8:  1 }^common line                                 |
      {7:  }{8:  2 }{22:DEF                                        }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  3 }{27:GHI}{4:                                        }│{7:  }{8:  2 }{27:HIL}{4:                                         }|
      {7:  }{8:  4 }{22:something                                  }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8:  5 }                                           │{7:  }{8:  3 }                                            |
      {7:  }{8:  6 }{4:a}{27:DEF}{4:abc                                    }│{7:  }{8:  4 }{4:a}{27:ABC}{4:abc                                     }|
      {7:  }{8:  7 }{27:xyz}{4:                                        }│{7:  }{8:  5 }{27:aABCabc}{4:                                     }|
      {7:  }{8:  8 }{27:xyz}{4:                                        }│{7:  }{8:  6 }{27:aABCabc}{4:                                     }|
      {7:  }{8:  9 }{27:xyz}{4:                                        }│{7:  }{8:  7 }{27:aABCabc}{4:                                     }|
      {7:  }{8: 10 }{22:aDEFabc                                    }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 11 }{22:aDEFabc                                    }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 12 }{22:aDEFabc                                    }│{7:  }{8:    }{23:--------------------------------------------}|
      {7:  }{8: 13 }common line                                │{7:  }{8:  8 }common line                                 |
      {7:  }{8: 14 }DEF                                        │{7:  }{8:  9 }DEF                                         |
      {7:  }{8: 15 }GHI                                        │{7:  }{8: 10 }GHI                                         |
      {7:  }{8: 16 }something else                             │{7:  }{8: 11 }something else                              |
      {7:  }{8: 17 }common line                                │{7:  }{8: 12 }common line                                 |
      {7:  }{8: 18 }something                                  │{7:  }{8: 13 }something                                   |
      {2:Xtest-functional-diff-screen-1.2                  }{3:Xtest-functional-diff-screen-1 [+]                }|
      :8,10diffget                                                                                        |
      ]])
      end
    )
  end)
end)

describe('regressions', function()
  local screen

  it("doesn't crash with long lines", function()
    clear()
    feed(':set diffopt+=linematch:30<cr>')
    screen = Screen.new(100, 20)
    screen:attach()
    -- line must be greater than MATCH_CHAR_MAX_LEN
    t.api.nvim_buf_set_lines(0, 0, -1, false, { string.rep('a', 1000) .. 'hello' })
    t.exec 'vnew'
    t.api.nvim_buf_set_lines(0, 0, -1, false, { string.rep('a', 1010) .. 'world' })
    t.exec 'windo diffthis'
  end)

  it('properly computes filler lines for hunks bigger than linematch limit', function()
    clear()
    feed(':set diffopt+=linematch:10<cr>')
    screen = Screen.new(100, 20)
    screen:attach()
    local lines = {}
    for i = 0, 29 do
      lines[#lines + 1] = tostring(i)
    end
    t.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    t.exec 'vnew'
    t.api.nvim_buf_set_lines(0, 0, -1, false, { '00', '29' })
    t.exec 'windo diffthis'
    feed('<C-e>')
    screen:expect {
      grid = [[
      {1:  }{2:------------------------------------------------}│{1:  }{3:^1                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:2                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:3                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:4                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:5                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:6                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:7                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:8                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:9                                              }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:10                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:11                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:12                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:13                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:14                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:15                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:16                                             }|
      {1:  }{2:------------------------------------------------}│{1:  }{3:17                                             }|
      {1:  }29                                              │{1:  }{3:18                                             }|
      {4:[No Name] [+]                                      }{5:[No Name] [+]                                    }|
                                                                                                          |
    ]],
      attr_ids = {
        [1] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Grey },
        [2] = {
          bold = true,
          background = Screen.colors.LightCyan,
          foreground = Screen.colors.Blue1,
        },
        [3] = { background = Screen.colors.LightBlue },
        [4] = { reverse = true },
        [5] = { reverse = true, bold = true },
      },
    }
  end)
end)
