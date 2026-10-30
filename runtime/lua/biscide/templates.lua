-- What a new declaration starts from: each kind's skeleton (to write it
-- from scratch) and templates, for Go and Rust. In their text `${name}` is
-- the declaration's name, `${recv}` the type a method is of, `${params}`,
-- `${results}` and `${fields}` what the code using it says it takes, gives
-- and has (biscide.infer; empty when it says nothing), `${cursor}` where the
-- cursor goes. Your own templates are files in
-- `stdpath("config")/biscide/templates/{go,rust}/` (the file's name, its
-- extension aside, is the template's), in the same form.

local M = {}

---@class biscide.Template
---@field title string
---@field text string
---@field kind? string the kind of declaration it makes (a skeleton's)
---@field recv? boolean it needs `${recv}` (a method)
---@field yours? boolean one of your files

---@type table<string, biscide.Template[]>
M.SKELETONS = {
  go = {
    { kind = "func", title = "func", text = "func ${name}(${params})${results} {\n\t${cursor}\n}" },
    {
      kind = "method",
      title = "method",
      recv = true,
      text = "func (r *${recv}) ${name}(${params})${results} {\n\t${cursor}\n}",
    },
    { kind = "struct", title = "struct", text = "type ${name} struct {\n\t${fields}${cursor}\n}" },
    { kind = "interface", title = "interface", text = "type ${name} interface {\n\t${cursor}\n}" },
    { kind = "type", title = "type", text = "type ${name} ${cursor}" },
    { kind = "const", title = "const", text = "const ${name} = ${cursor}" },
    { kind = "var", title = "var", text = "var ${name} ${cursor}" },
  },
  rust = {
    { kind = "func", title = "fn", text = "fn ${name}() {\n    ${cursor}\n}" },
    {
      kind = "method",
      title = "method",
      recv = true,
      text = "impl ${recv} {\n    fn ${name}(&self) {\n        ${cursor}\n    }\n}",
    },
    { kind = "struct", title = "struct", text = "struct ${name} {\n    ${cursor}\n}" },
    { kind = "enum", title = "enum", text = "enum ${name} {\n    ${cursor}\n}" },
    { kind = "interface", title = "trait", text = "trait ${name} {\n    ${cursor}\n}" },
    { kind = "type", title = "type", text = "type ${name} = ${cursor};" },
    { kind = "const", title = "const", text = "const ${name}: ${cursor} = ;" },
  },
}

---@type table<string, biscide.Template[]>
M.TEMPLATES = {
  go = {
    { title = "func returning an error", text = "func ${name}() error {\n\t${cursor}\n\treturn nil\n}" },
    {
      title = "func with a context",
      text = "func ${name}(ctx context.Context) error {\n\t${cursor}\n\treturn nil\n}",
    },
    {
      title = "struct with a constructor",
      text = "type ${name} struct {\n\t${cursor}\n}\n\n// New${name} makes a ${name}.\nfunc New${name}() *${name} {\n\treturn &${name}{}\n}",
    },
    { title = "error variable", text = 'var ${name} = errors.New("${cursor}")' },
    {
      title = "enum (iota)",
      text = "type ${name} int\n\nconst (\n\t${name}Unknown ${name} = iota\n\t${cursor}\n)",
    },
    {
      title = "method returning an error",
      recv = true,
      text = "func (r *${recv}) ${name}() error {\n\t${cursor}\n\treturn nil\n}",
    },
    { title = "test", text = "func Test${name}(t *testing.T) {\n\t${cursor}\n}" },
  },
  rust = {
    {
      title = "fn returning a Result",
      text = "fn ${name}() -> Result<(), Box<dyn std::error::Error>> {\n    ${cursor}\n    Ok(())\n}",
    },
    {
      title = "struct with new()",
      text = "pub struct ${name} {\n    ${cursor}\n}\n\nimpl ${name} {\n    pub fn new() -> Self {\n        Self {}\n    }\n}",
    },
    { title = "derived struct", text = "#[derive(Debug, Clone, PartialEq)]\npub struct ${name} {\n    ${cursor}\n}" },
    {
      title = "error enum",
      text = table.concat({
        "#[derive(Debug)]",
        "pub enum ${name} {",
        "    ${cursor}",
        "}",
        "",
        "impl std::fmt::Display for ${name} {",
        "    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {",
        '        write!(f, "{self:?}")',
        "    }",
        "}",
        "",
        "impl std::error::Error for ${name} {}",
      }, "\n"),
    },
    {
      title = "trait with an impl",
      recv = true,
      text = "trait ${name} {\n    fn ${cursor}(&self);\n}\n\nimpl ${name} for ${recv} {\n}",
    },
    { title = "test", text = "#[test]\nfn ${name}() {\n    ${cursor}\n}" },
  },
}

--- The language of a file, by its name ("go", "rust").
---@param path string
---@return string?
function M.lang(path)
  return path:match("%.go$") and "go" or path:match("%.rs$") and "rust" or nil
end

--- Your templates for `lang`, read from your configuration's directory.
---@param lang string
---@return biscide.Template[]
function M.yours(lang)
  local out = {}
  local dir = vim.fs.joinpath(vim.fn.stdpath("config"), "biscide", "templates", lang)
  for name, type in vim.fs.dir(dir) do
    if type == "file" then
      local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(dir, name))
      if ok then
        local text = table.concat(lines, "\n")
        out[#out + 1] = {
          title = name:gsub("%.[^.]*$", ""),
          text = text,
          recv = text:find("${recv}", 1, true) ~= nil,
          yours = true,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.title < b.title
  end)
  return out
end

--- A template's text made: its names filled in; its lines and where the
--- cursor goes in them (row from 1, byte from 0).
---@param t biscide.Template
---@param vars table<string, string> name, recv, params, results, fields
---@return string[], { [1]: integer, [2]: integer }
function M.expand(t, vars)
  local text = t.text:gsub("%${(%w+)}", function(key)
    if key == "cursor" then
      return nil
    end
    return vars[key] or ""
  end)
  local lines = vim.split(text, "\n", { plain = true })
  local at = { #lines, #lines[#lines] }
  for k, line in ipairs(lines) do
    local s = line:find("${cursor}", 1, true)
    if s then
      lines[k] = line:sub(1, s - 1) .. line:sub(s + #"${cursor}")
      at = { k, s - 1 }
      break
    end
  end
  return lines, at
end

return M
