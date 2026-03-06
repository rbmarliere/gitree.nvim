local config = require("gitree.config")

local logger = nil
local notify_levels = {
	info = vim.log.levels.INFO,
	warn = vim.log.levels.WARN,
	error = vim.log.levels.ERROR,
}

local notify = function(msg, mode_name)
	vim.notify(msg, notify_levels[mode_name])
end

local get_logger = function()
	if not logger then
		logger = require("plenary.log").new({
			plugin = "gitree",
			level = config.options.log_level,
			use_console = false,
				fmt_msg = function(is_console, mode_name, src_path, src_line, msg)
					local nameupper = mode_name:upper()
					local lineinfo = src_path .. ":" .. src_line
					if notify_levels[mode_name] then
						if vim.in_fast_event() then
							vim.schedule(function()
								notify(msg, mode_name)
							end)
						else
							notify(msg, mode_name)
						end
					end
					return string.format("[%-6s%s] %s: %s\n", nameupper, os.date("%Y/%m/%d %H:%M:%S"), lineinfo, msg)
				end,
			})
	end
	return logger
end

-- make sure to initialize logger only in the first usage, by then the config was already set
return setmetatable({}, {
	__index = function(_, k)
		return get_logger()[k]
	end,
})
