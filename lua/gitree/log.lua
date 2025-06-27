local config = require("gitree.config")

local logger = nil

local get_logger = function()
	if not logger then
		logger = require("plenary.log").new({
			plugin = "gitree",
			level = config.options.log_level,
			fmt_msg = function(is_console, mode_name, src_path, src_line, msg)
				local nameupper = mode_name:upper()
				local lineinfo = src_path .. ":" .. src_line
				if mode_name == "info" or mode_name == "warn" then
					-- override default log format if its a simple "info"
					return string.format("%s", msg)
				elseif is_console then
					return string.format("[%-6s%s] %s: %s", nameupper, os.date("%H:%M:%S"), lineinfo, msg)
				else
					return string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
				end
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
