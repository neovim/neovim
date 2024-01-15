local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = helpers.feed
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert
local write_file = helpers.write_file
local dedent = helpers.dedent
local exec = helpers.exec
local eq = helpers.eq
local api = helpers.api

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
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray },
      [2] = { background = Screen.colors.LightCyan1, bold = true, foreground = Screen.colors.Blue1 },
      [3] = { reverse = true },
      [4] = { background = Screen.colors.LightBlue },
      [5] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey },
      [6] = { bold = true, foreground = Screen.colors.Blue1 },
      [7] = { bold = true, reverse = true },
      [8] = { bold = true, background = Screen.colors.Red },
      [9] = { background = Screen.colors.LightMagenta },
    })
  end)

  it('Add a line in beginning of file 2', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }{2:------------------}│{1:  }{4:0                }|
      {1:  }^1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}│{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }{2:------------------}│{1:  }{4:0                }|
      {1:  }^1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}│{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in beginning of file 1', function()
    write_file(fname, '0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }{4:^0                 }│{1:  }{2:-----------------}|
      {1:  }1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}│{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }{4:^0                 }│{1:  }{2:-----------------}|
      {1:  }1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}│{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line at the end of file 2', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}│{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{2:------------------}│{1:  }{4:11               }|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}│{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{2:------------------}│{1:  }{4:11               }|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])

    screen:try_resize(40, 9)
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}│{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                              |
    ]])
  end)

  it('Add a line at the end of file 1', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}│{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{4:11                }│{1:  }{2:-----------------}|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}│{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{4:11                }│{1:  }{2:-----------------}|
      {6:~                   }│{6:~                  }|*6
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])

    screen:try_resize(40, 9)
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}│{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                              |
    ]])
  end)

  it('Add a line in the middle of file 2, remove on at the end of file 1', function()
    write_file(fname, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    write_file(fname_2, '1\n2\n3\n4\n4\n5\n6\n7\n8\n9\n10\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }^1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }{2:------------------}│{1:  }{4:4                }|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{4:11                }│{1:  }{2:-----------------}|
      {6:~                   }│{6:~                  }|*2
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }^1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }{2:------------------}│{1:  }{4:4                }|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{4:11                }│{1:  }{2:-----------------}|
      {6:~                   }│{6:~                  }|*2
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in the middle of file 1, remove on at the end of file 2', function()
    write_file(fname, '1\n2\n3\n4\n4\n5\n6\n7\n8\n9\n10\n', false)
    write_file(fname_2, '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }^1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }{4:4                 }│{1:  }{2:-----------------}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{2:------------------}│{1:  }{4:11               }|
      {6:~                   }│{6:~                  }|*2
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }^1                 │{1:  }1                |
      {1:  }2                 │{1:  }2                |
      {1:  }3                 │{1:  }3                |
      {1:  }4                 │{1:  }4                |
      {1:  }{4:4                 }│{1:  }{2:-----------------}|
      {1:  }5                 │{1:  }5                |
      {1:  }6                 │{1:  }6                |
      {1:  }7                 │{1:  }7                |
      {1:  }8                 │{1:  }8                |
      {1:  }9                 │{1:  }9                |
      {1:  }10                │{1:  }10               |
      {1:  }{2:------------------}│{1:  }{4:11               }|
      {6:~                   }│{6:~                  }|*2
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^#include <stdio.h>│{1:  }#include <stdio.h|
        {1:  }                  │{1:  }                 |
        {1:  }{8:// Frobs foo heart}│{1:  }{8:int fib(int n)}{9:   }|
        {1:  }{4:int frobnitz(int f}│{1:  }{2:-----------------}|
        {1:  }{                 │{1:  }{                |
        {1:  }{9:    i}{8:nt i;}{9:        }│{1:  }{9:    i}{8:f(n > 2)}{9:    }|
        {1:  }{4:    for(i = 0; i <}│{1:  }{2:-----------------}|
        {1:  }    {             │{1:  }    {            |
        {1:  }{9:        }{8:printf("Yo}│{1:  }{9:        }{8:return fi}|
        {1:  }{4:        printf("%d}│{1:  }{2:-----------------}|
        {1:  }    }             │{1:  }    }            |
        {1:  }{2:------------------}│{1:  }{4:    return 1;    }|
        {1:  }}                 │{1:  }}                |
        {1:  }                  │{1:  }                 |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])

      feed('G')
      screen:expect([[
        {1:  }{2:------------------}│{1:  }{4:int frobnitz(int }|
        {1:  }{                 │{1:  }{                |
        {1:  }{9:    i}{8:f(n > 1)}{9:     }│{1:  }{9:    i}{8:nt i;}{9:       }|
        {1:  }{2:------------------}│{1:  }{4:    for(i = 0; i }|
        {1:  }    {             │{1:  }    {            |
        {1:  }{9:        }{8:return fac}│{1:  }{9:        }{8:printf("%}|
        {1:  }    }             │{1:  }    }            |
        {1:  }{4:    return 1;     }│{1:  }{2:-----------------}|
        {1:  }}                 │{1:  }}                |
        {1:  }                  │{1:  }                 |
        {1:  }int main(int argc,│{1:  }int main(int argc|
        {1:  }{                 │{1:  }{                |
        {1:  }{9:    frobnitz(f}{8:act}{9:(}│{1:  }{9:    frobnitz(f}{8:ib}{9:(}|
        {1:  }^}                 │{1:  }}                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])
    end)

    it('diffopt+=algorithm:patience', function()
      reread()
      feed(':set diffopt=internal,filler,algorithm:patience<cr>')
      screen:expect([[
        {1:  }^#include <stdio.h>│{1:  }#include <stdio.h|
        {1:  }                  │{1:  }                 |
        {1:  }{2:------------------}│{1:  }{4:int fib(int n)   }|
        {1:  }{2:------------------}│{1:  }{4:{                }|
        {1:  }{2:------------------}│{1:  }{4:    if(n > 2)    }|
        {1:  }{2:------------------}│{1:  }{4:    {            }|
        {1:  }{2:------------------}│{1:  }{4:        return fi}|
        {1:  }{2:------------------}│{1:  }{4:    }            }|
        {1:  }{2:------------------}│{1:  }{4:    return 1;    }|
        {1:  }{2:------------------}│{1:  }{4:}                }|
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }// Frobs foo heart│{1:  }// Frobs foo hear|
        {1:  }int frobnitz(int f│{1:  }int frobnitz(int |
        {1:  }{                 │{1:  }{                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])

      feed('G')
      screen:expect([[
        {1:  }                  │{1:  }                 |
        {1:  }{4:int fact(int n)   }│{1:  }{2:-----------------}|
        {1:  }{4:{                 }│{1:  }{2:-----------------}|
        {1:  }{4:    if(n > 1)     }│{1:  }{2:-----------------}|
        {1:  }{4:    {             }│{1:  }{2:-----------------}|
        {1:  }{4:        return fac}│{1:  }{2:-----------------}|
        {1:  }{4:    }             }│{1:  }{2:-----------------}|
        {1:  }{4:    return 1;     }│{1:  }{2:-----------------}|
        {1:  }{4:}                 }│{1:  }{2:-----------------}|
        {1:  }{4:                  }│{1:  }{2:-----------------}|
        {1:  }int main(int argc,│{1:  }int main(int argc|
        {1:  }{                 │{1:  }{                |
        {1:  }{9:    frobnitz(f}{8:act}{9:(}│{1:  }{9:    frobnitz(f}{8:ib}{9:(}|
        {1:  }^}                 │{1:  }}                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)

    it('diffopt+=algorithm:histogram', function()
      reread()
      feed(':set diffopt=internal,filler,algorithm:histogram<cr>')
      screen:expect([[
        {1:  }^#include <stdio.h>│{1:  }#include <stdio.h|
        {1:  }                  │{1:  }                 |
        {1:  }{2:------------------}│{1:  }{4:int fib(int n)   }|
        {1:  }{2:------------------}│{1:  }{4:{                }|
        {1:  }{2:------------------}│{1:  }{4:    if(n > 2)    }|
        {1:  }{2:------------------}│{1:  }{4:    {            }|
        {1:  }{2:------------------}│{1:  }{4:        return fi}|
        {1:  }{2:------------------}│{1:  }{4:    }            }|
        {1:  }{2:------------------}│{1:  }{4:    return 1;    }|
        {1:  }{2:------------------}│{1:  }{4:}                }|
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }// Frobs foo heart│{1:  }// Frobs foo hear|
        {1:  }int frobnitz(int f│{1:  }int frobnitz(int |
        {1:  }{                 │{1:  }{                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])

      feed('G')
      screen:expect([[
        {1:  }                  │{1:  }                 |
        {1:  }{4:int fact(int n)   }│{1:  }{2:-----------------}|
        {1:  }{4:{                 }│{1:  }{2:-----------------}|
        {1:  }{4:    if(n > 1)     }│{1:  }{2:-----------------}|
        {1:  }{4:    {             }│{1:  }{2:-----------------}|
        {1:  }{4:        return fac}│{1:  }{2:-----------------}|
        {1:  }{4:    }             }│{1:  }{2:-----------------}|
        {1:  }{4:    return 1;     }│{1:  }{2:-----------------}|
        {1:  }{4:}                 }│{1:  }{2:-----------------}|
        {1:  }{4:                  }│{1:  }{2:-----------------}|
        {1:  }int main(int argc,│{1:  }int main(int argc|
        {1:  }{                 │{1:  }{                |
        {1:  }{9:    frobnitz(f}{8:act}{9:(}│{1:  }{9:    frobnitz(f}{8:ib}{9:(}|
        {1:  }^}                 │{1:  }}                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^def finalize(value│{1:  }def finalize(valu|
        {1:  }                  │{1:  }                 |
        {1:  }  values.each do |│{1:  }  values.each do |
        {1:  }{2:------------------}│{1:  }{4:    v.prepare    }|
        {1:  }{2:------------------}│{1:  }{4:  end            }|
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }{2:------------------}│{1:  }{4:  values.each do }|
        {1:  }    v.finalize    │{1:  }    v.finalize   |
        {1:  }  end             │{1:  }  end            |
        {6:~                   }│{6:~                  }|*5
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])
    end)

    it('indent-heuristic', function()
      reread()
      feed(':set diffopt=internal,filler,indent-heuristic<cr>')
      screen:expect([[
        {1:  }^def finalize(value│{1:  }def finalize(valu|
        {1:  }                  │{1:  }                 |
        {1:  }{2:------------------}│{1:  }{4:  values.each do }|
        {1:  }{2:------------------}│{1:  }{4:    v.prepare    }|
        {1:  }{2:------------------}│{1:  }{4:  end            }|
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }  values.each do |│{1:  }  values.each do |
        {1:  }    v.finalize    │{1:  }    v.finalize   |
        {1:  }  end             │{1:  }  end            |
        {6:~                   }│{6:~                  }|*5
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)

    it('indent-heuristic random order', function()
      reread()
      feed(':set diffopt=internal,filler,indent-heuristic,algorithm:patience<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^def finalize(value│{1:  }def finalize(valu|
        {1:  }                  │{1:  }                 |
        {1:  }{2:------------------}│{1:  }{4:  values.each do }|
        {1:  }{2:------------------}│{1:  }{4:    v.prepare    }|
        {1:  }{2:------------------}│{1:  }{4:  end            }|
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }  values.each do |│{1:  }  values.each do |
        {1:  }    v.finalize    │{1:  }    v.finalize   |
        {1:  }  end             │{1:  }  end            |
        {6:~                   }│{6:~                  }|*5
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
      {1:+ }{5:^+-- 10 lines: 1···}│{1:+ }{5:+-- 10 lines: 1··}|
      {6:~                   }│{6:~                  }|*13
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:+ }{5:^+-- 10 lines: 1···}│{1:+ }{5:+-- 10 lines: 1··}|
      {6:~                   }│{6:~                  }|*13
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Diff an empty file', function()
    write_file(fname, '', false)
    write_file(fname_2, '', false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:- }^                  │{1:- }                 |
      {6:~                   }│{6:~                  }|*13
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:- }^                  │{1:- }                 |
      {6:~                   }│{6:~                  }|*13
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('diffopt+=icase', function()
    write_file(fname, 'a\nb\ncd\n', false)
    write_file(fname_2, 'A\nb\ncDe\n', false)
    reread()

    feed(':set diffopt=filler,icase<cr>')
    screen:expect([[
      {1:  }^a                 │{1:  }A                |
      {1:  }b                 │{1:  }b                |
      {1:  }{9:cd                }│{1:  }{9:cD}{8:e}{9:              }|
      {6:~                   }│{6:~                  }|*11
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler,icase               |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }^a                 │{1:  }A                |
      {1:  }b                 │{1:  }b                |
      {1:  }{9:cd                }│{1:  }{9:cD}{8:e}{9:              }|
      {6:~                   }│{6:~                  }|*11
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^int main()        │{1:  }int main()       |
        {1:  }{                 │{1:  }{                |
        {1:  }{2:------------------}│{1:  }{4:   if (0)        }|
        {1:  }{2:------------------}│{1:  }{4:   {             }|
        {1:  }   printf("Hello, │{1:  }      printf("Hel|
        {1:  }   return 0;      │{1:  }      return 0;  |
        {1:  }{2:------------------}│{1:  }{4:   }             }|
        {1:  }}                 │{1:  }}                |
        {6:~                   }│{6:~                  }|*6
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=filler,iwhite              |
      ]])
    end)

    it('internal', function()
      reread()
      feed(':set diffopt=filler,iwhite,internal<cr>')
      screen:expect([[
        {1:  }^int main()        │{1:  }int main()       |
        {1:  }{                 │{1:  }{                |
        {1:  }{2:------------------}│{1:  }{4:   if (0)        }|
        {1:  }{2:------------------}│{1:  }{4:   {             }|
        {1:  }   printf("Hello, │{1:  }      printf("Hel|
        {1:  }   return 0;      │{1:  }      return 0;  |
        {1:  }{2:------------------}│{1:  }{4:   }             }|
        {1:  }}                 │{1:  }}                |
        {6:~                   }│{6:~                  }|*6
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^a                 │{1:  }a                |
        {1:  }{4:                  }│{1:  }{2:-----------------}|*2
        {1:  }cd                │{1:  }cd               |
        {1:  }ef                │{1:  }                 |
        {1:  }{8:xxx}{9:               }│{1:  }ef               |
        {6:~                   }│{1:  }{8:yyy}{9:              }|
        {6:~                   }│{6:~                  }|*7
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler,iblank     |
      ]])
    end)

    it('diffopt+=iwhite', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhite<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 │{1:  }a                |
        {1:  }                  │{1:  }cd               |
        {1:  }                  │{1:  }                 |
        {1:  }cd                │{1:  }ef               |
        {1:  }ef                │{1:  }{8:yyy}{9:              }|
        {1:  }{8:xxx}{9:               }│{6:~                  }|
        {6:~                   }│{6:~                  }|*8
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhiteall<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 │{1:  }a                |
        {1:  }                  │{1:  }cd               |
        {1:  }                  │{1:  }                 |
        {1:  }cd                │{1:  }ef               |
        {1:  }ef                │{1:  }{8:yyy}{9:              }|
        {1:  }{8:xxx}{9:               }│{6:~                  }|
        {6:~                   }│{6:~                  }|*8
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteeol', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhiteeol<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 │{1:  }a                |
        {1:  }                  │{1:  }cd               |
        {1:  }                  │{1:  }                 |
        {1:  }cd                │{1:  }ef               |
        {1:  }ef                │{1:  }{8:yyy}{9:              }|
        {1:  }{8:xxx}{9:               }│{6:~                  }|
        {6:~                   }│{6:~                  }|*8
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^a                 │{1:  }a                |
        {1:  }x                 │{1:  }x                |
        {1:  }{9:cd                }│{1:  }{9:c}{8: }{9:d              }|
        {1:  }{9:ef                }│{1:  }{8: }{9:ef              }|
        {1:  }{9:xx }{8: }{9:xx            }│{1:  }{9:xx xx            }|
        {1:  }foo               │{1:  }foo              |
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }bar               │{1:  }bar              |
        {6:~                   }│{6:~                  }|*6
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,iwhiteall<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 │{1:  }a                |
        {1:  }x                 │{1:  }x                |
        {1:  }cd                │{1:  }c d              |
        {1:  }ef                │{1:  } ef              |
        {1:  }xx  xx            │{1:  }xx xx            |
        {1:  }foo               │{1:  }foo              |
        {1:  }{2:------------------}│{1:  }{4:                 }|
        {1:  }bar               │{1:  }bar              |
        {6:~                   }│{6:~                  }|*6
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
      {1:  }line 1           │{1:  }line 1            |
      {1:  }line 2           │{1:  }line 2            |
      {1:  }line 3           │{1:  }line 3            |
      {1:  }line 4           │{1:  }line 4            |
      {1:  }                 │{1:  }^                  |
      {1:  }{2:-----------------}│{1:  }{4:Lorem             }|
      {1:  }{2:-----------------}│{1:  }{4:ipsum             }|
      {1:  }{2:-----------------}│{1:  }{4:dolor             }|
      {1:  }{2:-----------------}│{1:  }{4:sit               }|
      {1:  }{2:-----------------}│{1:  }{4:amet,             }|
      {3:<nal-diff-screen-1  }{7:<al-diff-screen-1.2 }|
      :e                                      |
    ]])
    feed('j')
    screen:expect([[
      {1:  }line 1           │{1:  }line 1            |
      {1:  }line 2           │{1:  }line 2            |
      {1:  }line 3           │{1:  }line 3            |
      {1:  }line 4           │{1:  }line 4            |
      {1:  }                 │{1:  }                  |
      {1:  }{2:-----------------}│{1:  }{4:^Lorem             }|
      {1:  }{2:-----------------}│{1:  }{4:ipsum             }|
      {1:  }{2:-----------------}│{1:  }{4:dolor             }|
      {1:  }{2:-----------------}│{1:  }{4:sit               }|
      {1:  }{2:-----------------}│{1:  }{4:amet,             }|
      {3:<nal-diff-screen-1  }{7:<al-diff-screen-1.2 }|
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
  {1:  }^if __name__ == "__│{1:  }if __name__ == "_|
  {1:  }    import sys    │{1:  }    import sys   |
  {1:  }{9:    }{8:app = QWidgets}│{1:  }{9:    }{8:comment these}|
  {1:  }{9:    }{8:MainWindow = Q}│{1:  }{9:    }{8:#app = QWidge}|
  {1:  }{9:    }{8:ui = UI_}{9:MainWi}│{1:  }{9:    }{8:#MainWindow =}|
  {1:  }{2:------------------}│{1:  }{4:    add a complet}|
  {1:  }{2:------------------}│{1:  }{4:    #ui = UI_Main}|
  {1:  }{2:------------------}│{1:  }{4:    add another n}|
  {1:  }    ui.setupUI(Mai│{1:  }    ui.setupUI(Ma|
  {1:  }    MainWindow.sho│{1:  }    MainWindow.sh|
  {1:  }    sys.exit(app.e│{1:  }    sys.exit(app.|
  {6:~                   }│{6:~                  }|*3
  {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
  :set diffopt=internal,filler            |
      ]])

      feed('G')
      feed(':set diffopt+=linematch:20<cr>')
      screen:expect([[
        {1:  }if __name__ == "__│{1:  }if __name__ == "_|
        {1:  }    import sys    │{1:  }    import sys   |
        {1:  }{2:------------------}│{1:  }{4:    comment these}|
        {1:  }{9:    app = QWidgets}│{1:  }{9:    }{8:#}{9:app = QWidge}|
        {1:  }{9:    MainWindow = Q}│{1:  }{9:    }{8:#}{9:MainWindow =}|
        {1:  }{2:------------------}│{1:  }{4:    add a complet}|
        {1:  }{9:    ui = UI_MainWi}│{1:  }{9:    }{8:#}{9:ui = UI_Main}|
        {1:  }{2:------------------}│{1:  }{4:    add another n}|
        {1:  }    ui.setupUI(Mai│{1:  }    ui.setupUI(Ma|
        {1:  }    MainWindow.sho│{1:  }    MainWindow.sh|
        {1:  }    ^sys.exit(app.e│{1:  }    sys.exit(app.|
        {6:~                   }│{6:~                  }|*3
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^DDD               │{1:  }DDD              |
        {1:  }{2:------------------}│{1:  }{4:AAA              }|
        {1:  }{8:_a}{9:a               }│{1:  }{8:ccc}{9:a             }|
        {6:~                   }│{6:~                  }|*11
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])
      feed(':set diffopt+=icase<cr>')
      screen:expect([[
        {1:  }^DDD               │{1:  }DDD              |
        {1:  }{8:_}{9:aa               }│{1:  }{8:A}{9:AA              }|
        {1:  }{2:------------------}│{1:  }{4:ccca             }|
        {6:~                   }│{6:~                  }|*11
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
        {1:  }^BB                │{1:  }BB               |
        {1:  }{9:   AA}{8:A}{9:            }│{1:  }{9:   AA}{8:B}{9:           }|
        {1:  }{2:------------------}│{1:  }{4:AAAB             }|
        {6:~                   }│{6:~                  }|*11
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]],
      }
      feed(':set diffopt+=iwhiteall<cr>')
      screen:expect {
        grid = [[
        {1:  }^BB                │{1:  }BB               |
        {1:  }{2:------------------}│{1:  }{4:   AAB           }|
        {1:  }{9:   AAA            }│{1:  }{9:AAA}{8:B}{9:             }|
        {6:~                   }│{6:~                  }|*11
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
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
      {1:  }aaa               │{1:  }aaa              |
      {1:  }bbb               │{1:  }bbb              |
      {1:  }ccc               │{1:  }ccc              |
      {1:  }                  │{1:  }                 |
      {1:  }{8:xx}{9:                }│{1:  }{8:yy}{9:               }|
      {6:~                   }│{6:~                  }|
      {3:<onal-diff-screen-1  <l-diff-screen-1.2 }|
      ^                                        |
      {6:~                                       }|*6
      {7:[No Name]                               }|
      :e                                      |
    ]],
    }

    api.nvim_buf_set_lines(buf, 1, 2, true, { 'BBB' })
    screen:expect {
      grid = [[
      {1:  }aaa               │{1:  }aaa              |
      {1:  }{8:BBB}{9:               }│{1:  }{8:bbb}{9:              }|
      {1:  }ccc               │{1:  }ccc              |
      {1:  }                  │{1:  }                 |
      {1:  }{8:xx}{9:                }│{1:  }{8:yy}{9:               }|
      {6:~                   }│{6:~                  }|
      {3:<-diff-screen-1 [+]  <l-diff-screen-1.2 }|
      ^                                        |
      {6:~                                       }|*6
      {7:[No Name]                               }|
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
      {1:  }aaa               │{1:  }aaa              |
      {1:  }bbb               │{1:  }bbb              |
      {1:  }ccc               │{1:  }ccc              |
      {1:  }                  │{1:  }                 |
      {1:  }{8:xx}{9:                }│{1:  }{8:yy}{9:               }|
      {6:~                   }│{6:~                  }|
      {3:<onal-diff-screen-1  <l-diff-screen-1.2 }|
      ^aaa                                     |
      bbb                                     |
      ccc                                     |
                                              |
      xx                                      |
      {6:~                                       }|*2
      {7:Xtest-functional-diff-screen-1          }|
      :e                                      |
    ]],
    }

    api.nvim_buf_set_lines(buf, 1, 2, true, { 'BBB' })
    screen:expect {
      grid = [[
      {1:  }aaa               │{1:  }aaa              |
      {1:  }{8:BBB}{9:               }│{1:  }{8:bbb}{9:              }|
      {1:  }ccc               │{1:  }ccc              |
      {1:  }                  │{1:  }                 |
      {1:  }{8:xx}{9:                }│{1:  }{8:yy}{9:               }|
      {6:~                   }│{6:~                  }|
      {3:<-diff-screen-1 [+]  <l-diff-screen-1.2 }|
      ^aaa                                     |
      BBB                                     |
      ccc                                     |
                                              |
      xx                                      |
      {6:~                                       }|*2
      {7:Xtest-functional-diff-screen-1 [+]      }|
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
  screen:set_default_attr_ids({
    [1] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray },
    [2] = { background = Screen.colors.LightCyan1, bold = true, foreground = Screen.colors.Blue1 },
    [3] = { reverse = true },
    [4] = { background = Screen.colors.LightBlue },
    [5] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey },
    [6] = { bold = true, foreground = Screen.colors.Blue1 },
    [7] = { bold = true, reverse = true },
    [8] = { bold = true, background = Screen.colors.Red },
    [9] = { background = Screen.colors.LightMagenta },
    [10] = { bold = true, foreground = Screen.colors.Brown },
    [11] = { foreground = Screen.colors.Brown },
  })
  exec([[
    call setline(1, ['a', 'a', 'a', 'y', 'b', 'b', 'b', 'b', 'b'])
    vnew
    call setline(1, ['a', 'a', 'a', 'x', 'x', 'x', 'b', 'b', 'b', 'b', 'b'])
    windo diffthis
    setlocal number rnu cursorline cursorlineopt=number foldcolumn=0
  ]])
  screen:expect([[
    {1:  }a                │{10:1   }^a               |
    {1:  }a                │{11:  1 }a               |
    {1:  }a                │{11:  2 }a               |
    {1:  }{8:x}{9:                }│{11:  3 }{8:y}{9:               }|
    {1:  }{4:x                }│{11:    }{2:----------------}|*2
    {1:  }b                │{11:  4 }b               |
    {1:  }b                │{11:  5 }b               |
    {1:  }b                │{11:  6 }b               |
    {1:  }b                │{11:  7 }b               |
    {1:  }b                │{11:  8 }b               |
    {6:~                  }│{6:~                   }|
    {3:[No Name] [+]       }{7:[No Name] [+]       }|
                                            |
  ]])
  feed('j')
  screen:expect([[
    {1:  }a                │{11:  1 }a               |
    {1:  }a                │{10:2   }^a               |
    {1:  }a                │{11:  1 }a               |
    {1:  }{8:x}{9:                }│{11:  2 }{8:y}{9:               }|
    {1:  }{4:x                }│{11:    }{2:----------------}|*2
    {1:  }b                │{11:  3 }b               |
    {1:  }b                │{11:  4 }b               |
    {1:  }b                │{11:  5 }b               |
    {1:  }b                │{11:  6 }b               |
    {1:  }b                │{11:  7 }b               |
    {6:~                  }│{6:~                   }|
    {3:[No Name] [+]       }{7:[No Name] [+]       }|
                                            |
  ]])
  feed('j')
  screen:expect([[
    {1:  }a                │{11:  2 }a               |
    {1:  }a                │{11:  1 }a               |
    {1:  }a                │{10:3   }^a               |
    {1:  }{8:x}{9:                }│{11:  1 }{8:y}{9:               }|
    {1:  }{4:x                }│{11:    }{2:----------------}|*2
    {1:  }b                │{11:  2 }b               |
    {1:  }b                │{11:  3 }b               |
    {1:  }b                │{11:  4 }b               |
    {1:  }b                │{11:  5 }b               |
    {1:  }b                │{11:  6 }b               |
    {6:~                  }│{6:~                   }|
    {3:[No Name] [+]       }{7:[No Name] [+]       }|
                                            |
  ]])
end)

-- oldtest: Test_diff_with_scroll_and_change()
it('Align the filler lines when changing text in diff mode', function()
  local screen = Screen.new(40, 20)
  screen:attach()
  screen:set_default_attr_ids({
    [1] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Gray },
    [2] = { background = Screen.colors.LightCyan, foreground = Screen.colors.Blue1, bold = true },
    [3] = { reverse = true },
    [4] = { background = Screen.colors.LightBlue },
    [5] = { background = Screen.colors.LightMagenta },
    [6] = { background = Screen.colors.Red, bold = true },
    [7] = { foreground = Screen.colors.Blue1, bold = true },
    [8] = { reverse = true, bold = true },
  })
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
    {1:  }{2:------------------}│{1:  }{4:6                }|
    {1:  }{2:------------------}│{1:  }{4:7                }|
    {1:  }{2:------------------}│{1:  }{4:8                }|
    {1:  }9                 │{1:  }9                |
    {1:  }10                │{1:  }10               |
    {1:  }11                │{1:  }11               |
    {1:  }12                │{1:  }12               |
    {1:  }13                │{1:  }13               |
    {1:  }14                │{1:  }14               |
    {1:- }1^5                │{1:- }15               |
    {7:~                   }│{7:~                  }|*8
    {8:[No Name] [+]        }{3:[No Name] [+]      }|
                                            |
  ]],
  }
  feed('ax<Esc>')
  screen:expect {
    grid = [[
    {1:  }{2:------------------}│{1:  }{4:6                }|
    {1:  }{2:------------------}│{1:  }{4:7                }|
    {1:  }{2:------------------}│{1:  }{4:8                }|
    {1:  }9                 │{1:  }9                |
    {1:  }10                │{1:  }10               |
    {1:  }11                │{1:  }11               |
    {1:  }12                │{1:  }12               |
    {1:  }13                │{1:  }13               |
    {1:  }14                │{1:  }14               |
    {1:  }{5:15}{6:^x}{5:               }│{1:  }{5:15               }|
    {7:~                   }│{7:~                  }|*8
    {8:[No Name] [+]        }{3:[No Name] [+]      }|
                                            |
  ]],
  }
  feed('<C-W>lay<Esc>')
  screen:expect {
    grid = [[
    {1:  }{2:-----------------}│{1:  }{4:6                 }|
    {1:  }{2:-----------------}│{1:  }{4:7                 }|
    {1:  }{2:-----------------}│{1:  }{4:8                 }|
    {1:  }9                │{1:  }9                 |
    {1:  }10               │{1:  }10                |
    {1:  }11               │{1:  }11                |
    {1:  }12               │{1:  }12                |
    {1:  }13               │{1:  }13                |
    {1:  }14               │{1:  }14                |
    {1:  }{5:15}{6:x}{5:              }│{1:  }{5:15}{6:^y}{5:               }|
    {7:~                  }│{7:~                   }|*8
    {3:[No Name] [+]       }{8:[No Name] [+]       }|
                                            |
  ]],
  }
end)

it("diff mode doesn't restore invalid 'foldcolumn' value #21647", function()
  local screen = Screen.new(60, 6)
  screen:set_default_attr_ids({
    [0] = { foreground = Screen.colors.Blue, bold = true },
  })
  screen:attach()
  eq('0', api.nvim_get_option_value('foldcolumn', {}))
  command('diffsplit | bd')
  screen:expect([[
    ^                                                            |
    {0:~                                                           }|*4
                                                                |
  ]])
  eq('0', api.nvim_get_option_value('foldcolumn', {}))
end)

-- oldtest: Test_diff_binary()
it('diff mode works properly if file contains NUL bytes vim-patch:8.2.3925', function()
  local screen = Screen.new(40, 20)
  screen:set_default_attr_ids({
    [1] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Gray },
    [2] = { reverse = true },
    [3] = { background = Screen.colors.LightBlue },
    [4] = { background = Screen.colors.LightMagenta },
    [5] = { background = Screen.colors.Red, bold = true },
    [6] = { foreground = Screen.colors.Blue, bold = true },
    [7] = { background = Screen.colors.Red, foreground = Screen.colors.Blue, bold = true },
    [8] = { reverse = true, bold = true },
  })
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
    {1:  }{5:^A}{4:                 }│{1:  }{5:a}{4:                }|
    {1:  }b                 │{1:  }b                |
    {1:  }{4:c                 }│{1:  }{4:c}{7:^@}{4:              }|
    {1:  }d                 │{1:  }d                |
    {1:  }{5:E}{4:                 }│{1:  }{5:e}{4:                }|
    {1:  }f                 │{1:  }f                |
    {1:  }g                 │{1:  }g                |
    {6:~                   }│{6:~                  }|*11
    {8:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])

  -- Test using internal diff and case folding
  command('set diffopt+=icase')
  feed('<C-L>')
  screen:expect([[
    {1:  }^A                 │{1:  }a                |
    {1:  }b                 │{1:  }b                |
    {1:  }{4:c                 }│{1:  }{4:c}{7:^@}{4:              }|
    {1:  }d                 │{1:  }d                |
    {1:  }E                 │{1:  }e                |
    {1:  }f                 │{1:  }f                |
    {1:  }g                 │{1:  }g                |
    {6:~                   }│{6:~                  }|*11
    {8:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])

  -- Test using external diff
  command('set diffopt=filler')
  feed('<C-L>')
  screen:expect([[
    {1:  }{5:^A}{4:                 }│{1:  }{5:a}{4:                }|
    {1:  }b                 │{1:  }b                |
    {1:  }{4:c                 }│{1:  }{4:c}{7:^@}{4:              }|
    {1:  }d                 │{1:  }d                |
    {1:  }{5:E}{4:                 }│{1:  }{5:e}{4:                }|
    {1:  }f                 │{1:  }f                |
    {1:  }g                 │{1:  }g                |
    {6:~                   }│{6:~                  }|*11
    {8:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])

  -- Test using external diff and case folding
  command('set diffopt+=filler,icase')
  feed('<C-L>')
  screen:expect([[
    {1:  }^A                 │{1:  }a                |
    {1:  }b                 │{1:  }b                |
    {1:  }{4:c                 }│{1:  }{4:c}{7:^@}{4:              }|
    {1:  }d                 │{1:  }d                |
    {1:  }E                 │{1:  }e                |
    {1:  }f                 │{1:  }f                |
    {1:  }g                 │{1:  }g                |
    {6:~                   }│{6:~                  }|*11
    {8:[No Name] [+]        }{2:[No Name] [+]      }|
                                            |
  ]])
end)

-- oldtest: Test_diff_breakindent_after_filler()
it("diff mode draws 'breakindent' correctly after filler lines", function()
  local screen = Screen.new(45, 8)
  screen:attach()
  screen:set_default_attr_ids({
    [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue },
    [2] = { background = Screen.colors.LightBlue },
    [3] = { background = Screen.colors.LightCyan, bold = true, foreground = Screen.colors.Blue },
    [4] = { foreground = Screen.colors.Blue, bold = true },
  })
  exec([[
    set laststatus=0 diffopt+=followwrap breakindent
    call setline(1, ['a', '  ' .. repeat('c', 50)])
    vnew
    call setline(1, ['a', 'b', '  ' .. repeat('c', 50)])
    windo diffthis
    norm! G$
  ]])
  screen:expect([[
    {1:  }a                   │{1:  }a                   |
    {1:  }{2:b                   }│{1:  }{3:--------------------}|
    {1:  }  cccccccccccccccccc│{1:  }  cccccccccccccccccc|*2
    {1:  }  cccccccccccccc    │{1:  }  ccccccccccccc^c    |
    {4:~                     }│{4:~                     }|*2
                                                 |
  ]])
end)
