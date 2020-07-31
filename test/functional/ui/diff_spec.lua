local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = helpers.feed
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert
local write_file = helpers.write_file

describe('Diff mode screen', function()
  local fname = 'Xtest-functional-diff-screen-1'
  local fname_2 = fname .. '.2'
  local screen

  local reread = function()
    feed(':e<cr><c-w>w:e<cr><c-w>w')
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
    feed(':e ' .. fname_2 .. '<cr>')
    feed(':vnew ' .. fname .. '<cr>')
    feed(':diffthis<cr>')
    feed('<c-w>w:diffthis<cr><c-w>w')

    screen = Screen.new(40, 16)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
      [2] = {background = Screen.colors.LightCyan1, bold = true, foreground = Screen.colors.Blue1},
      [3] = {reverse = true},
      [4] = {background = Screen.colors.LightBlue},
      [5] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [6] = {bold = true, foreground = Screen.colors.Blue1},
      [7] = {bold = true, reverse = true},
      [8] = {bold = true, background = Screen.colors.Red},
      [9] = {background = Screen.colors.LightMagenta},
    })
  end)

  it('Add a line in beginning of file 2', function()
    write_file(fname, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    write_file(fname_2, "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }{2:------------------}{3:│}{1:  }{4:0                }|
      {1:  }^1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}{3:│}{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }{2:------------------}{3:│}{1:  }{4:0                }|
      {1:  }^1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}{3:│}{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in beginning of file 1', function()
    write_file(fname, "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    write_file(fname_2, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    reread()

    feed(":set diffopt=filler<cr>")
    screen:expect([[
      {1:  }{4:^0                 }{3:│}{1:  }{2:-----------------}|
      {1:  }1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}{3:│}{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(":set diffopt+=internal<cr>")
    screen:expect([[
      {1:  }{4:^0                 }{3:│}{1:  }{2:-----------------}|
      {1:  }1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:+ }{5:+--  4 lines: 7···}{3:│}{1:+ }{5:+--  4 lines: 7··}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line at the end of file 2', function()
    write_file(fname, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    write_file(fname_2, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n", false)
    reread()

    feed(":set diffopt=filler<cr>")
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}{3:│}{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{2:------------------}{3:│}{1:  }{4:11               }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(":set diffopt+=internal<cr>")
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}{3:│}{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{2:------------------}{3:│}{1:  }{4:11               }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line at the end of file 1', function()
    write_file(fname, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n", false)
    write_file(fname_2, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    reread()

    feed(":set diffopt=filler<cr>")
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}{3:│}{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{4:11                }{3:│}{1:  }{2:-----------------}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(":set diffopt+=internal<cr>")
    screen:expect([[
      {1:+ }{5:^+--  4 lines: 1···}{3:│}{1:+ }{5:+--  4 lines: 1··}|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{4:11                }{3:│}{1:  }{2:-----------------}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in the middle of file 2, remove on at the end of file 1', function()
    write_file(fname, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n", false)
    write_file(fname_2, "1\n2\n3\n4\n4\n5\n6\n7\n8\n9\n10\n", false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }^1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }{2:------------------}{3:│}{1:  }{4:4                }|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{4:11                }{3:│}{1:  }{2:-----------------}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }^1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }{2:------------------}{3:│}{1:  }{4:4                }|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{4:11                }{3:│}{1:  }{2:-----------------}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Add a line in the middle of file 1, remove on at the end of file 2', function()
    write_file(fname, "1\n2\n3\n4\n4\n5\n6\n7\n8\n9\n10\n", false)
    write_file(fname_2, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n", false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:  }^1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }{4:4                 }{3:│}{1:  }{2:-----------------}|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{2:------------------}{3:│}{1:  }{4:11               }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }^1                 {3:│}{1:  }1                |
      {1:  }2                 {3:│}{1:  }2                |
      {1:  }3                 {3:│}{1:  }3                |
      {1:  }4                 {3:│}{1:  }4                |
      {1:  }{4:4                 }{3:│}{1:  }{2:-----------------}|
      {1:  }5                 {3:│}{1:  }5                |
      {1:  }6                 {3:│}{1:  }6                |
      {1:  }7                 {3:│}{1:  }7                |
      {1:  }8                 {3:│}{1:  }8                |
      {1:  }9                 {3:│}{1:  }9                |
      {1:  }10                {3:│}{1:  }10               |
      {1:  }{2:------------------}{3:│}{1:  }{4:11               }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
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
        {1:  }^#include <stdio.h>{3:│}{1:  }#include <stdio.h|
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{8:// Frobs foo heart}{3:│}{1:  }{8:int fib(int n)}{9:   }|
        {1:  }{4:int frobnitz(int f}{3:│}{1:  }{2:-----------------}|
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{9:    i}{8:nt i;}{9:        }{3:│}{1:  }{9:    i}{8:f(n > 2)}{9:    }|
        {1:  }{4:    for(i = 0; i <}{3:│}{1:  }{2:-----------------}|
        {1:  }    {             {3:│}{1:  }    {            |
        {1:  }{9:        }{8:printf("Yo}{3:│}{1:  }{9:        }{8:return fi}|
        {1:  }{4:        printf("%d}{3:│}{1:  }{2:-----------------}|
        {1:  }    }             {3:│}{1:  }    }            |
        {1:  }{2:------------------}{3:│}{1:  }{4:    return 1;    }|
        {1:  }}                 {3:│}{1:  }}                |
        {1:  }                  {3:│}{1:  }                 |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])

      feed('G')
      screen:expect([[
        {1:  }{2:------------------}{3:│}{1:  }{4:int frobnitz(int }|
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{9:    i}{8:f(n > 1)}{9:     }{3:│}{1:  }{9:    i}{8:nt i;}{9:       }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    for(i = 0; i }|
        {1:  }    {             {3:│}{1:  }    {            |
        {1:  }{9:        }{8:return fac}{3:│}{1:  }{9:        }{8:printf("%}|
        {1:  }    }             {3:│}{1:  }    }            |
        {1:  }{4:    return 1;     }{3:│}{1:  }{2:-----------------}|
        {1:  }}                 {3:│}{1:  }}                |
        {1:  }                  {3:│}{1:  }                 |
        {1:  }int main(int argc,{3:│}{1:  }int main(int argc|
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{9:    frobnitz(f}{8:act}{9:(}{3:│}{1:  }{9:    frobnitz(f}{8:ib}{9:(}|
        {1:  }^}                 {3:│}{1:  }}                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])
    end)

    it('diffopt+=algorithm:patience', function()
      reread()
      feed(':set diffopt=internal,filler,algorithm:patience<cr>')
      screen:expect([[
        {1:  }^#include <stdio.h>{3:│}{1:  }#include <stdio.h|
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{2:------------------}{3:│}{1:  }{4:int fib(int n)   }|
        {1:  }{2:------------------}{3:│}{1:  }{4:{                }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    if(n > 2)    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    {            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:        return fi}|
        {1:  }{2:------------------}{3:│}{1:  }{4:    }            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    return 1;    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:}                }|
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }// Frobs foo heart{3:│}{1:  }// Frobs foo hear|
        {1:  }int frobnitz(int f{3:│}{1:  }int frobnitz(int |
        {1:  }{                 {3:│}{1:  }{                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])

      feed('G')
      screen:expect([[
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{4:int fact(int n)   }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:{                 }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    if(n > 1)     }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    {             }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:        return fac}{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    }             }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    return 1;     }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:}                 }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:                  }{3:│}{1:  }{2:-----------------}|
        {1:  }int main(int argc,{3:│}{1:  }int main(int argc|
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{9:    frobnitz(f}{8:act}{9:(}{3:│}{1:  }{9:    frobnitz(f}{8:ib}{9:(}|
        {1:  }^}                 {3:│}{1:  }}                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)

    it('diffopt+=algorithm:histogram', function()
      reread()
      feed(':set diffopt=internal,filler,algorithm:histogram<cr>')
      screen:expect([[
        {1:  }^#include <stdio.h>{3:│}{1:  }#include <stdio.h|
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{2:------------------}{3:│}{1:  }{4:int fib(int n)   }|
        {1:  }{2:------------------}{3:│}{1:  }{4:{                }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    if(n > 2)    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    {            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:        return fi}|
        {1:  }{2:------------------}{3:│}{1:  }{4:    }            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    return 1;    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:}                }|
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }// Frobs foo heart{3:│}{1:  }// Frobs foo hear|
        {1:  }int frobnitz(int f{3:│}{1:  }int frobnitz(int |
        {1:  }{                 {3:│}{1:  }{                |
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])

      feed('G')
      screen:expect([[
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{4:int fact(int n)   }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:{                 }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    if(n > 1)     }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    {             }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:        return fac}{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    }             }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:    return 1;     }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:}                 }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:                  }{3:│}{1:  }{2:-----------------}|
        {1:  }int main(int argc,{3:│}{1:  }int main(int argc|
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{9:    frobnitz(f}{8:act}{9:(}{3:│}{1:  }{9:    frobnitz(f}{8:ib}{9:(}|
        {1:  }^}                 {3:│}{1:  }}                |
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
      feed(":set diffopt=internal,filler<cr>")
      screen:expect([[
        {1:  }^def finalize(value{3:│}{1:  }def finalize(valu|
        {1:  }                  {3:│}{1:  }                 |
        {1:  }  values.each do |{3:│}{1:  }  values.each do |
        {1:  }{2:------------------}{3:│}{1:  }{4:    v.prepare    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:  end            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }{2:------------------}{3:│}{1:  }{4:  values.each do }|
        {1:  }    v.finalize    {3:│}{1:  }    v.finalize   |
        {1:  }  end             {3:│}{1:  }  end            |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler            |
      ]])
    end)

    it('indent-heuristic', function()
      reread()
      feed(':set diffopt=internal,filler,indent-heuristic<cr>')
      screen:expect([[
        {1:  }^def finalize(value{3:│}{1:  }def finalize(valu|
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{2:------------------}{3:│}{1:  }{4:  values.each do }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    v.prepare    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:  end            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }  values.each do |{3:│}{1:  }  values.each do |
        {1:  }    v.finalize    {3:│}{1:  }    v.finalize   |
        {1:  }  end             {3:│}{1:  }  end            |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
                                                |
      ]])
    end)

    it('indent-heuristic random order', function()
      reread()
      feed(':set diffopt=internal,filler,indent-heuristic,algorithm:patience<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^def finalize(value{3:│}{1:  }def finalize(valu|
        {1:  }                  {3:│}{1:  }                 |
        {1:  }{2:------------------}{3:│}{1:  }{4:  values.each do }|
        {1:  }{2:------------------}{3:│}{1:  }{4:    v.prepare    }|
        {1:  }{2:------------------}{3:│}{1:  }{4:  end            }|
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }  values.each do |{3:│}{1:  }  values.each do |
        {1:  }    v.finalize    {3:│}{1:  }    v.finalize   |
        {1:  }  end             {3:│}{1:  }  end            |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)
  end)

  it('Diff the same file', function()
    write_file(fname, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    write_file(fname_2, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:+ }{5:^+-- 10 lines: 1···}{3:│}{1:+ }{5:+-- 10 lines: 1··}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:+ }{5:^+-- 10 lines: 1···}{3:│}{1:+ }{5:+-- 10 lines: 1··}|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('Diff an empty file', function()
    write_file(fname, "", false)
    write_file(fname_2, "", false)
    reread()

    feed(':set diffopt=filler<cr>')
    screen:expect([[
      {1:- }^                  {3:│}{1:- }                 |
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler                     |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:- }^                  {3:│}{1:- }                 |
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  it('diffopt+=icase', function()
    write_file(fname, "a\nb\ncd\n", false)
    write_file(fname_2, "A\nb\ncDe\n", false)
    reread()

    feed(':set diffopt=filler,icase<cr>')
    screen:expect([[
      {1:  }^a                 {3:│}{1:  }A                |
      {1:  }b                 {3:│}{1:  }b                |
      {1:  }{9:cd                }{3:│}{1:  }{9:cD}{8:e}{9:              }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt=filler,icase               |
    ]])

    feed(':set diffopt+=internal<cr>')
    screen:expect([[
      {1:  }^a                 {3:│}{1:  }A                |
      {1:  }b                 {3:│}{1:  }b                |
      {1:  }{9:cd                }{3:│}{1:  }{9:cD}{8:e}{9:              }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {6:~                   }{3:│}{6:~                  }|
      {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
      :set diffopt+=internal                  |
    ]])
  end)

  describe('diffopt+=iwhite', function()
    setup(function()
      local f1 = 'int main()\n{\n   printf("Hello, World!");\n   return 0;\n}\n'
      write_file(fname, f1, false)
      local f2 = 'int main()\n{\n   if (0)\n   {\n      printf("Hello, World!");\n      return 0;\n   }\n}\n'
      write_file(fname_2, f2, false)
      feed(':diffupdate!<cr>')
    end)

    it('external', function()
      reread()
      feed(':set diffopt=filler,iwhite<cr>')
      screen:expect([[
        {1:  }^int main()        {3:│}{1:  }int main()       |
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{2:------------------}{3:│}{1:  }{4:   if (0)        }|
        {1:  }{2:------------------}{3:│}{1:  }{4:   {             }|
        {1:  }   printf("Hello, {3:│}{1:  }      printf("Hel|
        {1:  }   return 0;      {3:│}{1:  }      return 0;  |
        {1:  }{2:------------------}{3:│}{1:  }{4:   }             }|
        {1:  }}                 {3:│}{1:  }}                |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=filler,iwhite              |
      ]])
    end)

    it('internal', function()
      reread()
      feed(':set diffopt=filler,iwhite,internal<cr>')
      screen:expect([[
        {1:  }^int main()        {3:│}{1:  }int main()       |
        {1:  }{                 {3:│}{1:  }{                |
        {1:  }{2:------------------}{3:│}{1:  }{4:   if (0)        }|
        {1:  }{2:------------------}{3:│}{1:  }{4:   {             }|
        {1:  }   printf("Hello, {3:│}{1:  }      printf("Hel|
        {1:  }   return 0;      {3:│}{1:  }      return 0;  |
        {1:  }{2:------------------}{3:│}{1:  }{4:   }             }|
        {1:  }}                 {3:│}{1:  }}                |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
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
        {1:  }^a                 {3:│}{1:  }a                |
        {1:  }{4:                  }{3:│}{1:  }{2:-----------------}|
        {1:  }{4:                  }{3:│}{1:  }{2:-----------------}|
        {1:  }cd                {3:│}{1:  }cd               |
        {1:  }ef                {3:│}{1:  }                 |
        {1:  }{8:xxx}{9:               }{3:│}{1:  }ef               |
        {6:~                   }{3:│}{1:  }{8:yyy}{9:              }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :set diffopt=internal,filler,iblank     |
      ]])
    end)

    it('diffopt+=iwhite', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhite<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 {3:│}{1:  }a                |
        {1:  }                  {3:│}{1:  }cd               |
        {1:  }                  {3:│}{1:  }                 |
        {1:  }cd                {3:│}{1:  }ef               |
        {1:  }ef                {3:│}{1:  }{8:yyy}{9:              }|
        {1:  }{8:xxx}{9:               }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhiteall<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 {3:│}{1:  }a                |
        {1:  }                  {3:│}{1:  }cd               |
        {1:  }                  {3:│}{1:  }                 |
        {1:  }cd                {3:│}{1:  }ef               |
        {1:  }ef                {3:│}{1:  }{8:yyy}{9:              }|
        {1:  }{8:xxx}{9:               }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteeol', function()
      reread()
      feed(':set diffopt=internal,filler,iblank,iwhiteeol<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 {3:│}{1:  }a                |
        {1:  }                  {3:│}{1:  }cd               |
        {1:  }                  {3:│}{1:  }                 |
        {1:  }cd                {3:│}{1:  }ef               |
        {1:  }ef                {3:│}{1:  }{8:yyy}{9:              }|
        {1:  }{8:xxx}{9:               }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
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
        {1:  }^a                 {3:│}{1:  }a                |
        {1:  }x                 {3:│}{1:  }x                |
        {1:  }{9:cd                }{3:│}{1:  }{9:c}{8: }{9:d              }|
        {1:  }{9:ef                }{3:│}{1:  }{8: }{9:ef              }|
        {1:  }{9:xx }{8: }{9:xx            }{3:│}{1:  }{9:xx xx            }|
        {1:  }foo               {3:│}{1:  }foo              |
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }bar               {3:│}{1:  }bar              |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)

    it('diffopt+=iwhiteall', function()
      reread()
      feed(':set diffopt=internal,filler,iwhiteall<cr>')
      feed(':<cr>')
      screen:expect([[
        {1:  }^a                 {3:│}{1:  }a                |
        {1:  }x                 {3:│}{1:  }x                |
        {1:  }cd                {3:│}{1:  }c d              |
        {1:  }ef                {3:│}{1:  } ef              |
        {1:  }xx  xx            {3:│}{1:  }xx xx            |
        {1:  }foo               {3:│}{1:  }foo              |
        {1:  }{2:------------------}{3:│}{1:  }{4:                 }|
        {1:  }bar               {3:│}{1:  }bar              |
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {6:~                   }{3:│}{6:~                  }|
        {7:<onal-diff-screen-1  }{3:<l-diff-screen-1.2 }|
        :                                       |
      ]])
    end)
  end)
end)

it('win_update redraws lines properly', function()
  local screen
  clear()
  screen = Screen.new(50, 10)
  screen:attach()
  screen:set_default_attr_ids({
    [1] = {bold = true, foreground = Screen.colors.Blue1},
    [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    [3] = {background = Screen.colors.Red, foreground = Screen.colors.Grey100, special = Screen.colors.Yellow},
    [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
    [5] = {special = Screen.colors.Yellow},
    [6] = {special = Screen.colors.Yellow, bold = true, foreground = Screen.colors.SeaGreen4},
    [7] = {foreground = Screen.colors.Grey0, background = Screen.colors.Grey100},
    [8] = {foreground = Screen.colors.Gray90, background = Screen.colors.Grey100},
    [9] = {foreground = tonumber('0x00000c'), background = Screen.colors.Grey100},
    [10] = {background = Screen.colors.Grey100, bold = true, foreground = tonumber('0xe5e5ff')},
    [11] = {background = Screen.colors.Grey100, bold = true, foreground = tonumber('0x2b8452')},
    [12] = {bold = true, reverse = true},
    [13] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
    [14] = {reverse = true},
    [15] = {background = Screen.colors.LightBlue},
    [16] = {background = Screen.colors.LightCyan1, bold = true, foreground = Screen.colors.Blue1},
    [17] = {bold = true, background = Screen.colors.Red},
    [18] = {background = Screen.colors.LightMagenta},
  })

  insert([[
  1


  2
  1a
  ]])
  command("vnew left")
  insert([[
  2
  2a
  2b
  ]])
  command("windo diffthis")
  command("windo 1")
  screen:expect{grid=[[
    {13:  }{16:-----------------------}{14:│}{13:  }{15:^1                     }|
    {13:  }{16:-----------------------}{14:│}{13:  }{15:                      }|
    {13:  }{16:-----------------------}{14:│}{13:  }{15:                      }|
    {13:  }2                      {14:│}{13:  }2                     |
    {13:  }{17:2}{18:a                     }{14:│}{13:  }{17:1}{18:a                    }|
    {13:  }{15:2b                     }{14:│}{13:  }{16:----------------------}|
    {13:  }                       {14:│}{13:  }                      |
    {1:~                        }{14:│}{1:~                       }|
    {14:left [+]                  }{12:[No Name] [+]           }|
                                                      |
  ]]}
  feed('<C-e>')
  feed('<C-e>')
  feed('<C-y>')
  feed('<C-y>')
  feed('<C-y>')
  screen:expect{grid=[[
    {13:  }{16:-----------------------}{14:│}{13:  }{15:1                     }|
    {13:  }{16:-----------------------}{14:│}{13:  }{15:                      }|
    {13:  }{16:-----------------------}{14:│}{13:  }{15:^                      }|
    {13:  }2                      {14:│}{13:  }2                     |
    {13:  }{17:2}{18:a                     }{14:│}{13:  }{17:1}{18:a                    }|
    {13:  }{15:2b                     }{14:│}{13:  }{16:----------------------}|
    {13:  }                       {14:│}{13:  }                      |
    {1:~                        }{14:│}{1:~                       }|
    {14:left [+]                  }{12:[No Name] [+]           }|
                                                      |
  ]]}
end)
