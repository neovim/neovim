local M = {}

local report_error = vim.fn['health#report_error']
local report_info = vim.fn['health#report_info']

function M.check_health()

	for key, client in pairs(vim.lsp.get_active_clients()) do
		M.lsp_dump_active_client(client)
	end
end

function M.lsp_dump_active_client(client)

	local config = client.config
	vim.fn["health#report_start"]('State of '..config.name)
	report_info("Working directory: "..config.root_dir)

end

return M

