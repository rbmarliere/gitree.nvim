local M = {}

local config = require("gitree.config")
local log = require("gitree.log")
local state = require("gitree.state")

local Path = require("plenary.path")

M.change_dir = function(worktree_path)
	vim.schedule(function()
		vim.api.nvim_set_current_dir(worktree_path)
		vim.api.nvim_command("clearjumps")
		log.info("Changed directory to " .. worktree_path)
		if config.options.on_select and type(config.options.on_select) == "function" then
			config.options.on_select()
		end
	end)
end

M.confirm = function(label, cb)
	assert(type(cb) == "function")
	vim.ui.select({ "No", "Yes" }, {
		prompt = label,
	}, function(ans)
		if ans then
			cb(ans)
		else
			state.new = {}
		end
	end)
end

M.input = function(prompt, default, cb)
	assert(type(cb) == "function")
	vim.ui.input({
		prompt = prompt,
		default = default,
		cancelreturn = vim.NIL,
	}, function(ans)
		if ans then
			cb(ans)
		else
			state.new = {}
		end
	end)
end

M.is_worktree_path_valid = function(path)
	path = Path:new(path)
	if path:absolute() == state.main_worktree_path:absolute() then
		log.warn("Worktree path can't be the same of the main worktree")
		return false
	end
	if path:absolute():sub(1, #state.main_worktree_path:absolute()) ~= state.main_worktree_path:absolute() then
		log.warn("Worktree path is not within the main worktree")
		return false
	end
	if path:exists() then
		log.warn("Worktree path already exists")
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
