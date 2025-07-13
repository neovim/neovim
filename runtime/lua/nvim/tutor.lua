---@class nvim.TutorMetadata
---@field expect table<string, string|-1>

---@alias nvim.TutorExtmarks table<string, string>

---@type nvim.TutorExtmarks?
vim.b.tutor_extmarks = vim.b.tutor_extmarks

---@type nvim.TutorMetadata?
vim.b.tutor_metadata = vim.b.tutor_metadata

local sign_text_correct = '✓'
local sign_text_incorrect = '✗'
local tutor_mark_ns = vim.api.nvim_create_namespace('nvim.tutor.mark')
local tutor_hl_ns = vim.api.nvim_create_namespace('nvim.tutor.hl')

local M = {}

---@param line integer 1-based
local function check_line(line)
  if vim.b.tutor_metadata and vim.b.tutor_metadata.expect and vim.b.tutor_extmarks then
    local ctext = vim.fn.getline(line)

    local extmarks = vim.api.nvim_buf_get_extmarks(
      0,
      tutor_mark_ns,
      { line - 1, 0 },
      { line - 1, -1 }, -- the extmark can move to col > 0 if users insert text there
      {}
    )
    for _, extmark in ipairs(extmarks) do
      local mark_id = extmark[1]
      local expct = vim.b.tutor_extmarks[tostring(mark_id)]
      local expect = vim.b.tutor_metadata.expect[expct]
      local is_correct = expect == -1 or ctext == expect

      vim.api.nvim_buf_set_extmark(0, tutor_mark_ns, line - 1, 0, {
        id = mark_id,
        sign_text = is_correct and sign_text_correct or sign_text_incorrect,
        sign_hl_group = is_correct and 'tutorOK' or 'tutorX',
        -- This may be a hack. By default, all extmarks only move forward, so a line cannot contain
        -- any extmarks that were originally created for later lines.
        priority = tonumber(expct),
      })
    end
  end
end

function M.apply_marks()
  vim.cmd [[hi! link tutorExpect Special]]
  if vim.b.tutor_metadata and vim.b.tutor_metadata.expect then
    vim.b.tutor_extmarks = {}
    for expct, _ in pairs(vim.b.tutor_metadata.expect) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      local lnum = tonumber(expct) ---@type integer
      vim.api.nvim_buf_set_extmark(0, tutor_hl_ns, lnum - 1, 0, {
        line_hl_group = 'tutorExpect',
      })

      local mark_id = vim.api.nvim_buf_set_extmark(0, tutor_mark_ns, lnum - 1, 0, {})

      -- Cannot edit field of a Vimscript dictionary from Lua directly, see `:h lua-vim-variables`
      ---@type nvim.TutorExtmarks
      local tutor_extmarks = vim.b.tutor_extmarks
      tutor_extmarks[tostring(mark_id)] = expct
      vim.b.tutor_extmarks = tutor_extmarks

      check_line(lnum)
    end
  end
end

function M.apply_marks_on_changed()
  if vim.b.tutor_metadata and vim.b.tutor_metadata.expect and vim.b.tutor_extmarks then
    local lnum = vim.fn.line('.')
    check_line(lnum)
  end
end

return M
