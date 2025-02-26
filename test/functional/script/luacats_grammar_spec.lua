local t = require('test.testutil')

local eq = t.eq

local grammar = require('gen.luacats_grammar')

describe('luacats grammar', function()
  --- @param text string
  --- @param exp table<string,string>
  local function test(text, exp)
    it(string.format('can parse %q', text), function()
      eq(exp, grammar:match(text))
    end)
  end

  test('@param hello vim.type', {
    kind = 'param',
    name = 'hello',
    type = 'vim.type',
  })

  test('@param hello vim.type this is a description', {
    kind = 'param',
    name = 'hello',
    type = 'vim.type',
    desc = 'this is a description',
  })

  test('@param hello vim.type|string this is a description', {
    kind = 'param',
    name = 'hello',
    type = 'vim.type|string',
    desc = 'this is a description',
  })

  test('@param hello vim.type?|string? this is a description', {
    kind = 'param',
    name = 'hello',
    type = 'vim.type?|string?',
    desc = 'this is a description',
  })

  test('@return string hello this is a description', {
    kind = 'return',
    {
      name = 'hello',
      type = 'string',
    },
    desc = 'this is a description',
  })

  test('@return fun() hello this is a description', {
    kind = 'return',
    {
      name = 'hello',
      type = 'fun()',
    },
    desc = 'this is a description',
  })

  test('@return fun(a: string[]): string hello this is a description', {
    kind = 'return',
    {
      name = 'hello',
      type = 'fun(a: string[]): string',
    },
    desc = 'this is a description',
  })

  test('@return fun(a: table<string,any>): string hello this is a description', {
    kind = 'return',
    {
      name = 'hello',
      type = 'fun(a: table<string,any>): string',
    },
    desc = 'this is a description',
  })

  test('@param ... string desc', {
    kind = 'param',
    name = '...',
    type = 'string',
    desc = 'desc',
  })

  test('@param level (integer|string) desc', {
    kind = 'param',
    name = 'level',
    type = 'integer|string',
    desc = 'desc',
  })

  test('@return (string command) the command and arguments', {
    kind = 'return',
    {
      name = 'command',
      type = 'string',
    },
    desc = 'the command and arguments',
  })

  test('@return (string command, string[] args) the command and arguments', {
    kind = 'return',
    {
      name = 'command',
      type = 'string',
    },
    {
      name = 'args',
      type = 'string[]',
    },
    desc = 'the command and arguments',
  })

  test('@param rfc "rfc2396" | "rfc2732" | "rfc3986" | nil', {
    kind = 'param',
    name = 'rfc',
    type = '"rfc2396" | "rfc2732" | "rfc3986" | nil',
  })

  test('@param position_encoding "utf-8" | "utf-16" | "utf-32" | nil', {
    kind = 'param',
    name = 'position_encoding',
    type = '"utf-8" | "utf-16" | "utf-32" | nil',
  })

  -- handle a : after the param type
  test('@param a b: desc', {
    kind = 'param',
    name = 'a',
    type = 'b',
    desc = 'desc',
  })

  test(
    '@field prefix? string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)',
    {
      kind = 'field',
      name = 'prefix?',
      type = 'string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)',
    }
  )

  test('@field [integer] integer', {
    kind = 'field',
    name = '[integer]',
    type = 'integer',
  })

  test('@field [1] integer', {
    kind = 'field',
    name = '[1]',
    type = 'integer',
  })

  test('@param type `T` this is a generic type', {
    desc = 'this is a generic type',
    kind = 'param',
    name = 'type',
    type = '`T`',
  })

  test('@param type [number,string,"good"|"bad"] this is a tuple type', {
    desc = 'this is a tuple type',
    kind = 'param',
    name = 'type',
    type = '[number,string,"good"|"bad"]',
  })

  test('@class vim.diagnostic.JumpOpts', {
    kind = 'class',
    name = 'vim.diagnostic.JumpOpts',
  })

  test('@class vim.diagnostic.JumpOpts : vim.diagnostic.GetOpts', {
    kind = 'class',
    name = 'vim.diagnostic.JumpOpts',
    parent = 'vim.diagnostic.GetOpts',
  })

  test('@param opt? { cmd?: string[] } Options', {
    kind = 'param',
    name = 'opt?',
    type = '{ cmd?: string[] }',
    desc = 'Options',
  })

  ---@type [string, string?][]
  local test_cases = {
    { 'foo' },
    { 'foo   ', 'foo' }, -- trims whitespace
    { 'true' },
    { 'vim.type' },
    { 'vim-type' },
    { 'vim_type' },
    { 'foo.bar-baz_baz' },
    { '`ABC`' },
    { '42' },
    { '-42' },
    { '(foo)', 'foo' }, -- removes unnecessary parens
    { 'true?' },
    { '(true)?' },
    { 'string[]' },
    { 'string|number' },
    { '(string)[]' },
    { '(string|number)[]' },
    { 'coalesce??', 'coalesce?' }, -- removes unnecessary ?
    { 'number?|string' },
    { "'foo'|'bar'|'baz'" },
    { '"foo"|"bar"|"baz"' },
    { '(number)?|string' }, --
    { 'number[]|string' },
    { 'string[]?' },
    { 'foo?[]' },
    { 'vim.type?|string?   ', 'vim.type?|string?' },
    { 'number[][]' },
    { 'number[][][]' },
    { 'number[][]?' },
    { 'string|integer[][]?' },

    -- tuples
    { '[string]' },
    { '[1]' },
    { '[string, number]' },
    { '[string, number]?' },
    { '[string, number][]' },
    { '[string, number]|string' },
    { '[string|number, number?]' },
    { 'string|[string, number]' },
    { '(true)?|[foo]' },
    { '[fun(a: string):boolean]' },

    -- dict
    { '{[string]:string}' },
    { '{ [ string ] : string }' },
    { '{ [ string|any ] : string }' },
    { '{[string]: string, [number]: boolean}' },

    -- key-value table
    { 'table<string,any>' },
    { 'table' },
    { 'string|table|boolean' },
    { 'string|table|(boolean)' },

    -- table literal
    { '{foo: number}' },
    { '{foo: string, bar: [number, boolean]?}' },
    { 'boolean|{reverse?:boolean}' },
    { '{ cmd?: string[] }' },

    -- function
    { 'fun(a: string, b:foo|bar): string' },
    { 'fun(a?: string): string' },
    { 'fun(a?: string): number?,string?' },
    { '(fun(a: string, b:foo|bar): string)?' },
    { 'fun(a: string, b:foo|bar): string, string' },
    { 'fun(a: string, b:foo|bar)' },
    { 'fun(_, foo, bar): string' },
    { 'fun(...): number' },
    { 'fun( ... ): number' },
    { 'fun(...:number): number' },
    { 'fun( ... : number): number' },

    -- generics
    { 'elem_or_list<string>' },
    {
      'elem_or_list<fun(client: vim.lsp.Client, initialize_result: lsp.InitializeResult)>',
      nil,
    },
  }

  for _, tc in ipairs(test_cases) do
    local ty, exp_ty = tc[1], tc[2]
    if exp_ty == nil then
      exp_ty = ty
    end

    local var, desc = 'x', 'some desc'
    local param = string.format('@param %s %s %s', var, ty, desc)
    test(param, {
      kind = 'param',
      name = var,
      type = exp_ty,
      desc = desc,
    })
  end
end)
