local buf = require 'vim.lsp.buf'
local util = require 'vim.lsp.util'
local vim = vim
local M = {}

function M.apply(action, ctx)
  -- textDocument/codeAction can return either Command[] or CodeAction[]
  --
  -- CodeAction
  --  ...
  --  edit?: WorkspaceEdit    -- <- must be applied before command
  --  command?: Command
  --
  -- Command:
  --  title: string
  --  command: string
  --  arguments?: any[]
  --
  if action.edit then
    util.apply_workspace_edit(action.edit)
  end
  if action.command then
    local command = type(action.command) == 'table' and action.command or action
    local fn = vim.lsp.commands[command.command]
    if fn then
      fn(command, ctx)
    else
      buf.execute_command(command)
    end
  end
end

return M
