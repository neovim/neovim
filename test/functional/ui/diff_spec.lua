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

  WriteDiffFiles3('a\nb\nc', 'd\ne', 'b\nf')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:d}{4:        }│{7:  }{27:^b}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:e}{4:        }│{7:  }{27:f}{4:        }|
    {7:  }{22:c        }│{7:  }{23:---------}│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  WriteDiffFiles3('a\nb\nc', 'd\ne', 'b')
  screen:expect([[
    {7:  }{27:a}{4:        }│{7:  }{27:d}{4:        }│{7:  }{27:^b}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:e}{4:        }│{7:  }{23:---------}|
    {7:  }{22:c        }│{7:  }{23:---------}│{7:  }{23:---------}|
    {1:~          }│{1:~          }│{1:~          }|*15
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  -- File 3 overlaps twice, 2nd overlap completely within the existing block.
  WriteDiffFiles3('foo\na\nb\nc\nbar', 'foo\nw\nx\ny\nz\nbar', 'foo\n1\na\nb\n2\nbar')
  screen:expect([[
    {7:  }foo      │{7:  }foo      │{7:  }^foo      |
    {7:  }{27:a}{4:        }│{7:  }{27:w}{4:        }│{7:  }{27:1}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:a}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{23:---------}│{7:  }{27:z}{4:        }│{7:  }{27:2}{4:        }|
    {7:  }bar      │{7:  }bar      │{7:  }bar      |
    {1:~          }│{1:~          }│{1:~          }|*12
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  -- File 3 overlaps twice, 2nd overlap extends beyond existing block on new
  -- side. Make sure we don't over-extend the range and hit 'bar'.
  WriteDiffFiles3('foo\na\nb\nc\nd\nbar', 'foo\nw\nx\ny\nz\nu\nbar', 'foo\n1\na\nb\n2\nd\nbar')
  screen:expect([[
    {7:  }foo      │{7:  }foo      │{7:  }^foo      |
    {7:  }{27:a}{4:        }│{7:  }{27:w}{4:        }│{7:  }{27:1}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:a}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:z}{4:        }│{7:  }{27:2}{4:        }|
    {7:  }{23:---------}│{7:  }{27:u}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }bar      │{7:  }bar      │{7:  }bar      |
    {1:~          }│{1:~          }│{1:~          }|*11
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  -- Chained overlaps. File 3's 2nd overlap spans two diff blocks and is longer
  -- than the 2nd one.
  WriteDiffFiles3(
    'foo\na\nb\nc\nd\ne\nf\nbar',
    'foo\nw\nx\ny\nz\ne\nu\nbar',
    'foo\n1\nb\n2\n3\nd\n4\nf\nbar'
  )
  screen:expect([[
    {7:  }foo      │{7:  }foo      │{7:  }^foo      |
    {7:  }{27:a}{4:        }│{7:  }{27:w}{4:        }│{7:  }{27:1}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }│{7:  }{27:2}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:z}{4:        }│{7:  }{27:3}{4:        }|
    {7:  }{27:e}{4:        }│{7:  }{27:e}{4:        }│{7:  }{27:d}{4:        }|
    {7:  }{27:f}{4:        }│{7:  }{27:u}{4:        }│{7:  }{27:4}{4:        }|
    {7:  }{23:---------}│{7:  }{23:---------}│{7:  }{22:f        }|
    {7:  }bar      │{7:  }bar      │{7:  }bar      |
    {1:~          }│{1:~          }│{1:~          }|*9
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  -- File 3 has 2 overlaps. An add and a delete. First overlap's expansion hits
  -- the 2nd one. Make sure we adjust the diff block to have fewer lines.
  WriteDiffFiles3('foo\na\nb\nbar', 'foo\nx\ny\nbar', 'foo\n1\na\nbar')
  screen:expect([[
    {7:  }foo      │{7:  }foo      │{7:  }^foo      |
    {7:  }{27:a}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:1}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:y}{4:        }│{7:  }{27:a}{4:        }|
    {7:  }bar      │{7:  }bar      │{7:  }bar      |
    {1:~          }│{1:~          }│{1:~          }|*14
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])

  -- File 3 has 2 overlaps. An add and another add. First overlap's expansion hits
  -- the 2nd one. Make sure we adjust the diff block to have more lines.
  WriteDiffFiles3('foo\na\nb\nc\nd\nbar', 'foo\nw\nx\ny\nz\nu\nbar', 'foo\n1\na\nb\n3\n4\nd\nbar')
  screen:expect([[
    {7:  }foo      │{7:  }foo      │{7:  }^foo      |
    {7:  }{27:a}{4:        }│{7:  }{27:w}{4:        }│{7:  }{27:1}{4:        }|
    {7:  }{27:b}{4:        }│{7:  }{27:x}{4:        }│{7:  }{27:a}{4:        }|
    {7:  }{27:c}{4:        }│{7:  }{27:y}{4:        }│{7:  }{27:b}{4:        }|
    {7:  }{27:d}{4:        }│{7:  }{27:z}{4:        }│{7:  }{27:3}{4:        }|
    {7:  }{23:---------}│{7:  }{27:u}{4:        }│{7:  }{27:4}{4:        }|
    {7:  }{23:---------}│{7:  }{23:---------}│{7:  }{22:d        }|
    {7:  }bar      │{7:  }bar      │{7:  }bar      |
    {1:~          }│{1:~          }│{1:~          }|*10
    {2:Xdifile1    Xdifile2    }{3:Xdifile3   }|
                                       |
  ]])
end)

-- oldtest: Test_diff_topline_noscroll()
it('diff mode does not scroll with line("w0")', function()
  local screen = Screen.new(45, 20)
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

-- oldtest: Test_diff_inline()
it('diff mode inline highlighting', function()
  write_file('Xdifile1', '')
  write_file('Xdifile2', '')
  finally(function()
    os.remove('Xdifile1')
    os.remove('Xdifile2')
  end)

  local screen = Screen.new(37, 20)
  screen:add_extra_attr_ids({
    [100] = { background = Screen.colors.Blue1 },
    [101] = { bold = true, background = Screen.colors.Red, foreground = Screen.colors.Blue1 },
    [102] = { background = Screen.colors.LightMagenta, foreground = Screen.colors.Blue1 },
    [103] = { bold = true, background = Screen.colors.Blue1, foreground = Screen.colors.Blue1 },
    [104] = { bold = true, background = Screen.colors.LightBlue, foreground = Screen.colors.Blue1 },
  })
  command('set winwidth=10')
  command('args Xdifile1 Xdifile2 | vert all | windo diffthis | 1wincmd w')

  WriteDiffFiles('abcdef ghi jk n\nx\ny', 'aBcef gHi lm n\ny\nz')
  command('set diffopt=internal,filler')
  local s1 = [[
    {7:  }{4:^a}{27:bcdef ghi jk}{4: n }│{7:  }{4:a}{27:Bcef gHi lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]]
  screen:expect(s1)
  command('set diffopt=internal,filler diffopt+=inline:none')
  local s2 = [[
    {7:  }{4:^abcdef ghi jk n }│{7:  }{4:aBcef gHi lm n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]]
  screen:expect(s2)

  -- inline:simple is the same as default
  command('set diffopt=internal,filler diffopt+=inline:simple')
  screen:expect(s1)

  command('set diffopt=internal,filler diffopt+=inline:char')
  local s3 = [[
    {7:  }{4:^a}{27:b}{4:c}{27:d}{4:ef g}{27:h}{4:i }{27:jk}{4: n }│{7:  }{4:a}{27:B}{4:cef g}{27:H}{4:i }{27:lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]]
  screen:expect(s3)

  command('set diffopt=internal,filler diffopt+=inline:word')
  screen:expect([[
    {7:  }{27:^abcdef}{4: }{27:ghi}{4: }{27:jk}{4: n }│{7:  }{27:aBcef}{4: }{27:gHi}{4: }{27:lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]])

  -- multiple inline values will the last one
  command('set diffopt=internal,filler diffopt+=inline:none,inline:char,inline:simple')
  screen:expect(s1)
  command('set diffopt=internal,filler diffopt+=inline:simple,inline:word,inline:none')
  screen:expect(s2)
  command('set diffopt=internal,filler diffopt+=inline:simple,inline:word,inline:char')
  screen:expect(s3)

  -- DiffTextAdd highlight
  command('hi DiffTextAdd guibg=blue')
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{4:^a}{27:b}{4:c}{100:d}{4:ef g}{27:h}{4:i }{27:jk}{4: n }│{7:  }{4:a}{27:B}{4:cef g}{27:H}{4:i }{27:lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]])

  -- Live update in insert mode
  feed('isometext')
  screen:expect([[
    {7:  }{27:sometext^abcd}{4:ef g}│{7:  }{27:aBc}{4:ef g}{27:H}{4:i }{27:lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1 [+]       }{2:Xdifile2          }|
    {5:-- INSERT --}                         |
  ]])
  feed('<Esc>')
  command('silent! undo')

  -- icase simple scenarios
  command('set diffopt=internal,filler diffopt+=inline:simple,icase')
  screen:expect([[
    {7:  }{4:^abc}{27:def ghi jk}{4: n }│{7:  }{4:aBc}{27:ef gHi lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,icase')
  screen:expect([[
    {7:  }{4:^abc}{100:d}{4:ef ghi }{27:jk}{4: n }│{7:  }{4:aBcef gHi }{27:lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:word,icase')
  screen:expect([[
    {7:  }{27:^abcdef}{4: ghi }{27:jk}{4: n }│{7:  }{27:aBcef}{4: gHi }{27:lm}{4: n  }|
    {7:  }{22:x               }│{7:  }{23:----------------}|
    {7:  }y               │{7:  }y               |
    {7:  }{23:----------------}│{7:  }{22:z               }|
    {1:~                 }│{1:~                 }|*14
    {3:Xdifile1           }{2:Xdifile2          }|
                                         |
  ]])

  screen:try_resize(45, 20)
  command('wincmd =')
  -- diff algorithms should affect highlight
  WriteDiffFiles('apples and oranges', 'oranges and apples')
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{27:^appl}{4:es and }{27:orang}{4:es  }│{7:  }{27:orang}{4:es and }{27:appl}{4:es  }|
    {1:~                     }│{1:~                     }|*17
    {3:Xdifile1               }{2:Xdifile2              }|
                                                 |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,algorithm:patience')
  screen:expect([[
    {7:  }{100:^apples and }{4:oranges  }│{7:  }{4:oranges}{100: and apples}{4:  }|
    {1:~                     }│{1:~                     }|*17
    {3:Xdifile1               }{2:Xdifile2              }|
                                                 |
  ]])

  screen:try_resize(65, 20)
  command('wincmd =')
  -- icase: composing chars and Unicode fold case edge cases
  WriteDiffFiles(
    '1 - sigma in 6σ and Ὀδυσσεύς\n1 - angstrom in åå\n1 - composing: ii⃗I⃗',
    '2 - Sigma in 6Σ and ὈΔΥΣΣΕΎΣ\n2 - Angstrom in ÅÅ\n2 - Composing: i⃗I⃗I⃗'
  )
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{27:^1}{4: - }{27:s}{4:igma in 6}{27:σ}{4: and Ὀ}{27:δυσσεύς}{4:  }│{7:  }{27:2}{4: - }{27:S}{4:igma in 6}{27:Σ}{4: and Ὀ}{27:ΔΥΣΣΕΎΣ}{4:  }|
    {7:  }{27:1}{4: - }{27:a}{4:ngstrom in }{27:åå}{4:            }│{7:  }{27:2}{4: - }{27:A}{4:ngstrom in }{27:ÅÅ}{4:            }|
    {7:  }{27:1}{4: - }{27:c}{4:omposing: }{100:i}{4:i⃗I⃗            }│{7:  }{27:2}{4: - }{27:C}{4:omposing: i⃗I⃗}{100:I⃗}{4:            }|
    {1:~                               }│{1:~                               }|*15
    {3:Xdifile1                         }{2:Xdifile2                        }|
                                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,icase')
  screen:expect([[
    {7:  }{27:^1}{4: - sigma in 6σ and Ὀδυσσεύς  }│{7:  }{27:2}{4: - Sigma in 6Σ and ὈΔΥΣΣΕΎΣ  }|
    {7:  }{27:1}{4: - angstrom in åå            }│{7:  }{27:2}{4: - Angstrom in ÅÅ            }|
    {7:  }{27:1}{4: - composing: }{27:i}{4:i⃗I⃗            }│{7:  }{27:2}{4: - Composing: }{27:i⃗}{4:I⃗I⃗            }|
    {1:~                               }│{1:~                               }|*15
    {3:Xdifile1                         }{2:Xdifile2                        }|
                                                                     |
  ]])

  screen:try_resize(35, 20)
  command('wincmd =')
  -- wide chars
  WriteDiffFiles('abc😅xde一\nf🚀g', 'abcy😢de\n二f🚀g')
  command('set diffopt=internal,filler diffopt+=inline:char,icase')
  screen:expect([[
    {7:  }{4:^abc}{27:😅x}{4:de}{100:一}{4:     }│{7:  }{4:abc}{27:y😢}{4:de       }|
    {7:  }{4:f🚀g           }│{7:  }{100:二}{4:f🚀g         }|
    {1:~                }│{1:~                }|*16
    {3:Xdifile1          }{2:Xdifile2         }|
                                       |
  ]])

  -- NUL char
  WriteDiffFiles('1\00034\0005\0006', '1234\0005\n6')
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{4:^1}{101:^@}{4:34}{102:^@}{4:5}{101:^@}{4:6    }│{7:  }{4:1}{27:2}{4:34}{102:^@}{4:5        }|
    {7:  }{23:---------------}│{7:  }{4:6              }|
    {1:~                }│{1:~                }|*16
    {3:Xdifile1          }{2:Xdifile2         }|
                                       |
  ]])

  -- word diff: always use first buffer's iskeyword and ignore others' for consistency
  WriteDiffFiles('foo+bar test', 'foo+baz test')
  command('set diffopt=internal,filler diffopt+=inline:word')
  local sw1 = [[
    {7:  }{4:^foo+}{27:bar}{4: test   }│{7:  }{4:foo+}{27:baz}{4: test   }|
    {1:~                }│{1:~                }|*17
    {3:Xdifile1          }{2:Xdifile2         }|
                                       |
  ]]
  screen:expect(sw1)

  command('set iskeyword+=+ | diffupdate')
  screen:expect([[
    {7:  }{27:^foo+bar}{4: test   }│{7:  }{27:foo+baz}{4: test   }|
    {1:~                }│{1:~                }|*17
    {3:Xdifile1          }{2:Xdifile2         }|
                                       |
  ]])

  command('set iskeyword& | wincmd w')
  command('set iskeyword+=+ | wincmd w | diffupdate')
  -- Use the previous screen as 2nd buffer's iskeyword does not matter
  screen:expect(sw1)

  command('windo set iskeyword& | 1wincmd w')

  screen:try_resize(75, 20)
  command('wincmd =')
  -- word diff: test handling of multi-byte characters. Only alphanumeric chars
  -- (e.g. Greek alphabet, but not CJK/emoji) count as words.
  WriteDiffFiles(
    '🚀⛵️一二三ひらがなΔέλτα Δelta foobar',
    '🚀🛸一二四ひらなδέλτα δelta foobar'
  )
  command('set diffopt=internal,filler diffopt+=inline:word')
  screen:expect([[
    {7:  }{4:^🚀}{27:⛵️}{4:一二}{27:三}{4:ひら}{100:が}{4:な}{27:Δέλτα}{4: }{27:Δelta}{4: fooba}│{7:  }{4:🚀}{27:🛸}{4:一二}{27:四}{4:ひらな}{27:δέλτα}{4: }{27:δelta}{4: foobar }|
    {1:~                                    }│{1:~                                    }|*17
    {3:Xdifile1                              }{2:Xdifile2                             }|
                                                                               |
  ]])

  screen:try_resize(69, 20)
  command('wincmd =')
  -- char diff: should slide highlight to whitespace boundary if possible for
  -- better readability (by using forced indent-heuristics). A wrong result
  -- would be if the highlight is "Bar, prefix". It should be "prefixBar, "
  -- instead.
  WriteDiffFiles('prefixFoo, prefixEnd', 'prefixFoo, prefixBar, prefixEnd')
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{4:^prefixFoo, prefixEnd            }│{7:  }{4:prefixFoo, }{100:prefixBar, }{4:prefixEnd }|
    {1:~                                 }│{1:~                                 }|*17
    {3:Xdifile1                           }{2:Xdifile2                          }|
                                                                         |
  ]])

  screen:try_resize(39, 20)
  command('wincmd =')
  -- char diff: small gaps between inline diff blocks will be merged during refine step
  -- - first segment: test that we iteratively merge small gaps after we merged
  --   adjacent blocks, but only with limited number (set to 4) of iterations.
  -- - second and third segments: show that we need a large enough adjacent block to
  --   trigger a merge.
  -- - fourth segment: small gaps are not merged when adjacent large block is
  --   on a different line.
  WriteDiffFiles(
    'abcdefghijklmno\nanchor1\n'
      .. 'abcdefghijklmno\nanchor2\n'
      .. 'abcdefghijklmno\nanchor3\n'
      .. 'test\nmultiline',
    'a?c?e?g?i?k???o\nanchor1\n'
      .. 'a??de?????klmno\nanchor2\n'
      .. 'a??de??????lmno\nanchor3\n'
      .. 't?s?\n??????i?e'
  )
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{4:^a}{27:b}{4:c}{27:defghijklmn}{4:o  }│{7:  }{4:a}{27:?}{4:c}{27:?e?g?i?k???}{4:o  }|
    {7:  }anchor1          │{7:  }anchor1          |
    {7:  }{4:a}{27:bc}{4:de}{27:fghij}{4:klmno  }│{7:  }{4:a}{27:??}{4:de}{27:?????}{4:klmno  }|
    {7:  }anchor2          │{7:  }anchor2          |
    {7:  }{4:a}{27:bcdefghijk}{4:lmno  }│{7:  }{4:a}{27:??de??????}{4:lmno  }|
    {7:  }anchor3          │{7:  }anchor3          |
    {7:  }{4:t}{27:e}{4:s}{27:t}{4:             }│{7:  }{4:t}{27:?}{4:s}{27:?}{4:             }|
    {7:  }{27:multilin}{4:e        }│{7:  }{27:??????i?}{4:e        }|
    {1:~                  }│{1:~                  }|*10
    {3:Xdifile1            }{2:Xdifile2           }|
                                           |
  ]])

  screen:try_resize(49, 20)
  command('wincmd =')
  -- Test multi-line blocks and whitespace
  WriteDiffFiles(
    'this   is   \nsometest text foo\nbaz abc def \none\nword another word\nadditional line',
    'this is some test\ntexts\nfoo bar abX Yef     \noneword another word'
  )
  command('set diffopt=internal,filler diffopt+=inline:char,iwhite')
  screen:expect([[
    {7:  }{4:^this   is             }│{7:  }{4:this is some}{100: }{4:test     }|
    {7:  }{4:sometest text foo     }│{7:  }{4:text}{100:s}{4:                 }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c}{4: }{27:d}{4:ef           }│{7:  }{4:foo ba}{27:r}{4: ab}{27:X}{4: }{27:Y}{4:ef       }|
    {7:  }{4:one                   }│{7:  }{4:oneword another word  }|
    {7:  }{4:word another word     }│{7:  }{23:----------------------}|
    {7:  }{22:additional line       }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {3:Xdifile1                 }{2:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:word,iwhite')
  screen:expect([[
    {7:  }{4:^this   is             }│{7:  }{4:this is }{27:some}{4: }{27:test}{4:     }|
    {7:  }{27:sometest}{4: }{27:text}{4: }{27:foo}{4:     }│{7:  }{27:texts}{4:                 }|
    {7:  }{27:baz}{4: }{27:abc}{4: }{27:def}{4:           }│{7:  }{27:foo}{4: }{27:bar}{4: }{27:abX}{4: }{27:Yef}{4:       }|
    {7:  }{27:one}{4:                   }│{7:  }{27:oneword}{4: another word  }|
    {7:  }{27:word}{4: another word     }│{7:  }{23:----------------------}|
    {7:  }{22:additional line       }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {3:Xdifile1                 }{2:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,iwhiteeol')
  screen:expect([[
    {7:  }{4:^this }{100:  }{4:is             }│{7:  }{4:this is some}{100: }{4:test     }|
    {7:  }{4:sometest text foo     }│{7:  }{4:text}{100:s}{4:                 }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c}{4: }{27:d}{4:ef           }│{7:  }{4:foo ba}{27:r}{4: ab}{27:X}{4: }{27:Y}{4:ef       }|
    {7:  }{4:one                   }│{7:  }{4:oneword another word  }|
    {7:  }{4:word another word     }│{7:  }{23:----------------------}|
    {7:  }{22:additional line       }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {3:Xdifile1                 }{2:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:word,iwhiteeol')
  screen:expect([[
    {7:  }{4:^this }{100:  }{4:is             }│{7:  }{4:this is }{27:some}{4: }{27:test}{4:     }|
    {7:  }{27:sometest}{4: }{27:text}{4: foo     }│{7:  }{27:texts}{4:                 }|
    {7:  }{27:baz}{4: }{27:abc}{4: }{27:def}{4:           }│{7:  }{4:foo }{27:bar}{4: }{27:abX}{4: }{27:Yef}{4:       }|
    {7:  }{27:one}{4:                   }│{7:  }{27:oneword}{4: another word  }|
    {7:  }{27:word}{4: another word     }│{7:  }{23:----------------------}|
    {7:  }{22:additional line       }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {3:Xdifile1                 }{2:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,iwhiteall')
  screen:expect([[
    {7:  }{4:^this   is             }│{7:  }{4:this is some test     }|
    {7:  }{4:sometest text foo     }│{7:  }{4:text}{100:s}{4:                 }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c d}{4:ef           }│{7:  }{4:foo ba}{27:r}{4: ab}{27:X Y}{4:ef       }|
    {7:  }{4:one                   }│{7:  }{4:oneword another word  }|
    {7:  }{4:word another word     }│{7:  }{23:----------------------}|
    {7:  }{22:additional line       }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {3:Xdifile1                 }{2:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:word,iwhiteall')
  screen:expect([[
    {7:  }{4:^this   is             }│{7:  }{4:this is }{27:some test}{4:     }|
    {7:  }{27:sometest text}{4: foo     }│{7:  }{27:texts}{4:                 }|
    {7:  }{27:baz abc def }{4:          }│{7:  }{4:foo }{27:bar abX Yef     }{4:  }|
    {7:  }{27:one}{4:                   }│{7:  }{27:oneword}{4: another word  }|
    {7:  }{27:word}{4: another word     }│{7:  }{23:----------------------}|
    {7:  }{22:additional line       }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {3:Xdifile1                 }{2:Xdifile2                }|
                                                     |
  ]])

  -- newline should be highlighted too when 'list' is set
  command('windo set list listchars=eol:$')
  command('set diffopt=internal,filler diffopt+=inline:char')
  screen:expect([[
    {7:  }{4:this }{100:  }{4:is }{100:  }{103:$}{4:         }│{7:  }{4:^this is some}{100: }{4:test}{101:$}{4:    }|
    {7:  }{4:sometest}{27: }{4:text}{27: }{4:foo}{101:$}{4:    }│{7:  }{4:text}{27:s}{101:$}{4:                }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c}{4: }{27:d}{4:ef }{11:$}{4:         }│{7:  }{4:foo}{27: }{4:ba}{27:r}{4: ab}{27:X}{4: }{27:Y}{4:ef }{100:    }{11:$}{4: }|
    {7:  }{4:one}{103:$}{4:                  }│{7:  }{4:oneword another word}{11:$}{4: }|
    {7:  }{4:word another word}{11:$}{4:    }│{7:  }{23:----------------------}|
    {7:  }{22:additional line}{104:$}{22:      }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {2:Xdifile1                 }{3:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,iwhite')
  screen:expect([[
    {7:  }{4:this   is   }{11:$}{4:         }│{7:  }{4:^this is some}{100: }{4:test}{11:$}{4:    }|
    {7:  }{4:sometest text foo}{11:$}{4:    }│{7:  }{4:text}{100:s}{11:$}{4:                }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c}{4: }{27:d}{4:ef }{11:$}{4:         }│{7:  }{4:foo ba}{27:r}{4: ab}{27:X}{4: }{27:Y}{4:ef     }{11:$}{4: }|
    {7:  }{4:one}{103:$}{4:                  }│{7:  }{4:oneword another word}{11:$}{4: }|
    {7:  }{4:word another word}{11:$}{4:    }│{7:  }{23:----------------------}|
    {7:  }{22:additional line}{104:$}{22:      }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {2:Xdifile1                 }{3:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,iwhiteeol')
  screen:expect([[
    {7:  }{4:this }{100:  }{4:is   }{11:$}{4:         }│{7:  }{4:^this is some}{100: }{4:test}{11:$}{4:    }|
    {7:  }{4:sometest text foo}{11:$}{4:    }│{7:  }{4:text}{100:s}{11:$}{4:                }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c}{4: }{27:d}{4:ef }{11:$}{4:         }│{7:  }{4:foo ba}{27:r}{4: ab}{27:X}{4: }{27:Y}{4:ef     }{11:$}{4: }|
    {7:  }{4:one}{103:$}{4:                  }│{7:  }{4:oneword another word}{11:$}{4: }|
    {7:  }{4:word another word}{11:$}{4:    }│{7:  }{23:----------------------}|
    {7:  }{22:additional line}{104:$}{22:      }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {2:Xdifile1                 }{3:Xdifile2                }|
                                                     |
  ]])
  command('set diffopt=internal,filler diffopt+=inline:char,iwhiteall')
  screen:expect([[
    {7:  }{4:this   is   }{11:$}{4:         }│{7:  }{4:^this is some test}{11:$}{4:    }|
    {7:  }{4:sometest text foo}{11:$}{4:    }│{7:  }{4:text}{100:s}{11:$}{4:                }|
    {7:  }{4:ba}{27:z}{4: ab}{27:c d}{4:ef }{11:$}{4:         }│{7:  }{4:foo ba}{27:r}{4: ab}{27:X Y}{4:ef     }{11:$}{4: }|
    {7:  }{4:one}{11:$}{4:                  }│{7:  }{4:oneword another word}{11:$}{4: }|
    {7:  }{4:word another word}{11:$}{4:    }│{7:  }{23:----------------------}|
    {7:  }{22:additional line}{104:$}{22:      }│{7:  }{23:----------------------}|
    {1:~                       }│{1:~                       }|*12
    {2:Xdifile1                 }{3:Xdifile2                }|
                                                     |
  ]])
  command('windo set nolist')
end)

-- oldtest: Test_diff_inline_multibuffer()
it('diff mode inline highlighting with 3 buffers', function()
  write_file('Xdifile1', '')
  write_file('Xdifile2', '')
  write_file('Xdifile3', '')
  finally(function()
    os.remove('Xdifile1')
    os.remove('Xdifile2')
    os.remove('Xdifile3')
  end)

  local screen = Screen.new(75, 20)
  screen:add_extra_attr_ids({
    [100] = { background = Screen.colors.Blue1 },
  })
  command('args Xdifile1 Xdifile2 Xdifile3 | vert all | windo diffthis | 1wincmd w')
  command('wincmd =')
  command('hi DiffTextAdd guibg=Blue')

  WriteDiffFiles3(
    'That is buffer1.\nanchor\nSome random text\nanchor',
    'This is buffer2.\nanchor\nSome text\nanchor\nbuffer2/3',
    'This is buffer3. Last.\nanchor\nSome more\ntext here.\nanchor\nonly in buffer2/3\nnot in buffer1'
  )
  command('set diffopt=internal,filler diffopt+=inline:char')
  local s1 = [[
    {7:  }{4:^Th}{27:at}{4: is buffer}{27:1}{4:.       }│{7:  }{4:Th}{27:is}{4: is buffer}{27:2}{4:.      }│{7:  }{4:Th}{27:is}{4: is buffer}{27:3. Last}{4:.}|
    {7:  }anchor                 │{7:  }anchor                │{7:  }anchor                |
    {7:  }{4:Some }{27:random }{4:text       }│{7:  }{4:Some text             }│{7:  }{4:Some }{27:more}{4:             }|
    {7:  }{23:-----------------------}│{7:  }{23:----------------------}│{7:  }{4:text}{100: here.}{4:            }|
    {7:  }anchor                 │{7:  }anchor                │{7:  }anchor                |
    {7:  }{23:-----------------------}│{7:  }{4:buffer2/3             }│{7:  }{100:only in }{4:buffer2/3     }|
    {7:  }{23:-----------------------}│{7:  }{23:----------------------}│{7:  }{22:not in buffer1        }|
    {1:~                        }│{1:~                       }│{1:~                       }|*11
    {3:Xdifile1                  }{2:Xdifile2                 Xdifile3                }|
                                                                               |
  ]]
  screen:expect(s1)

  -- Close one of the buffers and make sure it updates correctly
  command('diffoff')
  screen:expect([[
    ^That is buffer1.         │{7:  }{4:This is buffer}{27:2}{4:.      }│{7:  }{4:This is buffer}{27:3. Last}{4:.}|
    anchor                   │{7:  }anchor                │{7:  }anchor                |
    Some random text         │{7:  }{4:Some text             }│{7:  }{4:Some }{100:more}{4:             }|
    anchor                   │{7:  }{23:----------------------}│{7:  }{4:text}{100: here.}{4:            }|
    {1:~                        }│{7:  }anchor                │{7:  }anchor                |
    {1:~                        }│{7:  }{4:buffer2/3             }│{7:  }{100:only in }{4:buffer2/3     }|
    {1:~                        }│{7:  }{23:----------------------}│{7:  }{22:not in buffer1        }|
    {1:~                        }│{1:~                       }│{1:~                       }|*11
    {3:Xdifile1                  }{2:Xdifile2                 Xdifile3                }|
                                                                               |
  ]])

  -- Update text in the non-diff buffer and nothing should be changed
  feed('isometext')
  screen:expect([[
    sometext^That is buffer1. │{7:  }{4:This is buffer}{27:2}{4:.      }│{7:  }{4:This is buffer}{27:3. Last}{4:.}|
    anchor                   │{7:  }anchor                │{7:  }anchor                |
    Some random text         │{7:  }{4:Some text             }│{7:  }{4:Some }{100:more}{4:             }|
    anchor                   │{7:  }{23:----------------------}│{7:  }{4:text}{100: here.}{4:            }|
    {1:~                        }│{7:  }anchor                │{7:  }anchor                |
    {1:~                        }│{7:  }{4:buffer2/3             }│{7:  }{100:only in }{4:buffer2/3     }|
    {1:~                        }│{7:  }{23:----------------------}│{7:  }{22:not in buffer1        }|
    {1:~                        }│{1:~                       }│{1:~                       }|*11
    {3:Xdifile1 [+]              }{2:Xdifile2                 Xdifile3                }|
    {5:-- INSERT --}                                                               |
  ]])
  feed('<Esc>')
  command('silent! undo')

  command('diffthis')
  screen:expect(s1)

  -- Test that removing first buffer from diff will in turn use the next
  -- earliest buffer's iskeyword during word diff.
  WriteDiffFiles3('This+is=a-setence', 'This+is=another-setence', 'That+is=a-setence')
  command('set iskeyword+=+ | 2wincmd w | set iskeyword+=- | 1wincmd w')
  command('set diffopt=internal,filler diffopt+=inline:word')
  local s4 = [[
    {7:  }{27:^This+is}{4:=}{27:a}{4:-setence      }│{7:  }{27:This+is}{4:=}{27:another}{4:-setenc}│{7:  }{27:That+is}{4:=}{27:a}{4:-setence     }|
    {1:~                        }│{1:~                       }│{1:~                       }|*17
    {3:Xdifile1                  }{2:Xdifile2                 Xdifile3                }|
                                                                               |
  ]]
  screen:expect(s4)
  command('diffoff')
  screen:expect([[
    ^This+is=a-setence        │{7:  }{27:This}{4:+is=}{27:another-setenc}│{7:  }{27:That}{4:+is=}{27:a-setence}{4:     }|
    {1:~                        }│{1:~                       }│{1:~                       }|*17
    {3:Xdifile1                  }{2:Xdifile2                 Xdifile3                }|
                                                                               |
  ]])
  command('diffthis')
  screen:expect(s4)

  -- Test multi-buffer char diff refinement, and that removing a buffer from
  -- diff will update the others properly.
  WriteDiffFiles3('abcdefghijkYmYYY', 'aXXdXXghijklmnop', 'abcdefghijkYmYop')
  command('set diffopt=internal,filler diffopt+=inline:char')
  local s6 = [[
    {7:  }{4:^a}{27:bcdef}{4:ghijk}{27:YmYYY}{4:       }│{7:  }{4:a}{27:XXdXX}{4:ghijk}{27:lmnop}{4:      }│{7:  }{4:a}{27:bcdef}{4:ghijk}{27:YmYop}{4:      }|
    {1:~                        }│{1:~                       }│{1:~                       }|*17
    {3:Xdifile1                  }{2:Xdifile2                 Xdifile3                }|
                                                                               |
  ]]
  screen:expect(s6)
  command('diffoff')
  screen:expect([[
    ^abcdefghijkYmYYY         │{7:  }{4:a}{27:XXdXX}{4:ghijk}{27:l}{4:m}{27:n}{4:op      }│{7:  }{4:a}{27:bcdef}{4:ghijk}{27:Y}{4:m}{27:Y}{4:op      }|
    {1:~                        }│{1:~                       }│{1:~                       }|*17
    {3:Xdifile1                  }{2:Xdifile2                 Xdifile3                }|
                                                                               |
  ]])
  command('diffthis')
  screen:expect(s6)
end)

it('diff mode algorithm:histogram and inline:char with long lines #34329', function()
  local screen = Screen.new(55, 20)
  exec([[
    set diffopt=internal,filler,closeoff,algorithm:histogram,inline:char
    cd test/functional/fixtures/diff/
    args inline_char_file1 inline_char_file2
    vert all | windo diffthis | 1wincmd w
  ]])
  screen:expect([[
    {7:  }{27:^aaaa,aaaaaaaa,aaaaaaaaaa,}│{7:  }{27:bbbb,bbbbbbbb,bbbbbbbbbb,}|
    {7:  }{27:aaaaaaa-aaaaaaaaa-aaaaaa-}│{7:  }{27:bbbbbbb-bbbbbbbbb-bbbbbb-}|*11
    {1:~                          }│{1:~                          }|*6
    {3:inline_char_file1           }{2:inline_char_file2          }|
                                                           |
  ]])
  n.assert_alive()
  feed('G$')
  screen:expect([[
    {7:  }{4:                         }│{7:  }{4:                         }|
    {7:  }{27:aa,aa,aa,aa,aa,a,a}{4:"      }│{7:  }{27:,bb,bb,bb,bb,bb,b,b}{4:"     }|
    {7:  }{27:,aa,aa,aa,aa,aa,a}{4:"       }│{7:  }{27:b,bb,bb,bb,bb,bb,bb,b}{4:"   }|
    {7:  }{27:,aa,aa,aa,aa,aa}{4:"         }│{7:  }{27:bb,bb,bb,bb,bb,bb,bb,bb}{4:" }|
    {7:  }{27:a,aa,aa,aa,aa}{4:"           }│{7:  }{27:,bb,b,bb,bb,bb}{4:"          }|
    {7:  }{27:aa,aa,aa,aa,aa}{4:"          }│{7:  }{27:,bb,bb}{4:"                  }|
    {7:  }{27:a,a,a}{4:"                   }│{7:  }{27:b,b,b,b,b}{4:"               }|
    {7:  }{27:a,a,a,a,a}{4:"               }│{7:  }{27:,b,b,b,b,b}{4:"              }|
    {7:  }{27:aa,a,a,a,a,a,a}{4:"          }│{7:  }{27:b,b,b,b,b,b}{4:"             }|
    {7:  }{27:,aa,aa,a,a,a,a,a}{4:"        }│{7:  }{27:bb,b,b,b,b,b}{4:"            }|
    {7:  }{27:aa,aa,aa,aa,a,a,a,a}{4:"     }│{7:  }{27:bb,bb,bb,b,b,b,b}{4:"        }|
    {7:  }{27:,aa,aa,a,a,a}{4:^"            }│{7:  }{27:bb,bb,bb,bb,b,b,b}{4:"       }|
    {1:~                          }│{1:~                          }|*6
    {3:inline_char_file1           }{2:inline_char_file2          }|
                                                           |
  ]])
end)

-- oldtest: Test_linematch_diff()
it([["linematch" in 'diffopt' implies "filler"]], function()
  local screen = Screen.new(55, 20)
  command('set diffopt=internal,filler,closeoff,inline:simple,linematch:30')

  write_file('Xdifile1', '')
  write_file('Xdifile2', '')
  finally(function()
    os.remove('Xdifile1')
    os.remove('Xdifile2')
  end)

  WriteDiffFiles('// d?\n// d?', '!\nabc d!\nd!')
  command('args Xdifile1 Xdifile2 | vert all | windo diffthis | 1wincmd w')
  screen:expect([[
    {7:  }{23:-------------------------}│{7:  }{22:!                        }|
    {7:  }{27:^// d?}{4:                    }│{7:  }{27:abc d!}{4:                   }|
    {7:  }{27:// d?}{4:                    }│{7:  }{27:d!}{4:                       }|
    {1:~                          }│{1:~                          }|*15
    {3:Xdifile1                    }{2:Xdifile2                   }|
                                                           |
  ]])

  -- test that filler is always implicitly set by linematch
  command('set diffopt-=filler')
  screen:expect_unchanged()
end)

describe("'diffanchors'", function()
  local screen

  before_each(function()
    screen = Screen.new(32, 20)
    command('set winwidth=10 nohlsearch shortmess+=s')
  end)

  after_each(function()
    os.remove('Xdifile1')
    os.remove('Xdifile2')
    os.remove('Xdifile3')
  end)

  it('works', function()
    WriteDiffFiles3(
      'anchorA1\n1\n2\n3\n100\n101\n102\nanchorB\n103\n104\n105',
      '100\n101\n102\nanchorB\n103\n104\n105\nanchorA2\n1\n2\n3',
      '100\nanchorB\n103\nanchorA3\n1\n2\n3'
    )
    command('args Xdifile1 Xdifile2 Xdifile3 | vert all | windo diffthis | 1wincmd w')

    -- Simple diff without any anchors
    command('set diffopt=filler,internal')
    local s0 = [[
      {7:  }{22:^anchorA1}│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:1       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:2       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:3       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }100     │{7:  }100     │{7:  }100     |
      {7:  }{22:101     }│{7:  }{22:101     }│{7:  }{23:--------}|
      {7:  }{22:102     }│{7:  }{22:102     }│{7:  }{23:--------}|
      {7:  }anchorB │{7:  }anchorB │{7:  }anchorB |
      {7:  }103     │{7:  }103     │{7:  }103     |
      {7:  }{27:104}{4:     }│{7:  }{27:104}{4:     }│{7:  }{27:anchorA3}|
      {7:  }{4:1}{27:05}{4:     }│{7:  }{4:1}{27:05}{4:     }│{7:  }{4:1       }|
      {7:  }{23:--------}│{7:  }{27:anchorA}{4:2}│{7:  }{4:2       }|
      {7:  }{23:--------}│{7:  }{27:1}{4:       }│{7:  }{27:3}{4:       }|
      {7:  }{23:--------}│{7:  }{22:2       }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:3       }│{7:  }{23:--------}|
      {1:~         }│{1:~         }│{1:~         }|*3
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]]
    screen:expect(s0)

    -- Setting diffopt+=anchor or diffanchors without the other won't do anything
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect_unchanged()
    command('set diffopt=filler,internal dia=1/anchorA/')
    screen:expect_unchanged()

    -- Use a single anchor by specifying a pattern. Test both internal and
    -- external diff to make sure both paths work.
    command('set diffopt=filler dia=1/anchorA/ diffopt+=anchor')
    local s1 = [[
      {7:  }{23:--------}│{7:  }{4:100     }│{7:  }{4:100     }|
      {7:  }{23:--------}│{7:  }{27:101}{4:     }│{7:  }{27:anchorB}{4: }|
      {7:  }{23:--------}│{7:  }{4:10}{27:2}{4:     }│{7:  }{4:10}{27:3}{4:     }|
      {7:  }{23:--------}│{7:  }{22:anchorB }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:103     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:104     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:105     }│{7:  }{23:--------}|
      {7:  }{4:^anchorA}{27:1}│{7:  }{4:anchorA}{27:2}│{7:  }{4:anchorA}{27:3}|
      {7:  }1       │{7:  }1       │{7:  }1       |
      {7:  }2       │{7:  }2       │{7:  }2       |
      {7:  }3       │{7:  }3       │{7:  }3       |
      {7:  }{22:100     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:101     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:102     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:anchorB }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:103     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:104     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:105     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]]
    screen:expect(s1)
    command('set diffopt+=internal')
    screen:expect_unchanged()

    -- Use 2 anchors. They should be sorted by line number, so in file 2/3
    -- anchorB is used before anchorA.
    command('set diffopt=filler dia=1/anchorA/,1/anchorB/ diffopt+=anchor')
    local s2 = [[
      {7:  }{23:--------}│{7:  }{4:100     }│{7:  }{4:100     }|
      {7:  }{23:--------}│{7:  }{22:101     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:102     }│{7:  }{23:--------}|
      {7:  }{4:^anchor}{27:A1}│{7:  }{4:anchor}{27:B}{4: }│{7:  }{4:anchor}{27:B}{4: }|
      {7:  }{4:1       }│{7:  }{4:1}{27:03}{4:     }│{7:  }{4:1}{27:03}{4:     }|
      {7:  }{27:2}{4:       }│{7:  }{27:104}{4:     }│{7:  }{23:--------}|
      {7:  }{27:3}{4:       }│{7:  }{27:105}{4:     }│{7:  }{23:--------}|
      {7:  }{22:100     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:101     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:102     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{4:anchor}{27:B}{4: }│{7:  }{4:anchor}{27:A2}│{7:  }{4:anchor}{27:A3}|
      {7:  }{4:1}{27:03}{4:     }│{7:  }{4:1       }│{7:  }{4:1       }|
      {7:  }{27:104}{4:     }│{7:  }{27:2}{4:       }│{7:  }{27:2}{4:       }|
      {7:  }{27:105}{4:     }│{7:  }{27:3}{4:       }│{7:  }{27:3}{4:       }|
      {1:~         }│{1:~         }│{1:~         }|*4
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]]
    screen:expect(s2)
    command('set diffopt+=internal')
    screen:expect_unchanged()

    -- Set marks and specify addresses using marks and repeat the test
    command('2wincmd w | 1/anchorA/mark a')
    command('1/anchorB/mark b')
    command('3wincmd w | 1/anchorA/mark a')
    command('1/anchorB/mark b')
    command('1wincmd w | 1/anchorA/mark a')
    command('1/anchorB/mark b')

    command("set diffopt=filler,internal dia='a diffopt+=anchor")
    screen:expect(s1)
    command("set diffopt=filler,internal dia='a,'b diffopt+=anchor")
    screen:expect(s2)

    -- Update marks to point somewhere else. When we first set the mark the diff
    -- won't be updated until we manually invoke :diffupdate.
    command("set diffopt=filler,internal dia='a diffopt+=anchor")
    screen:expect(s1)
    command('1wincmd w | 1/anchorB/mark a')
    screen:expect_unchanged()
    command('diffupdate')
    screen:expect([[
      {7:  }{22:^anchorA1}│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:1       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:2       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:3       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }100     │{7:  }100     │{7:  }100     |
      {7:  }{27:101}{4:     }│{7:  }{27:101}{4:     }│{7:  }{27:anchorB}{4: }|
      {7:  }{4:10}{27:2}{4:     }│{7:  }{4:10}{27:2}{4:     }│{7:  }{4:10}{27:3}{4:     }|
      {7:  }{23:--------}│{7:  }{22:anchorB }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:103     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:104     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:105     }│{7:  }{23:--------}|
      {7:  }{4:anchor}{27:B}{4: }│{7:  }{4:anchor}{27:A2}│{7:  }{4:anchor}{27:A3}|
      {7:  }{4:1}{27:03}{4:     }│{7:  }{4:1       }│{7:  }{4:1       }|
      {7:  }{27:104}{4:     }│{7:  }{27:2}{4:       }│{7:  }{27:2}{4:       }|
      {7:  }{27:105}{4:     }│{7:  }{27:3}{4:       }│{7:  }{27:3}{4:       }|
      {1:~         }│{1:~         }│{1:~         }|*3
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])

    -- Use local diff anchors with line numbers, and repeat the same test
    command('2wincmd w | setlocal dia=8')
    command('3wincmd w | setlocal dia=4')
    command('1wincmd w | setlocal dia=1')
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect(s1)
    command('2wincmd w | setlocal dia=8,4')
    command('3wincmd w | setlocal dia=4,2')
    command('1wincmd w | setlocal dia=1,8')
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect(s2)

    -- Test multiple diff anchors on the same line in file 1.
    command('1wincmd w | setlocal dia=1,1')
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect([[
      {7:  }{23:--------}│{7:  }{4:100     }│{7:  }{4:100     }|
      {7:  }{23:--------}│{7:  }{22:101     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:102     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{4:anchorB }│{7:  }{4:anchorB }|
      {7:  }{23:--------}│{7:  }{4:103     }│{7:  }{4:103     }|
      {7:  }{23:--------}│{7:  }{22:104     }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:105     }│{7:  }{23:--------}|
      {7:  }{4:^anchorA}{27:1}│{7:  }{4:anchorA}{27:2}│{7:  }{4:anchorA}{27:3}|
      {7:  }1       │{7:  }1       │{7:  }1       |
      {7:  }2       │{7:  }2       │{7:  }2       |
      {7:  }3       │{7:  }3       │{7:  }3       |
      {7:  }{22:100     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:101     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:102     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:anchorB }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:103     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:104     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:105     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])

    -- Test that if one file has fewer diff anchors than others. Vim should only
    -- use the minimum in this case.
    command('1wincmd w | setlocal dia=8')
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect([[
      {7:  }{22:^anchorA1}│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:1       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:2       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:3       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }100     │{7:  }100     │{7:  }100     |
      {7:  }{22:101     }│{7:  }{22:101     }│{7:  }{23:--------}|
      {7:  }{22:102     }│{7:  }{22:102     }│{7:  }{23:--------}|
      {7:  }anchorB │{7:  }anchorB │{7:  }anchorB |
      {7:  }103     │{7:  }103     │{7:  }103     |
      {7:  }{27:104}{4:     }│{7:  }{27:104}{4:     }│{7:  }{27:anchorA3}|
      {7:  }{4:1}{27:05}{4:     }│{7:  }{4:1}{27:05}{4:     }│{7:  }{4:1       }|
      {7:  }{23:--------}│{7:  }{27:anchorA}{4:2}│{7:  }{4:2       }|
      {7:  }{23:--------}│{7:  }{27:1}{4:       }│{7:  }{27:3}{4:       }|
      {7:  }{23:--------}│{7:  }{22:2       }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:3       }│{7:  }{23:--------}|
      {1:~         }│{1:~         }│{1:~         }|*3
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])

    -- $+1 should anchor everything past the last line
    command('1wincmd w | setlocal dia=$+1')
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect([[
      {7:  }{22:^anchorA1}│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:1       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:2       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:3       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }100     │{7:  }100     │{7:  }100     |
      {7:  }{4:101     }│{7:  }{4:101     }│{7:  }{23:--------}|
      {7:  }{4:102     }│{7:  }{4:102     }│{7:  }{23:--------}|
      {7:  }{22:anchorB }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:103     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:104     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:105     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{4:anchorB }│{7:  }{4:anchorB }|
      {7:  }{23:--------}│{7:  }{4:103     }│{7:  }{4:103     }|
      {7:  }{23:--------}│{7:  }{27:104}{4:     }│{7:  }{27:anchorA3}|
      {7:  }{23:--------}│{7:  }{4:1}{27:05}{4:     }│{7:  }{4:1       }|
      {7:  }{23:--------}│{7:  }{27:anchorA}{4:2}│{7:  }{4:2       }|
      {7:  }{23:--------}│{7:  }{27:1}{4:       }│{7:  }{27:3}{4:       }|
      {7:  }{23:--------}│{7:  }{22:2       }│{7:  }{23:--------}|
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])

    -- Sorting of diff anchors should work with multiple anchors
    command('1wincmd w | setlocal dia=1,10,8,2')
    command('2wincmd w | setlocal dia=1,2,3,4')
    command('3wincmd w | setlocal dia=4,3,2,1')
    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect([[
      {7:  }{27:anchorA1}│{7:  }{27:100}{4:     }│{7:  }{27:^100}{4:     }|
      {7:  }{27:1}{4:       }│{7:  }{27:101}{4:     }│{7:  }{27:anchorB}{4: }|
      {7:  }{22:2       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:3       }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:100     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:101     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{22:102     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{27:anchorB}{4: }│{7:  }{27:102}{4:     }│{7:  }{27:103}{4:     }|
      {7:  }{22:103     }│{7:  }{23:--------}│{7:  }{23:--------}|
      {7:  }{27:104}{4:     }│{7:  }{27:anchorB}{4: }│{7:  }{27:anchorA3}|
      {7:  }{4:1}{27:05}{4:     }│{7:  }{4:1}{27:03}{4:     }│{7:  }{4:1       }|
      {7:  }{23:--------}│{7:  }{27:104}{4:     }│{7:  }{27:2}{4:       }|
      {7:  }{23:--------}│{7:  }{27:105}{4:     }│{7:  }{27:3}{4:       }|
      {7:  }{23:--------}│{7:  }{22:anchorA2}│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:1       }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:2       }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{22:3       }│{7:  }{23:--------}|
      {1:~         }│{1:~         }│{1:~         }|
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])

    -- Intentionally set an invalid anchor with wrong line number. Should fall
    -- back to treat it as if no anchors are used at all.
    command('1wincmd w | setlocal dia=1,10,8,2,1000 | silent! diffupdate')
    screen:expect(s0)
  end)

  -- oldtest: Test_diffanchors_scrollbind_topline()
  it('scrollbind works with adjacent diff blocks', function()
    WriteDiffFiles('anchor1\ndiff1a\nanchor2', 'anchor1\ndiff2a\nanchor2')
    command('args Xdifile1 Xdifile2 | vert all | windo diffthis | 1wincmd w')

    command('1wincmd w | setlocal dia=2')
    command('2wincmd w | setlocal dia=3')

    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect([[
      {7:  }anchor1      │{7:  }^anchor1       |
      {7:  }{23:-------------}│{7:  }{22:diff2a        }|
      {7:  }{22:diff1a       }│{7:  }{23:--------------}|
      {7:  }anchor2      │{7:  }anchor2       |
      {1:~              }│{1:~               }|*14
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{23:-------------}│{7:  }{22:^diff2a        }|
      {7:  }{22:diff1a       }│{7:  }{23:--------------}|
      {7:  }anchor2      │{7:  }anchor2       |
      {1:~              }│{1:~               }|*15
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{22:diff1a       }│{7:  }{23:--------------}|
      {7:  }anchor2      │{7:  }^anchor2       |
      {1:~              }│{1:~               }|*16
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }anchor2      │{7:  }^anchor2       |
      {1:~              }│{1:~               }|*17
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])

    -- Also test no-filler
    feed('gg')
    command('set diffopt=filler,internal diffopt+=anchor diffopt-=filler')
    screen:expect([[
      {7:  }anchor1      │{7:  }^anchor1       |
      {7:  }{22:diff1a       }│{7:  }{22:diff2a        }|
      {7:  }anchor2      │{7:  }anchor2       |
      {1:~              }│{1:~               }|*15
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{22:diff1a       }│{7:  }{22:^diff2a        }|
      {7:  }anchor2      │{7:  }anchor2       |
      {1:~              }│{1:~               }|*16
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }anchor2      │{7:  }^anchor2       |
      {1:~              }│{1:~               }|*17
      {2:Xdifile1        }{3:Xdifile2        }|
                                      |
    ]])
  end)

  -- oldtest: Test_diffanchors_scrollbind_topline2()
  it('scrollbind works with 3 files and overlapping diff blocks', function()
    WriteDiffFiles3(
      'anchor1',
      'diff2a\ndiff2b\ndiff2c\ndiff2d\nanchor2',
      'diff3a\ndiff3c\ndiff3d\nanchor3\ndiff3e'
    )
    command('args Xdifile1 Xdifile2 Xdifile3 | vert all | windo diffthis | 1wincmd w')

    command('1wincmd w | setlocal dia=1,1,2')
    command('2wincmd w | setlocal dia=3,5,6')
    command('3wincmd w | setlocal dia=2,4,5')

    command('set diffopt=filler,internal diffopt+=anchor')
    screen:expect([[
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:a  }│{7:  }{4:^diff}{27:3}{4:a  }|
      {7:  }{23:--------}│{7:  }{22:diff2b  }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:c  }│{7:  }{4:diff}{27:3}{4:c  }|
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:diff}{27:3}{4:d  }|
      {7:  }{4:anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {7:  }{23:--------}│{7:  }{23:--------}│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*12
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])
    command('1wincmd w')
    feed('<C-E>')
    screen:expect([[
      {7:  }{23:--------}│{7:  }{22:diff2b  }│{7:  }{23:--------}|
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:c  }│{7:  }{4:diff}{27:3}{4:c  }|
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:diff}{27:3}{4:d  }|
      {7:  }{4:^anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {7:  }{23:--------}│{7:  }{23:--------}│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*13
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:c  }│{7:  }{4:diff}{27:3}{4:c  }|
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:diff}{27:3}{4:d  }|
      {7:  }{4:^anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {7:  }{23:--------}│{7:  }{23:--------}│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*14
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{23:--------}│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:diff}{27:3}{4:d  }|
      {7:  }{4:^anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {7:  }{23:--------}│{7:  }{23:--------}│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*15
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{4:^anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {7:  }{23:--------}│{7:  }{23:--------}│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*16
      {3:Xdifile1   }{2:Xdifile2   Xdifile3  }|
                                      |
    ]])

    -- Also test no-filler
    command('3wincmd w')
    feed('gg')
    command('set diffopt=filler,internal diffopt+=anchor diffopt-=filler')
    screen:expect([[
      {7:  }{4:anchor}{27:1}{4: }│{7:  }{4:diff}{27:2}{4:a  }│{7:  }{4:^diff}{27:3}{4:a  }|
      {1:~         }│{7:  }{22:diff2b  }│{7:  }{4:diff}{27:3}{4:c  }|
      {1:~         }│{7:  }{4:diff}{27:2}{4:c  }│{7:  }{4:diff}{27:3}{4:d  }|
      {1:~         }│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:anchor}{27:3}{4: }|
      {1:~         }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*13
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{4:anchor}{27:1}{4: }│{7:  }{4:diff}{27:2}{4:c  }│{7:  }{4:^diff}{27:3}{4:c  }|
      {1:~         }│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:diff}{27:3}{4:d  }|
      {1:~         }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {1:~         }│{1:~         }│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*14
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{4:anchor}{27:1}{4: }│{7:  }{4:diff}{27:2}{4:d  }│{7:  }{4:^diff}{27:3}{4:d  }|
      {1:~         }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:anchor}{27:3}{4: }|
      {1:~         }│{1:~         }│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*15
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{4:anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{4:^anchor}{27:3}{4: }|
      {1:~         }│{1:~         }│{7:  }{22:diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*16
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])
    feed('<C-E>')
    screen:expect([[
      {7:  }{4:anchor}{27:1}{4: }│{7:  }{4:anchor}{27:2}{4: }│{7:  }{22:^diff3e  }|
      {1:~         }│{1:~         }│{1:~         }|*17
      {2:Xdifile1   Xdifile2   }{3:Xdifile3  }|
                                      |
    ]])
  end)
end)
