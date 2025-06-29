local M = {}

local log = require("gitree.log")
local state = require("gitree.state")

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

M.is_worktree_path_valid = function(path)
	if path:absolute() == state.main_worktree_path:absolute() then
		log.warn("New worktree path can't be the same of the main worktree")
		return false
	end
	if path:absolute():sub(1, #state.main_worktree_path:absolute()) ~= state.main_worktree_path:absolute() then
		log.warn("New worktree path is not within the main worktree")
		return false
	end
	if path:exists() then
		log.warn("New worktree path already exists")
		return false
	end
	return true
end

return M
