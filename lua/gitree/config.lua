local M = {}

M.options = nil

local defaults = {
	log_level = "info",
	backend = "telescope",
	on_select = function() end,
	on_add = function() end,
}

local set_options = function(options)
	if options and options.log_level then
		local log_levels = { "trace", "debug", "info", "warn", "error", "fatal" }
		local valid = false
		for _, level in pairs(log_levels) do
			if level == options.log_level then
				valid = true
				break
			end
		end
		if not valid then
			error("Invalid log level")
		end
	end
	M.options = vim.tbl_extend("force", defaults, options or {})
	if M.options.backend ~= "telescope" and M.options.backend ~= "snacks" then
		error("Invalid backend selected")
	end
end

M.setup = function(options)
	set_options(options)
	require("gitree.log").debug(vim.inspect(M.options))
end

return setmetatable(M, {
	__index = function(_, k)
		if k == "options" then
			M.setup()
		end
		return rawget(M, k)
	end,
})
