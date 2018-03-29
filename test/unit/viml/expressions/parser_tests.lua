local global_helpers = require('test.helpers')

local REMOVE_THIS = global_helpers.REMOVE_THIS

return function(itp, _check_parsing, hl, fmtn)
  local function check_parsing(...)
    return _check_parsing({flags={0, 1, 2, 3}, funcname='check_parsing'}, ...)
  end
  local function check_asgn_parsing(...)
    return _check_parsing({
      flags={4, 5, 6, 7},
      funcname='check_asgn_parsing',
    }, ...)
  end
  itp('works with + and @a', function()
    check_parsing('@a', {
      ast = {
        'Register(name=a):0:0:@a',
      },
    }, {
      hl('Register', '@a'),
    })
    check_parsing('+@a', {
      ast = {
        {
          'UnaryPlus:0:0:+',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
    })
    check_parsing('@a+@b', {
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:3:@b',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('@a+@b+@c', {
      ast = {
        {
          'BinaryPlus:0:5:+',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Register(name=a):0:0:@a',
                'Register(name=b):0:3:@b',
              },
            },
            'Register(name=c):0:6:@c',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
      hl('BinaryPlus', '+'),
      hl('Register', '@c'),
    })
    check_parsing('+@a+@b', {
      ast = {
        {
          'BinaryPlus:0:3:+',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:4:@b',
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('+@a++@b', {
      ast = {
        {
          'BinaryPlus:0:3:+',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              'UnaryPlus:0:4:+',
              children = {
                'Register(name=b):0:5:@b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('UnaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('@a@b', {
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:2:@b',
          },
        },
      },
      err = {
        arg = '@b',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidRegister', '@b'),
    }, {
      [1] = {
        ast = {
          len = 2,
          err = REMOVE_THIS,
          ast = {
            'Register(name=a):0:0:@a'
          },
        },
        hl_fs = {
          [2] = REMOVE_THIS,
        },
      },
    })
    check_parsing(' @a \t @b', {
      ast = {
        {
          'OpMissing:0:3:',
          children = {
            'Register(name=a):0:0: @a',
            'Register(name=b):0:3: \t @b',
          },
        },
      },
      err = {
        arg = '@b',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a', 1),
      hl('InvalidSpacing', ' \t '),
      hl('Register', '@b'),
    }, {
      [1] = {
        ast = {
          len = 6,
          err = REMOVE_THIS,
          ast = {
            'Register(name=a):0:0: @a'
          },
        },
        hl_fs = {
          [2] = REMOVE_THIS,
          [3] = REMOVE_THIS,
        },
      },
    })
    check_parsing('+', {
      ast = {
        'UnaryPlus:0:0:+',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryPlus', '+'),
    })
    check_parsing(' +', {
      ast = {
        'UnaryPlus:0:0: +',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryPlus', '+', 1),
    })
    check_parsing('@a+  ', {
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
    })
  end)
  itp('works with @a, + and parenthesis', function()
    check_parsing('(@a)', {
      ast = {
        {
          'Nested:0:0:(',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
    })
    check_parsing('()', {
      ast = {
        {
          'Nested:0:0:(',
          children = {
            'Missing:0:1:',
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing(')', {
      ast = {
        {
          'Nested:0:0:',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing('+)', {
      ast = {
        {
          'Nested:0:1:',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'Missing:0:1:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing('+@a(@b)', {
      ast = {
        {
          'UnaryPlus:0:0:+',
          children = {
            {
              'Call:0:3:(',
              children = {
                'Register(name=a):0:1:@a',
                'Register(name=b):0:4:@b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a+@b(@c)', {
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:5:(',
              children = {
                'Register(name=b):0:3:@b',
                'Register(name=c):0:6:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a()', {
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a ()', {
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Nested:0:2: (',
              children = {
                'Missing:0:4:',
              },
            },
          },
        },
      },
      err = {
        arg = '()',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidSpacing', ' '),
      hl('NestingParenthesis', '('),
      hl('InvalidNestingParenthesis', ')'),
    }, {
      [1] = {
        ast = {
          len = 3,
          err = REMOVE_THIS,
          ast = {
            'Register(name=a):0:0:@a',
          },
        },
        hl_fs = {
          [2] = REMOVE_THIS,
          [3] = REMOVE_THIS,
          [4] = REMOVE_THIS,
        },
      },
    })
    check_parsing('@a + (@b)', {
      ast = {
        {
          'BinaryPlus:0:2: +',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Nested:0:4: (',
              children = {
                'Register(name=b):0:6:@b',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+', 1),
      hl('NestingParenthesis', '(', 1),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
    })
    check_parsing('@a + (+@b)', {
      ast = {
        {
          'BinaryPlus:0:2: +',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Nested:0:4: (',
              children = {
                {
                  'UnaryPlus:0:6:+',
                  children = {
                    'Register(name=b):0:7:@b',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+', 1),
      hl('NestingParenthesis', '(', 1),
      hl('UnaryPlus', '+'),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
    })
    check_parsing('@a + (@b + @c)', {
      ast = {
        {
          'BinaryPlus:0:2: +',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Nested:0:4: (',
              children = {
                {
                  'BinaryPlus:0:8: +',
                  children = {
                    'Register(name=b):0:6:@b',
                    'Register(name=c):0:10: @c',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+', 1),
      hl('NestingParenthesis', '(', 1),
      hl('Register', '@b'),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@c', 1),
      hl('NestingParenthesis', ')'),
    })
    check_parsing('(@a)+@b', {
      ast = {
        {
          'BinaryPlus:0:4:+',
          children = {
            {
              'Nested:0:0:(',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:5:@b',
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('@a+(@b)(@c)', {
      --           01234567890
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:7:(',
              children = {
                {
                  'Nested:0:3:(',
                  children = { 'Register(name=b):0:4:@b' },
                },
                'Register(name=c):0:8:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a+((@b))(@c)', {
      --           01234567890123456890123456789
      --           0         1        2
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:9:(',
              children = {
                {
                  'Nested:0:3:(',
                  children = {
                    {
                      'Nested:0:4:(',
                      children = { 'Register(name=b):0:5:@b' }
                    },
                  },
                },
                'Register(name=c):0:10:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('NestingParenthesis', '('),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a+((@b))+@c', {
      --           01234567890123456890123456789
      --           0         1        2
      ast = {
        {
          'BinaryPlus:0:9:+',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Register(name=a):0:0:@a',
                {
                  'Nested:0:3:(',
                  children = {
                    {
                      'Nested:0:4:(',
                      children = { 'Register(name=b):0:5:@b' }
                    },
                  },
                },
              },
            },
            'Register(name=c):0:10:@c',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('NestingParenthesis', '('),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
      hl('NestingParenthesis', ')'),
      hl('BinaryPlus', '+'),
      hl('Register', '@c'),
    })
    check_parsing(
      '@a + (@b + @c) + @d(@e) + (+@f) + ((+@g(@h))(@j)(@k))(@l)', {--[[
       | | | | | |   | |  ||  | | ||  | | ||| ||   ||  ||   ||
       000000000011111111112222222222333333333344444444445555555
       012345678901234567890123456789012345678901234567890123456
      ]]
        ast = {{
          'BinaryPlus:0:31: +',
          children = {
            {
              'BinaryPlus:0:23: +',
              children = {
                {
                  'BinaryPlus:0:14: +',
                  children = {
                    {
                      'BinaryPlus:0:2: +',
                      children = {
                        'Register(name=a):0:0:@a',
                        {
                          'Nested:0:4: (',
                          children = {
                            {
                              'BinaryPlus:0:8: +',
                              children = {
                                'Register(name=b):0:6:@b',
                                'Register(name=c):0:10: @c',
                              },
                            },
                          },
                        },
                      },
                    },
                    {
                      'Call:0:19:(',
                      children = {
                        'Register(name=d):0:16: @d',
                        'Register(name=e):0:20:@e',
                      },
                    },
                  },
                },
                {
                  'Nested:0:25: (',
                  children = {
                    {
                      'UnaryPlus:0:27:+',
                      children = {
                        'Register(name=f):0:28:@f',
                      },
                    },
                  },
                },
              },
            },
            {
              'Call:0:53:(',
              children = {
                {
                  'Nested:0:33: (',
                  children = {
                    {
                      'Call:0:48:(',
                      children = {
                        {
                          'Call:0:44:(',
                          children = {
                            {
                              'Nested:0:35:(',
                              children = {
                                {
                                  'UnaryPlus:0:36:+',
                                  children = {
                                    {
                                      'Call:0:39:(',
                                      children = {
                                        'Register(name=g):0:37:@g',
                                        'Register(name=h):0:40:@h',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                            'Register(name=j):0:45:@j',
                          },
                        },
                        'Register(name=k):0:49:@k',
                      },
                    },
                  },
                },
                'Register(name=l):0:54:@l',
              },
            },
          },
        }},
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Register', '@b'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@c', 1),
        hl('NestingParenthesis', ')'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@d', 1),
        hl('CallingParenthesis', '('),
        hl('Register', '@e'),
        hl('CallingParenthesis', ')'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('UnaryPlus', '+'),
        hl('Register', '@f'),
        hl('NestingParenthesis', ')'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('NestingParenthesis', '('),
        hl('UnaryPlus', '+'),
        hl('Register', '@g'),
        hl('CallingParenthesis', '('),
        hl('Register', '@h'),
        hl('CallingParenthesis', ')'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@j'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@k'),
        hl('CallingParenthesis', ')'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@l'),
        hl('CallingParenthesis', ')'),
      })
    check_parsing('@a)', {
      --           012
      ast = {
        {
          'Nested:0:2:',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Unexpected closing parenthesis: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing('(@a', {
      --           012
      ast = {
        {
          'Nested:0:0:(',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
      err = {
        arg = '(@a',
        msg = 'E110: Missing closing parenthesis for nested expression: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
    })
    check_parsing('@a(@b', {
      --           01234
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:3:@b',
          },
        },
      },
      err = {
        arg = '(@b',
        msg = 'E116: Missing closing parenthesis for function call: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
    })
    check_parsing('@a(@b, @c, @d, @e)', {
      --           012345678901234567
      --           0         1
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Comma:0:5:,',
              children = {
                'Register(name=b):0:3:@b',
                {
                  'Comma:0:9:,',
                  children = {
                    'Register(name=c):0:6: @c',
                    {
                      'Comma:0:13:,',
                      children = {
                        'Register(name=d):0:10: @d',
                        'Register(name=e):0:14: @e',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c', 1),
      hl('Comma', ','),
      hl('Register', '@d', 1),
      hl('Comma', ','),
      hl('Register', '@e', 1),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a(@b(@c))', {
      --           01234567890123456789012345678901234567
      --           0         1         2         3
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:5:(',
              children = {
                'Register(name=b):0:3:@b',
                'Register(name=c):0:6:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a(@b(@c(@d(@e), @f(@g(@h), @i(@j)))))', {
      --           01234567890123456789012345678901234567
      --           0         1         2         3
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:5:(',
              children = {
                'Register(name=b):0:3:@b',
                {
                  'Call:0:8:(',
                  children = {
                    'Register(name=c):0:6:@c',
                    {
                      'Comma:0:15:,',
                      children = {
                        {
                          'Call:0:11:(',
                          children = {
                            'Register(name=d):0:9:@d',
                            'Register(name=e):0:12:@e',
                          },
                        },
                        {
                          'Call:0:19:(',
                          children = {
                            'Register(name=f):0:16: @f',
                            {
                              'Comma:0:26:,',
                              children = {
                                {
                                  'Call:0:22:(',
                                  children = {
                                    'Register(name=g):0:20:@g',
                                    'Register(name=h):0:23:@h',
                                  },
                                },
                                {
                                  'Call:0:30:(',
                                  children = {
                                    'Register(name=i):0:27: @i',
                                    'Register(name=j):0:31:@j',
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', '('),
      hl('Register', '@d'),
      hl('CallingParenthesis', '('),
      hl('Register', '@e'),
      hl('CallingParenthesis', ')'),
      hl('Comma', ','),
      hl('Register', '@f', 1),
      hl('CallingParenthesis', '('),
      hl('Register', '@g'),
      hl('CallingParenthesis', '('),
      hl('Register', '@h'),
      hl('CallingParenthesis', ')'),
      hl('Comma', ','),
      hl('Register', '@i', 1),
      hl('CallingParenthesis', '('),
      hl('Register', '@j'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('()()', {
      --           0123
      ast = {
        {
          'Call:0:2:(',
          children = {
            {
              'Nested:0:0:(',
              children = {
                'Missing:0:1:',
              },
            },
          },
        },
      },
      err = {
        arg = ')()',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidNestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('(@a)()', {
      --           012345
      ast = {
        {
          'Call:0:4:(',
          children = {
            {
              'Nested:0:0:(',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('(@a)(@b)', {
      --           01234567
      ast = {
        {
          'Call:0:4:(',
          children = {
            {
              'Nested:0:0:(',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:5:@b',
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('(@a) (@b)', {
      --           012345678
      ast = {
        {
          'OpMissing:0:4:',
          children = {
            {
              'Nested:0:0:(',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              'Nested:0:4: (',
              children = {
                'Register(name=b):0:6:@b',
              },
            },
          },
        },
      },
      err = {
        arg = '(@b)',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
      hl('InvalidSpacing', ' '),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
    }, {
      [1] = {
        ast = {
          len = 5,
          ast = {
            {
              'Nested:0:0:(',
              children = {
                'Register(name=a):0:1:@a',
                REMOVE_THIS,
              },
            },
          },
          err = REMOVE_THIS,
        },
        hl_fs = {
          [4] = REMOVE_THIS,
          [5] = REMOVE_THIS,
          [6] = REMOVE_THIS,
          [7] = REMOVE_THIS,
        },
      },
    })
  end)
  itp('works with variable names, including curly braces ones', function()
    check_parsing('var', {
        ast = {
          'PlainIdentifier(scope=0,ident=var):0:0:var',
        },
    }, {
      hl('IdentifierName', 'var'),
    })
    check_parsing('g:var', {
        ast = {
          'PlainIdentifier(scope=g,ident=var):0:0:g:var',
        },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('IdentifierName', 'var'),
    })
    check_parsing('g:', {
        ast = {
          'PlainIdentifier(scope=g,ident=):0:0:g:',
        },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
    })
    check_parsing('{a}', {
      --           012
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierName', 'a'),
      hl('Curly', '}'),
    })
    check_parsing('{a:b}', {
      --           012
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            'PlainIdentifier(scope=a,ident=b):0:1:a:b',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
    })
    check_parsing('{a:@b}', {
      --           012345
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            {
              'OpMissing:0:3:',
              children={
                'PlainIdentifier(scope=a,ident=):0:1:a:',
                'Register(name=b):0:3:@b',
              },
            },
          },
        },
      },
      err = {
        arg = '@b}',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('InvalidRegister', '@b'),
      hl('Curly', '}'),
    })
    check_parsing('{@a}', {
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
    })
    check_parsing('{@a}{@b}', {
      --           01234567
      ast = {
        {
          'ComplexIdentifier:0:4:',
          children = {
            {
              fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              fmtn('CurlyBracesIdentifier', '--i', ':0:4:{'),
              children = {
                'Register(name=b):0:5:@b',
              },
            },
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('Register', '@b'),
      hl('Curly', '}'),
    })
    check_parsing('g:{@a}', {
      --           01234567
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=g,ident=):0:0:g:',
            {
              fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
              children = {
                'Register(name=a):0:3:@a',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
    })
    check_parsing('{@a}_test', {
      --           012345678
      ast = {
        {
          'ComplexIdentifier:0:4:',
          children = {
            {
              fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'PlainIdentifier(scope=0,ident=_test):0:4:_test',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('IdentifierName', '_test'),
    })
    check_parsing('g:{@a}_test', {
      --           01234567890
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=g,ident=):0:0:g:',
            {
              'ComplexIdentifier:0:6:',
              children = {
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
                  children = {
                    'Register(name=a):0:3:@a',
                  },
                },
                'PlainIdentifier(scope=0,ident=_test):0:6:_test',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('IdentifierName', '_test'),
    })
    check_parsing('g:{@a}_test()', {
      --           0123456789012
      ast = {
        {
          'Call:0:11:(',
          children = {
            {
              'ComplexIdentifier:0:2:',
              children = {
                'PlainIdentifier(scope=g,ident=):0:0:g:',
                {
                  'ComplexIdentifier:0:6:',
                  children = {
                    {
                      fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
                      children = {
                        'Register(name=a):0:3:@a',
                      },
                    },
                    'PlainIdentifier(scope=0,ident=_test):0:6:_test',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('IdentifierName', '_test'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('{@a} ()', {
      --           0123456789012
      ast = {
        {
          'Call:0:4: (',
          children = {
            {
              fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
              children = {
                'Register(name=a):0:1:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('CallingParenthesis', '(', 1),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('g:{@a} ()', {
      --           0123456789012
      ast = {
        {
          'Call:0:6: (',
          children = {
            {
              'ComplexIdentifier:0:2:',
              children = {
                'PlainIdentifier(scope=g,ident=):0:0:g:',
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
                  children = {
                    'Register(name=a):0:3:@a',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('CallingParenthesis', '(', 1),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('{@a', {
      --           012
      ast = {
        {
          fmtn('UnknownFigure', '-di', ':0:0:{'),
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
      err = {
        arg = '{@a',
        msg = 'E15: Missing closing figure brace: %.*s',
      },
    }, {
      hl('FigureBrace', '{'),
      hl('Register', '@a'),
    })
    check_parsing('a ()', {
      --           0123
      ast = {
        {
          'Call:0:1: (',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('CallingParenthesis', '(', 1),
      hl('CallingParenthesis', ')'),
    })
  end)
  itp('works with lambdas and dictionaries', function()
    check_parsing('{}', {
      ast = {
        fmtn('DictLiteral', '-di', ':0:0:{'),
      },
    }, {
      hl('Dict', '{'),
      hl('Dict', '}'),
    })
    check_parsing('{->@a}', {
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Arrow:0:1:->',
              children = {
                'Register(name=a):0:3:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{->@a+@b}', {
      --           012345678
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Arrow:0:1:->',
              children = {
                {
                  'BinaryPlus:0:5:+',
                  children = {
                    'Register(name=a):0:3:@a',
                    'Register(name=b):0:6:@b',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
      hl('Lambda', '}'),
    })
    check_parsing('{a->@a}', {
      --           012345678
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
            {
              'Arrow:0:2:->',
              children = {
                'Register(name=a):0:4:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b->@a}', {
      --           012345678
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                'Register(name=a):0:6:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b,c->@a}', {
      --           01234567890
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:4:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3:b',
                    'PlainIdentifier(scope=0,ident=c):0:5:c',
                  },
                },
              },
            },
            {
              'Arrow:0:6:->',
              children = {
                'Register(name=a):0:8:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Comma', ','),
      hl('IdentifierName', 'c'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b,c,d->@a}', {
      --           0123456789012
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:4:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3:b',
                    {
                      'Comma:0:6:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:5:c',
                        'PlainIdentifier(scope=0,ident=d):0:7:d',
                      },
                    },
                  },
                },
              },
            },
            {
              'Arrow:0:8:->',
              children = {
                'Register(name=a):0:10:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Comma', ','),
      hl('IdentifierName', 'c'),
      hl('Comma', ','),
      hl('IdentifierName', 'd'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b,c,d,->@a}', {
      --           01234567890123
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:4:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3:b',
                    {
                      'Comma:0:6:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:5:c',
                        {
                          'Comma:0:8:,',
                          children = {
                            'PlainIdentifier(scope=0,ident=d):0:7:d',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            {
              'Arrow:0:9:->',
              children = {
                'Register(name=a):0:11:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Comma', ','),
      hl('IdentifierName', 'c'),
      hl('Comma', ','),
      hl('IdentifierName', 'd'),
      hl('Comma', ','),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b->{c,d->{e,f->@a}}}', {
      --           01234567890123456789012
      --           0         1         2
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                {
                  fmtn('Lambda', '\\di', ':0:6:{'),
                  children = {
                    {
                      'Comma:0:8:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:7:c',
                        'PlainIdentifier(scope=0,ident=d):0:9:d',
                      },
                    },
                    {
                      'Arrow:0:10:->',
                      children = {
                        {
                          fmtn('Lambda', '\\di', ':0:12:{'),
                          children = {
                            {
                              'Comma:0:14:,',
                              children = {
                                'PlainIdentifier(scope=0,ident=e):0:13:e',
                                'PlainIdentifier(scope=0,ident=f):0:15:f',
                              },
                            },
                            {
                              'Arrow:0:16:->',
                              children = {
                                'Register(name=a):0:18:@a',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Arrow', '->'),
      hl('Lambda', '{'),
      hl('IdentifierName', 'c'),
      hl('Comma', ','),
      hl('IdentifierName', 'd'),
      hl('Arrow', '->'),
      hl('Lambda', '{'),
      hl('IdentifierName', 'e'),
      hl('Comma', ','),
      hl('IdentifierName', 'f'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
      hl('Lambda', '}'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b->c,d}', {
      --           0123456789
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                {
                  'Comma:0:7:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:6:c',
                    'PlainIdentifier(scope=0,ident=d):0:8:d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ',d}',
        msg = 'E15: Comma outside of call, lambda or literal: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Arrow', '->'),
      hl('IdentifierName', 'c'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'd'),
      hl('Lambda', '}'),
    })
    check_parsing('a,b,c,d', {
      --           0123456789
      ast = {
        {
          'Comma:0:1:,',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comma:0:3:,',
              children = {
              'PlainIdentifier(scope=0,ident=b):0:2:b',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                    'PlainIdentifier(scope=0,ident=d):0:6:d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ',b,c,d',
        msg = 'E15: Comma outside of call, lambda or literal: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'b'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'c'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'd'),
    })
    check_parsing('a,b,c,d,', {
      --           0123456789
      ast = {
        {
          'Comma:0:1:,',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comma:0:3:,',
              children = {
              'PlainIdentifier(scope=0,ident=b):0:2:b',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                    {
                      'Comma:0:7:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=d):0:6:d',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ',b,c,d,',
        msg = 'E15: Comma outside of call, lambda or literal: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'b'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'c'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'd'),
      hl('InvalidComma', ','),
    })
    check_parsing(',', {
      --           0123456789
      ast = {
        {
          'Comma:0:0:,',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = ',',
        msg = 'E15: Expected value, got comma: %.*s',
      },
    }, {
      hl('InvalidComma', ','),
    })
    check_parsing('{,a->@a}', {
      --           0123456789
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            {
              'Arrow:0:3:->',
              children = {
                {
                  'Comma:0:1:,',
                  children = {
                    'Missing:0:1:',
                    'PlainIdentifier(scope=0,ident=a):0:2:a',
                  },
                },
                'Register(name=a):0:5:@a',
              },
            },
          },
        },
      },
      err = {
        arg = ',a->@a}',
        msg = 'E15: Expected value, got comma: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('InvalidComma', ','),
      hl('IdentifierName', 'a'),
      hl('InvalidArrow', '->'),
      hl('Register', '@a'),
      hl('Curly', '}'),
    })
    check_parsing('}', {
      --           0123456789
      ast = {
        fmtn('UnknownFigure', '---', ':0:0:'),
      },
      err = {
        arg = '}',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('InvalidFigureBrace', '}'),
    })
    check_parsing('{->}', {
      --           0123456789
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            'Arrow:0:1:->',
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected value, got closing figure brace: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('InvalidLambda', '}'),
    })
    check_parsing('{a,b}', {
      --           0123456789
      ast = {
        {
          fmtn('Lambda', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected lambda arguments list or arrow: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('InvalidLambda', '}'),
    })
    check_parsing('{a,}', {
      --           0123456789
      ast = {
        {
          fmtn('Lambda', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected lambda arguments list or arrow: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('InvalidLambda', '}'),
    })
    check_parsing('{@a:@b}', {
      --           0123456789
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Colon:0:3::',
              children = {
                'Register(name=a):0:1:@a',
                'Register(name=b):0:4:@b',
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Dict', '}'),
    })
    check_parsing('{@a:@b,@c:@d}', {
      --           0123456789012
      --           0         1
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
                {
                  'Colon:0:9::',
                  children = {
                    'Register(name=c):0:7:@c',
                    'Register(name=d):0:10:@d',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c'),
      hl('Colon', ':'),
      hl('Register', '@d'),
      hl('Dict', '}'),
    })
    check_parsing('{@a:@b,@c:@d,@e:@f,}', {
      --           01234567890123456789
      --           0         1
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
                {
                  'Comma:0:12:,',
                  children = {
                    {
                      'Colon:0:9::',
                      children = {
                        'Register(name=c):0:7:@c',
                        'Register(name=d):0:10:@d',
                      },
                    },
                    {
                      'Comma:0:18:,',
                      children = {
                        {
                          'Colon:0:15::',
                          children = {
                            'Register(name=e):0:13:@e',
                            'Register(name=f):0:16:@f',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c'),
      hl('Colon', ':'),
      hl('Register', '@d'),
      hl('Comma', ','),
      hl('Register', '@e'),
      hl('Colon', ':'),
      hl('Register', '@f'),
      hl('Comma', ','),
      hl('Dict', '}'),
    })
    check_parsing('{@a:@b,@c:@d,@e:@f,@g:}', {
      --           01234567890123456789012
      --           0         1         2
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
                {
                  'Comma:0:12:,',
                  children = {
                    {
                      'Colon:0:9::',
                      children = {
                        'Register(name=c):0:7:@c',
                        'Register(name=d):0:10:@d',
                      },
                    },
                    {
                      'Comma:0:18:,',
                      children = {
                        {
                          'Colon:0:15::',
                          children = {
                            'Register(name=e):0:13:@e',
                            'Register(name=f):0:16:@f',
                          },
                        },
                        {
                          'Colon:0:21::',
                          children = {
                            'Register(name=g):0:19:@g',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected value, got closing figure brace: %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c'),
      hl('Colon', ':'),
      hl('Register', '@d'),
      hl('Comma', ','),
      hl('Register', '@e'),
      hl('Colon', ':'),
      hl('Register', '@f'),
      hl('Comma', ','),
      hl('Register', '@g'),
      hl('Colon', ':'),
      hl('InvalidDict', '}'),
    })
    check_parsing('{@a:@b,}', {
      --           01234567890123
      --           0         1
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Dict', '}'),
    })
    check_parsing('{({f -> g})(@h)(@i)}', {
      --           01234567890123456789
      --           0         1
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            {
              'Call:0:15:(',
              children = {
                {
                  'Call:0:11:(',
                  children = {
                    {
                      'Nested:0:1:(',
                      children = {
                        {
                          fmtn('Lambda', '\\di', ':0:2:{'),
                          children = {
                            'PlainIdentifier(scope=0,ident=f):0:3:f',
                            {
                              'Arrow:0:4: ->',
                              children = {
                                'PlainIdentifier(scope=0,ident=g):0:7: g',
                              },
                            },
                          },
                        },
                      },
                    },
                    'Register(name=h):0:12:@h',
                  },
                },
                'Register(name=i):0:16:@i',
              },
            },
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('NestingParenthesis', '('),
      hl('Lambda', '{'),
      hl('IdentifierName', 'f'),
      hl('Arrow', '->', 1),
      hl('IdentifierName', 'g', 1),
      hl('Lambda', '}'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@h'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@i'),
      hl('CallingParenthesis', ')'),
      hl('Curly', '}'),
    })
    check_parsing('a:{b()}c', {
      --           01234567
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=a,ident=):0:0:a:',
            {
              'ComplexIdentifier:0:7:',
              children = {
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
                  children = {
                    {
                      'Call:0:4:(',
                      children = {
                        'PlainIdentifier(scope=0,ident=b):0:3:b',
                      },
                    },
                  },
                },
                'PlainIdentifier(scope=0,ident=c):0:7:c',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
      hl('Curly', '}'),
      hl('IdentifierName', 'c'),
    })
    check_parsing('a:{{b, c -> @d + @e + ({f -> g})(@h)}(@i)}j', {
      --           01234567890123456789012345678901234567890123456
      --           0         1         2         3         4
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=a,ident=):0:0:a:',
            {
              'ComplexIdentifier:0:42:',
              children = {
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
                  children = {
                    {
                      'Call:0:37:(',
                      children = {
                        {
                          fmtn('Lambda', '\\di', ':0:3:{'),
                          children = {
                            {
                              'Comma:0:5:,',
                              children = {
                                'PlainIdentifier(scope=0,ident=b):0:4:b',
                                'PlainIdentifier(scope=0,ident=c):0:6: c',
                              },
                            },
                            {
                              'Arrow:0:8: ->',
                              children = {
                                {
                                  'BinaryPlus:0:19: +',
                                  children = {
                                    {
                                      'BinaryPlus:0:14: +',
                                      children = {
                                        'Register(name=d):0:11: @d',
                                        'Register(name=e):0:16: @e',
                                      },
                                    },
                                    {
                                      'Call:0:32:(',
                                      children = {
                                        {
                                          'Nested:0:21: (',
                                          children = {
                                            {
                                              fmtn('Lambda', '\\di', ':0:23:{'),
                                              children = {
                                                'PlainIdentifier(scope=0,ident=f):0:24:f',
                                                {
                                                  'Arrow:0:25: ->',
                                                  children = {
                                                    'PlainIdentifier(scope=0,ident=g):0:28: g',
                                                  },
                                                },
                                              },
                                            },
                                          },
                                        },
                                        'Register(name=h):0:33:@h',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                        'Register(name=i):0:38:@i',
                      },
                    },
                  },
                },
                'PlainIdentifier(scope=0,ident=j):0:42:j',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Lambda', '{'),
      hl('IdentifierName', 'b'),
      hl('Comma', ','),
      hl('IdentifierName', 'c', 1),
      hl('Arrow', '->', 1),
      hl('Register', '@d', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@e', 1),
      hl('BinaryPlus', '+', 1),
      hl('NestingParenthesis', '(', 1),
      hl('Lambda', '{'),
      hl('IdentifierName', 'f'),
      hl('Arrow', '->', 1),
      hl('IdentifierName', 'g', 1),
      hl('Lambda', '}'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@h'),
      hl('CallingParenthesis', ')'),
      hl('Lambda', '}'),
      hl('CallingParenthesis', '('),
      hl('Register', '@i'),
      hl('CallingParenthesis', ')'),
      hl('Curly', '}'),
      hl('IdentifierName', 'j'),
    })
    check_parsing('{@a + @b : @c + @d, @e + @f : @g + @i}', {
      --           01234567890123456789012345678901234567
      --           0         1         2         3
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:18:,',
              children = {
                {
                  'Colon:0:8: :',
                  children = {
                    {
                      'BinaryPlus:0:3: +',
                      children = {
                        'Register(name=a):0:1:@a',
                        'Register(name=b):0:5: @b',
                      },
                    },
                    {
                      'BinaryPlus:0:13: +',
                      children = {
                        'Register(name=c):0:10: @c',
                        'Register(name=d):0:15: @d',
                      },
                    },
                  },
                },
                {
                  'Colon:0:27: :',
                  children = {
                    {
                      'BinaryPlus:0:22: +',
                      children = {
                        'Register(name=e):0:19: @e',
                        'Register(name=f):0:24: @f',
                      },
                    },
                    {
                      'BinaryPlus:0:32: +',
                      children = {
                        'Register(name=g):0:29: @g',
                        'Register(name=i):0:34: @i',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@b', 1),
      hl('Colon', ':', 1),
      hl('Register', '@c', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@d', 1),
      hl('Comma', ','),
      hl('Register', '@e', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@f', 1),
      hl('Colon', ':', 1),
      hl('Register', '@g', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@i', 1),
      hl('Dict', '}'),
    })
    check_parsing('-> -> ->', {
      --           01234567
      ast = {
        {
          'Arrow:0:0:->',
          children = {
            'Missing:0:0:',
            {
              'Arrow:0:2: ->',
              children = {
                'Missing:0:2:',
                {
                  'Arrow:0:5: ->',
                  children = {
                    'Missing:0:5:',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '-> -> ->',
        msg = 'E15: Unexpected arrow: %.*s',
      },
    }, {
      hl('InvalidArrow', '->'),
      hl('InvalidArrow', '->', 1),
      hl('InvalidArrow', '->', 1),
    })
    check_parsing('a -> b -> c -> d', {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Arrow:0:1: ->',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Arrow:0:6: ->',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:4: b',
                {
                  'Arrow:0:11: ->',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:9: c',
                    'PlainIdentifier(scope=0,ident=d):0:14: d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '-> b -> c -> d',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'b', 1),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'c', 1),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'd', 1),
    })
    check_parsing('{a -> b -> c}', {
      --           0123456789012
      --           0         1
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
            {
              'Arrow:0:2: ->',
              children = {
                {
                  'Arrow:0:7: ->',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:5: b',
                    'PlainIdentifier(scope=0,ident=c):0:10: c',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '-> c}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Arrow', '->', 1),
      hl('IdentifierName', 'b', 1),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'c', 1),
      hl('Lambda', '}'),
    })
    check_parsing('{a: -> b}', {
      --           012345678
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            {
              'Arrow:0:3: ->',
              children = {
                'PlainIdentifier(scope=a,ident=):0:1:a:',
                'PlainIdentifier(scope=0,ident=b):0:6: b',
              },
            },
          },
        },
      },
      err = {
        arg = '-> b}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'b', 1),
      hl('Curly', '}'),
    })

    check_parsing('{a:b -> b}', {
      --           0123456789
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            {
              'Arrow:0:4: ->',
              children = {
                'PlainIdentifier(scope=a,ident=b):0:1:a:b',
                'PlainIdentifier(scope=0,ident=b):0:7: b',
              },
            },
          },
        },
      },
      err = {
        arg = '-> b}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('IdentifierName', 'b'),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'b', 1),
      hl('Curly', '}'),
    })

    check_parsing('{a#b -> b}', {
      --           0123456789
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
          children = {
            {
              'Arrow:0:4: ->',
              children = {
                'PlainIdentifier(scope=0,ident=a#b):0:1:a#b',
                'PlainIdentifier(scope=0,ident=b):0:7: b',
              },
            },
          },
        },
      },
      err = {
        arg = '-> b}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierName', 'a#b'),
      hl('InvalidArrow', '->', 1),
      hl('IdentifierName', 'b', 1),
      hl('Curly', '}'),
    })
    check_parsing('{a : b : c}', {
      --           01234567890
      --           0         1
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Colon:0:2: :',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Colon:0:6: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:4: b',
                    'PlainIdentifier(scope=0,ident=c):0:8: c',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ': c}',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('IdentifierName', 'a'),
      hl('Colon', ':', 1),
      hl('IdentifierName', 'b', 1),
      hl('InvalidColon', ':', 1),
      hl('IdentifierName', 'c', 1),
      hl('Dict', '}'),
    })
    check_parsing('{', {
      --           0
      ast = {
        fmtn('UnknownFigure', '\\di', ':0:0:{'),
      },
      err = {
        arg = '{',
        msg = 'E15: Missing closing figure brace: %.*s',
      },
    }, {
      hl('FigureBrace', '{'),
    })
    check_parsing('{a', {
      --           01
      ast = {
        {
          fmtn('UnknownFigure', '\\di', ':0:0:{'),
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
      err = {
        arg = '{a',
        msg = 'E15: Missing closing figure brace: %.*s',
      },
    }, {
      hl('FigureBrace', '{'),
      hl('IdentifierName', 'a'),
    })
    check_parsing('{a,b', {
      --           0123
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
          },
        },
      },
      err = {
        arg = '{a,b',
        msg = 'E15: Missing closing figure brace for lambda: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
    })
    check_parsing('{a,b->', {
      --           012345
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            'Arrow:0:4:->',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Arrow', '->'),
    })
    check_parsing('{a,b->c', {
      --           0123456
      ast = {
        {
          fmtn('Lambda', '\\di', ':0:0:{'),
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                'PlainIdentifier(scope=0,ident=c):0:6:c',
              },
            },
          },
        },
      },
      err = {
        arg = '{a,b->c',
        msg = 'E15: Missing closing figure brace for lambda: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b'),
      hl('Arrow', '->'),
      hl('IdentifierName', 'c'),
    })
    check_parsing('{a : b', {
      --           012345
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Colon:0:2: :',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:4: b',
              },
            },
          },
        },
      },
      err = {
        arg = '{a : b',
        msg = 'E723: Missing end of Dictionary \'}\': %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('IdentifierName', 'a'),
      hl('Colon', ':', 1),
      hl('IdentifierName', 'b', 1),
    })
    check_parsing('{a : b,', {
      --           0123456
      ast = {
        {
          fmtn('DictLiteral', '-di', ':0:0:{'),
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:2: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=a):0:1:a',
                    'PlainIdentifier(scope=0,ident=b):0:4: b',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('IdentifierName', 'a'),
      hl('Colon', ':', 1),
      hl('IdentifierName', 'b', 1),
      hl('Comma', ','),
    })
  end)
  itp('works with ternary operator', function()
    check_parsing('a ? b : c', {
      --           012345678
      ast = {
        {
          'Ternary:0:1: ?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:5: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:3: b',
                'PlainIdentifier(scope=0,ident=c):0:7: c',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?', 1),
      hl('IdentifierName', 'b', 1),
      hl('TernaryColon', ':', 1),
      hl('IdentifierName', 'c', 1),
    })
    check_parsing('@a?@b?@c:@d:@e', {
      --           01234567890123
      --           0         1
      ast = {
        {
          'Ternary:0:2:?',
          children = {
            'Register(name=a):0:0:@a',
            {
              'TernaryValue:0:11::',
              children = {
                {
                  'Ternary:0:5:?',
                  children = {
                    'Register(name=b):0:3:@b',
                    {
                      'TernaryValue:0:8::',
                      children = {
                        'Register(name=c):0:6:@c',
                        'Register(name=d):0:9:@d',
                      },
                    },
                  },
                },
                'Register(name=e):0:12:@e',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('Ternary', '?'),
      hl('Register', '@c'),
      hl('TernaryColon', ':'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
    })
    check_parsing('@a?@b:@c?@d:@e', {
      --           01234567890123
      --           0         1
      ast = {
        {
          'Ternary:0:2:?',
          children = {
            'Register(name=a):0:0:@a',
            {
              'TernaryValue:0:5::',
              children = {
                'Register(name=b):0:3:@b',
                {
                  'Ternary:0:8:?',
                  children = {
                    'Register(name=c):0:6:@c',
                    {
                      'TernaryValue:0:11::',
                      children = {
                        'Register(name=d):0:9:@d',
                        'Register(name=e):0:12:@e',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
    })
    check_parsing('@a?@b?@c?@d:@e?@f:@g:@h?@i:@j:@k', {
      --           01234567890123456789012345678901
      --           0         1         2         3
      ast = {
        {
          'Ternary:0:2:?',
          children = {
            'Register(name=a):0:0:@a',
            {
              'TernaryValue:0:29::',
              children = {
                {
                  'Ternary:0:5:?',
                  children = {
                    'Register(name=b):0:3:@b',
                    {
                      'TernaryValue:0:20::',
                      children = {
                        {
                          'Ternary:0:8:?',
                          children = {
                            'Register(name=c):0:6:@c',
                            {
                              'TernaryValue:0:11::',
                              children = {
                                'Register(name=d):0:9:@d',
                                {
                                  'Ternary:0:14:?',
                                  children = {
                                    'Register(name=e):0:12:@e',
                                    {
                                      'TernaryValue:0:17::',
                                      children = {
                                        'Register(name=f):0:15:@f',
                                        'Register(name=g):0:18:@g',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                        {
                          'Ternary:0:23:?',
                          children = {
                            'Register(name=h):0:21:@h',
                            {
                              'TernaryValue:0:26::',
                              children = {
                                'Register(name=i):0:24:@i',
                                'Register(name=j):0:27:@j',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
                'Register(name=k):0:30:@k',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('Ternary', '?'),
      hl('Register', '@c'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
      hl('Ternary', '?'),
      hl('Register', '@f'),
      hl('TernaryColon', ':'),
      hl('Register', '@g'),
      hl('TernaryColon', ':'),
      hl('Register', '@h'),
      hl('Ternary', '?'),
      hl('Register', '@i'),
      hl('TernaryColon', ':'),
      hl('Register', '@j'),
      hl('TernaryColon', ':'),
      hl('Register', '@k'),
    })
    check_parsing('?', {
      --           0
      ast = {
        {
          'Ternary:0:0:?',
          children = {
            'Missing:0:0:',
            'TernaryValue:0:0:?',
          },
        },
      },
      err = {
        arg = '?',
        msg = 'E15: Expected value, got question mark: %.*s',
      },
    }, {
      hl('InvalidTernary', '?'),
    })

    check_parsing('?:', {
      --           01
      ast = {
        {
          'Ternary:0:0:?',
          children = {
            'Missing:0:0:',
            {
              'TernaryValue:0:1::',
              children = {
                'Missing:0:1:',
              },
            },
          },
        },
      },
      err = {
        arg = '?:',
        msg = 'E15: Expected value, got question mark: %.*s',
      },
    }, {
      hl('InvalidTernary', '?'),
      hl('InvalidTernaryColon', ':'),
    })

    check_parsing('?::', {
      --           012
      ast = {
        {
          'Colon:0:2::',
          children = {
            {
              'Ternary:0:0:?',
              children = {
                'Missing:0:0:',
                {
                  'TernaryValue:0:1::',
                  children = {
                    'Missing:0:1:',
                    'Missing:0:2:',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '?::',
        msg = 'E15: Expected value, got question mark: %.*s',
      },
    }, {
      hl('InvalidTernary', '?'),
      hl('InvalidTernaryColon', ':'),
      hl('InvalidColon', ':'),
    })

    check_parsing('a?b', {
      --           012
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:1:?',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
              },
            },
          },
        },
      },
      err = {
        arg = '?b',
        msg = 'E109: Missing \':\' after \'?\': %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierName', 'b'),
    })
    check_parsing('a?b:', {
      --           0123
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:1:?',
              children = {
                'PlainIdentifier(scope=b,ident=):0:2:b:',
              },
            },
          },
        },
      },
      err = {
        arg = '?b:',
        msg = 'E109: Missing \':\' after \'?\': %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
    })

    check_parsing('a?b::c', {
      --           012345
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:4::',
              children = {
                'PlainIdentifier(scope=b,ident=):0:2:b:',
                'PlainIdentifier(scope=0,ident=c):0:5:c',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('TernaryColon', ':'),
      hl('IdentifierName', 'c'),
    })

    check_parsing('a?b :', {
      --           01234
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:3: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierName', 'b'),
      hl('TernaryColon', ':', 1),
    })

    check_parsing('(@a?@b:@c)?@d:@e', {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Ternary:0:10:?',
          children = {
            {
              'Nested:0:0:(',
              children = {
                {
                  'Ternary:0:3:?',
                  children = {
                    'Register(name=a):0:1:@a',
                    {
                      'TernaryValue:0:6::',
                      children = {
                        'Register(name=b):0:4:@b',
                        'Register(name=c):0:7:@c',
                      },
                    },
                  },
                },
              },
            },
            {
              'TernaryValue:0:13::',
              children = {
                'Register(name=d):0:11:@d',
                'Register(name=e):0:14:@e',
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('NestingParenthesis', ')'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
    })

    check_parsing('(@a?@b:@c)?(@d?@e:@f):(@g?@h:@i)', {
      --           01234567890123456789012345678901
      --           0         1         2         3
      ast = {
        {
          'Ternary:0:10:?',
          children = {
            {
              'Nested:0:0:(',
              children = {
                {
                  'Ternary:0:3:?',
                  children = {
                    'Register(name=a):0:1:@a',
                    {
                      'TernaryValue:0:6::',
                      children = {
                        'Register(name=b):0:4:@b',
                        'Register(name=c):0:7:@c',
                      },
                    },
                  },
                },
              },
            },
            {
              'TernaryValue:0:21::',
              children = {
                {
                  'Nested:0:11:(',
                  children = {
                    {
                      'Ternary:0:14:?',
                      children = {
                        'Register(name=d):0:12:@d',
                        {
                          'TernaryValue:0:17::',
                          children = {
                            'Register(name=e):0:15:@e',
                            'Register(name=f):0:18:@f',
                          },
                        },
                      },
                    },
                  },
                },
                {
                  'Nested:0:22:(',
                  children = {
                    {
                      'Ternary:0:25:?',
                      children = {
                        'Register(name=g):0:23:@g',
                        {
                          'TernaryValue:0:28::',
                          children = {
                            'Register(name=h):0:26:@h',
                            'Register(name=i):0:29:@i',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('NestingParenthesis', ')'),
      hl('Ternary', '?'),
      hl('NestingParenthesis', '('),
      hl('Register', '@d'),
      hl('Ternary', '?'),
      hl('Register', '@e'),
      hl('TernaryColon', ':'),
      hl('Register', '@f'),
      hl('NestingParenthesis', ')'),
      hl('TernaryColon', ':'),
      hl('NestingParenthesis', '('),
      hl('Register', '@g'),
      hl('Ternary', '?'),
      hl('Register', '@h'),
      hl('TernaryColon', ':'),
      hl('Register', '@i'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(@a?@b:@c)?@d?@e:@f:@g?@h:@i', {
      --           0123456789012345678901234567
      --           0         1         2
      ast = {
        {
          'Ternary:0:10:?',
          children = {
            {
              'Nested:0:0:(',
              children = {
                {
                  'Ternary:0:3:?',
                  children = {
                    'Register(name=a):0:1:@a',
                    {
                      'TernaryValue:0:6::',
                      children = {
                        'Register(name=b):0:4:@b',
                        'Register(name=c):0:7:@c',
                      },
                    },
                  },
                },
              },
            },
            {
              'TernaryValue:0:19::',
              children = {
                {
                  'Ternary:0:13:?',
                  children = {
                    'Register(name=d):0:11:@d',
                    {
                      'TernaryValue:0:16::',
                      children = {
                        'Register(name=e):0:14:@e',
                        'Register(name=f):0:17:@f',
                      },
                    },
                  },
                },
                {
                  'Ternary:0:22:?',
                  children = {
                    'Register(name=g):0:20:@g',
                    {
                      'TernaryValue:0:25::',
                      children = {
                        'Register(name=h):0:23:@h',
                        'Register(name=i):0:26:@i',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('NestingParenthesis', ')'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('Ternary', '?'),
      hl('Register', '@e'),
      hl('TernaryColon', ':'),
      hl('Register', '@f'),
      hl('TernaryColon', ':'),
      hl('Register', '@g'),
      hl('Ternary', '?'),
      hl('Register', '@h'),
      hl('TernaryColon', ':'),
      hl('Register', '@i'),
    })
    check_parsing('a?b{cdef}g:h', {
      --           012345678901
      --           0         1
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:10::',
              children = {
                {
                  'ComplexIdentifier:0:3:',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:2:b',
                    {
                      'ComplexIdentifier:0:9:',
                      children = {
                        {
                          fmtn('CurlyBracesIdentifier', '--i', ':0:3:{'),
                          children = {
                            'PlainIdentifier(scope=0,ident=cdef):0:4:cdef',
                          },
                        },
                        'PlainIdentifier(scope=0,ident=g):0:9:g',
                      },
                    },
                  },
                },
                'PlainIdentifier(scope=0,ident=h):0:11:h',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierName', 'b'),
      hl('Curly', '{'),
      hl('IdentifierName', 'cdef'),
      hl('Curly', '}'),
      hl('IdentifierName', 'g'),
      hl('TernaryColon', ':'),
      hl('IdentifierName', 'h'),
    })
    check_parsing('a ? b : c : d', {
      --           0123456789012
      --           0         1
      ast = {
        {
          'Colon:0:9: :',
          children = {
            {
              'Ternary:0:1: ?',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'TernaryValue:0:5: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    'PlainIdentifier(scope=0,ident=c):0:7: c',
                  },
                },
              },
            },
            'PlainIdentifier(scope=0,ident=d):0:11: d',
          },
        },
      },
      err = {
        arg = ': d',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Ternary', '?', 1),
      hl('IdentifierName', 'b', 1),
      hl('TernaryColon', ':', 1),
      hl('IdentifierName', 'c', 1),
      hl('InvalidColon', ':', 1),
      hl('IdentifierName', 'd', 1),
    })
  end)
  itp('works with comparison operators', function()
    check_parsing('a == b', {
      --           012345
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:1: ==',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '==', 1),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a ==? b', {
      --           0123456
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=IgnoreCase):0:1: ==?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '==', 1),
      hl('ComparisonModifier', '?'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a ==# b', {
      --           0123456
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=MatchCase):0:1: ==#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '==', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a !=# b', {
      --           0123456
      ast = {
        {
          'Comparison(type=Equal,inv=1,ccs=MatchCase):0:1: !=#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '!=', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a <=# b', {
      --           0123456
      ast = {
        {
          'Comparison(type=Greater,inv=1,ccs=MatchCase):0:1: <=#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '<=', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a >=# b', {
      --           0123456
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=0,ccs=MatchCase):0:1: >=#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '>=', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a ># b', {
      --           012345
      ast = {
        {
          'Comparison(type=Greater,inv=0,ccs=MatchCase):0:1: >#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '>', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a <# b', {
      --           012345
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=1,ccs=MatchCase):0:1: <#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '<', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a is#b', {
      --           012345
      ast = {
        {
          'Comparison(type=Identical,inv=0,ccs=MatchCase):0:1: is#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', 'is', 1),
      hl('ComparisonModifier', '#'),
      hl('IdentifierName', 'b'),
    })

    check_parsing('a is?b', {
      --           012345
      ast = {
        {
          'Comparison(type=Identical,inv=0,ccs=IgnoreCase):0:1: is?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', 'is', 1),
      hl('ComparisonModifier', '?'),
      hl('IdentifierName', 'b'),
    })

    check_parsing('a isnot b', {
      --           012345678
      ast = {
        {
          'Comparison(type=Identical,inv=1,ccs=UseOption):0:1: isnot',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:7: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', 'isnot', 1),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a < b < c', {
      --           012345678
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:1: <',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:5: <',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:3: b',
                'PlainIdentifier(scope=0,ident=c):0:7: c',
              },
            },
          },
        },
      },
      err = {
        arg = ' < c',
        msg = 'E15: Operator is not associative: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '<', 1),
      hl('IdentifierName', 'b', 1),
      hl('InvalidComparison', '<', 1),
      hl('IdentifierName', 'c', 1),
    })

    check_parsing('a < b <# c', {
      --           012345678
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:1: <',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comparison(type=GreaterOrEqual,inv=1,ccs=MatchCase):0:5: <#',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:3: b',
                'PlainIdentifier(scope=0,ident=c):0:8: c',
              },
            },
          },
        },
      },
      err = {
        arg = ' <# c',
        msg = 'E15: Operator is not associative: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Comparison', '<', 1),
      hl('IdentifierName', 'b', 1),
      hl('InvalidComparison', '<', 1),
      hl('InvalidComparisonModifier', '#'),
      hl('IdentifierName', 'c', 1),
    })

    check_parsing('a += b', {
      --           012345
      ast = {
        {
          'Assignment(Add):0:1: +=',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
      err = {
        arg = '+= b',
        msg = 'E15: Misplaced assignment: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('InvalidAssignmentWithAddition', '+=', 1),
      hl('IdentifierName', 'b', 1),
    })
    check_parsing('a + b == c + d', {
      --           01234567890123
      --           0         1
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:5: ==',
          children = {
            {
              'BinaryPlus:0:1: +',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
            {
              'BinaryPlus:0:10: +',
              children = {
                'PlainIdentifier(scope=0,ident=c):0:8: c',
                'PlainIdentifier(scope=0,ident=d):0:12: d',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('BinaryPlus', '+', 1),
      hl('IdentifierName', 'b', 1),
      hl('Comparison', '==', 1),
      hl('IdentifierName', 'c', 1),
      hl('BinaryPlus', '+', 1),
      hl('IdentifierName', 'd', 1),
    })
    check_parsing('+ a == + b', {
      --           0123456789
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:3: ==',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1: a',
              },
            },
            {
              'UnaryPlus:0:6: +',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:8: b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('IdentifierName', 'a', 1),
      hl('Comparison', '==', 1),
      hl('UnaryPlus', '+', 1),
      hl('IdentifierName', 'b', 1),
    })
  end)
  itp('works with concat/subscript', function()
    check_parsing('.', {
      --           0
      ast = {
        {
          'ConcatOrSubscript:0:0:.',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = '.',
        msg = 'E15: Unexpected dot: %.*s',
      },
    }, {
      hl('InvalidConcatOrSubscript', '.'),
    })

    check_parsing('a.', {
      --           01
      ast = {
        {
          'ConcatOrSubscript:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('ConcatOrSubscript', '.'),
    })

    check_parsing('a.b', {
      --           012
      ast = {
        {
          'ConcatOrSubscript:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainKey(key=b):0:2:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', 'b'),
    })

    check_parsing('1.2', {
      --           012
      ast = {
        'Float(val=1.200000e+00):0:0:1.2',
      },
    }, {
      hl('Float', '1.2'),
    })

    check_parsing('1.2 + 1.3e-5', {
      --           012345678901
      --           0         1
      ast = {
        {
          'BinaryPlus:0:3: +',
          children = {
            'Float(val=1.200000e+00):0:0:1.2',
            'Float(val=1.300000e-05):0:5: 1.3e-5',
          },
        },
      },
    }, {
      hl('Float', '1.2'),
      hl('BinaryPlus', '+', 1),
      hl('Float', '1.3e-5', 1),
    })

    check_parsing('a . 1.2 + 1.3e-5', {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'BinaryPlus:0:7: +',
          children = {
            {
              'Concat:0:1: .',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'ConcatOrSubscript:0:5:.',
                  children = {
                    'Integer(val=1):0:3: 1',
                    'PlainKey(key=2):0:6:2',
                  },
                },
              },
            },
            'Float(val=1.300000e-05):0:9: 1.3e-5',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Concat', '.', 1),
      hl('Number', '1', 1),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
      hl('BinaryPlus', '+', 1),
      hl('Float', '1.3e-5', 1),
    })

    check_parsing('1.3e-5 + 1.2 . a', {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Concat:0:12: .',
          children = {
            {
              'BinaryPlus:0:6: +',
              children = {
                'Float(val=1.300000e-05):0:0:1.3e-5',
                'Float(val=1.200000e+00):0:8: 1.2',
              },
            },
            'PlainIdentifier(scope=0,ident=a):0:14: a',
          },
        },
      },
    }, {
      hl('Float', '1.3e-5'),
      hl('BinaryPlus', '+', 1),
      hl('Float', '1.2', 1),
      hl('Concat', '.', 1),
      hl('IdentifierName', 'a', 1),
    })

    check_parsing('1.3e-5 + a . 1.2', {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Concat:0:10: .',
          children = {
            {
              'BinaryPlus:0:6: +',
              children = {
                'Float(val=1.300000e-05):0:0:1.3e-5',
                'PlainIdentifier(scope=0,ident=a):0:8: a',
              },
            },
            {
              'ConcatOrSubscript:0:14:.',
              children = {
                'Integer(val=1):0:12: 1',
                'PlainKey(key=2):0:15:2',
              },
            },
          },
        },
      },
    }, {
      hl('Float', '1.3e-5'),
      hl('BinaryPlus', '+', 1),
      hl('IdentifierName', 'a', 1),
      hl('Concat', '.', 1),
      hl('Number', '1', 1),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
    })

    check_parsing('1.2.3', {
      --           01234
      ast = {
        {
          'ConcatOrSubscript:0:3:.',
          children = {
            {
              'ConcatOrSubscript:0:1:.',
              children = {
                'Integer(val=1):0:0:1',
                'PlainKey(key=2):0:2:2',
              },
            },
            'PlainKey(key=3):0:4:3',
          },
        },
      },
    }, {
      hl('Number', '1'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '3'),
    })

    check_parsing('a.1.2', {
      --           01234
      ast = {
        {
          'ConcatOrSubscript:0:3:.',
          children = {
            {
              'ConcatOrSubscript:0:1:.',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainKey(key=1):0:2:1',
              },
            },
            'PlainKey(key=2):0:4:2',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '1'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
    })

    check_parsing('a . 1.2', {
      --           0123456
      ast = {
        {
          'Concat:0:1: .',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'ConcatOrSubscript:0:5:.',
              children = {
                'Integer(val=1):0:3: 1',
                'PlainKey(key=2):0:6:2',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Concat', '.', 1),
      hl('Number', '1', 1),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
    })

    check_parsing('+a . +b', {
      --           0123456
      ast = {
        {
          'Concat:0:2: .',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
            {
              'UnaryPlus:0:4: +',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:6:b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('IdentifierName', 'a'),
      hl('Concat', '.', 1),
      hl('UnaryPlus', '+', 1),
      hl('IdentifierName', 'b'),
    })

    check_parsing('a. b', {
      --           0123
      ast = {
        {
          'Concat:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:2: b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierName', 'b', 1),
    })

    check_parsing('a. 1', {
      --           0123
      ast = {
        {
          'Concat:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'Integer(val=1):0:2: 1',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('Number', '1', 1),
    })

    check_parsing('a[1][2][3[4', {
      --           01234567890
      --           0         1
      ast = {
        {
          'Subscript:0:7:[',
          children = {
            {
              'Subscript:0:4:[',
              children = {
                {
                  'Subscript:0:1:[',
                  children = {
                    'PlainIdentifier(scope=0,ident=a):0:0:a',
                    'Integer(val=1):0:2:1',
                  },
                },
                'Integer(val=2):0:5:2',
              },
            },
            {
              'Subscript:0:9:[',
              children = {
                'Integer(val=3):0:8:3',
                'Integer(val=4):0:10:4',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('Number', '1'),
      hl('SubscriptBracket', ']'),
      hl('SubscriptBracket', '['),
      hl('Number', '2'),
      hl('SubscriptBracket', ']'),
      hl('SubscriptBracket', '['),
      hl('Number', '3'),
      hl('SubscriptBracket', '['),
      hl('Number', '4'),
    })
  end)
  itp('works with bracket subscripts', function()
    check_parsing(':', {
      --           0
      ast = {
        {
          'Colon:0:0::',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = ':',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('InvalidColon', ':'),
    })
    check_parsing('a[]', {
      --           012
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = ']',
        msg = 'E15: Expected value, got closing bracket: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('InvalidSubscriptBracket', ']'),
    })
    check_parsing('a[b:]', {
      --           01234
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=b,ident=):0:2:b:',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('SubscriptBracket', ']'),
    })

    check_parsing('a[b:c]', {
      --           012345
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=b,ident=c):0:2:b:c',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('IdentifierName', 'c'),
      hl('SubscriptBracket', ']'),
    })
    check_parsing('a[b : c]', {
      --           01234567
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Colon:0:3: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
                'PlainIdentifier(scope=0,ident=c):0:5: c',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'b'),
      hl('SubscriptColon', ':', 1),
      hl('IdentifierName', 'c', 1),
      hl('SubscriptBracket', ']'),
    })

    check_parsing('a[: b]', {
      --           012345
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Colon:0:2::',
              children = {
                'Missing:0:2:',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('SubscriptColon', ':'),
      hl('IdentifierName', 'b', 1),
      hl('SubscriptBracket', ']'),
    })

    check_parsing('a[b :]', {
      --           012345
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Colon:0:3: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'b'),
      hl('SubscriptColon', ':', 1),
      hl('SubscriptBracket', ']'),
    })
    check_parsing('a[b][c][d](e)(f)(g)', {
      --           0123456789012345678
      --           0         1
      ast = {
        {
          'Call:0:16:(',
          children = {
            {
              'Call:0:13:(',
              children = {
                {
                  'Call:0:10:(',
                  children = {
                    {
                      'Subscript:0:7:[',
                      children = {
                        {
                          'Subscript:0:4:[',
                          children = {
                            {
                              'Subscript:0:1:[',
                              children = {
                                'PlainIdentifier(scope=0,ident=a):0:0:a',
                                'PlainIdentifier(scope=0,ident=b):0:2:b',
                              },
                            },
                            'PlainIdentifier(scope=0,ident=c):0:5:c',
                          },
                        },
                        'PlainIdentifier(scope=0,ident=d):0:8:d',
                      },
                    },
                    'PlainIdentifier(scope=0,ident=e):0:11:e',
                  },
                },
                'PlainIdentifier(scope=0,ident=f):0:14:f',
              },
            },
            'PlainIdentifier(scope=0,ident=g):0:17:g',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'b'),
      hl('SubscriptBracket', ']'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'c'),
      hl('SubscriptBracket', ']'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'd'),
      hl('SubscriptBracket', ']'),
      hl('CallingParenthesis', '('),
      hl('IdentifierName', 'e'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('IdentifierName', 'f'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('IdentifierName', 'g'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('{a}{b}{c}[d][e][f]', {
      --           012345678901234567
      --           0         1
      ast = {
        {
          'Subscript:0:15:[',
          children = {
            {
              'Subscript:0:12:[',
              children = {
                {
                  'Subscript:0:9:[',
                  children = {
                    {
                      'ComplexIdentifier:0:3:',
                      children = {
                        {
                          fmtn('CurlyBracesIdentifier', '-di', ':0:0:{'),
                          children = {
                            'PlainIdentifier(scope=0,ident=a):0:1:a',
                          },
                        },
                        {
                          'ComplexIdentifier:0:6:',
                          children = {
                            {
                              fmtn('CurlyBracesIdentifier', '--i', ':0:3:{'),
                              children = {
                                'PlainIdentifier(scope=0,ident=b):0:4:b',
                              },
                            },
                            {
                              fmtn('CurlyBracesIdentifier', '--i', ':0:6:{'),
                              children = {
                                'PlainIdentifier(scope=0,ident=c):0:7:c',
                              },
                            },
                          },
                        },
                      },
                    },
                    'PlainIdentifier(scope=0,ident=d):0:10:d',
                  },
                },
                'PlainIdentifier(scope=0,ident=e):0:13:e',
              },
            },
            'PlainIdentifier(scope=0,ident=f):0:16:f',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierName', 'a'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('IdentifierName', 'c'),
      hl('Curly', '}'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'd'),
      hl('SubscriptBracket', ']'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'e'),
      hl('SubscriptBracket', ']'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'f'),
      hl('SubscriptBracket', ']'),
    })
  end)
  itp('supports list literals', function()
    check_parsing('[]', {
      --           01
      ast = {
        'ListLiteral:0:0:[',
      },
    }, {
      hl('List', '['),
      hl('List', ']'),
    })

    check_parsing('[a]', {
      --           012
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('List', ']'),
    })

    check_parsing('[a, b]', {
      --           012345
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b', 1),
      hl('List', ']'),
    })

    check_parsing('[a, b, c]', {
      --           012345678
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    'PlainIdentifier(scope=0,ident=c):0:6: c',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b', 1),
      hl('Comma', ','),
      hl('IdentifierName', 'c', 1),
      hl('List', ']'),
    })

    check_parsing('[a, b, c, ]', {
      --           01234567890
      --           0         1
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    {
                      'Comma:0:8:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:6: c',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b', 1),
      hl('Comma', ','),
      hl('IdentifierName', 'c', 1),
      hl('Comma', ','),
      hl('List', ']', 1),
    })

    check_parsing('[a : b, c : d]', {
      --           01234567890123
      --           0         1
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:2: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=a):0:1:a',
                    'PlainIdentifier(scope=0,ident=b):0:4: b',
                  },
                },
                {
                  'Colon:0:9: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:7: c',
                    'PlainIdentifier(scope=0,ident=d):0:11: d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ': b, c : d]',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('InvalidColon', ':', 1),
      hl('IdentifierName', 'b', 1),
      hl('Comma', ','),
      hl('IdentifierName', 'c', 1),
      hl('InvalidColon', ':', 1),
      hl('IdentifierName', 'd', 1),
      hl('List', ']'),
    })

    check_parsing(']', {
      --           0
      ast = {
        'ListLiteral:0:0:',
      },
      err = {
        arg = ']',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('InvalidList', ']'),
    })

    check_parsing('a]', {
      --           01
      ast = {
        {
          'ListLiteral:0:1:',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = ']',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('InvalidList', ']'),
    })

    check_parsing('[] []', {
      --           01234
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'ListLiteral:0:0:[',
            'ListLiteral:0:2: [',
          },
        },
      },
      err = {
        arg = '[]',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('List', '['),
      hl('List', ']'),
      hl('InvalidSpacing', ' '),
      hl('List', '['),
      hl('List', ']'),
    }, {
      [1] = {
        ast = {
          len = 3,
          err = REMOVE_THIS,
          ast = {
            'ListLiteral:0:0:[',
          },
        },
        hl_fs = {
          [3] = REMOVE_THIS,
          [4] = REMOVE_THIS,
          [5] = REMOVE_THIS,
        },
      },
    })

    check_parsing('[][]', {
      --           0123
      ast = {
        {
          'Subscript:0:2:[',
          children = {
            'ListLiteral:0:0:[',
          },
        },
      },
      err = {
        arg = ']',
        msg = 'E15: Expected value, got closing bracket: %.*s',
      },
    }, {
      hl('List', '['),
      hl('List', ']'),
      hl('SubscriptBracket', '['),
      hl('InvalidSubscriptBracket', ']'),
    })

    check_parsing('[', {
      --           0
      ast = {
        'ListLiteral:0:0:[',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('List', '['),
    })

    check_parsing('[1', {
      --           01
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            'Integer(val=1):0:1:1',
          },
        },
      },
      err = {
        arg = '[1',
        msg = 'E697: Missing end of List \']\': %.*s',
      },
    }, {
      hl('List', '['),
      hl('Number', '1'),
    })
  end)
  itp('works with strings', function()
    check_parsing('\'abc\'', {
      --           01234
      ast = {
        fmtn('SingleQuotedString', 'val="abc"', ':0:0:\'abc\''),
      },
    }, {
      hl('SingleQuote', '\''),
      hl('SingleQuotedBody', 'abc'),
      hl('SingleQuote', '\''),
    })
    check_parsing('"abc"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="abc"', ':0:0:"abc"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedBody', 'abc'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('\'\'', {
      --           01
      ast = {
        fmtn('SingleQuotedString', 'val=NULL', ':0:0:\'\''),
      },
    }, {
      hl('SingleQuote', '\''),
      hl('SingleQuote', '\''),
    })
    check_parsing('""', {
      --           01
      ast = {
        fmtn('DoubleQuotedString', 'val=NULL', ':0:0:""'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"', {
      --           0
      ast = {
        fmtn('DoubleQuotedString', 'val=NULL', ':0:0:"'),
      },
      err = {
        arg = '"',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
    })
    check_parsing('\'', {
      --           0
      ast = {
        fmtn('SingleQuotedString', 'val=NULL', ':0:0:\''),
      },
      err = {
        arg = '\'',
        msg = 'E115: Missing single quote: %.*s',
      },
    }, {
      hl('InvalidSingleQuote', '\''),
    })
    check_parsing('"a', {
      --           01
      ast = {
        fmtn('DoubleQuotedString', 'val="a"', ':0:0:"a'),
      },
      err = {
        arg = '"a',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedBody', 'a'),
    })
    check_parsing('\'a', {
      --           01
      ast = {
        fmtn('SingleQuotedString', 'val="a"', ':0:0:\'a'),
      },
      err = {
        arg = '\'a',
        msg = 'E115: Missing single quote: %.*s',
      },
    }, {
      hl('InvalidSingleQuote', '\''),
      hl('InvalidSingleQuotedBody', 'a'),
    })
    check_parsing('\'abc\'\'def\'', {
      --           0123456789
      ast = {
        fmtn('SingleQuotedString', 'val="abc\'def"', ':0:0:\'abc\'\'def\''),
      },
    }, {
      hl('SingleQuote', '\''),
      hl('SingleQuotedBody', 'abc'),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedBody', 'def'),
      hl('SingleQuote', '\''),
    })
    check_parsing('\'abc\'\'', {
      --           012345
      ast = {
        fmtn('SingleQuotedString', 'val="abc\'"', ':0:0:\'abc\'\''),
      },
      err = {
        arg = '\'abc\'\'',
        msg = 'E115: Missing single quote: %.*s',
      },
    }, {
      hl('InvalidSingleQuote', '\''),
      hl('InvalidSingleQuotedBody', 'abc'),
      hl('InvalidSingleQuotedQuote', '\'\''),
    })
    check_parsing('\'\'\'\'\'\'\'\'', {
      --           01234567
      ast = {
        fmtn('SingleQuotedString', 'val="\'\'\'"', ':0:0:\'\'\'\'\'\'\'\''),
      },
    }, {
      hl('SingleQuote', '\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuote', '\''),
    })
    check_parsing('\'\'\'a\'\'\'\'bc\'', {
      --           01234567890
      --           0         1
      ast = {
        fmtn('SingleQuotedString', 'val="\'a\'\'bc"', ':0:0:\'\'\'a\'\'\'\'bc\''),
      },
    }, {
      hl('SingleQuote', '\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedBody', 'a'),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedBody', 'bc'),
      hl('SingleQuote', '\''),
    })
    check_parsing('"\\"\\"\\"\\""', {
      --           0123456789
      ast = {
        fmtn('DoubleQuotedString', 'val="\\"\\"\\"\\""', ':0:0:"\\"\\"\\"\\""'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"abc\\"def\\"ghi\\"jkl\\"mno"', {
      --           0123456789012345678901234
      --           0         1         2
      ast = {
        fmtn('DoubleQuotedString', 'val="abc\\"def\\"ghi\\"jkl\\"mno"', ':0:0:"abc\\"def\\"ghi\\"jkl\\"mno"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedBody', 'abc'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'def'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'ghi'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'jkl'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'mno'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\b\\e\\f\\r\\t\\\\"', {
      --           0123456789012345
      --           0         1
      ast = {
        [[DoubleQuotedString(val="\008\027\012\r\t\\"):0:0:"\b\e\f\r\t\\"]],
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\b'),
      hl('DoubleQuotedEscape', '\\e'),
      hl('DoubleQuotedEscape', '\\f'),
      hl('DoubleQuotedEscape', '\\r'),
      hl('DoubleQuotedEscape', '\\t'),
      hl('DoubleQuotedEscape', '\\\\'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\n\n"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="\\n\\n"', ':0:0:"\\n\n"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\n'),
      hl('DoubleQuotedBody', '\n'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\x00"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000"', ':0:0:"\\x00"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\x00'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\xFF"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\255"', ':0:0:"\\xFF"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\xFF'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\xF"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\015"', ':0:0:"\\xF"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\xF'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\u00AB"', {
      --           01234567
      ast = {
        fmtn('DoubleQuotedString', 'val="«"', ':0:0:"\\u00AB"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\u00AB'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\U000000AB"', {
      --           01234567
      ast = {
        fmtn('DoubleQuotedString', 'val="«"', ':0:0:"\\U000000AB"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U000000AB'),
      hl('DoubleQuote', '"'),
    })
    check_parsing('"\\x"', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="x"', ':0:0:"\\x"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\x'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\x', {
      --           012
      ast = {
        fmtn('DoubleQuotedString', 'val="x"', ':0:0:"\\x'),
      },
      err = {
        arg = '"\\x',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\x'),
    })

    check_parsing('"\\xF', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="\\015"', ':0:0:"\\xF'),
      },
      err = {
        arg = '"\\xF',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedEscape', '\\xF'),
    })

    check_parsing('"\\u"', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="u"', ':0:0:"\\u"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\u'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\u', {
      --           012
      ast = {
        fmtn('DoubleQuotedString', 'val="u"', ':0:0:"\\u'),
      },
      err = {
        arg = '"\\u',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\u'),
    })

    check_parsing('"\\U', {
      --           012
      ast = {
        fmtn('DoubleQuotedString', 'val="U"', ':0:0:"\\U'),
      },
      err = {
        arg = '"\\U',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
    })

    check_parsing('"\\U"', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="U"', ':0:0:"\\U"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\U'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\xFX"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\015X"', ':0:0:"\\xFX"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\xF'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\XFX"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\015X"', ':0:0:"\\XFX"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\XF'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\xX"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="xX"', ':0:0:"\\xX"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\x'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\XX"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="XX"', ':0:0:"\\XX"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\X'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\uX"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="uX"', ':0:0:"\\uX"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\u'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\UX"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="UX"', ':0:0:"\\UX"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\U'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\x0X"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\x0X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\x0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\X0X"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\X0X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\X0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\u0X"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\u0X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\u0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U0X"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U0X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\x00X"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\x00X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\x00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\X00X"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\X00X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\X00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\u00X"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\u00X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\u00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U00X"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U00X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\u000X"', {
      --           01234567
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\u000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\u000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U000X"', {
      --           01234567
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\u0000X"', {
      --           012345678
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\u0000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\u0000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U0000X"', {
      --           012345678
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U0000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U0000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U00000X"', {
      --           0123456789
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U00000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U00000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U000000X"', {
      --           01234567890
      --           0         1
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U000000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U000000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U0000000X"', {
      --           012345678901
      --           0         1
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U0000000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U0000000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U00000000X"', {
      --           0123456789012
      --           0         1
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000X"', ':0:0:"\\U00000000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U00000000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\x000X"', {
      --           01234567
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0000X"', ':0:0:"\\x000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\x00'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\X000X"', {
      --           01234567
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0000X"', ':0:0:"\\X000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\X00'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\u00000X"', {
      --           0123456789
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0000X"', ':0:0:"\\u00000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\u0000'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\U000000000X"', {
      --           01234567890123
      --           0         1
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0000X"', ':0:0:"\\U000000000X"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\U00000000'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\0"', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000"', ':0:0:"\\0"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\0'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\00"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000"', ':0:0:"\\00"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\00'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\000"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\000"', ':0:0:"\\000"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\000'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\0000"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0000"', ':0:0:"\\0000"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\000'),
      hl('DoubleQuotedBody', '0'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\8"', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="8"', ':0:0:"\\8"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\8'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\08"', {
      --           01234
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0008"', ':0:0:"\\08"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\0'),
      hl('DoubleQuotedBody', '8'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\008"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0008"', ':0:0:"\\008"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\00'),
      hl('DoubleQuotedBody', '8'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\0008"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="\\0008"', ':0:0:"\\0008"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\000'),
      hl('DoubleQuotedBody', '8'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\777"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\255"', ':0:0:"\\777"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\777'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\050"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\40"', ':0:0:"\\050"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\050'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\<C-u>"', {
      --           012345
      ast = {
        fmtn('DoubleQuotedString', 'val="\\021"', ':0:0:"\\<C-u>"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedEscape', '\\<C-u>'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\<', {
      --           012
      ast = {
        fmtn('DoubleQuotedString', 'val="<"', ':0:0:"\\<'),
      },
      err = {
        arg = '"\\<',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\<'),
    })

    check_parsing('"\\<"', {
      --           0123
      ast = {
        fmtn('DoubleQuotedString', 'val="<"', ':0:0:"\\<"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\<'),
      hl('DoubleQuote', '"'),
    })

    check_parsing('"\\<C-u"', {
      --           0123456
      ast = {
        fmtn('DoubleQuotedString', 'val="<C-u"', ':0:0:"\\<C-u"'),
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedUnknownEscape', '\\<'),
      hl('DoubleQuotedBody', 'C-u'),
      hl('DoubleQuote', '"'),
    })
  end)
  itp('works with multiplication-like operators', function()
    check_parsing('2+2*2', {
      --           01234
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Multiplication:0:3:*',
              children = {
                'Integer(val=2):0:2:2',
                'Integer(val=2):0:4:2',
              },
            },
          },
        },
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Multiplication', '*'),
      hl('Number', '2'),
    })

    check_parsing('2+2*', {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Multiplication:0:3:*',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Multiplication', '*'),
    })

    check_parsing('2+*2', {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Multiplication:0:2:*',
              children = {
                'Missing:0:2:',
                'Integer(val=2):0:3:2',
              },
            },
          },
        },
      },
      err = {
        arg = '*2',
        msg = 'E15: Unexpected multiplication-like operator: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('InvalidMultiplication', '*'),
      hl('Number', '2'),
    })

    check_parsing('2+2/2', {
      --           01234
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Division:0:3:/',
              children = {
                'Integer(val=2):0:2:2',
                'Integer(val=2):0:4:2',
              },
            },
          },
        },
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Division', '/'),
      hl('Number', '2'),
    })

    check_parsing('2+2/', {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Division:0:3:/',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Division', '/'),
    })

    check_parsing('2+/2', {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Division:0:2:/',
              children = {
                'Missing:0:2:',
                'Integer(val=2):0:3:2',
              },
            },
          },
        },
      },
      err = {
        arg = '/2',
        msg = 'E15: Unexpected multiplication-like operator: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('InvalidDivision', '/'),
      hl('Number', '2'),
    })

    check_parsing('2+2%2', {
      --           01234
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Mod:0:3:%',
              children = {
                'Integer(val=2):0:2:2',
                'Integer(val=2):0:4:2',
              },
            },
          },
        },
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Mod', '%'),
      hl('Number', '2'),
    })

    check_parsing('2+2%', {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Mod:0:3:%',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Mod', '%'),
    })

    check_parsing('2+%2', {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Mod:0:2:%',
              children = {
                'Missing:0:2:',
                'Integer(val=2):0:3:2',
              },
            },
          },
        },
      },
      err = {
        arg = '%2',
        msg = 'E15: Unexpected multiplication-like operator: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('InvalidMod', '%'),
      hl('Number', '2'),
    })
  end)
  itp('works with -', function()
    check_parsing('@a', {
      ast = {
        'Register(name=a):0:0:@a',
      },
    }, {
      hl('Register', '@a'),
    })
    check_parsing('-@a', {
      ast = {
        {
          'UnaryMinus:0:0:-',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('UnaryMinus', '-'),
      hl('Register', '@a'),
    })
    check_parsing('@a-@b', {
      ast = {
        {
          'BinaryMinus:0:2:-',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:3:@b',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('Register', '@b'),
    })
    check_parsing('@a-@b-@c', {
      ast = {
        {
          'BinaryMinus:0:5:-',
          children = {
            {
              'BinaryMinus:0:2:-',
              children = {
                'Register(name=a):0:0:@a',
                'Register(name=b):0:3:@b',
              },
            },
            'Register(name=c):0:6:@c',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('Register', '@b'),
      hl('BinaryMinus', '-'),
      hl('Register', '@c'),
    })
    check_parsing('-@a-@b', {
      ast = {
        {
          'BinaryMinus:0:3:-',
          children = {
            {
              'UnaryMinus:0:0:-',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:4:@b',
          },
        },
      },
    }, {
      hl('UnaryMinus', '-'),
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('Register', '@b'),
    })
    check_parsing('-@a--@b', {
      ast = {
        {
          'BinaryMinus:0:3:-',
          children = {
            {
              'UnaryMinus:0:0:-',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              'UnaryMinus:0:4:-',
              children = {
                'Register(name=b):0:5:@b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryMinus', '-'),
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('UnaryMinus', '-'),
      hl('Register', '@b'),
    })
    check_parsing('-', {
      ast = {
        'UnaryMinus:0:0:-',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryMinus', '-'),
    })
    check_parsing(' -', {
      ast = {
        'UnaryMinus:0:0: -',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryMinus', '-', 1),
    })
    check_parsing('@a-  ', {
      ast = {
        {
          'BinaryMinus:0:2:-',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
    })
  end)
  itp('works with logical operators', function()
    check_parsing('a && b || c && d', {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Or:0:6: ||',
          children = {
            {
              'And:0:1: &&',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainIdentifier(scope=0,ident=b):0:4: b',
              },
            },
            {
              'And:0:11: &&',
              children = {
                'PlainIdentifier(scope=0,ident=c):0:9: c',
                'PlainIdentifier(scope=0,ident=d):0:14: d',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('And', '&&', 1),
      hl('IdentifierName', 'b', 1),
      hl('Or', '||', 1),
      hl('IdentifierName', 'c', 1),
      hl('And', '&&', 1),
      hl('IdentifierName', 'd', 1),
    })

    check_parsing('&& a', {
      --           0123
      ast = {
        {
          'And:0:0:&&',
          children = {
            'Missing:0:0:',
            'PlainIdentifier(scope=0,ident=a):0:2: a',
          },
        },
      },
      err = {
        arg = '&& a',
        msg = 'E15: Unexpected and operator: %.*s',
      },
    }, {
      hl('InvalidAnd', '&&'),
      hl('IdentifierName', 'a', 1),
    })

    check_parsing('|| a', {
      --           0123
      ast = {
        {
          'Or:0:0:||',
          children = {
            'Missing:0:0:',
            'PlainIdentifier(scope=0,ident=a):0:2: a',
          },
        },
      },
      err = {
        arg = '|| a',
        msg = 'E15: Unexpected or operator: %.*s',
      },
    }, {
      hl('InvalidOr', '||'),
      hl('IdentifierName', 'a', 1),
    })

    check_parsing('a||', {
      --           012
      ast = {
        {
          'Or:0:1:||',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Or', '||'),
    })

    check_parsing('a&&', {
      --           012
      ast = {
        {
          'And:0:1:&&',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('And', '&&'),
    })

    check_parsing('(&&)', {
      --           0123
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'And:0:1:&&',
              children = {
                'Missing:0:1:',
                'Missing:0:3:',
              },
            },
          },
        },
      },
      err = {
        arg = '&&)',
        msg = 'E15: Unexpected and operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidAnd', '&&'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(||)', {
      --           0123
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Or:0:1:||',
              children = {
                'Missing:0:1:',
                'Missing:0:3:',
              },
            },
          },
        },
      },
      err = {
        arg = '||)',
        msg = 'E15: Unexpected or operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidOr', '||'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(a||)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Or:0:2:||',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'Missing:0:4:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('IdentifierName', 'a'),
      hl('Or', '||'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(a&&)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'And:0:2:&&',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'Missing:0:4:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('IdentifierName', 'a'),
      hl('And', '&&'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(&&a)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'And:0:1:&&',
              children = {
                'Missing:0:1:',
                'PlainIdentifier(scope=0,ident=a):0:3:a',
              },
            },
          },
        },
      },
      err = {
        arg = '&&a)',
        msg = 'E15: Unexpected and operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidAnd', '&&'),
      hl('IdentifierName', 'a'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(||a)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Or:0:1:||',
              children = {
                'Missing:0:1:',
                'PlainIdentifier(scope=0,ident=a):0:3:a',
              },
            },
          },
        },
      },
      err = {
        arg = '||a)',
        msg = 'E15: Unexpected or operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidOr', '||'),
      hl('IdentifierName', 'a'),
      hl('NestingParenthesis', ')'),
    })
  end)
  itp('works with &opt', function()
    check_parsing('&', {
      --           0
      ast = {
        'Option(scope=0,ident=):0:0:&',
      },
      err = {
        arg = '&',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('InvalidOptionSigil', '&'),
    })

    check_parsing('&opt', {
      --           0123
      ast = {
        'Option(scope=0,ident=opt):0:0:&opt',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionName', 'opt'),
    })

    check_parsing('&l:opt', {
      --           012345
      ast = {
        'Option(scope=l,ident=opt):0:0:&l:opt',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionScope', 'l'),
      hl('OptionScopeDelimiter', ':'),
      hl('OptionName', 'opt'),
    })

    check_parsing('&g:opt', {
      --           012345
      ast = {
        'Option(scope=g,ident=opt):0:0:&g:opt',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionScope', 'g'),
      hl('OptionScopeDelimiter', ':'),
      hl('OptionName', 'opt'),
    })

    check_parsing('&s:opt', {
      --           012345
      ast = {
        {
          'Colon:0:2::',
          children = {
            'Option(scope=0,ident=s):0:0:&s',
            'PlainIdentifier(scope=0,ident=opt):0:3:opt',
          },
        },
      },
      err = {
        arg = ':opt',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionName', 's'),
      hl('InvalidColon', ':'),
      hl('IdentifierName', 'opt'),
    })

    check_parsing('& ', {
      --           01
      ast = {
        'Option(scope=0,ident=):0:0:&',
      },
      err = {
        arg = '& ',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('InvalidOptionSigil', '&'),
    })

    check_parsing('&-', {
      --           01
      ast = {
        {
          'BinaryMinus:0:1:-',
          children = {
            'Option(scope=0,ident=):0:0:&',
          },
        },
      },
      err = {
        arg = '&-',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('InvalidOptionSigil', '&'),
      hl('BinaryMinus', '-'),
    })

    check_parsing('&A', {
      --           01
      ast = {
        'Option(scope=0,ident=A):0:0:&A',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionName', 'A'),
    })

    check_parsing('&xxx_yyy', {
      --           01234567
      ast = {
        {
          'OpMissing:0:4:',
          children = {
            'Option(scope=0,ident=xxx):0:0:&xxx',
            'PlainIdentifier(scope=0,ident=_yyy):0:4:_yyy',
          },
        },
      },
      err = {
        arg = '_yyy',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionName', 'xxx'),
      hl('InvalidIdentifierName', '_yyy'),
    }, {
      [1] = {
        ast = {
          len = 4,
          err = REMOVE_THIS,
          ast = {
            'Option(scope=0,ident=xxx):0:0:&xxx',
          },
        },
        hl_fs = {
          [3] = REMOVE_THIS,
        },
      },
    })

    check_parsing('(1+&)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Integer(val=1):0:1:1',
                'Option(scope=0,ident=):0:3:&',
              },
            },
          },
        },
      },
      err = {
        arg = '&)',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Number', '1'),
      hl('BinaryPlus', '+'),
      hl('InvalidOptionSigil', '&'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(&+1)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Option(scope=0,ident=):0:1:&',
                'Integer(val=1):0:3:1',
              },
            },
          },
        },
      },
      err = {
        arg = '&+1)',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidOptionSigil', '&'),
      hl('BinaryPlus', '+'),
      hl('Number', '1'),
      hl('NestingParenthesis', ')'),
    })
  end)
  itp('works with $ENV', function()
    check_parsing('$', {
      --           0
      ast = {
        'Environment(ident=):0:0:$',
      },
      err = {
        arg = '$',
        msg = 'E15: Environment variable name missing',
      },
    }, {
      hl('InvalidEnvironmentSigil', '$'),
    })

    check_parsing('$g:A', {
      --           0123
      ast = {
        {
          'Colon:0:2::',
          children = {
            'Environment(ident=g):0:0:$g',
            'PlainIdentifier(scope=0,ident=A):0:3:A',
          },
        },
      },
      err = {
        arg = ':A',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', 'g'),
      hl('InvalidColon', ':'),
      hl('IdentifierName', 'A'),
    })

    check_parsing('$A', {
      --           01
      ast = {
        'Environment(ident=A):0:0:$A',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', 'A'),
    })

    check_parsing('$ABC', {
      --           0123
      ast = {
        'Environment(ident=ABC):0:0:$ABC',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', 'ABC'),
    })

    check_parsing('(1+$)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Integer(val=1):0:1:1',
                'Environment(ident=):0:3:$',
              },
            },
          },
        },
      },
      err = {
        arg = '$)',
        msg = 'E15: Environment variable name missing',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Number', '1'),
      hl('BinaryPlus', '+'),
      hl('InvalidEnvironmentSigil', '$'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('($+1)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Environment(ident=):0:1:$',
                'Integer(val=1):0:3:1',
              },
            },
          },
        },
      },
      err = {
        arg = '$+1)',
        msg = 'E15: Environment variable name missing',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidEnvironmentSigil', '$'),
      hl('BinaryPlus', '+'),
      hl('Number', '1'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('$_ABC', {
      --           01234
      ast = {
        'Environment(ident=_ABC):0:0:$_ABC',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', '_ABC'),
    })

    check_parsing('$_', {
      --           01
      ast = {
        'Environment(ident=_):0:0:$_',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', '_'),
    })

    check_parsing('$ABC_DEF', {
      --           01234567
      ast = {
        'Environment(ident=ABC_DEF):0:0:$ABC_DEF',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', 'ABC_DEF'),
    })
  end)
  itp('works with unary !', function()
    check_parsing('!', {
      --           0
      ast = {
        'Not:0:0:!',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Not', '!'),
    })

    check_parsing('!!', {
      --           01
      ast = {
        {
          'Not:0:0:!',
          children = {
            'Not:0:1:!',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Not', '!'),
      hl('Not', '!'),
    })

    check_parsing('!!1', {
      --           012
      ast = {
        {
          'Not:0:0:!',
          children = {
            {
              'Not:0:1:!',
              children = {
                'Integer(val=1):0:2:1',
              },
            },
          },
        },
      },
    }, {
      hl('Not', '!'),
      hl('Not', '!'),
      hl('Number', '1'),
    })

    check_parsing('!1', {
      --           01
      ast = {
        {
          'Not:0:0:!',
          children = {
            'Integer(val=1):0:1:1',
          },
        },
      },
    }, {
      hl('Not', '!'),
      hl('Number', '1'),
    })

    check_parsing('(!1)', {
      --           0123
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Not:0:1:!',
              children = {
                'Integer(val=1):0:2:1',
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Not', '!'),
      hl('Number', '1'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(!)', {
      --           012
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Not:0:1:!',
              children = {
                'Missing:0:2:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Not', '!'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(1!2)', {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'OpMissing:0:2:',
              children = {
                'Integer(val=1):0:1:1',
                {
                  'Not:0:2:!',
                  children = {
                    'Integer(val=2):0:3:2',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '!2)',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Number', '1'),
      hl('InvalidNot', '!'),
      hl('Number', '2'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('1!2', {
      --           012
      ast = {
        {
          'OpMissing:0:1:',
          children = {
            'Integer(val=1):0:0:1',
            {
              'Not:0:1:!',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '!2',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Number', '1'),
      hl('InvalidNot', '!'),
      hl('Number', '2'),
    }, {
      [1] = {
        ast = {
          len = 1,
          err = REMOVE_THIS,
          ast = {
            'Integer(val=1):0:0:1',
          },
        },
        hl_fs = {
          [2] = REMOVE_THIS,
          [3] = REMOVE_THIS,
        },
      },
    })
  end)
  itp('highlights numbers with prefix', function()
    check_parsing('0xABCDEF', {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0xABCDEF',
      },
    }, {
      hl('NumberPrefix', '0x'),
      hl('Number', 'ABCDEF'),
    })

    check_parsing('0Xabcdef', {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0Xabcdef',
      },
    }, {
      hl('NumberPrefix', '0X'),
      hl('Number', 'abcdef'),
    })

    check_parsing('0XABCDEF', {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0XABCDEF',
      },
    }, {
      hl('NumberPrefix', '0X'),
      hl('Number', 'ABCDEF'),
    })

    check_parsing('0xabcdef', {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0xabcdef',
      },
    }, {
      hl('NumberPrefix', '0x'),
      hl('Number', 'abcdef'),
    })

    check_parsing('0b001', {
      --           01234
      ast = {
        'Integer(val=1):0:0:0b001',
      },
    }, {
      hl('NumberPrefix', '0b'),
      hl('Number', '001'),
    })

    check_parsing('0B001', {
      --           01234
      ast = {
        'Integer(val=1):0:0:0B001',
      },
    }, {
      hl('NumberPrefix', '0B'),
      hl('Number', '001'),
    })

    check_parsing('0B00', {
      --           0123
      ast = {
        'Integer(val=0):0:0:0B00',
      },
    }, {
      hl('NumberPrefix', '0B'),
      hl('Number', '00'),
    })

    check_parsing('00', {
      --           01
      ast = {
        'Integer(val=0):0:0:00',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '0'),
    })

    check_parsing('001', {
      --           012
      ast = {
        'Integer(val=1):0:0:001',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '01'),
    })

    check_parsing('01', {
      --           01
      ast = {
        'Integer(val=1):0:0:01',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '1'),
    })

    check_parsing('1', {
      --           0
      ast = {
        'Integer(val=1):0:0:1',
      },
    }, {
      hl('Number', '1'),
    })
  end)
  itp('works (KLEE tests)', function()
    check_parsing('\0002&A:\000', {
      len = 0,
      ast = nil,
      err = {
        arg = '\0002&A:\000',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
    }, {
      [2] = {
        ast = {
          len = REMOVE_THIS,
          ast = {
            {
              'Colon:0:4::',
              children = {
                {
                  'OpMissing:0:2:',
                  children = {
                    'Integer(val=2):0:1:2',
                    'Option(scope=0,ident=A):0:2:&A',
                  },
                },
              },
            },
          },
          err = {
            msg = 'E15: Unexpected EOC character: %.*s',
          },
        },
        hl_fs = {
          hl('InvalidSpacing', '\0'),
          hl('Number', '2'),
          hl('InvalidOptionSigil', '&'),
          hl('InvalidOptionName', 'A'),
          hl('InvalidColon', ':'),
          hl('InvalidSpacing', '\0'),
        },
      },
      [3] = {
        ast = {
          len = 2,
          ast = {
            'Integer(val=2):0:1:2',
          },
          err = {
            msg = 'E15: Unexpected EOC character: %.*s',
          },
        },
        hl_fs = {
          hl('InvalidSpacing', '\0'),
          hl('Number', '2'),
        },
      },
    })
    check_parsing({data='01', size=1}, {
      len = 1,
      ast = {
        'Integer(val=0):0:0:0',
      },
    }, {
      hl('Number', '0'),
    })
    check_parsing({data='001', size=2}, {
      len = 2,
      ast = {
        'Integer(val=0):0:0:00',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '0'),
    })
    check_parsing('"\\U\\', {
      --           0123
      ast = {
        [[DoubleQuotedString(val="U\\"):0:0:"\U\]],
      },
      err = {
        arg = '"\\U\\',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
      hl('InvalidDoubleQuotedBody', '\\'),
    })
    check_parsing('"\\U', {
      --           012
      ast = {
        fmtn('DoubleQuotedString', 'val="U"', ':0:0:"\\U'),
      },
      err = {
        arg = '"\\U',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
    })
    check_parsing('|"\\U\\', {
      --           01234
      len = 0,
      err = {
        arg = '|"\\U\\',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
    }, {
      [2] = {
        ast = {
          len = REMOVE_THIS,
          ast = {
            {
              'Or:0:0:|',
              children = {
                'Missing:0:0:',
                fmtn('DoubleQuotedString', 'val="U\\\\"', ':0:1:"\\U\\'),
              },
            },
          },
          err = {
            msg = 'E15: Unexpected EOC character: %.*s',
          },
        },
        hl_fs = {
          hl('InvalidOr', '|'),
          hl('InvalidDoubleQuote', '"'),
          hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
          hl('InvalidDoubleQuotedBody', '\\'),
        },
      },
    })
    check_parsing('|"\\e"', {
      --           01234
      len = 0,
      err = {
        arg = '|"\\e"',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
    }, {
      [2] = {
        ast = {
          len = REMOVE_THIS,
          ast = {
            {
              'Or:0:0:|',
              children = {
                'Missing:0:0:',
                fmtn('DoubleQuotedString', 'val="\\027"', ':0:1:"\\e"'),
              },
            },
          },
          err = {
            msg = 'E15: Unexpected EOC character: %.*s',
          },
        },
        hl_fs = {
          hl('InvalidOr', '|'),
          hl('DoubleQuote', '"'),
          hl('DoubleQuotedEscape', '\\e'),
          hl('DoubleQuote', '"'),
        },
      },
    })
    check_parsing('|\029', {
      --           01
      len = 0,
      err = {
        arg = '|\029',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
    }, {
      [2] = {
        ast = {
          len = REMOVE_THIS,
          ast = {
            {
              'Or:0:0:|',
              children = {
                'Missing:0:0:',
                'PlainIdentifier(scope=0,ident=\029):0:1:\029',
              },
            },
          },
          err = {
            msg = 'E15: Unexpected EOC character: %.*s',
          },
        },
        hl_fs = {
          hl('InvalidOr', '|'),
          hl('InvalidIdentifierName', '\029'),
        },
      },
    })
    check_parsing('"\\<', {
      --           012
      ast = {
        fmtn('DoubleQuotedString', 'val="<"', ':0:0:"\\<'),
      },
      err = {
        arg = '"\\<',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\<'),
    })
    check_parsing('"\\1', {
      --           01 2
      ast = {
        fmtn('DoubleQuotedString', 'val="\\001"', ':0:0:"\\1'),
      },
      err = {
        arg = '"\\1',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedEscape', '\\1'),
    })
    check_parsing('}l', {
      --           01
      ast = {
        {
          'OpMissing:0:1:',
          children = {
            fmtn('UnknownFigure', '---', ':0:0:'),
            'PlainIdentifier(scope=0,ident=l):0:1:l',
          },
        },
      },
      err = {
        arg = '}l',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('InvalidFigureBrace', '}'),
      hl('InvalidIdentifierName', 'l'),
    }, {
      [1] = {
        ast = {
          len = 1,
          ast = {
            fmtn('UnknownFigure', '---', ':0:0:'),
          },
        },
        hl_fs = {
          [2] = REMOVE_THIS,
        },
      },
    })
    check_parsing(':?\000\000\000\000\000\000\000', {
      len = 2,
      ast = {
        {
          'Colon:0:0::',
          children = {
            'Missing:0:0:',
            {
              'Ternary:0:1:?',
              children = {
                'Missing:0:1:',
                'TernaryValue:0:1:?',
              },
            },
          },
        },
      },
      err = {
        arg = ':?\000\000\000\000\000\000\000',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('InvalidColon', ':'),
      hl('InvalidTernary', '?'),
    }, {
      [2] = {
        ast = {
          len = REMOVE_THIS,
        },
        hl_fs = {
          [3] = hl('InvalidSpacing', '\0'),
          [4] = hl('InvalidSpacing', '\0'),
          [5] = hl('InvalidSpacing', '\0'),
          [6] = hl('InvalidSpacing', '\0'),
          [7] = hl('InvalidSpacing', '\0'),
          [8] = hl('InvalidSpacing', '\0'),
          [9] = hl('InvalidSpacing', '\0'),
        },
      },
    })
  end)
  itp('works with assignments', function()
    check_asgn_parsing('a=b', {
      --                012
      ast = {
        {
          'Assignment(Plain):0:1:=',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:2:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('PlainAssignment', '='),
      hl('IdentifierName', 'b'),
    })

    check_asgn_parsing('a+=b', {
      --                0123
      ast = {
        {
          'Assignment(Add):0:1:+=',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:3:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('AssignmentWithAddition', '+='),
      hl('IdentifierName', 'b'),
    })

    check_asgn_parsing('a-=b', {
      --                0123
      ast = {
        {
          'Assignment(Subtract):0:1:-=',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:3:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('AssignmentWithSubtraction', '-='),
      hl('IdentifierName', 'b'),
    })

    check_asgn_parsing('a.=b', {
      --                0123
      ast = {
        {
          'Assignment(Concat):0:1:.=',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:3:b',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('AssignmentWithConcatenation', '.='),
      hl('IdentifierName', 'b'),
    })

    check_asgn_parsing('a', {
      --                0
      ast = {
        'PlainIdentifier(scope=0,ident=a):0:0:a',
      },
    }, {
      hl('IdentifierName', 'a'),
    })

    check_asgn_parsing('a b', {
      --                012
      ast = {
        {
          'OpMissing:0:1:',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:1: b',
          },
        },
      },
      err = {
        arg = 'b',
        msg = 'E15: Expected assignment operator or subscript: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('InvalidSpacing', ' '),
      hl('IdentifierName', 'b'),
    }, {
      [5] = {
        ast = {
          len = 2,
          ast = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
          err = REMOVE_THIS,
        },
        hl_fs = {
          [2] = REMOVE_THIS,
          [3] = REMOVE_THIS,
        }
      },
    })

    check_asgn_parsing('[a, b, c]', {
      --                012345678
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    'PlainIdentifier(scope=0,ident=c):0:6: c',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b', 1),
      hl('Comma', ','),
      hl('IdentifierName', 'c', 1),
      hl('List', ']'),
    })

    check_asgn_parsing('[a, b]', {
      --                012345
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('Comma', ','),
      hl('IdentifierName', 'b', 1),
      hl('List', ']'),
    })

    check_asgn_parsing('[a]', {
      --                012
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('List', ']'),
    })

    check_asgn_parsing('[]', {
      --                01
      ast = {
        'ListLiteral:0:0:[',
      },
      err = {
        arg = ']',
        msg = 'E475: Unable to assign to empty list: %.*s',
      },
    }, {
      hl('List', '['),
      hl('InvalidList', ']'),
    })

    check_asgn_parsing('a[1] += 3', {
      --                012345678
      ast = {
        {
          'Assignment(Add):0:4: +=',
          children = {
            {
              'Subscript:0:1:[',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'Integer(val=1):0:2:1',
              },
            },
            'Integer(val=3):0:7: 3',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('Number', '1'),
      hl('SubscriptBracket', ']'),
      hl('AssignmentWithAddition', '+=', 1),
      hl('Number', '3', 1),
    })

    check_asgn_parsing('a[1 + 2] += 3', {
      --                0123456789012
      --                0         1
      ast = {
        {
          'Assignment(Add):0:8: +=',
          children = {
            {
              'Subscript:0:1:[',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'BinaryPlus:0:3: +',
                  children = {
                    'Integer(val=1):0:2:1',
                    'Integer(val=2):0:5: 2',
                  },
                },
              },
            },
            'Integer(val=3):0:11: 3',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('Number', '1'),
      hl('BinaryPlus', '+', 1),
      hl('Number', '2', 1),
      hl('SubscriptBracket', ']'),
      hl('AssignmentWithAddition', '+=', 1),
      hl('Number', '3', 1),
    })

    check_asgn_parsing('a[{-> {b{3}: 4}[5]}()] += 6', {
      --                012345678901234567890123456
      --                0         1         2
      ast = {
        {
          'Assignment(Add):0:22: +=',
          children = {
            {
              'Subscript:0:1:[',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'Call:0:19:(',
                  children = {
                    {
                      fmtn('Lambda', '\\di', ':0:2:{'),
                      children = {
                        {
                          'Arrow:0:3:->',
                          children = {
                            {
                              'Subscript:0:15:[',
                              children = {
                                {
                                  fmtn('DictLiteral', '-di', ':0:5: {'),
                                  children = {
                                    {
                                      'Colon:0:11::',
                                      children = {
                                        {
                                          'ComplexIdentifier:0:8:',
                                          children = {
                                            'PlainIdentifier(scope=0,ident=b):0:7:b',
                                            {
                                              fmtn('CurlyBracesIdentifier', '--i', ':0:8:{'),
                                              children = {
                                                'Integer(val=3):0:9:3',
                                              },
                                            },
                                          },
                                        },
                                        'Integer(val=4):0:12: 4',
                                      },
                                    },
                                  },
                                },
                                'Integer(val=5):0:16:5',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            'Integer(val=6):0:25: 6',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('Dict', '{', 1),
      hl('IdentifierName', 'b'),
      hl('Curly', '{'),
      hl('Number', '3'),
      hl('Curly', '}'),
      hl('Colon', ':'),
      hl('Number', '4', 1),
      hl('Dict', '}'),
      hl('SubscriptBracket', '['),
      hl('Number', '5'),
      hl('SubscriptBracket', ']'),
      hl('Lambda', '}'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
      hl('SubscriptBracket', ']'),
      hl('AssignmentWithAddition', '+=', 1),
      hl('Number', '6', 1),
    })

    check_asgn_parsing('a{1}.2[{-> {b{3}: 4}[5]}()]', {
      --                012345678901234567890123456
      --                0         1         2
      ast = {
        {
          'Subscript:0:6:[',
          children = {
            {
              'ConcatOrSubscript:0:4:.',
              children = {
                {
                  'ComplexIdentifier:0:1:',
                  children = {
                    'PlainIdentifier(scope=0,ident=a):0:0:a',
                    {
                      fmtn('CurlyBracesIdentifier', '--i', ':0:1:{'),
                      children = {
                        'Integer(val=1):0:2:1',
                      },
                    },
                  },
                },
                'PlainKey(key=2):0:5:2',
              },
            },
            {
              'Call:0:24:(',
              children = {
                {
                  fmtn('Lambda', '\\di', ':0:7:{'),
                  children = {
                    {
                      'Arrow:0:8:->',
                      children = {
                        {
                          'Subscript:0:20:[',
                          children = {
                            {
                              fmtn('DictLiteral', '-di', ':0:10: {'),
                              children = {
                                {
                                  'Colon:0:16::',
                                  children = {
                                    {
                                      'ComplexIdentifier:0:13:',
                                      children = {
                                        'PlainIdentifier(scope=0,ident=b):0:12:b',
                                        {
                                          fmtn('CurlyBracesIdentifier', '--i', ':0:13:{'),
                                          children = {
                                            'Integer(val=3):0:14:3',
                                          },
                                        },
                                      },
                                    },
                                    'Integer(val=4):0:17: 4',
                                  },
                                },
                              },
                            },
                            'Integer(val=5):0:21:5',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Curly', '{'),
      hl('Number', '1'),
      hl('Curly', '}'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
      hl('SubscriptBracket', '['),
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('Dict', '{', 1),
      hl('IdentifierName', 'b'),
      hl('Curly', '{'),
      hl('Number', '3'),
      hl('Curly', '}'),
      hl('Colon', ':'),
      hl('Number', '4', 1),
      hl('Dict', '}'),
      hl('SubscriptBracket', '['),
      hl('Number', '5'),
      hl('SubscriptBracket', ']'),
      hl('Lambda', '}'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
      hl('SubscriptBracket', ']'),
    })

    check_asgn_parsing('a', {
      --                0
      ast = {
        'PlainIdentifier(scope=0,ident=a):0:0:a',
      },
    }, {
      hl('IdentifierName', 'a'),
    })

    check_asgn_parsing('{a}', {
      --                012
      ast = {
        {
          fmtn('CurlyBracesIdentifier', '--i', ':0:0:{'),
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
    }, {
      hl('FigureBrace', '{'),
      hl('IdentifierName', 'a'),
      hl('Curly', '}'),
    })

    check_asgn_parsing('{a}b', {
      --                0123
      ast = {
        {
          'ComplexIdentifier:0:3:',
          children = {
            {
              fmtn('CurlyBracesIdentifier', '--i', ':0:0:{'),
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
            'PlainIdentifier(scope=0,ident=b):0:3:b',
          },
        },
      },
    }, {
      hl('FigureBrace', '{'),
      hl('IdentifierName', 'a'),
      hl('Curly', '}'),
      hl('IdentifierName', 'b'),
    })

    check_asgn_parsing('a{b}c', {
      --                01234
      ast = {
        {
          'ComplexIdentifier:0:1:',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'ComplexIdentifier:0:4:',
              children = {
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:1:{'),
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:2:b',
                  },
                },
                'PlainIdentifier(scope=0,ident=c):0:4:c',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
      hl('IdentifierName', 'c'),
    })

    check_asgn_parsing('a{b}c[0]', {
      --                01234567
      ast = {
        {
          'Subscript:0:5:[',
          children = {
            {
              'ComplexIdentifier:0:1:',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'ComplexIdentifier:0:4:',
                  children = {
                    {
                      fmtn('CurlyBracesIdentifier', '--i', ':0:1:{'),
                      children = {
                        'PlainIdentifier(scope=0,ident=b):0:2:b',
                      },
                    },
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                  },
                },
              },
            },
            'Integer(val=0):0:6:0',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
      hl('IdentifierName', 'c'),
      hl('SubscriptBracket', '['),
      hl('Number', '0'),
      hl('SubscriptBracket', ']'),
    })

    check_asgn_parsing('a{b}c.0', {
      --                0123456
      ast = {
        {
          'ConcatOrSubscript:0:5:.',
          children = {
            {
              'ComplexIdentifier:0:1:',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'ComplexIdentifier:0:4:',
                  children = {
                    {
                      fmtn('CurlyBracesIdentifier', '--i', ':0:1:{'),
                      children = {
                        'PlainIdentifier(scope=0,ident=b):0:2:b',
                      },
                    },
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                  },
                },
              },
            },
            'PlainKey(key=0):0:6:0',
          },
        },
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
      hl('IdentifierName', 'c'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '0'),
    })

    check_asgn_parsing('[a{b}c[0].0]', {
      --                012345678901
      --                0         1
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'ConcatOrSubscript:0:9:.',
              children = {
                {
                  'Subscript:0:6:[',
                  children = {
                    {
                      'ComplexIdentifier:0:2:',
                      children = {
                        'PlainIdentifier(scope=0,ident=a):0:1:a',
                        {
                          'ComplexIdentifier:0:5:',
                          children = {
                            {
                              fmtn('CurlyBracesIdentifier', '--i', ':0:2:{'),
                              children = {
                                'PlainIdentifier(scope=0,ident=b):0:3:b',
                              },
                            },
                            'PlainIdentifier(scope=0,ident=c):0:5:c',
                          },
                        },
                      },
                    },
                    'Integer(val=0):0:7:0',
                  },
                },
                'PlainKey(key=0):0:10:0',
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
      hl('IdentifierName', 'c'),
      hl('SubscriptBracket', '['),
      hl('Number', '0'),
      hl('SubscriptBracket', ']'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '0'),
      hl('List', ']'),
    })

    check_asgn_parsing('{a}{b}', {
      --                012345
      ast = {
        {
          'ComplexIdentifier:0:3:',
          children = {
            {
              fmtn('CurlyBracesIdentifier', '--i', ':0:0:{'),
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
            {
              fmtn('CurlyBracesIdentifier', '--i', ':0:3:{'),
              children = {
                'PlainIdentifier(scope=0,ident=b):0:4:b',
              },
            },
          },
        },
      },
    }, {
      hl('FigureBrace', '{'),
      hl('IdentifierName', 'a'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('IdentifierName', 'b'),
      hl('Curly', '}'),
    })

    check_asgn_parsing('a.b{c}{d}', {
      --                012345678
      ast = {
        {
          'OpMissing:0:3:',
          children = {
            {
              'ConcatOrSubscript:0:1:.',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainKey(key=b):0:2:b',
              },
            },
            {
              'ComplexIdentifier:0:6:',
              children = {
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:3:{'),
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                  },
                },
                {
                  fmtn('CurlyBracesIdentifier', '--i', ':0:6:{'),
                  children = {
                    'PlainIdentifier(scope=0,ident=d):0:7:d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '{c}{d}',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('IdentifierName', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', 'b'),
      hl('InvalidFigureBrace', '{'),
      hl('IdentifierName', 'c'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('IdentifierName', 'd'),
      hl('Curly', '}'),
    })

    check_asgn_parsing('[a] = 1', {
      --                0123456
      ast = {
        {
          'Assignment(Plain):0:3: =',
          children = {
            {
              'ListLiteral:0:0:[',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
            'Integer(val=1):0:5: 1',
          },
        },
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('List', ']'),
      hl('PlainAssignment', '=', 1),
      hl('Number', '1', 1),
    })

    check_asgn_parsing('[a[b], [c, [d, [e]]]] = 1', {
      --                0123456789012345678901234
      --                0         1         2
      ast = {
        {
          'Assignment(Plain):0:21: =',
          children = {
            {
              'ListLiteral:0:0:[',
              children = {
                {
                  'Comma:0:5:,',
                  children = {
                    {
                      'Subscript:0:2:[',
                      children = {
                        'PlainIdentifier(scope=0,ident=a):0:1:a',
                        'PlainIdentifier(scope=0,ident=b):0:3:b',
                      },
                    },
                    {
                      'ListLiteral:0:6: [',
                      children = {
                        {
                          'Comma:0:9:,',
                          children = {
                            'PlainIdentifier(scope=0,ident=c):0:8:c',
                            {
                              'ListLiteral:0:10: [',
                              children = {
                                {
                                  'Comma:0:13:,',
                                  children = {
                                    'PlainIdentifier(scope=0,ident=d):0:12:d',
                                    {
                                      'ListLiteral:0:14: [',
                                      children = {
                                        'PlainIdentifier(scope=0,ident=e):0:16:e',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            'Integer(val=1):0:23: 1',
          },
        },
      },
      err = {
        arg = '[c, [d, [e]]]] = 1',
        msg = 'E475: Nested lists not allowed when assigning: %.*s',
      },
    }, {
      hl('List', '['),
      hl('IdentifierName', 'a'),
      hl('SubscriptBracket', '['),
      hl('IdentifierName', 'b'),
      hl('SubscriptBracket', ']'),
      hl('Comma', ','),
      hl('InvalidList', '[', 1),
      hl('IdentifierName', 'c'),
      hl('Comma', ','),
      hl('InvalidList', '[', 1),
      hl('IdentifierName', 'd'),
      hl('Comma', ','),
      hl('InvalidList', '[', 1),
      hl('IdentifierName', 'e'),
      hl('List', ']'),
      hl('List', ']'),
      hl('List', ']'),
      hl('List', ']'),
      hl('PlainAssignment', '=', 1),
      hl('Number', '1', 1),
    })

    check_asgn_parsing('$X += 1', {
      --                0123456
      ast = {
        {
          'Assignment(Add):0:2: +=',
          children = {
            'Environment(ident=X):0:0:$X',
            'Integer(val=1):0:5: 1',
          },
        },
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', 'X'),
      hl('AssignmentWithAddition', '+=', 1),
      hl('Number', '1', 1),
    })

    check_asgn_parsing('@a .= 1', {
      --                0123456
      ast = {
        {
          'Assignment(Concat):0:2: .=',
          children = {
            'Register(name=a):0:0:@a',
            'Integer(val=1):0:5: 1',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('AssignmentWithConcatenation', '.=', 1),
      hl('Number', '1', 1),
    })

    check_asgn_parsing('&option -= 1', {
      --                012345678901
      --                0         1
      ast = {
        {
          'Assignment(Subtract):0:7: -=',
          children = {
            'Option(scope=0,ident=option):0:0:&option',
            'Integer(val=1):0:10: 1',
          },
        },
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionName', 'option'),
      hl('AssignmentWithSubtraction', '-=', 1),
      hl('Number', '1', 1),
    })

    check_asgn_parsing('[$X, @a, &l:option] = [1, 2, 3]', {
      --                0123456789012345678901234567890
      --                0         1         2         3
      ast = {
        {
          'Assignment(Plain):0:19: =',
          children = {
            {
              'ListLiteral:0:0:[',
              children = {
                {
                  'Comma:0:3:,',
                  children = {
                    'Environment(ident=X):0:1:$X',
                    {
                      'Comma:0:7:,',
                      children = {
                        'Register(name=a):0:4: @a',
                        'Option(scope=l,ident=option):0:8: &l:option',
                      },
                    },
                  },
                },
              },
            },
            {
              'ListLiteral:0:21: [',
              children = {
                {
                  'Comma:0:24:,',
                  children = {
                    'Integer(val=1):0:23:1',
                    {
                      'Comma:0:27:,',
                      children = {
                        'Integer(val=2):0:25: 2',
                        'Integer(val=3):0:28: 3',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('EnvironmentSigil', '$'),
      hl('EnvironmentName', 'X'),
      hl('Comma', ','),
      hl('Register', '@a', 1),
      hl('Comma', ','),
      hl('OptionSigil', '&', 1),
      hl('OptionScope', 'l'),
      hl('OptionScopeDelimiter', ':'),
      hl('OptionName', 'option'),
      hl('List', ']'),
      hl('PlainAssignment', '=', 1),
      hl('List', '[', 1),
      hl('Number', '1'),
      hl('Comma', ','),
      hl('Number', '2', 1),
      hl('Comma', ','),
      hl('Number', '3', 1),
      hl('List', ']'),
    })
  end)
  itp('works with non-ASCII characters', function()
    check_parsing('"«»"«»', {
      --           013568
      ast = {
        {
          'OpMissing:0:6:',
          children = {
            'DoubleQuotedString(val="«»"):0:0:"«»"',
            {
              'ComplexIdentifier:0:8:',
              children = {
                'PlainIdentifier(scope=0,ident=«):0:6:«',
                'PlainIdentifier(scope=0,ident=»):0:8:»',
              },
            },
          },
        },
      },
      err = {
        arg = '«»',
        msg = 'E15: Unidentified character: %.*s',
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedBody', '«»'),
      hl('DoubleQuote', '"'),
      hl('InvalidIdentifierName', '«'),
      hl('InvalidIdentifierName', '»'),
    }, {
      [1] = {
        ast = {
          ast = {
            'DoubleQuotedString(val="«»"):0:0:"«»"',
          },
          len = 6,
        },
        hl_fs = {
          [5] = REMOVE_THIS,
          [4] = REMOVE_THIS,
        },
      },
    })
    check_parsing('"\192"\192"foo"', {
      --           01   23   45678
      ast = {
        {
          'OpMissing:0:3:',
          children = {
            'DoubleQuotedString(val="\192"):0:0:"\192"',
            {
              'OpMissing:0:4:',
              children = {
                'PlainIdentifier(scope=0,ident=\192):0:3:\192',
                'DoubleQuotedString(val="foo"):0:4:"foo"',
              },
            },
          },
        },
      },
      err = {
        arg = '\192"foo"',
        msg = 'E15: Unidentified character: %.*s',
      },
    }, {
      hl('DoubleQuote', '"'),
      hl('DoubleQuotedBody', '\192'),
      hl('DoubleQuote', '"'),
      hl('InvalidIdentifierName', '\192'),
      hl('InvalidDoubleQuote', '"'),
      hl('InvalidDoubleQuotedBody', 'foo'),
      hl('InvalidDoubleQuote', '"'),
    }, {
      [1] = {
        ast = {
          ast = {
            'DoubleQuotedString(val="\192"):0:0:"\192"',
          },
          len = 3,
        },
        hl_fs = {
          [4] = REMOVE_THIS,
          [5] = REMOVE_THIS,
          [6] = REMOVE_THIS,
          [7] = REMOVE_THIS,
        },
      },
    })
  end)
end
