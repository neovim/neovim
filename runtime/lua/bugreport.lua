local TEMPLATE = [[<!-- Before reporting: search existing issues and check the FAQ. -->

- `nvim --version`:

```%s
```

- `vim -u DEFAULTS` (version: ) behaves differently?
- Operating system/version:
    - OS: `%s`
    - Release: `%s`
    - Version: `%s`
    - Distribution:  `%s`
    - Architecture: `%s`
- Terminal name/version:
- `$TERM`: %s

### Steps to reproduce using `nvim -u NORC`

```
nvim -u NORC
# Alternative for shell-related problems:
# env -i TERM=ansi-256color "$(which nvim)"

```

### Actual behaviour

### Expected behaviour]]

local api = vim.api
local fn = vim.fn

local function fetch_distro_info()
	if fn.has("unix") == 1 then
		local distro_info = {}
		local ETC_RELEASE = fn.glob("/etc/*-release", false, true)
		for _, path in ipairs(ETC_RELEASE) do
			for line in io.lines(path) do
				for key, value in line:gmatch("(.+)=(.+)") do
					distro_info[key] = value
				end
			end
		end
		return distro_info
	end
end

local template_pre_filled
do
	local TERM = vim.env.TERM
	local NVIM_VERSION = fn.execute("version")
	local SYSTEM_INFO = vim.loop.os_uname()
	local DISTRO_INFO = fetch_distro_info()

	template_pre_filled = TEMPLATE:format(
		NVIM_VERSION,
		SYSTEM_INFO.sysname,
		SYSTEM_INFO.release,
		SYSTEM_INFO.version,
		DISTRO_INFO.PRETTY_NAME or (DISTRO_INFO.NAME .. " " .. DISTRO_INFO.VERSION) or "",
		SYSTEM_INFO.machine,
		TERM
	)
end

local function open_markdown_buffer()
	vim.cmd("tabnew")
	local bufnr = api.nvim_get_current_buf()
	api.nvim_buf_set_name(bufnr, "bugreport.md")
	api.nvim_buf_set_lines(bufnr, 0, 1, false, vim.split(template_pre_filled, "\n"))
	api.nvim_buf_set_option(bufnr, "filetype", "markdown")
end

open_markdown_buffer()
