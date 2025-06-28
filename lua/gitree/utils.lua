local M = {}

local log = require("gitree.log")

M.confirm = function(label)
	local confirmed = vim.fn.input(string.format("%s [y|N]: ", label))
	if string.sub(string.lower(confirmed), 0, 1) == "y" then
		return true
	end
	return false
end

M.ask_input = function(prefix, suffix)
	local new_path = vim.fn.input(prefix, suffix)
	if new_path == "" then
		log.warn("No valid input")
		return
	end
	return new_path
end

return M
