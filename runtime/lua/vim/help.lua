local M = {}
local vim = vim
local nvim_get_runtime_file = vim.api.nvim_get_runtime_file

---Find the tagfiles to search tags on.
---Tag falenames have the pattern 'tags(-\w\w)?' :help :helptags
---@param lang string|nil The tagname to search for.
M.tag_files_search = function(lang)
  local patt = "doc/tags"
  local res = {}
  if lang ~= nil then
    patt = string.format("%s-%s", patt, lang)
  end
  res = nvim_get_runtime_file(patt, true)
  return res
end

---Find the tags that match the given pattern in the given language.
M.find_tags = function(patterns, lang)
  local files = M.tag_files_search(lang)
  -- Matches will be stored here by find_in_tagfile_and_score
  local results = { count = 0, matches = {} }
  for _, fname in ipairs(files) do
    -- Finds the tags in each file, scores them and adds them to the results
    M.find_in_tagfile_and_score(fname, results, patterns)
  end
  return results
end

---A tagfile is a tab separated file with three fields: tagname, file, tag_regexp
---This function finds the tags that mtch the given patterns and scores the match. The results are
---appened to the results.matches table.
---@param filename string the full path of the tagfile to search in.
---@param results table with two keys count number, matches table
---@param patterns table with keys escaped, icase, wildcard
---@return nil
M.find_in_tagfile_and_score = function(filename, results, patterns)
  -- TODO: Do you even vim.loop
  local file = io.open(filename, "r")
  local contents = file:read("*a")
  file:close()
  local escaped, icase, wildcard = patterns.escaped, patterns.icase, patterns.wildcard
  local score, entry, tag, add = 0, {}, "", false
  local matchpos, t
  for line in vim.gsplit(contents, '\n', true) do
    if line == "" then break end
    entry = vim.split(line, "\t")
    tag = entry[1]
    matchpos = tag:find(escaped)
    -- Regular case sensitive escaped pattern match
    if matchpos ~= nil then
      add = true
      t = 'pattern'
    else
      -- Case insensitive match
      matchpos = tag:find(icase)
      if matchpos ~= nil then
        add = true
        -- Add 5000 if the match is case insensitive
        score = score + 5000
        t = 'icase'
      else
        -- Wildcard match
        matchpos = tag:find(wildcard)
        if matchpos ~= nil then
          add = true
          -- Add 20000 if it was a wildcard match
          score = score + 20000
        end
      end
    end
    if add then
      -- Add the number of chars/length of tag
      score = score + #tag
      -- Add 100 for every letter of the match
      tag:gsub("%a", function()
        score = score + 100
      end)
      -- Add 10000 when the match is not at the start but making sure matchpos and matchpos-1 are
      -- alphanumeir
      if matchpos > 1 and string.find(tag, '^%w%w', matchpos - 1, false) then
        score = score + 10000
      -- If it's over the third position mulyiply by 200
      else if matchpos > 3 then
        score = score * 200
      end
      end
      results.count = results.count + 1
      results.matches[results.count] = { entry[1], filename:gsub('tags.-$', entry[2]), entry[3], score, t}
    end
    add = false
    score = 0
  end
end

---Patterns in which the whole match is replaced
local full_replacements = {
  ["*"] = "star",
  ["g*"] = "gstar",
  ["[*"] = "[star",
  ["]*"] = "]star",
  ["/*"] = "/star",
  ["/\\*"] = "/\\star",
  ['"*'] = "quotestar",
  ["**"] = "starstar",
}

---Search for the following patterns in the tag name and replace them.
---Items: { pattern, replacement, should_escape_pattern }
local replacements = {
  ---NOTE: the order matters
  { '"', "quote", true }, -- Replace " with quote
  { "|", "bar", true }, -- Repce | with bar
  -- The next two need to be applied in order one expands ^ the other separates repetitive
  { "%^(.)", "CTRL%-%1", false }, -- ^n to CTRL-n
  { "(CTRL%-.)([^_])", "%1_%2", false }, -- Insert _ between CTRL-x_CTRL-n
}

---Make lua pattern case insensitive.
---@param text string the text/pattern to make case insensitive.
---@return string The case insensitive pattern.
local function ignorecase_pattern(text)
  return text:gsub("(%a)", function(a)
    return string.format("[%s%s]", a:lower(), a:upper())
  end)
end

---Escape any lua pattern matching characters.
---@param text string The text/pattern to escape.
local function escape_pattern(text)
  return text:gsub("([^%w])", "%%%1")
end

---Given user input transform it to be a tagname, and return the lua patterns to search.
---Three patterns are necessary: normal, case insensitive, and wildcards enabled '*' or '?'.
---@param name string user input that represents a tagname.
---@return string, string first pattern is with all magic chatacters escaped, second is with wildcards enabled.
M.generate_search_patterns = function(name)
  -- The escaping of the returned tag name is only escaped once at the time of return
  if full_replacements[name] ~= nil then
    name = full_replacements[name]
  else
    -- Perform the replacements
    local patt, repl, should_escape
    for _, expr in ipairs(replacements) do
      patt, repl, should_escape = expr[1], expr[2], expr[3]
      if should_escape then
        patt = escape_pattern(patt)
      end
      name = name:gsub(patt, repl)
    end
  end
  -- Escaped pattern assures the tag is looked by the name without the characters having any
  -- special meaning
  local patterns = {}
  patterns.escaped = escape_pattern(name)
  patterns.icase = ignorecase_pattern(patterns.escaped)
  patterns.wildcard = patterns.escaped:gsub("%%%*", ".*"):gsub("%%%?", ".")
  if patterns.escaped == patterns.wildcard then
    patterns.wildcard ='^$'
  end
  return patterns
end

M.ex_help = function(tag_name)
  local patterns = M.generate_search_patterns(tag_name)
  print("Generated patterns", vim.inspect(patterns))
  local results = M.find_tags(patterns, nil)
  table.sort(results.matches, function(a, b)
    return a[4] < b[4]
  end)
  print(vim.inspect(results))
end

-- Examples
-- M.ex_help([[CTRL-\_CTRL-N]])
-- M.ex_help([[^N]])
-- M.ex_help([[i_^_]])
-- M.ex_help([[i_^_^D]]) -- Special case doesn't work and I think it shouldn't
-- M.ex_help([[^_]])
-- M.ex_help([[/|]])
-- M.ex_help([[i_^x^E]])
-- M.ex_help([[^X^N]])
-- M.ex_help([[^x^N]])
-- M.ex_help([[Cino]])
-- M.ex_help([[sort]])
-- M.ex_help("[pattern]")
-- M.ex_help("s/\\1")
-- M.ex_help([[/\star]])
-- M.ex_help(":s\\=")
-- M.ex_help([['sp]])
-- M.ex_help([[motion]])
-- M.ex_help([[expr-!~]])
-- M.ex_help([[rw?]])
-- M.ex_help([[netrw-%]])
-- M.ex_help([[...]])
-- M.ex_help([[tw?]])
M.ex_help([[c*vis]])
-- M.ex_help([[z?]])

return M
