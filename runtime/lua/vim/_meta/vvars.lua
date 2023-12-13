--- @meta _

-- TODO(lewis6991): generate this and `:help vim-variable`

--- @class vim.v
--- The count given for the last Normal mode command.  Can be used
--- to get the count before a mapping.  Read-only.  Example:
--- ```vim
--- :map _x :<C-U>echo "the count is " .. v:count<CR>
--- ```
--- Note: The <C-U> is required to remove the line range that you
--- get when typing ':' after a count.
--- When there are two counts, as in "3d2w", they are multiplied,
--- just like what happens in the command, "d6w" for the example.
--- Also used for evaluating the 'formatexpr' option.
--- @field count integer
---
--- Line number for the 'foldexpr' |fold-expr|, 'formatexpr',
--- 'indentexpr' and 'statuscolumn' expressions, tab page number
--- for 'guitablabel' and 'guitabtooltip'.  Only valid while one of
--- these expressions is being evaluated.  Read-only when in the |sandbox|.
--- @field lnum integer
vim.v = ...
