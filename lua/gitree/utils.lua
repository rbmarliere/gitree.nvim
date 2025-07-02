local M = {}

local log = require("gitree.log")
local state = require("gitree.state")

M.confirm = function(label)
	local ans = M.input(string.format("%s [y|N]: ", label), "")
	if ans == nil then
		return
	end
	return string.sub(string.lower(ans), 0, 1) == "y"
end

M.input = function(prompt, default)
	local ok, ans = pcall(vim.fn.input, {
		prompt = prompt,
		default = default,
		cancelreturn = vim.NIL,
	})
	if not ok or ans == vim.NIL then
		return
	end
	return ans
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
