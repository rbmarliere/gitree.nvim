local M = {}

local cmd = require("gitree.cmd")
local log = require("gitree.log")
local state = require("gitree.state")
local utils = require("gitree.utils")

local Path = require("plenary.path")

M.is_bare_repository = function(path)
	local ret, stdout, stderr = cmd.git("-C", path, "rev-parse", "--is-bare-repository")
	return ret == 0 and stdout and stdout[1] == "true"
end

M.try_get_common_dir = function()
	local ret, stdout, stderr = cmd.git("rev-parse", "--path-format=absolute", "--git-common-dir")
	if ret ~= 0 then
		log.warn("Could not find common git directory. Is CWD a repository?")
		return false
	end
	assert(stdout ~= nil)
	return stdout[1]
end

M.list_worktrees = function()
	local ret, stdout, stderr = cmd.git("worktree", "list", "--porcelain")
	assert(ret == 0)
	assert(stdout ~= nil)
	return stdout
end

M.get_worktrees = function()
	local common_dir = M.try_get_common_dir()
	if not common_dir then
		return false
	end
	if not M.is_bare_repository(common_dir) then
		log.warn("The common git directory is not a bare repository.")
		return false
	end

	local stdout = M.list_worktrees()
	local trees = {}
	local tree = {
		label = "(bare)", -- first one is always the main worktree
		path = "",
		head = "",
		branch = "",
	}
	local i = 1

	for _, line in ipairs(stdout) do
		if line == "" then
			table.insert(trees, i, tree)
			tree = {
				label = "",
				path = "",
				head = "",
				branch = "",
			}
			i = i + 1
		else
			local path = string.match(line, "^worktree%s+(.+)$")
			if path then
				tree.path = path
			end
			local head = string.match(line, "^HEAD%s+(.+)$")
			if head then
				tree.head = head:sub(0, 12)
			end
			local branch = string.match(line, "^branch refs/heads/(.+)$")
			if branch then
				tree.branch = string.format("%s", branch)
				tree.label = string.format("[%s]", branch)
			elseif string.find(line, "^detached$") then
				tree.label = "(detached HEAD)"
			end
		end
	end

	log.debug(trees)

	return trees
end

M.has_branch = function(branch)
	local ret, stdout, stderr = cmd.git("branch", "--list", branch)
	assert(ret == 0)
	assert(stdout ~= nil)
	return stdout[1] ~= nil
end

M.has_submodule = function(tree)
	local ret, stdout, stderr = cmd.git("-C", tree.path, "submodule", "status")
	assert(ret == 0)
	assert(stdout ~= nil)
	return stdout[1] ~= nil
end

M.add_worktree = function(opts)
	log.debug(opts)
	local path = opts.path or nil
	local commit = opts.commit or nil
	local branch = opts.branch or nil
	local upstream = opts.upstream or nil
	local cmdline = { "worktree", "add" }

	if path == nil then
		log.warn("New worktree path can't be nil")
		return false
	else
		path = Path:new(path)
	end

	if not utils.is_worktree_path_valid(path) then
		return false
	end

	if branch == nil and commit == nil then
		log.warn("Need a branch or commit to create new worktree")
		return false
	end

	if branch == nil then
		table.insert(cmdline, "--detach")
		table.insert(cmdline, path:absolute())
		table.insert(cmdline, commit)
	else
		for _, tree in ipairs(state.worktrees) do
			log.debug(tree)
			if tree.branch == branch then
				log.warn("Branch", branch, "already in use in", tree.path)
				return false
			end
		end
		if M.has_branch(branch) then
			table.insert(cmdline, path:absolute())
			table.insert(cmdline, branch)
		else
			table.insert(cmdline, "-b")
			table.insert(cmdline, branch)
			table.insert(cmdline, path:absolute())
			if upstream ~= nil then
				table.insert(cmdline, "--track")
				table.insert(cmdline, upstream)
			end
		end
	end

	local ret, stdout, stderr = cmd.git(cmdline)
	return ret == 0
end

M.delete_branch = function(branch)
	local ret, stdout, stderr = cmd.git("branch", "-D", branch)
	return ret == 0
end

M.remove_worktree = function(path)
	local cmdline = { "worktree", "remove", path }
	local ret, stdout, stderr = cmd.git(cmdline)
	if ret ~= 0 and utils.confirm("Unable to remove, force? (might contain submodules or uncommitted changes)") then
		table.insert(cmdline, "--force")
		ret, stdout, stderr = cmd.git(cmdline)
		return ret == 0
	end
	return ret == 0
end

M.move_worktree = function(tree, dest)
	if dest == nil then
		log.warn("New worktree path can't be nil")
		return false
	else
		dest = Path:new(dest)
	end

	if not utils.is_worktree_path_valid(dest) then
		return false
	end

	local ret, stdout, stderr
	if M.has_submodule(tree) then
		if utils.confirm("Worktree has submodules, force move? (deinit && mv && repair && init)") then
			ret, stdout, stderr = cmd.git("-C", tree.path, "submodule", "deinit", "--all")
			if not ret then
				log.warn("Unable to deinit modules")
				return false
			end
			ret = vim.fn.rename(tree.path, dest:absolute())
			if not ret then
				log.warn(string.format("Unable to rename directory %s to %s", tree.path, dest:absolute()))
				return false
			end
			ret, stdout, stderr = cmd.git("-C", dest:absolute(), "worktree", "repair")
			if not ret then
				log.warn("Unable to repair worktree")
				return false
			end
			ret, stdout, stderr = cmd.git("-C", dest:absolute(), "submodule", "update", "--init", "--recursive")
			if not ret then
				log.warn("Unable to re-init submodules")
				return false
			end
			tree.path = dest:absolute()
			return true
		else
			return false
		end
	else
		ret, stdout, stderr = cmd.git("worktree", "move", tree.path, dest:absolute())
		return ret == 0
	end
end

M.rename_branch = function(old, new)
	local ret, stdout, stderr = cmd.git("branch", "-m", old, new)
	return ret == 0
end

return M
