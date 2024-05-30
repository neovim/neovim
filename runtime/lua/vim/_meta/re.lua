--- @meta
error('Cannot require a meta file')

-- Documentations and Lua types for vim.re (vendored re.lua, lpeg-1.1.0)
-- https://www.inf.puc-rio.br/~roberto/lpeg/re.html
--
-- Copyright © 2007-2023 Lua.org, PUC-Rio.
-- See 'lpeg.html' for license

--- @brief
--- The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg
--- |vim.lpeg|. (Unrelated to |vim.regex| which provides Vim |regexp| from Lua.)
---
--- See https://www.inf.puc-rio.br/~roberto/lpeg/re.html for the original documentation including
--- regex syntax and examples.

--- Compiles the given {string} and returns an equivalent LPeg pattern. The given string may define
--- either an expression or a grammar. The optional {defs} table provides extra Lua values to be used
--- by the pattern.
--- @param string string
--- @param defs? table
--- @return vim.lpeg.Pattern
function vim.re.compile(string, defs) end

--- Searches the given {pattern} in the given {subject}. If it finds a match, returns the index
--- where this occurrence starts and the index where it ends. Otherwise, returns nil.
---
--- An optional numeric argument {init} makes the search starts at that position in the subject
--- string. As usual in Lua libraries, a negative value counts from the end.
--- @param subject string
--- @param pattern vim.lpeg.Pattern|string
--- @param init? integer
--- @return integer|nil : the index where the occurrence starts, nil if no match
--- @return integer|nil : the index where the occurrence ends, nil if no match
function vim.re.find(subject, pattern, init) end

--- Does a global substitution, replacing all occurrences of {pattern} in the given {subject} by
--- {replacement}.
--- @param subject string
--- @param pattern vim.lpeg.Pattern|string
--- @param replacement string
--- @return string
function vim.re.gsub(subject, pattern, replacement) end

--- Matches the given {pattern} against the given {subject}, returning all captures.
--- @param subject string
--- @param pattern vim.lpeg.Pattern|string
--- @param init? integer
--- @return integer|vim.lpeg.Capture|nil
--- @see vim.lpeg.match()
function vim.re.match(subject, pattern, init) end

--- Updates the pre-defined character classes to the current locale.
function vim.re.updatelocale() end
