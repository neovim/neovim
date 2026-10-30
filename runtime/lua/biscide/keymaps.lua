-- biscide's keys, as the GUI's keymaps (`vim.keymap.set(…, { gui = true })`,
-- |nvim_gui_set_keymap()|): they come first in every buffer (a card, the
-- tree, a plugin's), over the buffer's own maps and the configuration's
-- global ones. A key that has nothing to do where it is pressed (<CR> with
-- no card to make active) is handed on: to the buffer's own map of it,
-- else to Nvim. Set when biscide's plugin loads, after init.lua: a key
-- init.lua gave a GUI keymap of its own keeps it; `vim.g.biscide_no_maps`
-- leaves them all to it.

local M = {}

--- What key `lhs` does without biscide's map: the current buffer's own map
--- of it, else Nvim's (with the count typed).
---@param lhs string
function M.hand_on(lhs)
  local keys = vim.keycode(lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
    if vim.keycode(m.lhs) == keys then
      if m.callback and m.expr ~= 1 then
        return m.callback()
      end
      local rhs = m.rhs or ""
      if m.expr == 1 then
        rhs = m.callback and m.callback() or vim.api.nvim_eval(rhs)
      end
      if m.expr ~= 1 or m.replace_keycodes == 1 then
        rhs = vim.keycode(rhs)
      end
      return vim.api.nvim_feedkeys(rhs, m.noremap == 1 and "in" or "im", false)
    end
  end
  local count = vim.v.count > 0 and tostring(vim.v.count) or ""
  vim.api.nvim_feedkeys(count .. keys, "in", false)
end

--- A key's handler: `fn` says whether it did anything; when not, the key
--- is handed on.
---@param lhs string
---@param fn fun(): boolean?
local function or_hand_on(lhs, fn)
  return function()
    if not fn() then
      M.hand_on(lhs)
    end
  end
end

--- <CR>: to the card under the card cursor; in a card that is not the
--- active one, it becomes the active one.
---@return boolean
local function enter()
  -- The tree's, a picker's: their own.
  if vim.w.biscide_ui then
    return false
  end
  local navigate = require("biscide.navigate")
  if navigate.go_cursor() then
    return true
  end
  local State = require("biscide.state")
  local card = State.cards:of_win(vim.api.nvim_get_current_win())
  local active = State.active()
  if card and card.node and not (card.lane == "file" and active and card.node == active.id) then
    navigate.activate(card.node, card.lane)
    return true
  end
  return false
end

---@class biscide.KeymapSpec
---@field [1] string lhs
---@field [2] string|function rhs
---@field [3] string desc

---@param navigate table biscide.navigate
---@return biscide.KeymapSpec[]
local function specs(navigate)
  local function lane(dir)
    return function()
      navigate.lane(dir, vim.v.count1)
    end
  end
  local function history(by)
    return function()
      navigate.history(by * vim.v.count1)
    end
  end
  local function pick(name)
    return function()
      require("biscide.pickers").open(name)
    end
  end
  return {
    { "<C-h>", lane("left"), "biscide: card cursor left" },
    { "<C-j>", lane("down"), "biscide: card cursor down" },
    { "<C-k>", lane("up"), "biscide: card cursor up" },
    { "<C-l>", lane("right"), "biscide: card cursor right" },
    { "gU", lane("uses"), "biscide: card cursor to what it uses" },
    { "gR", lane("used_by"), "biscide: card cursor to what uses it" },
    { "<CR>", or_hand_on("<CR>", enter), "biscide: make the card the active one" },
    {
      "<Esc>",
      or_hand_on("<Esc>", function()
        return not vim.w.biscide_ui and navigate.drop_cursor()
      end),
      "biscide: drop the card cursor",
    },
    { "<A-Left>", history(-1), "biscide: back through the declarations gone to" },
    { "<A-Right>", history(1), "biscide: forth through the declarations gone to" },
    { "<leader>e", "<Cmd>BiscideTree toggle<CR>", "biscide: the project's files" },
    { "<A-1>", "<Cmd>BiscideTree toggle<CR>", "biscide: the project's files" },
    { "<leader>m", "<Cmd>BiscideMessages toggle<CR>", "biscide: the messages" },
    { "<A-2>", "<Cmd>BiscideMessages toggle<CR>", "biscide: the messages" },
    { "<leader>/", pick("declarations"), "biscide: find a declaration" },
    { "<leader>ss", pick("declarations"), "biscide: find a declaration" },
    { "<leader><space>", pick("files"), "biscide: find a file" },
    { "<leader>ff", pick("files"), "biscide: find a file" },
    { "<leader>sg", pick("grep"), "biscide: grep the project" },
    { "<leader>sw", pick("grep_word"), "biscide: grep the word under the cursor" },
    { "<leader>sd", pick("diagnostics"), "biscide: the diagnostics" },
    { "<leader>fr", pick("history"), "biscide: the declarations gone to" },
    { "<leader>sC", pick("commands"), "biscide: the commands" },
    { "<leader>sk", pick("keymaps"), "biscide: the keymaps" },
    { "<leader>sR", pick("resume"), "biscide: the last picker again" },
    { "<leader>sp", pick("pickers"), "biscide: the pickers" },
    { "<leader>n", "<Cmd>BiscideNew<CR>", "biscide: a new declaration" },
    { "gm", "<Cmd>BiscideResolve<CR>", "biscide: resolve the missing name under the cursor" },
    { "<leader>b", "<Cmd>BiscideBack<CR>", "biscide: the previous declaration" },
    { "<leader>z", "<Cmd>BiscideCentre<CR>", "biscide: the camera back on the active card" },
  }
end

--- Maps biscide's keys as the GUI's keymaps (those init.lua mapped already
--- kept).
function M.setup()
  if vim.g.biscide_no_maps then
    return
  end
  local taken = {}
  for _, m in ipairs(vim.api.nvim_gui_get_keymap("n")) do
    taken[m.lhs] = true
  end
  for _, s in ipairs(specs(require("biscide.navigate"))) do
    local lhs = vim.fn.keytrans(vim.keycode((s[1]:gsub("<leader>", vim.g.mapleader or "\\"))))
    if not taken[lhs] then
      vim.keymap.set("n", s[1], s[2], { gui = true, desc = s[3] })
    end
  end
end

return M
