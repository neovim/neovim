local vim = vim
local api = vim.api
local npcall = vim.F.npcall

local util = require("vim.ui.util")

--@class Popup
local Popup = {}

--- Creates a popup window
---
--@param contents table of lines to show in window
--@param syntax string of syntax to set for opened buffer
--@param opts dictionary with optional fields
---             - height           of floating window (defaults to min height required for given content)
---             - width            of floating window (defaults to min width required for given content)
---             - wrap             boolean enable wrapping of long lines (defaults to true)
---             - relative         string of what the popup window position is relative to (defaults to win)
---             - position         direction of the popup window relative to the `relative` option (automatically caluculated if relative = 'cursor')
---             - row              row position in units of "screen cell height", may be fractional
---             - col              column position in units of "screen cell width", may be fractional
---             - zindex           of the window (defaults to 50)
---             - padding          table of amounts of padding to apply to content ({top, right, bottom, left}) (defaults to 0)
---             - enter            enter the floating window when it is shown (boolean, defaults to false)
---             - border           the type of the border the popup should have (boolean, defaults to single)
---             - max_height       maximum height of the contents, excluding border and padding
---             - min_height       minimum height of the contents, excluding border and padding
---             - max_width        maximum width of the contents, excluding border and padding
---             - min_width        minimum width of the contents, excluding border and padding
---             - focus_id         if a popup with this id is opened, then focus it
---             - close_events     list of events that closes the floating window
---             - focusable        make the popup focusable (boolean, default to true)
---             - stylize_markdown see `vim.ui.util.stylize_markdown` (boolean, defaults to false)
---             - noautocmd        if true, no buffer related autocmds would run
function Popup:create(contents, opts)
	setmetatable({}, self)
	self.__index = self

	vim.validate({
		contents = { contents, "t" },
		opts = { opts, "t", true },
	})

	-- Clean up input: trim empty lines from the end, pad
	contents = vim.lsp.util._trim(contents)
	self.contents = opts.padding and util.apply_padding_to_content(opts.padding, contents) or contents

	self.buf = {
		id = nil,
	}

	self.win = {
		id = nil,
		enter = util.get_val_or_default(opts.enter, false),
		border = util.get_val_or_default(opts.border, "single"),
		style = "minimal",
		zindex = util.get_val_or_default(opts.zindex, 50),
		relative = util.get_val_or_default(opts.relative, "win"),
		position = util.get_val_or_default(opts.position, "NW"),
		row = util.get_val_or_default(opts.row, 0),
		col = util.get_val_or_default(opts.col, 0),
		wrap = util.get_val_or_default(opts.wrap, true),
		close_events = util.get_val_or_default(
			opts.close_events,
			{ "CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre" }
		),
		focusable = util.get_val_or_default(opts.focusable, true),
		focus_id = util.get_val_or_default(opts.focus_id, "vim_ui_popup"),
		stylize_markdown = util.get_val_or_default(opts.stylize_markdown, false),
	}

	self.win.width, self.win.height = util._make_floating_popup_size(contents, self.win)

	return self
end

--@private
local function find_window_by_var(name, value)
	for _, win in ipairs(api.nvim_list_wins()) do
		if npcall(api.nvim_win_get_var, win, name) == value then
			return win
		end
	end
end

--- Shows a popup window
function Popup:show()
	-- current buffer
	local bufnr = api.nvim_get_current_buf()

	-- check if this popup is focusable and if we need to focus it
	if self.win.focus_id and self.win.focusable ~= false then
		-- Go back to previous window if we are in a focusable one
		local current_winnr = api.nvim_get_current_win()
		if npcall(api.nvim_win_get_var, current_winnr, self.win.focus_id) then
			api.nvim_command("wincmd p")
			self.win.id = current_winnr
			self.buf.id = bufnr
			return
		end
		do
			local win = find_window_by_var(self.win.focus_id, bufnr)
			if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
				-- focus and return the existing buf, win
				api.nvim_set_current_win(win)
				api.nvim_command("stopinsert")
				self.win.id = win
				self.buf.id = api.nvim_win_get_buf(win)
				return
			end
		end
	end

	-- check if another floating popup already exists for this buffer
	-- and close it if needed
	local existing_float = npcall(api.nvim_buf_get_var, bufnr, "vim_ui_popup")
	if existing_float and api.nvim_win_is_valid(existing_float) then
		api.nvim_win_close(existing_float, true)
	end

	self.buf.id = api.nvim_create_buf(false, true)

	if self.win.stylize_markdown then
		-- `stylize_markdown` will also set the content of the buffer with
		-- appropriate highlighting
		self.contents = util.stylize_markdown(self.buf.id, self.contents, self.win)
	else
		-- if `stylize_markdown` was not called, we have to set the contents of the
		-- buffer
		api.nvim_buf_set_lines(self.buf.id, 0, -1, true, self.contents)
	end

	local float_options
	if self.win.relative == "cursor" then
		float_options = util.make_floating_popup_options(self.win.width, self.win.height, self.win)
	else
		float_options = {
			relative = self.win.relative,
			anchor = self.win.position,
			row = self.win.row,
			col = self.win.col,
			height = self.win.height,
			focusable = self.win.focusable,
			style = self.win.style,
			width = self.win.width,
			border = self.win.border,
			zindex = self.win.zindex,
		}
	end

	-- create the floating window
	self.win.id = api.nvim_open_win(self.buf.id, self.win.enter, float_options)

	-- set some options for pretty markdown
	if self.win.stylize_markdown then
		self:set_opt("conceallevel", 2)
		self:set_opt("concealcursor", "n")
	end

	-- disable folding
	self:set_opt("foldenable", false)
	-- set wrapping
	self:set_opt("wrap", self.win.wrap)

	self:set_opt("modifiable", false, "buf")
	self:set_opt("bufhidden", "wipe", "buf")

	-- Add keymap to close popup using 'q'
	self:set_keymap("n", "q", "<cmd>bdelete<cr>", { silent = true, noremap = true })

	-- set the autocmds to automatically close the popup on certain events
	util.close_preview_autocmd(self.win.close_events, self.win.id)

	-- save focus_id
	api.nvim_buf_set_var(bufnr, self.win.focus_id, self.buf.id)
	api.nvim_win_set_var(self.win.id, self.win.focus_id, bufnr)
end

--- Sets an option on a popup window
---
--@param option the option you want to set the value for
--@param value  the value you want to set for the option
--@param on     the thing you want to set the option on (defualts to 'win')
function Popup:set_opt(option, value, on)
	if self.win.id == nil or self.buf.id == nil then
		error("you must first show the window using Popup:show() before setting any options!")
	end

	local set_opt_fns = {
		win = function()
			api.nvim_win_set_option(self.win.id, option, value)
		end,
		buf = function()
			api.nvim_buf_set_option(self.buf.id, option, value)
		end,
	}

	if on and set_opt_fns[on] then
		set_opt_fns[on]()
	else
		set_opt_fns["win"]()
	end
end

function Popup:set_keymap(mode, lhs, rhs, opts)
	if self.win.id == nil or self.buf.id == nil then
		error("you must first show the window using Popup:show() before setting any keymaps!")
	end

	api.nvim_buf_set_keymap(self.buf.id, mode, lhs, rhs, opts)
end

return Popup
