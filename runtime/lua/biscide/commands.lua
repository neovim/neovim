-- biscide's Ex commands, a table of them (each its name, what it runs, its
-- arguments).

local M = {}

---@class biscide.CommandSpec
---@field name string
---@field run fun(args: vim.api.keyset.create_user_command.command_args)
---@field opts vim.api.keyset.user_command

---@return biscide.CommandSpec[]
local function specs()
  local navigate = require("biscide.navigate")
  local program = require("biscide.program")
  local function choices(list)
    return function()
      return list
    end
  end
  return {
    {
      name = "BiscideGo",
      run = function()
        if not navigate.go_cursor() and require("biscide.state").lanes then
          navigate.centre()
        end
      end,
      opts = { desc = "biscide: to the card under the card cursor" },
    },
    {
      name = "BiscideBack",
      run = function(a)
        for _ = 1, math.max(1, a.count) do
          navigate.back()
        end
      end,
      opts = { count = 1, desc = "biscide: back to the previous declaration" },
    },
    {
      name = "BiscideLane",
      run = function(a)
        navigate.lane(a.args, math.max(1, a.count))
      end,
      opts = {
        nargs = 1,
        count = 1,
        complete = choices({ "down", "up", "left", "right", "top", "bottom", "uses", "used_by" }),
        desc = "biscide: move the card cursor",
      },
    },
    {
      name = "BiscideHistory",
      run = function(a)
        local n = math.max(1, a.count)
        navigate.history(a.args == "back" and -n or n)
      end,
      opts = {
        nargs = 1,
        count = 1,
        complete = choices({ "back", "forward" }),
        desc = "biscide: back and forth through the declarations gone to",
      },
    },
    {
      name = "BiscideTree",
      run = function(a)
        local tree = require("biscide.tree")
        local actions = {
          toggle = tree.toggle,
          open = function()
            tree.open(true)
          end,
          close = tree.close,
          reveal = function()
            local n = require("biscide.state").active()
            tree.reveal(n and n.rel)
          end,
        }
        local run = actions[a.args ~= "" and a.args or "toggle"]
        if run then
          run()
        end
      end,
      opts = { nargs = "?", complete = choices({ "toggle", "open", "close", "reveal" }), desc = "biscide: the project's files" },
    },
    {
      name = "BiscidePick",
      run = function(a)
        local name, query = a.args:match("^(%S+)%s*(.*)$")
        require("biscide.pickers").open(name or "pickers", query ~= "" and query or nil)
      end,
      opts = {
        nargs = "*",
        complete = function(lead, line)
          -- The picker's name: the first argument.
          if line:match("^%S+%s+%S+%s") then
            return {}
          end
          return vim.tbl_filter(function(n)
            return n:find(lead, 1, true) == 1
          end, require("biscide.pickers").names())
        end,
        desc = "biscide: a picker (its name, its query)",
      },
    },
    {
      name = "BiscideFind",
      run = function(a)
        require("biscide.pickers").open("declarations", a.args ~= "" and a.args or nil)
      end,
      opts = { nargs = "?", desc = "biscide: find a declaration by name" },
    },
    {
      name = "BiscideMessages",
      run = function(a)
        require("biscide.view").send("messages", { action = a.args ~= "" and a.args or "toggle" })
      end,
      opts = {
        nargs = "?",
        complete = choices({ "toggle", "open", "close", "clear" }),
        desc = "biscide: the messages panel",
      },
    },
    {
      name = "BiscideNew",
      run = function()
        navigate.new()
      end,
      opts = { desc = "biscide: a new declaration at the file's end" },
    },
    {
      name = "BiscideResolve",
      run = function()
        require("biscide.missing").at_cursor()
      end,
      opts = { desc = "biscide: resolve a name that is nowhere (import it, create it)" },
    },
    { name = "BiscideCentre", run = navigate.centre, opts = { desc = "biscide: the camera back on the active card" } },
    {
      name = "BiscideReload",
      run = function()
        program.reload()
      end,
      opts = { desc = "biscide: read the program again" },
    },
    {
      name = "BiscideCardCols",
      run = function(a)
        vim.g.biscide_card_cols = math.max(30, math.min(240, tonumber(a.args) or 80))
        local view = require("biscide.view")
        view.send("cols", vim.g.biscide_card_cols)
        view.render()
      end,
      opts = { nargs = 1, desc = "biscide: a card's width in columns" },
    },
  }
end

function M.setup()
  for _, c in ipairs(specs()) do
    vim.api.nvim_create_user_command(c.name, c.run, c.opts)
  end
end

return M
