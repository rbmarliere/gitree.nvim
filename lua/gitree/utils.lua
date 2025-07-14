local M = {}

local log = require("gitree.log")
local state = require("gitree.state")

local Path = require("plenary.path")

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

M.is_dir_empty = function(path)
	local fd = vim.loop.fs_scandir(path)
	if not fd then
		return false -- cannot scan, assume not empty or invalid
	end
	return vim.loop.fs_scandir_next(fd) == nil
end

M.rm_dangling_dirs = function(path)
	-- git does not clean up empty directories
	-- e.g. `git worktree remove foo/bar` will not remove `foo` if it becomes empty
	local root = state.main_worktree_path
	local current = Path:new(path):parent()
	while current:absolute():sub(1, #root:absolute()) == root:absolute() do
		if not current:exists() or not current:is_dir() or not M.is_dir_empty(current:absolute()) then
			break
		end
		log.debug("removing empty dir", current:absolute())
		current:rmdir()
		current = current:parent()
		if current:absolute() == root:absolute() then
			break
		end
	end
end

return M
