local M = {}

M.options = {}

local defaults = {
	log_level = "info",
}

local set_log_level = function(log_level)
	local log_levels = { "trace", "debug", "info", "warn", "error", "fatal" }
	for _, level in pairs(log_levels) do
		if level == log_level then
			return log_level
		end
	end
end

local set_options = function(options)
	if options.log_level then
		options.log_level = set_log_level(options.log_level)
	end
	M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup = function(options)
	set_options(options)
end

return M
