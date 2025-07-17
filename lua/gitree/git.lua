local M = {}

local cmd = require("gitree.cmd")
local log = require("gitree.log")
local state = require("gitree.state")
local utils = require("gitree.utils")

local Path = require("plenary.path")

M.is_bare_repository = function(path)
	local ret, stdout, _ = cmd.git("-C", path, "rev-parse", "--is-bare-repository")
	return ret == 0 and stdout and stdout[1] == "true"
end

M.try_get_common_dir = function()
	local ret, stdout, _ = cmd.git("rev-parse", "--path-format=absolute", "--git-common-dir")
	if ret ~= 0 then
		log.warn("Could not find common git directory. Is CWD a repository?")
		return false
	end
	assert(stdout ~= nil)
	return stdout[1]
end

M.list_worktrees = function()
	local ret, stdout, _ = cmd.git("worktree", "list", "--porcelain")
	assert(ret == 0)
	assert(stdout ~= nil)
	return stdout
end

M.get_tags = function()
	local common_dir = M.try_get_common_dir()
	if not common_dir then
		return false
	end

	local ret, stdout, _ = cmd.git("-C", common_dir, "tag")
	assert(ret == 0)
	if not stdout then
		return {}
	end

	local tags = {}
	for i, line in ipairs(stdout) do
		if line then
			local tag = {}
			tag.text = line
			tag.commit = line -- for use in actions.add_from_commit
			table.insert(tags, i, tag)
		end
	end

	log.debug(tags)
	return tags
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
		text = "",
		path = "",
		head = "",
		branch = "",
		branch_label = "",
	}
	local i = 1

	for _, line in ipairs(stdout) do
		if line == "" then
			if i == 1 then
				state.main_worktree_path = Path:new(tree.path)
				tree.text = tree.path
			else
				tree.text = string.format("%s", tree.path:sub(#state.main_worktree_path:absolute() + 2))
			end
			local cur = ""
			if tree.path == vim.uv.cwd() then
				cur = "[.] "
			end
			tree.text = string.format("%s%s", cur, tree.text)
			table.insert(trees, i, tree)
			tree = {
				text = "",
				path = "",
				head = "",
				branch = "",
				branch_label = "(bare)", -- first one is always the main worktree
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
				tree.branch_label = string.format("[%s]", branch)
			elseif string.find(line, "^detached$") then
				tree.branch_label = "(detached HEAD)"
			end
		end
	end

	local path_width = 0
	for _, tree in ipairs(trees) do
		path_width = math.max(#tree.text, path_width)
	end

	local pad = 0
	for _, tree in ipairs(trees) do
		pad = path_width - #tree.text + 1
		tree.text = tree.text .. string.rep(" ", pad) .. tree.head .. " " .. tree.branch_label
		tree.text = tree.text:gsub("%s+$", "")
	end

	log.debug(trees)
	return trees
end

M.has_branch = function(branch)
	local ret, stdout, _ = cmd.git("branch", "--list", branch)
	assert(ret == 0)
	assert(stdout ~= nil)
	return stdout[1] ~= nil
end

M.has_submodule = function(tree)
	local ret, stdout, _ = cmd.git("-C", tree.path, "submodule", "status")
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

	if branch == nil then
		if commit == nil then
			log.warn("Need a commit to create new detached worktree")
		end
		table.insert(cmdline, "-d")
		table.insert(cmdline, path:absolute())
		table.insert(cmdline, commit)
	else
		for _, tree in ipairs(state.worktrees) do
			if tree.branch == branch then
				log.warn("Branch", branch, "already in use in", tree.path)
				return false
			end
		end

		table.insert(cmdline, path:absolute())

		if not M.has_branch(branch) then
			table.insert(cmdline, "-b")
		elseif (upstream ~= nil or commit ~= nil) and utils.confirm("Reset existing branch?") then
			table.insert(cmdline, "-B")
		end
		table.insert(cmdline, branch)

		if upstream ~= nil then
			table.insert(cmdline, "--track")
			table.insert(cmdline, upstream)
		elseif commit ~= nil then
			table.insert(cmdline, commit)
		end
	end

	local ret, _, _ = cmd.git(cmdline)
	return ret == 0
end

M.delete_branch = function(branch)
	local ret, _, _ = cmd.git("branch", "-D", branch)
	return ret == 0
end

M.remove_worktree = function(path)
	local cmdline = { "worktree", "remove", path }
	local removed, _, _ = cmd.git(cmdline)
	if removed ~= 0 and utils.confirm("Unable to remove, force? (might contain submodules or uncommitted changes)") then
		table.insert(cmdline, "--force")
		removed, _, _ = cmd.git(cmdline)
	end
	if removed ~= 0 then
		return false
	end
	utils.rm_dangling_dirs(path)
	return true
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

	-- git fails if required subdirectory is not found
	-- e.g. `git worktree move foo nonexistantdir/foo
	vim.system({ "mkdir", "-p", dest:parent():absolute() }):wait()

	local ret, _, _
	if M.has_submodule(tree) then
		local ok = utils.confirm("Worktree has submodules, force move? (deinit && mv && repair && init)")
		if ok == nil then
			return
		end
		if ok then
			ret, _, _ = cmd.git("-C", tree.path, "submodule", "deinit", "--all")
			if not ret then
				log.warn("Unable to deinit modules")
				return false
			end
			ret = vim.fn.rename(tree.path, dest:absolute())
			if not ret then
				log.warn(string.format("Unable to rename directory %s to %s", tree.path, dest:absolute()))
				return false
			end
			ret, _, _ = cmd.git("-C", dest:absolute(), "worktree", "repair")
			if not ret then
				log.warn("Unable to repair worktree")
				return false
			end
			ret, _, _ = cmd.git("-C", dest:absolute(), "submodule", "update", "--init", "--recursive")
			if not ret then
				log.warn("Unable to re-init submodules")
				return false
			end
			utils.rm_dangling_dirs(tree.path)
			tree.path = dest:absolute()
			return true
		else
			return false
		end
	else
		ret, _, _ = cmd.git("worktree", "move", tree.path, dest:absolute())
		if ret ~= 0 then
			return false
		end
		utils.rm_dangling_dirs(tree.path)
		return true
	end
end

M.rename_branch = function(old, new)
	local ret, _, _ = cmd.git("branch", "-m", old, new)
	return ret == 0
end

return M
