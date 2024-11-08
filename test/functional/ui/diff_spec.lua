local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local feed = n.feed
local clear = n.clear
local command = n.command
local insert = n.insert
local write_file = t.write_file
local dedent = t.dedent
local exec = n.exec
local eq = t.eq
local api = n.api

local function WriteDiffFiles(text1, text2)
  write_file('Xdifile1', text1)
  write_file('Xdifile2', text2)
  command('checktime')
end

local function WriteDiffFiles3(text1, text2, text3)
  write_file('Xdifile1', text1)
  write_file('Xdifile2', text2)
  write_file('Xdifile3', text3)
  command('checktime')
end

before_each(clear)

describe('Diff mode screen', function()
  local fname = 'Xtest-functional-diff-screen-1'
  local fname_2 = fname .. '.2'
  local screen

  local reread = function()
    feed(':e<cr><c-w>w:e<cr><c-w>w')
  end

  setup(function()
    os.remove(fname)
    os.remove(fname_2)
  end)

  teardown(function()
    os.remove(fname)
    os.remove(fname_2)
  end)

  before_each(function()
    feed(':e ' .. fname_2 .. '<cr>')
    feed(':vnew ' .. fname .. '<cr>')
    feed(':diffthis<cr>')
    feed('<c-w>w:diffthis<cr><c-w>w')

    screen = Screen.new(40, 16)
    screen:attach()
  end)

  it('Add a line in beginning of file 2', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:  }{23:------------------}│{7:  }{22:0                }|
      {7:  }^1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:+ }{13:+--  4 lines: 7···}│{7:+ }{13:+--  4 lines: 7··}|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:  }{23:------------------}│{7:  }{22:0                }|
      {7:  }^1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:+ }{13:+--  4 lines: 7···}│{7:+ }{13:+--  4 lines: 7··}|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in beginning of file 1', function()
    write_file(fname, '0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:  }{22:^0                 }│{7:  }{23:-----------------}|
      {7:  }1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:+ }{13:+--  4 lines: 7···}│{7:+ }{13:+--  4 lines: 7··}|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:  }{22:^0                 }│{7:  }{23:-----------------}|
      {7:  }1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:+ }{13:+--  4 lines: 7···}│{7:+ }{13:+--  4 lines: 7··}|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line at the end of file 2', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:+ }{13:^+--  4 lines: 1···}│{7:+ }{13:+--  4 lines: 1··}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{23:------------------}│{7:  }{22:11               }|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:+ }{13:^+--  4 lines: 1···}│{7:+ }{13:+--  4 lines: 1··}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{23:------------------}│{7:  }{22:11               }|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])

    screen:try_resize(40, 9)
    screen:expect([[
      {7:+ }{13:^+--  4 lines: 1···}│{7:+ }{13:+--  4 lines: 1··}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                              |
    ]])
  end)

  it('Add a line at the end of file 1', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:+ }{13:^+--  4 lines: 1···}│{7:+ }{13:+--  4 lines: 1··}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{22:11                }│{7:  }{23:-----------------}|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:+ }{13:^+--  4 lines: 1···}│{7:+ }{13:+--  4 lines: 1··}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{22:11                }│{7:  }{23:-----------------}|
      {1:~                   }│{1:~                  }|*6
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])

    screen:try_resize(40, 9)
    screen:expect([[
      {7:+ }{13:^+--  4 lines: 1···}│{7:+ }{13:+--  4 lines: 1··}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                              |
    ]])
  end)

  it('Add a line in the middle of file 2, remove on at the end of file 1', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    write_file(fname_2, '1\n2\n3\n4\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:  }^1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }{23:------------------}│{7:  }{22:4                }|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{22:11                }│{7:  }{23:-----------------}|
      {1:~                   }│{1:~                  }|*2
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:  }^1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }{23:------------------}│{7:  }{22:4                }|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{22:11                }│{7:  }{23:-----------------}|
      {1:~                   }│{1:~                  }|*2
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in the middle of file 1, remove on at the end of file 2', function()
    write_file(fname, '1\n2\n3\n4\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:  }^1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }{22:4                 }│{7:  }{23:-----------------}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{23:------------------}│{7:  }{22:11               }|
      {1:~                   }│{1:~                  }|*2
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:  }^1                 │{7:  }1                |
      {7:  }2                 │{7:  }2                |
      {7:  }3                 │{7:  }3                |
      {7:  }4                 │{7:  }4                |
      {7:  }{22:4                 }│{7:  }{23:-----------------}|
      {7:  }5                 │{7:  }5                |
      {7:  }6                 │{7:  }6                |
      {7:  }7                 │{7:  }7                |
      {7:  }8                 │{7:  }8                |
      {7:  }9                 │{7:  }9                |
      {7:  }10                │{7:  }10               |
      {7:  }{23:------------------}│{7:  }{22:11               }|
      {1:~                   }│{1:~                  }|*2
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  describe('normal/patience/histogram diff algorithm', function()
    setup(function()
      local f1 = [[#include <stdio.h>

// Frobs foo heartily
int frobnitz(int foo)
{
    int i;
    for(i = 0; i < 10; i++)
    {
        printf("Your answer is: ");
        printf("%d\n", foo);
    }
}

int fact(int n)
{
    if(n > 1)
    {
        return fact(n-1) * n;
    }
    return 1;
}

int main(int argc, char **argv)
{
    frobnitz(fact(10));
}]]
      write_file(fname, f1, false)
      local f2 = [[#include <stdio.h>

int fib(int n)
{
    if(n > 2)
    {
        return fib(n-1) + fib(n-2);
    }
    return 1;
}

// Frobs foo heartily
int frobnitz(int foo)
{
    int i;
    for(i = 0; i < 10; i++)
    {
        printf("%d\n", foo);
    }
}

int main(int argc, char **argv)
{
    frobnitz(fib(10));
}]]
      write_file(fname_2, f2, false)
    end)

    it('diffopt=+algorithm:myers', function()
      reread()
      feed(':set diffopt=internal,filler<cr>')
      screen:expect([[
        {7:  }^#include <stdio.h>│{7:  }#include <stdio.h|
        {7:  }                  │{7:  }                 |
        {7:  }{27:// Frobs foo heart}│{7:  }{27:int fib(int n)}{4:   }|
        {7:  }{22:int frobnitz(int f}│{7:  }{23:-----------------}|
        {7:  }{                 │{7:  }{                |
        {7:  }{4:    i}{27:nt i;}{4:        }│{7:  }{4:    i}{27:f(n > 2)}{4:    }|
        {7:  }{22:    for(i = 0; i <}│{7:  }{23:-----------------}|
        {7:  }    {             │{7:  }    {            |
        {7:  }{4:        }{27:printf("Yo}│{7:  }{4:        }{27:return fi}|
        {7:  }{22:        printf("%d}│{7:  }{23:-----------------}|
        {7:  }    }             │{7:  }    }            |
        {7:  }{23:------------------}│{7:  }{22:    return 1;    }|
        {7:  }}                 │{7:  }}                |
        {7:  }                  │{7:  }                 |
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])

      feed('G')
      screen:expect([[
        {7:  }{23:------------------}│{7:  }{22:int frobnitz(int }|
        {7:  }{                 │{7:  }{                |
        {7:  }{4:    i}{27:f(n > 1)}{4:     }│{7:  }{4:    i}{27:nt i;}{4:       }|
        {7:  }{23:------------------}│{7:  }{22:    for(i = 0; i }|
        {7:  }    {             │{7:  }    {            |
        {7:  }{4:        }{27:return fac}│{7:  }{4:        }{27:printf("%}|
        {7:  }    }             │{7:  }    }            |
        {7:  }{22:    return 1;     }│{7:  }{23:-----------------}|
        {7:  }}                 │{7:  }}                |
        {7:  }                  │{7:  }                 |
        {7:  }int main(int argc,│{7:  }int main(int argc|
        {7:  }{                 │{7:  }{                |
        {7:  }{4:    frobnitz(f}{27:act}{4:(}│{7:  }{4:    frobnitz(f}{27:ib}{4:(}|
        {7:  }^}                 │{7:  }}                |
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])
    end)

    it('diffopt+=algorithm:patience', function()
      reread()
      feed(':set diffopt=internal,filler,algorithm:patience<cr>')
      screen:expect([[
        {7:  }^#include <stdio.h>│{7:  }#include <stdio.h|
        {7:  }                  │{7:  }                 |
        {7:  }{23:------------------}│{7:  }{22:int fib(int n)   }|
        {7:  }{23:------------------}│{7:  }{22:{                }|
        {7:  }{23:------------------}│{7:  }{22:    if(n > 2)    }|
        {7:  }{23:------------------}│{7:  }{22:    {            }|
        {7:  }{23:------------------}│{7:  }{22:        return fi}|
        {7:  }{23:------------------}│{7:  }{22:    }            }|
        {7:  }{23:------------------}│{7:  }{22:    return 1;    }|
        {7:  }{23:------------------}│{7:  }{22:}                }|
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }// Frobs foo heart│{7:  }// Frobs foo hear|
        {7:  }int frobnitz(int f│{7:  }int frobnitz(int |
        {7:  }{                 │{7:  }{                |
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]])

      feed('G')
      screen:expect([[
        {7:  }                  │{7:  }                 |
        {7:  }{22:int fact(int n)   }│{7:  }{23:-----------------}|
        {7:  }{22:{                 }│{7:  }{23:-----------------}|
        {7:  }{22:    if(n > 1)     }│{7:  }{23:-----------------}|
        {7:  }{22:    {             }│{7:  }{23:-----------------}|
        {7:  }{22:        return fac}│{7:  }{23:-----------------}|
        {7:  }{22:    }             }│{7:  }{23:-----------------}|
        {7:  }{22:    return 1;     }│{7:  }{23:-----------------}|
        {7:  }{22:}                 }│{7:  }{23:-----------------}|
        {7:  }{22:                  }│{7:  }{23:-----------------}|
        {7:  }int main(int argc,│{7:  }int main(int argc|
        {7:  }{                 │{7:  }{                |
        {7:  }{4:    frobnitz(f}{27:act}{4:(}│{7:  }{4:    frobnitz(f}{27:ib}{4:(}|
        {7:  }^}                 │{7:  }}                |
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)

    it('diffopt+=algorithm:histogram', function()
      reread()
      feed(':set diffopt=internal,filler,algorithm:histogram<cr>')
      screen:expect([[
        {7:  }^#include <stdio.h>│{7:  }#include <stdio.h|
        {7:  }                  │{7:  }                 |
        {7:  }{23:------------------}│{7:  }{22:int fib(int n)   }|
        {7:  }{23:------------------}│{7:  }{22:{                }|
        {7:  }{23:------------------}│{7:  }{22:    if(n > 2)    }|
        {7:  }{23:------------------}│{7:  }{22:    {            }|
        {7:  }{23:------------------}│{7:  }{22:        return fi}|
        {7:  }{23:------------------}│{7:  }{22:    }            }|
        {7:  }{23:------------------}│{7:  }{22:    return 1;    }|
        {7:  }{23:------------------}│{7:  }{22:}                }|
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }// Frobs foo heart│{7:  }// Frobs foo hear|
        {7:  }int frobnitz(int f│{7:  }int frobnitz(int |
        {7:  }{                 │{7:  }{                |
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]])

      feed('G')
      screen:expect([[
        {7:  }                  │{7:  }                 |
        {7:  }{22:int fact(int n)   }│{7:  }{23:-----------------}|
        {7:  }{22:{                 }│{7:  }{23:-----------------}|
        {7:  }{22:    if(n > 1)     }│{7:  }{23:-----------------}|
        {7:  }{22:    {             }│{7:  }{23:-----------------}|
        {7:  }{22:        return fac}│{7:  }{23:-----------------}|
        {7:  }{22:    }             }│{7:  }{23:-----------------}|
        {7:  }{22:    return 1;     }│{7:  }{23:-----------------}|
        {7:  }{22:}                 }│{7:  }{23:-----------------}|
        {7:  }{22:                  }│{7:  }{23:-----------------}|
        {7:  }int main(int argc,│{7:  }int main(int argc|
        {7:  }{                 │{7:  }{                |
        {7:  }{4:    frobnitz(f}{27:act}{4:(}│{7:  }{4:    frobnitz(f}{27:ib}{4:(}|
        {7:  }^}                 │{7:  }}                |
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)
  end)

  describe('diffopt+=indent-heuristic', function()
    setup(function()
      local f1 = [[
  def finalize(values)

    values.each do |v|
      v.finalize
    end]]
      write_file(fname, f1, false)
      local f2 = [[
  def finalize(values)

    values.each do |v|
      v.prepare
    end

    values.each do |v|
      v.finalize
    end]]
      write_file(fname_2, f2, false)
      feed(':diffupdate!<cr>')
    end)

    it('internal', function()
      reread()
      feed(':set diffopt=internal,filler<cr>')
      screen:expect([[
        {7:  }^def finalize(value│{7:  }def finalize(valu|
        {7:  }                  │{7:  }                 |
        {7:  }  values.each do |│{7:  }  values.each do |
        {7:  }{23:------------------}│{7:  }{22:    v.prepare    }|
        {7:  }{23:------------------}│{7:  }{22:  end            }|
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }{23:------------------}│{7:  }{22:  values.each do }|
        {7:  }    v.finalize    │{7:  }    v.finalize   |
        {7:  }  end             │{7:  }  end            |
        {1:~                   }│{1:~                  }|*5
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])
    end)

    it('indent-heuristic', function()
      reread()
      feed(':set diffopt=internal,filler,indent-heuristic<cr>')
      screen:expect([[
        {7:  }^def finalize(value│{7:  }def finalize(valu|
        {7:  }                  │{7:  }                 |
        {7:  }{23:------------------}│{7:  }{22:  values.each do }|
        {7:  }{23:------------------}│{7:  }{22:    v.prepare    }|
        {7:  }{23:------------------}│{7:  }{22:  end            }|
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }  values.each do |│{7:  }  values.each do |
        {7:  }    v.finalize    │{7:  }    v.finalize   |
        {7:  }  end             │{7:  }  end            |
        {1:~                   }│{1:~                  }|*5
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)

    it('indent-heuristic random order', function()
      reread()
      feed(':set diffopt=internal,filler,indent-heuristic,algorithm:patience<cr>')
      feed(':<cr>')
      screen:expect([[
        {7:  }^def finalize(value│{7:  }def finalize(valu|
        {7:  }                  │{7:  }                 |
        {7:  }{23:------------------}│{7:  }{22:  values.each do }|
        {7:  }{23:------------------}│{7:  }{22:    v.prepare    }|
        {7:  }{23:------------------}│{7:  }{22:  end            }|
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }  values.each do |│{7:  }  values.each do |
        {7:  }    v.finalize    │{7:  }    v.finalize   |
        {7:  }  end             │{7:  }  end            |
        {1:~                   }│{1:~                  }|*5
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)
  end)

  it('Diff the same file', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:+ }{13:^+-- 10 lines: 1···}│{7:+ }{13:+-- 10 lines: 1··}|
      {1:~                   }│{1:~                  }|*13
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:+ }{13:^+-- 10 lines: 1···}│{7:+ }{13:+-- 10 lines: 1··}|
      {1:~                   }│{1:~                  }|*13
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Diff an empty file', function()
    write_file(fname, '', false)
    write_file(fname_2, '', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:- }^                  │{7:- }                 |
      {1:~                   }│{1:~                  }|*13
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:- }^                  │{7:- }                 |
      {1:~                   }│{1:~                  }|*13
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Diff empty and non-empty file', function()
    write_file(fname, '', false)
    write_file(fname_2, 'foo\nbar\nbaz', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {7:  }{23:------------------}│{7:  }{22:foo              }|
      {7:  }{23:------------------}│{7:  }{22:bar              }|
      {7:  }{23:------------------}│{7:  }{22:baz              }|
      {7:  }^                  │{1:~                  }|
      {1:~                   }│{1:~                  }|*10
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:  }{23:------------------}│{7:  }{22:foo              }|
      {7:  }{23:------------------}│{7:  }{22:bar              }|
      {7:  }{23:------------------}│{7:  }{22:baz              }|
      {7:  }^                  │{1:~                  }|
      {1:~                   }│{1:~                  }|*10
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('diffopt+=icase', function()
    write_file(fname, 'a\nb\ncd\n', false)
    write_file(fname_2, 'A\nb\ncDe\n', false)
    reread()

    feed(':set diffopt=filler,icase<cr>')
    screen:expect([[
      {7:  }^a                 │{7:  }A                |
      {7:  }b                 │{7:  }b                |
      {7:  }{4:cd                }│{7:  }{4:cD}{27:e}{4:              }|
      {1:~                   }│{1:~                  }|*11
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt=filler,icase               |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {7:  }^a                 │{7:  }A                |
      {7:  }b                 │{7:  }b                |
      {7:  }{4:cd                }│{7:  }{4:cD}{27:e}{4:              }|
      {1:~                   }│{1:~                  }|*11
      {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  describe('diffopt+=iwhite', function()
    setup(function()
      local f1 = 'int main()\n{\n   printf("Hello, World!");\n   return 0;\n}\n'
      write_file(fname, f1, false)
      local f2 =
        'int main()\n{\n   if (0)\n   {\n      printf("Hello, World!");\n      return 0;\n   }\n}\n'
      write_file(fname_2, f2, false)
      feed(':diffupdate!<cr>')
    end)

    it('external', function()
      reread()
      feed(':set diffopt=filler,iwhite<cr>')
      screen:expect([[
        {7:  }^int main()        │{7:  }int main()       |
        {7:  }{                 │{7:  }{                |
        {7:  }{23:------------------}│{7:  }{22:   if (0)        }|
        {7:  }{23:------------------}│{7:  }{22:   {             }|
        {7:  }   printf("Hello, │{7:  }      printf("Hel|
        {7:  }   return 0;      │{7:  }      return 0;  |
        {7:  }{23:------------------}│{7:  }{22:   }             }|
        {7:  }}                 │{7:  }}                |
        {1:~                   }│{1:~                  }|*6
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt=filler,iwhite              |
      ]])
    end)

    it('internal', function()
      reread()
      feed(':set diffopt=filler,iwhite,internal<cr>')
      screen:expect([[
        {7:  }^int main()        │{7:  }int main()       |
        {7:  }{                 │{7:  }{                |
        {7:  }{23:------------------}│{7:  }{22:   if (0)        }|
        {7:  }{23:------------------}│{7:  }{22:   {             }|
        {7:  }   printf("Hello, │{7:  }      printf("Hel|
        {7:  }   return 0;      │{7:  }      return 0;  |
        {7:  }{23:------------------}│{7:  }{22:   }             }|
        {7:  }}                 │{7:  }}                |
        {1:~                   }│{1:~                  }|*6
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt=filler,iwhite,internal     |
      ]])
    end)
  end)

  describe('diffopt+=iblank', function()
    setup(function()
      write_file(fname, 'a\n\n \ncd\nef\nxxx\n', false)
      write_file(fname_2, 'a\ncd\n\nef\nyyy\n', false)
      feed(':diffupdate!<cr>')
    end)

    it('generic', function()
      reread()
      feed(':set diffopt=internal,filler,iblank<cr>')
      screen:expect([[
        {7:  }^a                 │{7:  }a                |
        {7:  }{22:                  }│{7:  }{23:-----------------}|*2
        {7:  }cd                │{7:  }cd               |
        {7:  }ef                │{7:  }                 |
        {7:  }{27:xxx}{4:               }│{7:  }ef               |
        {1:~                   }│{7:  }{27:yyy}{4:              }|
        {1:~                   }│{1:~                  }|*7
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler,iblank     |
      ]])
    end)

    it('diffopt+=iwhite', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhite<cr>')
      feed(':<cr>')
      screen:expect([[
        {7:  }^a                 │{7:  }a                |
        {7:  }                  │{7:  }cd               |
        {7:  }                  │{7:  }                 |
        {7:  }cd                │{7:  }ef               |
        {7:  }ef                │{7:  }{27:yyy}{4:              }|
        {7:  }{27:xxx}{4:               }│{1:~                  }|
        {1:~                   }│{1:~                  }|*8
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhiteall<cr>')
      feed(':<cr>')
      screen:expect([[
        {7:  }^a                 │{7:  }a                |
        {7:  }                  │{7:  }cd               |
        {7:  }                  │{7:  }                 |
        {7:  }cd                │{7:  }ef               |
        {7:  }ef                │{7:  }{27:yyy}{4:              }|
        {7:  }{27:xxx}{4:               }│{1:~                  }|
        {1:~                   }│{1:~                  }|*8
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteeol', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhiteeol<cr>')
      feed(':<cr>')
      screen:expect([[
        {7:  }^a                 │{7:  }a                |
        {7:  }                  │{7:  }cd               |
        {7:  }                  │{7:  }                 |
        {7:  }cd                │{7:  }ef               |
        {7:  }ef                │{7:  }{27:yyy}{4:              }|
        {7:  }{27:xxx}{4:               }│{1:~                  }|
        {1:~                   }│{1:~                  }|*8
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)
  end)

  describe('diffopt+=iwhite{eol,all}', function()
    setup(function()
      write_file(fname, 'a \nx\ncd\nef\nxx  xx\nfoo\nbar\n', false)
      write_file(fname_2, 'a\nx\nc d\n ef\nxx xx\nfoo\n\nbar\n', false)
      feed(':diffupdate!<cr>')
    end)

    it('diffopt+=iwhiteeol', function()
      reread()
      feed(':set diffopt=internal,filler,iwhiteeol<cr>')
      feed(':<cr>')
      screen:expect([[
        {7:  }^a                 │{7:  }a                |
        {7:  }x                 │{7:  }x                |
        {7:  }{4:cd                }│{7:  }{4:c}{27: }{4:d              }|
        {7:  }{4:ef                }│{7:  }{27: }{4:ef              }|
        {7:  }{4:xx }{27: }{4:xx            }│{7:  }{4:xx xx            }|
        {7:  }foo               │{7:  }foo              |
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }bar               │{7:  }bar              |
        {1:~                   }│{1:~                  }|*6
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,iwhiteall<cr>')
      feed(':<cr>')
      screen:expect([[
        {7:  }^a                 │{7:  }a                |
        {7:  }x                 │{7:  }x                |
        {7:  }cd                │{7:  }c d              |
        {7:  }ef                │{7:  } ef              |
        {7:  }xx  xx            │{7:  }xx xx            |
        {7:  }foo               │{7:  }foo              |
        {7:  }{23:------------------}│{7:  }{22:                 }|
        {7:  }bar               │{7:  }bar              |
        {1:~                   }│{1:~                  }|*6
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)
  end)

  -- oldtest: Test_diff_scroll()
  -- This was scrolling for 'cursorbind' but 'scrollbind' is more important
  it('scrolling works correctly vim-patch:8.2.5155', function()
    screen:try_resize(40, 12)
    write_file(
      fname,
      dedent([[
      line 1
      line 2
      line 3
      line 4

      // Common block
      // one
      // containing
      // four lines

      // Common block
      // two
      // containing
      // four lines]]),
      false
    )
    write_file(
      fname_2,
      dedent([[
      line 1
      line 2
      line 3
      line 4

      Lorem
      ipsum
      dolor
      sit
      amet,
      consectetur
      adipiscing
      elit.
      Etiam
      luctus
      lectus
      sodales,
      dictum

      // Common block
      // one
      // containing
      // four lines

      Vestibulum
      tincidunt
      aliquet
      nulla.

      // Common block
      // two
      // containing
      // four lines]]),
      false
    )
    reread()

    feed('<C-W><C-W>jjjj')
    screen:expect([[
      {7:  }line 1           │{7:  }line 1            |
      {7:  }line 2           │{7:  }line 2            |
      {7:  }line 3           │{7:  }line 3            |
      {7:  }line 4           │{7:  }line 4            |
      {7:  }                 │{7:  }^                  |
      {7:  }{23:-----------------}│{7:  }{22:Lorem             }|
      {7:  }{23:-----------------}│{7:  }{22:ipsum             }|
      {7:  }{23:-----------------}│{7:  }{22:dolor             }|
      {7:  }{23:-----------------}│{7:  }{22:sit               }|
      {7:  }{23:-----------------}│{7:  }{22:amet,             }|
      {2:<nal-diff-screen-1  }{3:<al-diff-screen-1.2 }|
      :e                                      |
    ]])
    feed('j')
    screen:expect([[
      {7:  }line 1           │{7:  }line 1            |
      {7:  }line 2           │{7:  }line 2            |
      {7:  }line 3           │{7:  }line 3            |
      {7:  }line 4           │{7:  }line 4            |
      {7:  }                 │{7:  }                  |
      {7:  }{23:-----------------}│{7:  }{22:^Lorem             }|
      {7:  }{23:-----------------}│{7:  }{22:ipsum             }|
      {7:  }{23:-----------------}│{7:  }{22:dolor             }|
      {7:  }{23:-----------------}│{7:  }{22:sit               }|
      {7:  }{23:-----------------}│{7:  }{22:amet,             }|
      {2:<nal-diff-screen-1  }{3:<al-diff-screen-1.2 }|
      :e                                      |
    ]])
  end)

  describe('line matching diff algorithm', function()
    setup(function()
      local f1 = [[if __name__ == "__main__":
    import sys
    app = QWidgets.QApplication(sys.args)
    MainWindow = QtWidgets.QMainWindow()
    ui = UI_MainWindow()
    ui.setupUI(MainWindow)
    MainWindow.show()
    sys.exit(app.exec_())]]
      write_file(fname, f1, false)
      local f2 = [[if __name__ == "__main__":
    import sys
    comment these things
    #app = QWidgets.QApplication(sys.args)
    #MainWindow = QtWidgets.QMainWindow()
    add a completely different line here
    #ui = UI_MainWindow()
    add another new line
    ui.setupUI(MainWindow)
    MainWindow.show()
    sys.exit(app.exec_())]]
      write_file(fname_2, f2, false)
    end)

    it('diffopt+=linematch:20', function()
      reread()
      feed(':set diffopt=internal,filler<cr>')
      screen:expect([[
  {7:  }^if __name__ == "__│{7:  }if __name__ == "_|
  {7:  }    import sys    │{7:  }    import sys   |
  {7:  }{4:    }{27:app = QWidgets}│{7:  }{4:    }{27:comment these}|
  {7:  }{4:    }{27:MainWindow = Q}│{7:  }{4:    }{27:#app = QWidge}|
  {7:  }{4:    }{27:ui = UI_}{4:MainWi}│{7:  }{4:    }{27:#MainWindow =}|
  {7:  }{23:------------------}│{7:  }{22:    add a complet}|
  {7:  }{23:------------------}│{7:  }{22:    #ui = UI_Main}|
  {7:  }{23:------------------}│{7:  }{22:    add another n}|
  {7:  }    ui.setupUI(Mai│{7:  }    ui.setupUI(Ma|
  {7:  }    MainWindow.sho│{7:  }    MainWindow.sh|
  {7:  }    sys.exit(app.e│{7:  }    sys.exit(app.|
  {1:~                   }│{1:~                  }|*3
  {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
  :set diffopt=internal,filler            |
      ]])

      feed('G')
      feed(':set diffopt+=linematch:20<cr>')
      screen:expect([[
        {7:  }if __name__ == "__│{7:  }if __name__ == "_|
        {7:  }    import sys    │{7:  }    import sys   |
        {7:  }{23:------------------}│{7:  }{22:    comment these}|
        {7:  }{4:    app = QWidgets}│{7:  }{4:    }{27:#}{4:app = QWidge}|
        {7:  }{4:    MainWindow = Q}│{7:  }{4:    }{27:#}{4:MainWindow =}|
        {7:  }{23:------------------}│{7:  }{22:    add a complet}|
        {7:  }{4:    ui = UI_MainWi}│{7:  }{4:    }{27:#}{4:ui = UI_Main}|
        {7:  }{23:------------------}│{7:  }{22:    add another n}|
        {7:  }    ui.setupUI(Mai│{7:  }    ui.setupUI(Ma|
        {7:  }    MainWindow.sho│{7:  }    MainWindow.sh|
        {7:  }    ^sys.exit(app.e│{7:  }    sys.exit(app.|
        {1:~                   }│{1:~                  }|*3
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt+=linematch:20              |
      ]])
    end)
  end)

  describe('line matching diff algorithm with icase', function()
    setup(function()
      local f1 = [[DDD
_aa]]
      write_file(fname, f1, false)
      local f2 = [[DDD
AAA
ccca]]
      write_file(fname_2, f2, false)
    end)
    it('diffopt+=linematch:20,icase', function()
      reread()
      feed(':set diffopt=internal,filler,linematch:20<cr>')
      screen:expect([[
        {7:  }^DDD               │{7:  }DDD              |
        {7:  }{23:------------------}│{7:  }{22:AAA              }|
        {7:  }{27:_a}{4:a               }│{7:  }{27:ccc}{4:a             }|
        {1:~                   }│{1:~                  }|*11
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]])
      feed(':set diffopt+=icase<cr>')
      screen:expect([[
        {7:  }^DDD               │{7:  }DDD              |
        {7:  }{27:_}{4:aa               }│{7:  }{27:A}{4:AA              }|
        {7:  }{23:------------------}│{7:  }{22:ccca             }|
        {1:~                   }│{1:~                  }|*11
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt+=icase                     |
      ]])
    end)
  end)

  describe('line matching diff algorithm with iwhiteall', function()
    setup(function()
      local f1 = [[BB
   AAA]]
      write_file(fname, f1, false)
      local f2 = [[BB
   AAB
AAAB]]
      write_file(fname_2, f2, false)
    end)
    it('diffopt+=linematch:20,iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,linematch:20<cr>')
      screen:expect {
        grid = [[
        {7:  }^BB                │{7:  }BB               |
        {7:  }{4:   AA}{27:A}{4:            }│{7:  }{4:   AA}{27:B}{4:           }|
        {7:  }{23:------------------}│{7:  }{22:AAAB             }|
        {1:~                   }│{1:~                  }|*11
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
                                                |
      ]],
      }
      feed(':set diffopt+=iwhiteall<cr>')
      screen:expect {
        grid = [[
        {7:  }^BB                │{7:  }BB               |
        {7:  }{23:------------------}│{7:  }{22:   AAB           }|
        {7:  }{4:   AAA            }│{7:  }{4:AAA}{27:B}{4:             }|
        {1:~                   }│{1:~                  }|*11
        {3:<onal-diff-screen-1  }{2:<l-diff-screen-1.2 }|
        :set diffopt+=iwhiteall                 |
      ]],
      }
    end)
  end)

  it('redraws with a change to non-current buffer', function()
    write_file(fname, 'aaa\nbbb\nccc\n\nxx', false)
    write_file(fname_2, 'aaa\nbbb\nccc\n\nyy', false)
    reread()
    local buf = api.nvim_get_current_buf()
    command('botright new')
    screen:expect {
      grid = [[
      {7:  }aaa               │{7:  }aaa              |
      {7:  }bbb               │{7:  }bbb              |
      {7:  }ccc               │{7:  }ccc              |
      {7:  }                  │{7:  }                 |
      {7:  }{27:xx}{4:                }│{7:  }{27:yy}{4:               }|
      {1:~                   }│{1:~                  }|
      {2:<onal-diff-screen-1  <l-diff-screen-1.2 }|
      ^                                        |
      {1:~                                       }|*6
      {3:[No Name]                               }|
      :e                                      |
    ]],
    }

    api.nvim_buf_set_lines(buf, 1, 2, true, { 'BBB' })
    screen:expect {
      grid = [[
      {7:  }aaa               │{7:  }aaa              |
      {7:  }{27:BBB}{4:               }│{7:  }{27:bbb}{4:              }|
      {7:  }ccc               │{7:  }ccc              |
      {7:  }                  │{7:  }                 |
      {7:  }{27:xx}{4:                }│{7:  }{27:yy}{4:               }|
      {1:~                   }│{1:~                  }|
      {2:<-diff-screen-1 [+]  <l-diff-screen-1.2 }|
      ^                                        |
      {1:~                                       }|*6
      {3:[No Name]                               }|
      :e                                      |
    ]],
    }
  end)

  it('redraws with a change current buffer in another window', function()
    write_file(fname, 'aaa\nbbb\nccc\n\nxx', false)
    write_file(fname_2, 'aaa\nbbb\nccc\n\nyy', false)
    reread()
    local buf = api.nvim_get_current_buf()
    command('botright split | diffoff')
    screen:expect {
      grid = [[
      {7:  }aaa               │{7:  }aaa              |
      {7:  }bbb               │{7:  }bbb              |
      {7:  }ccc               │{7:  }ccc              |
      {7:  }                  │{7:  }                 |
      {7:  }{27:xx}{4:                }│{7:  }{27:yy}{4:               }|
      {1:~                   }│{1:~                  }|
      {2:<onal-diff-screen-1  <l-diff-screen-1.2 }|
      ^aaa                                     |
      bbb                                     |
      ccc                                     |
                                              |
      xx                                      |
      {1:~                                       }|*2
      {3:Xtest-functional-diff-screen-1          }|
      :e                                      |
    ]],
    }

    api.nvim_buf_set_lines(buf, 1, 2, true, { 'BBB' })
    screen:expect {
      grid = [[
      {7:  }aaa               │{7:  }aaa              |
      {7:  }{27:BBB}{4:               }│{7:  }{27:bbb}{4:              }|
      {7:  }ccc               │{7:  }ccc              |
      {7:  }                  │{7:  }                 |
      {7:  }{27:xx}{4:                }│{7:  }{27:yy}{4:               }|
      {1:~                   }│{1:~                  }|
      {2:<-diff-screen-1 [+]  <l-diff-screen-1.2 }|
      ^aaa                                     |
      BBB                                     |
      ccc                                     |
                                              |
      xx                                      |
      {1:~                                       }|*2
      {3:Xtest-functional-diff-screen-1 [+]      }|
      :e                                      |
    ]],
    }
  end)
end)

it('win_update redraws lines properly', function()
  local screen
  screen = Screen.new(50, 10)
  screen:attach()
  screen:set_default_attr_ids({
    [1] = { bold = true, foreground = Screen.colors.Blue1 },
    [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
    [3] = {
      background = Screen.colors.Red,
      foreground = Screen.colors.Grey100,
      special = Screen.colors.Yellow,
    },
    [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    [5] = { special = Screen.colors.Yellow },
    [6] = { special = Screen.colors.Yellow, bold = true, foreground = Screen.colors.SeaGreen4 },
    [7] = { foreground = Screen.colors.Grey0, background = Screen.colors.Grey100 },
    [8] = { foreground = Screen.colors.Gray90, background = Screen.colors.Grey100 },
    [9] = { foreground = tonumber('0x00000c'), background = Screen.colors.Grey100 },
    [10] = { background = Screen.colors.Grey100, bold = true, foreground = tonumber('0xe5e5ff') },
    [11] = { background = Screen.colors.Grey100, bold = true, foreground = tonumber('0x2b8452') },
    [12] = { bold = true, reverse = true },
    [13] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray },
    [14] = { reverse = true },
    [15] = { background = Screen.colors.LightBlue },
    [16] = { background = Screen.colors.LightCyan1, bold = true, foreground = Screen.colors.Blue1 },
    [17] = { bold = true, background = Screen.colors.Red },
    [18] = { background = Screen.colors.LightMagenta },
  })

  insert([[
  1


  2
  1a
  ]])
  command('vnew left')
  insert([[
  2
  2a
  2b
  ]])
  command('windo diffthis')
  command('windo 1')
  screen:expect {
    grid = [[
    {13:  }{16:-----------------------}│{13:  }{15:^1                     }|
    {13:  }{16:-----------------------}│{13:  }{15:                      }|*2
    {13:  }2                      │{13:  }2                     |
    {13:  }{17:2}{18:a                     }│{13:  }{17:1}{18:a                    }|
    {13:  }{15:2b                     }│{13:  }{16:----------------------}|
    {13:  }                       │{13:  }                      |
    {1:~                        }│{1:~                       }|
    {14:left [+]                  }{12:[No Name] [+]           }|
                                                      |
  ]],
  }
  feed('<C-e>')
  feed('<C-e>')
  feed('<C-y>')
  feed('<C-y>')
  feed('<C-y>')
  screen:expect {
    grid = [[
    {13:  }{16:-----------------------}│{13:  }{15:1                     }|
    {13:  }{16:-----------------------}│{13:  }{15:                      }|
    {13:  }{16:-----------------------}│{13:  }{15:^                      }|
    {13:  }2                      │{13:  }2                     |
    {13:  }{17:2}{18:a                     }│{13:  }{17:1}{18:a                    }|
    {13:  }{15:2b                     }│{13:  }{16:----------------------}|
    {13:  }                       │{13:  }                      |
    {1:~                        }│{1:~                       }|
    {14:left [+]                  }{12:[No Name] [+]           }|
                                                      |
  ]],
  }
end)

-- oldtest: Test_diff_rnu()
it('diff updates line numbers below filler lines', function()
  local screen = Screen.new(40, 14)
  screen:attach()
  exec([[
    call setline(1, ['a', 'a', 'a', 'y', 'b', 'b', 'b', 'b', 'b'])
    vnew
    call setline(1, ['a', 'a', 'a', 'x', 'x', 'x', 'b', 'b', 'b', 'b', 'b'])
    windo diffthis
    setlocal number rnu cursorline cursorlineopt=number foldcolumn=0
  ]])
  screen:expect([[
    {7:  }a                │{15:1   }^a               |
    {7:  }a                │{8:  1 }a               |
    {7:  }a                │{8:  2 }a               |
    {7:  }{27:x}{4:                }│{8:  3 }{27:y}{4:               }|
    {7:  }{22:x                }│{8:    }{23:----------------}|*2
    {7:  }b                │{8:  4 }b               |
    {7:  }b                │{8:  5 }b               |
    {7:  }b                │{8:  6 }b               |
    {7:  }b                │{8:  7 }b               |
    {7:  }b                │{8:  8 }b               |
    {1:~                  }│{1:~                   }|
    {2:[No Name] [+]       }{3:[No Name] [+]       }|
                                            |
  ]])
  feed('j')
  screen:expect([[
    {7:  }a                │{8:  1 }a               |
    {7:  }a                │{15:2   }^a               |
    {7:  }a                │{8:  1 }a               |
    {7:  }{27:x}{4:                }│{8:  2 }{27:y}{4:               }|
    {7:  }{22:x                }│{8:    }{23:----------------}|*2
    {7:  }b                │{8:  3 }b               |
    {7:  }b                │{8:  4 }b               |
    {7:  }b                │{8:  5 }b               |
    {7:  }b                │{8:  6 }b               |
    {7:  }b                │{8:  7 }b               |
    {1:~                  }│{1:~                   }|
    {2:[No Name] [+]       }{3:[No Name] [+]       }|
                                            |
  ]])
  feed('j')
  screen:expect([[
    {7:  }a                │{8:  2 }a               |
    {7:  }a                │{8:  1 }a               |
    {7:  }a                │{15:3   }^a               |
    {7:  }{27:x}{4:                }│{8:  1 }{27:y}{4:               }|
    {7:  }{22:x                }│{8:    }{23:----------------}|*2
    {7:  }b                │{8:  2 }b               |
    {7:  }b                │{8:  3 }b               |
    {7:  }b                │{8:  4 }b               |
    {7:  }b                │{8:  5 }b               |
    {7:  }b                │{8:  6 }b               |
    {1:~                  }│{1:~                   }|
    {2:[No Name] [+]       }{3:[No Name] [+]       }|
                                            |
  ]])
end)

-- oldtest: Test_diff_with_scroll_and_change()
it('Align the filler lines when changing text in diff mode', function()
  local screen = Screen.new(40, 20)
  screen:attach()
  exec([[
    call setline(1, range(1, 15))
    vnew
    call setline(1, range(9, 15))
    windo diffthis
    wincmd h
    exe "normal Gl5\<C-E>"
  ]])
  screen:expect {
    grid = [[
    {7:  }{23:------------------}│{7:  }{22:6                }|
    {7:  }{23:------------------}│{7:  }{22:7                }|
    {7:  }{23:------------------}│{7:  }{22:8                }|
    {7:  }9                 │{7:  }9                |
    {7:  }10                │{7:  }10               |
    {7:  }11                │{7:  }11               |
    {7:  }12                │{7:  }12               |
    {7:  }13                │{7:  }13               |
    {7:  }14                │{7:  }14               |
    {7:- }1^5                │{7:- }15               |
    {1:~                   }│{1:~                  }|*8
    {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]],
  }
  feed('ax<Esc>')
  screen:expect {
    grid = [[
    {7:  }{23:------------------}│{7:  }{22:6                }|
    {7:  }{23:------------------}│{7:  }{22:7                }|
    {7:  }{23:------------------}│{7:  }{22:8                }|
    {7:  }9                 │{7:  }9                |
    {7:  }10                │{7:  }10               |
    {7:  }11                │{7:  }11               |
    {7:  }12                │{7:  }12               |
    {7:  }13                │{7:  }13               |
    {7:  }14                │{7:  }14               |
    {7:  }{4:15}{27:^x}{4:               }│{7:  }{4:15               }|
    {1:~                   }│{1:~                  }|*8
    {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]],
  }
  feed('<C-W>lay<Esc>')
  screen:expect {
    grid = [[
    {7:  }{23:-----------------}│{7:  }{22:6                 }|
    {7:  }{23:-----------------}│{7:  }{22:7                 }|
    {7:  }{23:-----------------}│{7:  }{22:8                 }|
    {7:  }9                │{7:  }9                 |
    {7:  }10               │{7:  }10                |
    {7:  }11               │{7:  }11                |
    {7:  }12               │{7:  }12                |
    {7:  }13               │{7:  }13                |
    {7:  }14               │{7:  }14                |
    {7:  }{4:15}{27:x}{4:              }│{7:  }{4:15}{27:^y}{4:               }|
    {1:~                  }│{1:~                   }|*8
    {2:[No Name] [+]       }{3:[No Name] [+]       }|
                                            |
  ]],
  }
end)

it("diff mode doesn't restore invalid 'foldcolumn' value #21647", function()
  local screen = Screen.new(60, 6)
  screen:attach()
  eq('0', api.nvim_get_option_value('foldcolumn', {}))
  command('diffsplit | bd')
  screen:expect([[
    ^                                                            |
    {1:~                                                           }|*4
                                                                |
  ]])
  eq('0', api.nvim_get_option_value('foldcolumn', {}))
end)

it("'relativenumber' doesn't draw beyond end of window in diff mode #29403", function()
  local screen = Screen.new(60, 12)
  screen:attach()
  command('set relativenumber')
  feed('10aa<CR><Esc>gg')
  command('vnew')
  feed('ab<CR><Esc>gg')
  command('windo diffthis')
  command('wincmd |')
  screen:expect([[
    {8: }│{7:  }{8:  0 }{27:^a}{4:                                                   }|
    {8: }│{7:  }{8:  1 }{22:a                                                   }|
    {8: }│{7:  }{8:  2 }{22:a                                                   }|
    {8: }│{7:  }{8:  3 }{22:a                                                   }|
    {8: }│{7:  }{8:  4 }{22:a                                                   }|
    {8: }│{7:  }{8:  5 }{22:a                                                   }|
    {8: }│{7:  }{8:  6 }{22:a                                                   }|
    {8: }│{7:  }{8:  7 }{22:a                                                   }|
    {8: }│{7:  }{8:  8 }{22:a                                                   }|
    {8: }│{7:  }{8:  9 }{22:a                                                   }|
    {2:< }{3:[No Name] [+]                                             }|
                                                                |
  ]])
  feed('j')
  screen:expect([[
    {8: }│{7:  }{8:  1 }{27:a}{4:                                                   }|
    {8: }│{7:  }{8:  0 }{22:^a                                                   }|
    {8: }│{7:  }{8:  1 }{22:a                                                   }|
    {8: }│{7:  }{8:  2 }{22:a                                                   }|
    {8: }│{7:  }{8:  3 }{22:a                                                   }|
    {8: }│{7:  }{8:  4 }{22:a                                                   }|
    {8: }│{7:  }{8:  5 }{22:a                                                   }|
    {8: }│{7:  }{8:  6 }{22:a                                                   }|
    {8: }│{7:  }{8:  7 }{22:a                                                   }|
    {8: }│{7:  }{8:  8 }{22:a                                                   }|
    {2:< }{3:[No Name] [+]                                             }|
                                                                |
  ]])
end)

-- oldtest: Test_diff_binary()
it('diff mode works properly if file contains NUL bytes vim-patch:8.2.3925', function()
  local screen = Screen.new(40, 20)
  screen:add_extra_attr_ids {
    [100] = { foreground = Screen.colors.Blue, bold = true, background = Screen.colors.Red },
  }
  screen:attach()
  exec([[
    call setline(1, ['a', 'b', "c\n", 'd', 'e', 'f', 'g'])
    vnew
    call setline(1, ['A', 'b', 'c', 'd', 'E', 'f', 'g'])
    windo diffthis
    wincmd p
    norm! gg0
    redraw!
  ]])

  -- Test using internal diff
  screen:expect([[
    {7:  }{27:^A}{4:                 }│{7:  }{27:a}{4:                }|
    {7:  }b                 │{7:  }b                |
    {7:  }{4:c                 }│{7:  }{4:c}{100:^@}{4:              }|
    {7:  }d                 │{7:  }d                |
    {7:  }{27:E}{4:                 }│{7:  }{27:e}{4:                }|
    {7:  }f                 │{7:  }f                |
    {7:  }g                 │{7:  }g                |
    {1:~                   }│{1:~                  }|*11
    {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])

  -- Test using internal diff and case folding
  command('set diffopt+=icase')
  feed('<C-L>')
  screen:expect([[
    {7:  }^A                 │{7:  }a                |
    {7:  }b                 │{7:  }b                |
    {7:  }{4:c                 }│{7:  }{4:c}{100:^@}{4:              }|
    {7:  }d                 │{7:  }d                |
    {7:  }E                 │{7:  }e                |
    {7:  }f                 │{7:  }f                |
    {7:  }g                 │{7:  }g                |
    {1:~                   }│{1:~                  }|*11
    {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])

  -- Test using external diff
  command('set diffopt=filler')
  feed('<C-L>')
  screen:expect([[
    {7:  }{27:^A}{4:                 }│{7:  }{27:a}{4:                }|
    {7:  }b                 │{7:  }b                |
    {7:  }{4:c                 }│{7:  }{4:c}{100:^@}{4:              }|
    {7:  }d                 │{7:  }d                |
    {7:  }{27:E}{4:                 }│{7:  }{27:e}{4:                }|
    {7:  }f                 │{7:  }f                |
    {7:  }g                 │{7:  }g                |
    {1:~                   }│{1:~                  }|*11
    {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])

  -- Test using external diff and case folding
  command('set diffopt+=filler,icase')
  feed('<C-L>')
  screen:expect([[
    {7:  }^A                 │{7:  }a                |
    {7:  }b                 │{7:  }b                |
    {7:  }{4:c                 }│{7:  }{4:c}{100:^@}{4:              }|
    {7:  }d                 │{7:  }d                |
    {7:  }E                 │{7:  }e                |
    {7:  }f                 │{7:  }f                |
    {7:  }g                 │{7:  }g                |
    {1:~                   }│{1:~                  }|*11
    {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])
end)

-- oldtest: Test_diff_breakindent_after_filler()
it("diff mode draws 'breakindent' correctly after filler lines", function()
  local screen = Screen.new(45, 8)
  screen:attach()
  exec([[
    set laststatus=0 diffopt+=followwrap breakindent breakindentopt=min:0
    call setline(1, ['a', '  ' .. repeat('c', 50)])
    vnew
    call setline(1, ['a', 'b', '  ' .. repeat('c', 50)])
    windo diffthis
    norm! G$
  ]])
  screen:expect([[
    {7:  }a                   │{7:  }a                   |
    {7:  }{22:b                   }│{7:  }{23:--------------------}|
    {7:  }  cccccccccccccccccc│{7:  }  cccccccccccccccccc|*2
    {7:  }  cccccccccccccc    │{7:  }  ccccccccccccc^c    |
    {1:~                     }│{1:~                     }|*2
                                                 |
  ]])
end)

-- oldtest: Test_diff_overlapped_diff_blocks_will_be_merged()
it('diff mode overlapped diff blocks will be merged', function()
  write_file('Xdifile1', '')
  write_file('Xdifile2', '')
  write_file('Xdifile3', '')

  finally(function()
    os.remove('Xdifile1')
    os.remove('Xdifile2')
    os.remove('Xdifile3')
    os.remove('Xdiin1')
    os.remove('Xdinew1')
    os.remove('Xdiout1')
    os.remove('Xdiin2')
    os.remove('Xdinew2')
    os.remove('Xdiout2')
  end)

  exec([[
    func DiffExprStub()
      let txt_in = readfile(v:fname_in)
      let txt_new = readfile(v:fname_new)
      if txt_in == ["line1"] && txt_new == ["line2"]
        call writefile(["1c1"], v:fname_out)
      elseif txt_in == readfile("Xdiin1") && txt_new == readfile("Xdinew1")
        call writefile(readfile("Xdiout1"), v:fname_out)
      elseif txt_in == readfile("Xdiin2") && txt_new == readfile("Xdinew2")
        call writefile(readfile("Xdiout2"), v:fname_out)
      endif
    endfunc
  ]])

  local screen = Screen.new(35, 20)
  screen:attach()
  command('set winwidth=10 diffopt=filler,internal')

  command('args Xdifile1 Xdifile2 | vert all | windo diffthis')

  WriteDiffFiles('a\nb', 'x\nx')
  write_file('Xdiin1', 'a\nb')
  write_file('Xdinew1', 'x\nx')
  write_file('Xdiout1', '1c1\n2c2')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:              }│{7:  }{27:^x}{4:              }|
    {7:  }{27:b}{4:              }│{7:  }{27:x}{4:              }|
    {1:~                }│{1:~                }|*16
    {2:Xdifile1          }{3:Xdifile2         }|
                                       |
  ]])
  command('set diffexpr&')

  WriteDiffFiles('a\nb\nc', 'x\nc')
  write_file('Xdiin1', 'a\nb\nc')
  write_file('Xdinew1', 'x\nc')
  write_file('Xdiout1', '1c1\n2c1')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:              }│{7:  }{27:^x}{4:              }|
    {7:  }{22:b              }│{7:  }{23:---------------}|
    {7:  }c              │{7:  }c              |
    {1:~                }│{1:~                }|*15
    {2:Xdifile1          }{3:Xdifile2         }|
                                       |
  ]])
  command('set diffexpr&')

  WriteDiffFiles('a\nc', 'x\nx\nc')
  write_file('Xdiin1', 'a\nc')
  write_file('Xdinew1', 'x\nx\nc')
  write_file('Xdiout1', '1c1\n1a2')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:              }│{7:  }{27:^x}{4:              }|
    {7:  }{23:---------------}│{7:  }{22:x              }|
    {7:  }c              │{7:  }c              |
    {1:~                }│{1:~                }|*15
    {2:Xdifile1          }{3:Xdifile2         }|
                                       |
  ]])
  command('set diffexpr&')

  command('args Xdifile1 Xdifile2 Xdifile3 | vert all | windo diffthis')

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'y\nb\nc')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a\ny\nc')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a\nb\ny')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'y\ny\nc')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a\ny\ny')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'y\ny\ny')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nx', 'y\ny\nc')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:c}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'x\nx\nc', 'a\ny\ny')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:^a}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'y\ny\ny\nd\ne')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'y\ny\ny\ny\ne')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'y\ny\ny\ny\ny')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:e}{4:        }│{7:  }{27:e}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\ny\ny\nd\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\ny\ny\ny\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\ny\ny\ny\ny')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:e}{4:        }│{7:  }{27:e}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nb\ny\nd\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nb\ny\ny\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nb\ny\ny\ny')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:e}{4:        }│{7:  }{27:e}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb', 'x\nb', 'y\ny')
  write_file('Xdiin1', 'a\nb')
  write_file('Xdinew1', 'x\nb')
  write_file('Xdiout1', '1c1')
  write_file('Xdiin2', 'a\nb')
  write_file('Xdinew2', 'y\ny')
  write_file('Xdiout2', '1c1\n2c2')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:b}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*16
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])
  command('set diffexpr&')

  WriteDiffFiles3('a\nb\nc\nd', 'x\nb\nx\nd', 'y\ny\nc\nd')
  write_file('Xdiin1', 'a\nb\nc\nd')
  write_file('Xdinew1', 'x\nb\nx\nd')
  write_file('Xdiout1', '1c1\n3c3')
  write_file('Xdiin2', 'a\nb\nc\nd')
  write_file('Xdinew2', 'y\ny\nc\nd')
  write_file('Xdiout2', '1c1\n2c2')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:b}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:c}{4:        }|
    {7:  }d        │{7:  }d        │{7:  }d        |
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])
  command('set diffexpr&')

  WriteDiffFiles3('a\nb\nc\nd', 'x\nb\nx\nd', 'y\ny\ny\nd')
  write_file('Xdiin1', 'a\nb\nc\nd')
  write_file('Xdinew1', 'x\nb\nx\nd')
  write_file('Xdiout1', '1c1\n3c3')
  write_file('Xdiin2', 'a\nb\nc\nd')
  write_file('Xdinew2', 'y\ny\ny\nd')
  write_file('Xdiout2', '1c1\n2,3c2,3')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:b}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }d        │{7:  }d        │{7:  }d        |
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])
  command('set diffexpr&')

  WriteDiffFiles3('a\nb\nc\nd', 'x\nb\nx\nd', 'y\ny\ny\ny')
  write_file('Xdiin1', 'a\nb\nc\nd')
  write_file('Xdinew1', 'x\nb\nx\nd')
  write_file('Xdiout1', '1c1\n3c3')
  write_file('Xdiin2', 'a\nb\nc\nd')
  write_file('Xdinew2', 'y\ny\ny\ny')
  write_file('Xdiout2', '1c1\n2,4c2,4')
  command('set diffexpr=DiffExprStub()')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:^y}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:b}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:d}{4:        }│{7:  }{27:y}{4:        }|
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])
  command('set diffexpr&')

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'b\nc')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^b}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'c')
  screen:expect([[
    {7:  }{4:a        }│{7:  }{4:a        }│{7:  }{23:---------}|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }c        │{7:  }c        │{7:  }^c        |
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', '')
  screen:expect([[
    {7:  }{4:a        }│{7:  }{4:a        }│{7:  }{23:---------}|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{7:  }^         |
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a\nc')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'b')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^b}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'd\ne')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:a}{4:        }│{7:  }{27:^d}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'e')
  screen:expect([[
    {7:  }{4:a        }│{7:  }{4:a        }│{7:  }{23:---------}|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }e        │{7:  }e        │{7:  }^e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nd\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:e        }│{7:  }{4:e        }│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nb\nd\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:c}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nb\ne')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }e        │{7:  }e        │{7:  }e        |
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc\nd\ne', 'a\nx\nc\nx\ne', 'a\nb')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{4:c        }│{7:  }{4:c        }│{7:  }{23:---------}|
    {7:  }{27:d}{4:        }│{7:  }{27:x}{4:        }│{7:  }{23:---------}|
    {7:  }{4:e        }│{7:  }{4:e        }│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{1:~          }|*13
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a\ny\nb\nc')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:y}{4:        }|
    {7:  }{23:---------}│{7:  }{23:---------}│{7:  }{22:b        }|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'a\nx\nc', 'a\nb\ny\nc')
  screen:expect([[
    {7:  }a        │{7:  }a        │{7:  }^a        |
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{23:---------}│{7:  }{23:---------}│{7:  }{22:y        }|
    {7:  }c        │{7:  }c        │{7:  }c        |
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])
end)

-- oldtest: Test_diff_topline_noscroll()
it('diff mode does not scroll with line("w0")', function()
  local screen = Screen.new(45, 20)
  screen:attach()
  exec([[
    set scrolloff=5
    call setline(1, range(1,60))
    vnew
    call setline(1, range(1,10) + range(50,60))
    windo diffthis
    norm! G
    exe "norm! 30\<C-y>"
  ]])
  screen:expect([[
    {7:  }9                   │{7:  }9                   |
    {7:  }10                  │{7:  }10                  |
    {7:  }{23:--------------------}│{7:  }{22:11                  }|
    {7:  }{23:--------------------}│{7:  }{22:12                  }|
    {7:  }{23:--------------------}│{7:  }{22:13                  }|
    {7:  }{23:--------------------}│{7:  }{22:14                  }|
    {7:  }{23:--------------------}│{7:  }{22:15                  }|
    {7:  }{23:--------------------}│{7:  }{22:16                  }|
    {7:  }{23:--------------------}│{7:  }{22:17                  }|
    {7:  }{23:--------------------}│{7:  }{22:18                  }|
    {7:  }{23:--------------------}│{7:  }{22:19                  }|
    {7:  }{23:--------------------}│{7:  }{22:20                  }|
    {7:  }{23:--------------------}│{7:  }{22:^21                  }|
    {7:  }{23:--------------------}│{7:  }{22:22                  }|
    {7:  }{23:--------------------}│{7:  }{22:23                  }|
    {7:  }{23:--------------------}│{7:  }{22:24                  }|
    {7:  }{23:--------------------}│{7:  }{22:25                  }|
    {7:  }{23:--------------------}│{7:  }{22:26                  }|
    {2:[No Name] [+]          }{3:[No Name] [+]         }|
                                                 |
  ]])
  command([[echo line('w0', 1001)]])
  screen:expect([[
    {7:  }9                   │{7:  }9                   |
    {7:  }10                  │{7:  }10                  |
    {7:  }{23:--------------------}│{7:  }{22:11                  }|
    {7:  }{23:--------------------}│{7:  }{22:12                  }|
    {7:  }{23:--------------------}│{7:  }{22:13                  }|
    {7:  }{23:--------------------}│{7:  }{22:14                  }|
    {7:  }{23:--------------------}│{7:  }{22:15                  }|
    {7:  }{23:--------------------}│{7:  }{22:16                  }|
    {7:  }{23:--------------------}│{7:  }{22:17                  }|
    {7:  }{23:--------------------}│{7:  }{22:18                  }|
    {7:  }{23:--------------------}│{7:  }{22:19                  }|
    {7:  }{23:--------------------}│{7:  }{22:20                  }|
    {7:  }{23:--------------------}│{7:  }{22:^21                  }|
    {7:  }{23:--------------------}│{7:  }{22:22                  }|
    {7:  }{23:--------------------}│{7:  }{22:23                  }|
    {7:  }{23:--------------------}│{7:  }{22:24                  }|
    {7:  }{23:--------------------}│{7:  }{22:25                  }|
    {7:  }{23:--------------------}│{7:  }{22:26                  }|
    {2:[No Name] [+]          }{3:[No Name] [+]         }|
    9                                            |
  ]])
  feed('<C-W>p')
  screen:expect([[
    {7:  }{23:--------------------}│{7:  }{22:39                  }|
    {7:  }{23:--------------------}│{7:  }{22:40                  }|
    {7:  }{23:--------------------}│{7:  }{22:41                  }|
    {7:  }{23:--------------------}│{7:  }{22:42                  }|
    {7:  }{23:--------------------}│{7:  }{22:43                  }|
    {7:  }{23:--------------------}│{7:  }{22:44                  }|
    {7:  }{23:--------------------}│{7:  }{22:45                  }|
    {7:  }{23:--------------------}│{7:  }{22:46                  }|
    {7:  }{23:--------------------}│{7:  }{22:47                  }|
    {7:  }{23:--------------------}│{7:  }{22:48                  }|
    {7:  }{23:--------------------}│{7:  }{22:49                  }|
    {7:  }^50                  │{7:  }50                  |
    {7:  }51                  │{7:  }51                  |
    {7:  }52                  │{7:  }52                  |
    {7:  }53                  │{7:  }53                  |
    {7:  }54                  │{7:  }54                  |
    {7:  }55                  │{7:  }55                  |
    {7:+ }{13:+--  5 lines: 56····}│{7:+ }{13:+--  5 lines: 56····}|
    {3:[No Name] [+]          }{2:[No Name] [+]         }|
    9                                            |
  ]])
  feed('<C-W>p')
  screen:expect([[
    {7:  }{23:--------------------}│{7:  }{22:39                  }|
    {7:  }{23:--------------------}│{7:  }{22:40                  }|
    {7:  }{23:--------------------}│{7:  }{22:41                  }|
    {7:  }{23:--------------------}│{7:  }{22:42                  }|
    {7:  }{23:--------------------}│{7:  }{22:43                  }|
    {7:  }{23:--------------------}│{7:  }{22:^44                  }|
    {7:  }{23:--------------------}│{7:  }{22:45                  }|
    {7:  }{23:--------------------}│{7:  }{22:46                  }|
    {7:  }{23:--------------------}│{7:  }{22:47                  }|
    {7:  }{23:--------------------}│{7:  }{22:48                  }|
    {7:  }{23:--------------------}│{7:  }{22:49                  }|
    {7:  }50                  │{7:  }50                  |
    {7:  }51                  │{7:  }51                  |
    {7:  }52                  │{7:  }52                  |
    {7:  }53                  │{7:  }53                  |
    {7:  }54                  │{7:  }54                  |
    {7:  }55                  │{7:  }55                  |
    {7:+ }{13:+--  5 lines: 56····}│{7:+ }{13:+--  5 lines: 56····}|
    {2:[No Name] [+]          }{3:[No Name] [+]         }|
    9                                            |
  ]])
end)
