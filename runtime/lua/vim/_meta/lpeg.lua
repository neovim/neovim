--- @meta
error('Cannot require a meta file')

-- These types were taken from https://github.com/LuaCATS/lpeg
-- (based on revision 4aded588f9531d89555566bb1de27490354b91c7)
-- with types being renamed to include the vim namespace and with some descriptions made less verbose.

-- The documentation for operators were take from https://www.inf.puc-rio.br/~roberto/lpeg
-- with some rewrites (mostly removal of verbose lines)

---@defgroup vim.lpeg
---<pre>help
---LPeg is a pattern-matching library for Lua, based on
---Parsing Expression Grammars (https://bford.info/packrat/) (PEGs).
---
---                                                                    *lua-lpeg*
---                                                            *vim.lpeg.Pattern*
---The LPeg library for parsing expression grammars is included as `vim.lpeg`
---(https://www.inf.puc-rio.br/~roberto/lpeg/).
---
---In addition, its regex-like interface is available as |vim.re|
---(https://www.inf.puc-rio.br/~roberto/lpeg/re.html).
---
---                                                                 *vim.lpeg.op*
---                                                *vim.lpeg.op.len* *vim.lpeg.#*
--- Returns a pattern that matches only if the input string matches patt, but
--- without consuming any input, independently of success or failure.
---
--- This pattern never produces any capture.
---
---                                    *vim.lpeg.op.unary-sub* *vim.lpeg.unary.-*
--- Returns a pattern that matches only if the input string does not match patt.
--- It does not consume any input, independently of success or failure.
---
--- As an example, the pattern -lpeg.P(1) matches only the end of string.
---
--- This pattern never produces any captures, because either patt fails or -patt
--- fails. (A failing pattern never produces captures.)
---
--- Note that -patt is equivalent to lpeg.P("") - patt.
---
---                                                *vim.lpeg.op.add* *vim.lpeg.+*
--- Returns a pattern equivalent to an ordered choice of patt1 and patt2. It
--- matches either patt1 or patt2, with no backtracking once one of them succeeds.
---
---                                                *vim.lpeg.op.sub* *vim.lpeg.-*
--- Returns a pattern that asserts that the input does not match patt2 and then
--- matches patt1.
---
--- When successful, this pattern produces all captures from patt1. It never
--- produces any capture from patt2.
---
---                                            *vim.lpeg.op.star* *vim.lpeg.star*
--- Returns a pattern that matches patt1 and then matches patt2, starting where
--- patt1 finished.
---
---                                                *vim.lpeg.op.pow* *vim.lpeg.^*
--- If n is nonnegative then it matches n or more occurrences of patt.
---
--- Otherwise, when n is negative, then it matches at most |n| occurrences of
--- patt.
---
--- In particular, patt^0 is equivalent to patt* in regex, patt^1 is equivalent
--- to patt+ in regex, and patt^-1 is equivalent to patt? in regex.
---
--- In all cases, the resulting pattern is greedy with no backtracking (also
--- called a possessive repetition). That is, it matches only the longest
--- possible sequence of matches for patt.
---
---                                                *vim.lpeg.op.div* *vim.lpeg./*
--- Does different things depending on the type of the denominator.
---
--- When the denominator is a string, it creates a capture string based on
--- string. The captured value is a copy of string, except that the character %
--- works as an escape character: any sequence in string of the form %n, with n
--- between 1 and 9, stands for the match of the n-th capture in patt. The
--- sequence %0 stands for the whole match.
---
--- When the denominator is a number, for a non-zero number, the captured value
--- is the n-th value captured by patt. When number is zero, there are no
--- captured values.
---
--- When the denominator is a function, it calls the given function passing all
--- captures made by patt as arguments, or the whole match if patt made no
--- capture. The values returned by the function are the final values of the
--- capture. In particular, if function returns no value, there is no captured
--- value.
---
---                                                *vim.lpeg.op.mod* *vim.lpeg.%*
--- Creates an accumulator capture. This pattern behaves similarly to a function
--- capture, with the following differences: The last captured value before patt
--- is added as a first argument to the call; the return of the function is
--- adjusted to one single value; that value replaces the last captured value.
--- Note that the capture itself produces no values; it only changes the value
--- of its previous capture.
---</pre>

--- *LPeg* is a new pattern-matching library for Lua, based on [Parsing Expression Grammars](https://bford.info/packrat/) (PEGs).
vim.lpeg = {}

--- @class vim.lpeg.Pattern
--- @operator unm: vim.lpeg.Pattern
--- @operator add(vim.lpeg.Pattern): vim.lpeg.Pattern
--- @operator sub(vim.lpeg.Pattern): vim.lpeg.Pattern
--- @operator mul(vim.lpeg.Pattern): vim.lpeg.Pattern
--- @operator mul(vim.lpeg.Capture): vim.lpeg.Pattern
--- @operator div(string): vim.lpeg.Capture
--- @operator div(number): vim.lpeg.Capture
--- @operator div(table): vim.lpeg.Capture
--- @operator div(function): vim.lpeg.Capture
--- @operator pow(number): vim.lpeg.Pattern
--- @operator mod(function): nil
local Pattern = {}

--- @alias vim.lpeg.Capture vim.lpeg.Pattern

--- Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the
--- subject of the first character after the match, or the captured values (if the pattern captured any value).
--- An optional numeric argument `init` makes the match start at that position in the subject string. As usual
--- in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match`
--- works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject
--- string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a
--- pattern anywhere in a string, we must either write a loop in Lua or write a pattern that
--- matches anywhere.
---
--- Example:
---
--- ```lua
--- local pattern = lpeg.R("az") ^ 1 * -1
--- assert(pattern:match("hello") == 6)
--- assert(lpeg.match(pattern, "hello") == 6)
--- assert(pattern:match("1 hello") == nil)
--- ```
---
--- @param pattern vim.lpeg.Pattern
--- @param subject string
--- @param init? integer
--- @return integer|vim.lpeg.Capture|nil
function vim.lpeg.match(pattern, subject, init) end

--- Matches the given `pattern` against the `subject` string. If the match succeeds, returns the
--- index in the subject of the first character after the match, or the captured values (if the
--- pattern captured any value). An optional numeric argument `init` makes the match start at
--- that position in the subject string. As usual in Lua libraries, a negative value counts from the end.
--- Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries
--- to match the pattern with a prefix of the given subject string (at position `init`), not with
--- an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string,
--- we must either write a loop in Lua or write a pattern that matches anywhere.
---
--- Example:
---
--- ```lua
--- local pattern = lpeg.R("az") ^ 1 * -1
--- assert(pattern:match("hello") == 6)
--- assert(lpeg.match(pattern, "hello") == 6)
--- assert(pattern:match("1 hello") == nil)
--- ```
---
--- @param subject string
--- @param init? integer
--- @return integer|vim.lpeg.Capture|nil
function Pattern:match(subject, init) end

--- Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.
---
--- @return "pattern"|nil
function vim.lpeg.type(value) end

--- Returns a string with the running version of LPeg.
--- @return string
function vim.lpeg.version() end

--- Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices.
--- The default limit is `400`. Most well-written patterns need little backtrack levels and
--- therefore you seldom need to change this limit; before changing it you should try to rewrite
--- your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow.
--- Also, with recursive grammars, subjects with deep recursion may also need larger limits.
---
--- @param max integer
function vim.lpeg.setmaxstack(max) end

--- Converts the given value into a proper pattern. This following rules are applied:
--- * If the argument is a pattern, it is returned unmodified.
--- * If the argument is a string, it is translated to a pattern that matches the string literally.
--- * If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.
--- * If the argument is a negative number `-n`, the result is a pattern that succeeds only if
--- the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)`
--- (see the unary minus operation).
--- * If the argument is a boolean, the result is a pattern that always succeeds or always fails
--- (according to the boolean value), without consuming any input.
--- * If the argument is a table, it is interpreted as a grammar (see Grammars).
--- * If the argument is a function, returns a pattern equivalent to a match-time captureover the empty string.
---
--- @param value vim.lpeg.Pattern|string|integer|boolean|table|function
--- @return vim.lpeg.Pattern
function vim.lpeg.P(value) end

--- Returns a pattern that matches only if the input string at the current position is preceded by `patt`.
--- Pattern `patt` must match only strings with some fixed length, and it cannot contain captures.
--- Like the and predicate, this pattern never consumes any input, independently of success or failure.
---
--- @param pattern vim.lpeg.Pattern
--- @return vim.lpeg.Pattern
function vim.lpeg.B(pattern) end

--- Returns a pattern that matches any single character belonging to one of the given ranges.
--- Each `range` is a string `xy` of length 2, representing all characters with code between the codes of
--- `x` and `y` (both inclusive). As an example, the pattern `lpeg.R("09")` matches any digit, and
--- `lpeg.R("az", "AZ")` matches any ASCII letter.
---
--- Example:
---
--- ```lua
--- local pattern = lpeg.R("az") ^ 1 * -1
--- assert(pattern:match("hello") == 6)
--- ```
---
--- @param ... string
--- @return vim.lpeg.Pattern
function vim.lpeg.R(...) end

--- Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set).
--- As an example, the pattern `lpeg.S("+-*/")` matches any arithmetic operator. Note that, if `s` is a character
--- (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to
--- `lpeg.R(s..s)`. Note also that both `lpeg.S("")` and `lpeg.R()` are patterns that always fail.
---
--- @param string string
--- @return vim.lpeg.Pattern
function vim.lpeg.S(string) end

--- Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable)
--- for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.
---
--- Example:
---
--- ```lua
--- local b = lpeg.P({"(" * ((1 - lpeg.S "()") + lpeg.V(1)) ^ 0 * ")"})
--- assert(b:match('((string))') == 11)
--- assert(b:match('(') == nil)
--- ```
---
--- @param v string|integer
--- @return vim.lpeg.Pattern
function vim.lpeg.V(v) end

--- @class vim.lpeg.Locale
--- @field alnum userdata
--- @field alpha userdata
--- @field cntrl userdata
--- @field digit userdata
--- @field graph userdata
--- @field lower userdata
--- @field print userdata
--- @field punct userdata
--- @field space userdata
--- @field upper userdata
--- @field xdigit userdata

--- Returns a table with patterns for matching some character classes according to the current locale.
--- The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`,
--- `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches
--- any single character that belongs to its class.
--- If called with an argument `table`, then it creates those fields inside the given table and returns
--- that table.
---
--- Example:
---
--- ```lua
--- lpeg.locale(lpeg)
--- local space = lpeg.space^0
--- local name = lpeg.C(lpeg.alpha^1) * space
--- local sep = lpeg.S(",;") * space
--- local pair = lpeg.Cg(name * "=" * space * name) * sep^-1
--- local list = lpeg.Cf(lpeg.Ct("") * pair^0, rawset)
--- local t = list:match("a=b, c = hi; next = pi")
--- assert(t.a == 'b')
--- assert(t.c == 'hi')
--- assert(t.next == 'pi')
--- local locale = lpeg.locale()
--- assert(type(locale.digit) == 'userdata')
--- ```
---
--- @param tab? table
--- @return vim.lpeg.Locale
function vim.lpeg.locale(tab) end

--- Creates a simple capture, which captures the substring of the subject that matches `patt`.
--- The captured value is a string. If `patt` has other captures, their values are returned after this one.
---
--- Example:
---
--- ```lua
--- local function split (s, sep)
---   sep = lpeg.P(sep)
---   local elem = lpeg.C((1 - sep)^0)
---   local p = elem * (sep * elem)^0
---   return lpeg.match(p, s)
--- end
--- local a, b, c = split('a,b,c', ',')
--- assert(a == 'a')
--- assert(b == 'b')
--- assert(c == 'c')
--- ```
---
--- @param patt vim.lpeg.Pattern
--- @return vim.lpeg.Capture
function vim.lpeg.C(patt) end

--- Creates an argument capture. This pattern matches the empty string and produces the value given as the
--- nth extra argument given in the call to `lpeg.match`.
--- @param n integer
--- @return vim.lpeg.Capture
function vim.lpeg.Carg(n) end

--- Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent
--- group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost
--- group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture
--- has matched. An Outermost capture means that the capture is not inside another complete capture.
--- In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses
--- values previously produced by the group or re-evaluates them.
---
--- @param name any
--- @return vim.lpeg.Capture
function vim.lpeg.Cb(name) end

--- Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.
---
--- @param ... any
--- @return vim.lpeg.Capture
function vim.lpeg.Cc(...) end

--- Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value
--- `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from
--- `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at
--- least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific
--- initial value, you may prefix a constant captureto `patt`.) For each subsequent capture, LPeg calls `func`
--- with this accumulator as the first argument and all values produced by the capture as extra arguments;
--- the first result from this call becomes the new value for the accumulator. The final value of the accumulator
--- becomes the captured value.
---
--- Example:
---
--- ```lua
--- local number = lpeg.R("09") ^ 1 / tonumber
--- local list = number * ("," * number) ^ 0
--- local function add(acc, newvalue) return acc + newvalue end
--- local sum = lpeg.Cf(list, add)
--- assert(sum:match("10,30,43") == 83)
--- ```
---
--- @param patt vim.lpeg.Pattern
--- @param func fun(acc, newvalue)
--- @return vim.lpeg.Capture
function vim.lpeg.Cf(patt, func) end

--- Creates a group capture. It groups all values returned by `patt` into a single capture.
--- The group may be anonymous (if no name is given) or named with the given name (which
--- can be any non-nil Lua value).
---
--- @param patt vim.lpeg.Pattern
--- @param name? string
--- @return vim.lpeg.Capture
function vim.lpeg.Cg(patt, name) end

--- Creates a position capture. It matches the empty string and captures the position in the
--- subject where the match occurs. The captured value is a number.
---
--- Example:
---
--- ```lua
--- local I = lpeg.Cp()
--- local function anywhere(p) return lpeg.P({I * p * I + 1 * lpeg.V(1)}) end
--- local match_start, match_end = anywhere("world"):match("hello world!")
--- assert(match_start == 7)
--- assert(match_end == 12)
--- ```
---
--- @return vim.lpeg.Capture
function vim.lpeg.Cp() end

--- Creates a substitution capture. This function creates a substitution capture, which
--- captures the substring of the subject that matches `patt`, with substitutions.
--- For any capture inside `patt` with a value, the substring that matched the capture
--- is replaced by the capture value (which should be a string). The final captured
--- value is the string resulting from all replacements.
---
--- Example:
---
--- ```lua
--- local function gsub (s, patt, repl)
---   patt = lpeg.P(patt)
---   patt = lpeg.Cs((patt / repl + 1)^0)
---   return lpeg.match(patt, s)
--- end
--- assert(gsub('Hello, xxx!', 'xxx', 'World') == 'Hello, World!')
--- ```
---
--- @param patt vim.lpeg.Pattern
--- @return vim.lpeg.Capture
function vim.lpeg.Cs(patt) end

--- Creates a table capture. This capture returns a table with all values from all anonymous captures
--- made by `patt` inside this table in successive integer keys, starting at 1.
--- Moreover, for each named capture group created by `patt`, the first value of the group is put into
--- the table with the group name as its key. The captured value is only the table.
---
--- @param patt vim.lpeg.Pattern|''
--- @return vim.lpeg.Capture
function vim.lpeg.Ct(patt) end

--- Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs
--- (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures
--- and then calls `function`. The given function gets as arguments the entire subject, the current position
--- (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function`
--- defines how the match happens. If the call returns a number, the match succeeds and the returned number
--- becomes the new current position. (Assuming a subject sand current position i, the returned number must be
--- in the range [i, len(s) + 1].) If the call returns true, the match succeeds without consuming any input
--- (so, to return true is equivalent to return i). If the call returns false, nil, or no value, the match fails.
--- Any extra values returned by the function become the values produced by the capture.
---
--- @param patt vim.lpeg.Pattern
--- @param fn function
--- @return vim.lpeg.Capture
function vim.lpeg.Cmt(patt, fn) end
