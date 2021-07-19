local protocol = require("vim.lsp.protocol")

local M = {}

---@class LspOptions
local defaults = {
  floating_preview = {
    offset_x = 0,
    offset_y = 0,
    border = nil, -- nil for default, single, duoble, shadow
  },
  stylize_markdown_fences = { -- map of markdown code block langs to syntax
    console = "sh",
    js = "javascript",
    jsx = "javascriptreact",
    shell = "sh",
    ts = "typescript",
    tsx = "typescriptreact",
  },
  diagnostics = {
    signs = {
      error = "E",
      warning = "W",
      information = "I",
      hint = "H",
    },
    display = {
      signs = true,
      underline = true,
      virtual_text = true,
      update_in_insert = false,
      severity_sort = false,
    },
  },
  protocol = { symbols = {}, completion_items = {} },
}

---@type LspOptions
M.options = {}

-- Configure the built-in LSP client.
--
-- @param opts LspOptions
--     - floating_preview:
--          * default options for lsp floating windows
--          * See |vim.lsp.util.open_floating_preview|
--     - stylize_markdown_fences:
--          * table of markdown code block langs to syntax
--          * for example, this will map a *ts* code-block to the **typescript** syntax
--     - diagnostics:
--          * display: See |vim.lsp.handlers.on_publish_diagnostics|
--          * signs: table of diagnostic severity to sign
--     - protocol:
--          * completion_items:
--               - table of completion item kind to display text
--               - See |vim.lsp.protocol.CompletionItemKind|
--          * symbols:
--               - table of symbol kind to display text
--               - See |vim.lsp.protocol.SymbolKind|
function M.setup(opts)
  opts = opts or {}

  M.options = vim.tbl_deep_extend("force", {}, defaults, M.options, opts)

  -- configure diagnostics
  -- only override the signs when we explicitely pass them in the options
  require("vim.lsp.diagnostic")._setup({}, opts.diagnostics and opts.diagnostics.signs)

  -- configure completion item kind
  for i, kind in ipairs(protocol.CompletionItemKind) do
    protocol.CompletionItemKind[i] = M.options.protocol.completion_items[kind] or kind
  end

  -- configure symbol item kind
  for i, kind in ipairs(protocol.SymbolKind) do
    protocol.SymbolKind[i] = M.options.protocol.symbols[kind] or kind
  end
end

function M.reset()
  M.options = {}
  M.setup()
end

-- use defer, since we require modules requiring config
vim.defer_fn(M.setup, 0)

return M
