--[[ Copyright (c) 2009 Peter "Corsix" Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. --]]

-- this C parser was taken from Corsix-TH, I'm sure this could be done much
-- better (i.e.: I think everything I do could be substitutions made with LPeg
-- during parsing), but I've just learned enough basic LPeg to make this
-- work.
-- see: http://lua-users.org/wiki/LpegRecipes

local lpeg = require "lpeg"

local C, P, R, S, V = lpeg.C, lpeg.P, lpeg.R, lpeg.S, lpeg.V
local Carg, Cc, Cp, Ct = lpeg.Carg, lpeg.Cc, lpeg.Cp, lpeg.Ct

local tokens = P { "tokens";
  -- Comment of form /* ... */
  comment = Ct(P"/*" * C((V"newline" + (1 - P"*/"))^0) * P"*/" * Cc"comment"),

  -- Single line comment
  line_comment = Ct(P"//" * C((1 - V"newline")^0)  * Cc"comment_line"),

  -- Single platform independent line break which increments line number
  newline = (P"\r\n" + P"\n\r" + S"\r\n") * (Cp() * Carg(1)) / function(pos, state)
    state.line = state.line + 1
    state.line_start = pos
  end,

  -- Line continuation
  line_extend = Ct(C(P[[\]] * V"newline") * Cc"line_extend"),

  -- Whitespace of any length (includes newlines)
  whitespace = Ct(C((S" \t" + V"newline")^1) * Cc"whitespace"),

  -- Special form of #include with filename followed in angled brackets (matches 3 tokens)
  include = Ct(C(P"#include") * Cc"preprocessor") *
            Ct(C(S" \t"^1) * Cc"whitespace") *
            Ct(C(P"<" * (1 - P">")^1 * P">") * Cc"string"),

  -- Preprocessor instruction
  preprocessor = V"include" +
                 Ct(C(P"#" * P" "^0 * ( P"define" + P"elif" + P"else" + P"endif" + P"#" +
                               P"error" + P"ifdef" + P"ifndef" + P"if" + P"import" +
                               P"include" + P"line" + P"pragma" + P"undef" + P"using" +
                               P"pragma"
                             ) * #S" \r\n\t") * Cc"preprocessor"),

  -- Identifier of form [a-zA-Z_][a-zA-Z0-9_]*
  identifier = Ct(C(R("az","AZ","__") * R("09","az","AZ","__")^0) * Cc"identifier"),

  -- Single character in a string
  sstring_char = R("\001&","([","]\255") + (P"\\" * S[[ntvbrfa\?'"0x]]),
  dstring_char = R("\001!","#[","]\255") + (P"\\" * S[[ntvbrfa\?'"0x]]),

  -- String literal
  string = Ct(C(P"'" * (V"sstring_char" + P'"')^0 * P"'" +
                P'"' * (V"dstring_char" + P"'")^0 * P'"') * Cc"string"),

  -- Operator
  operator = Ct(C(P">>=" + P"<<=" + P"..." +
                  P"::" + P"<<" + P">>" + P"<=" + P">=" + P"==" + P"!=" +
                  P"||" + P"&&" + P"++" + P"--" + P"->" + P"+=" + P"-=" +
                  P"*=" + P"/=" + P"|=" + P"&=" + P"^=" + S"+-*/=<>%^|&.?:!~,") * Cc"operator"),

  -- Misc. char (token type is the character itself)
  char = Ct(C(S"[]{}();") / function(x) return x, x end),

  -- Hex, octal or decimal number
  int = Ct(C((P"0x" * R("09","af","AF")^1) + (P"0" * R"07"^0) + R"09"^1) * Cc"integer"),

  -- Floating point number
  f_exponent = S"eE" + S"+-"^-1 * R"09"^1,
  f_terminator = S"fFlL",
  float = Ct(C(
            R"09"^1 * V"f_exponent" * V"f_terminator"^-1 +
            R"09"^0 * P"." * R"09"^1 * V"f_exponent"^-1 * V"f_terminator"^-1 +
            R"09"^1 * P"." * R"09"^0 * V"f_exponent"^-1 * V"f_terminator"^-1
          ) * Cc"float"),

  -- Any token
  token = V"comment" +
          V"line_comment" +
          V"identifier" +
          V"whitespace" +
          V"line_extend" +
          V"preprocessor" +
          V"string" +
          V"char" +
          V"operator" +
          V"float" +
          V"int",

  -- Error for when nothing else matches
  error = (Cp() * C(P(1) ^ -8) * Carg(1)) / function(pos, where, state)
    error(("Tokenising error on line %i, position %i, near '%s'")
      :format(state.line, pos - state.line_start + 1, where))
  end,

  -- Match end of input or throw error
  finish = -P(1) + V"error",

  -- Match stream of tokens into a table
  tokens = Ct(V"token" ^ 0) * V"finish",
}

local function TokeniseC(str)
  return tokens:match(str, 1, {line = 1, line_start = 1})
end

local function set(t)
  local s = {}
  for _, v in ipairs(t) do
    s[v] = true
  end
  return s
end

local C_keywords = set {  -- luacheck: ignore
  "break", "case", "char", "const", "continue", "default", "do", "double",
  "else", "enum", "extern", "float", "for", "goto", "if", "int", "long",
  "register", "return", "short", "signed", "sizeof", "static", "struct",
  "switch", "typedef", "union", "unsigned", "void", "volatile", "while",
}

-- Very primitive C formatter that tries to put "things" inside braces on one
-- line. This is a step done after preprocessing the C source to ensure that
-- the duplicate line detecter can more reliably pick out identical declarations.
--
-- an example:
--   struct mystruct
--   {
--      int a;
--      int b;
--   };
--
-- would become:
--  struct mystruct { int a; int b; };
--
--  The first one will have a lot of false positives (the line '{' for
--  example), the second one is more unique.
local function formatc(str)
  local toks = TokeniseC(str)
  local result = {}
  local block_level = 0
  local allow_one_nl = false
  local end_at_brace = false

  for _, token in ipairs(toks) do
    local typ = token[2]
    if typ == '{' then
      block_level = block_level + 1
    elseif typ == '}' then
      block_level = block_level - 1

      if block_level == 0 and end_at_brace then
        -- if we're not inside a block, we're at the basic statement level,
        -- and ';' indicates we're at the end of a statement, so we put end
        -- it with a newline.
        token[1] = token[1] .. "\n"
        end_at_brace = false
      end
    elseif typ == 'identifier' then
      -- static and/or inline usually indicate an inline header function,
      -- which has no trailing ';', so we have to add a newline after the
      -- '}' ourselves.
      local tok = token[1]
      if tok == 'static' or tok == 'inline' or tok == '__inline' then
        end_at_brace = true
      end
    elseif typ == 'preprocessor' then
      -- preprocessor directives don't end in ';' but need their newline, so
      -- we're going to allow the next newline to pass.
      allow_one_nl = true
    elseif typ == ';' then
      if block_level == 0 then
        -- if we're not inside a block, we're at the basic statement level,
        -- and ';' indicates we're at the end of a statement, so we put end
        -- it with a newline.
        token[1] = ";\n"
      end
    elseif typ == 'whitespace' then
      -- replace all whitespace by one space
      local repl = " "

      -- except when allow_on_nl is true and there's a newline in the whitespace
      if string.find(token[1], "[\r\n]+") and allow_one_nl == true then
        -- in that case we replace all whitespace by one newline
        repl = "\n"
        allow_one_nl = false
      end

      token[1] = string.gsub(token[1], "%s+", repl)
    end
    result[#result + 1] = token[1]
  end

  return table.concat(result)
end

-- standalone operation (very handy for debugging)
local function standalone(...)  -- luacheck: ignore
  local Preprocess = require("preprocess")
  Preprocess.add_to_include_path('./../../src')
  Preprocess.add_to_include_path('./../../build/include')
  Preprocess.add_to_include_path('./../../.deps/usr/include')

  local raw = Preprocess.preprocess('', arg[1])

  local formatted
  if #arg == 2 and arg[2] == 'no' then
      formatted = raw
  else
      formatted = formatc(raw)
  end

  print(formatted)
end
-- uncomment this line (and comment the `return`) for standalone debugging
-- example usage:
--    ../../.deps/usr/bin/luajit formatc.lua ../../include/fileio.h.generated.h
--    ../../.deps/usr/bin/luajit formatc.lua /usr/include/malloc.h
-- standalone(...)
return formatc
