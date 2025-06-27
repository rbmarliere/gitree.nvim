local M = {}

local cmd = require("gitree.cmd")
local log = require("gitree.log")

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
		main = true,  -- first one is always the main worktree
		path = "",
		head = "",
		branch = "(bare)",
	}
	local i = 1

	for _, line in ipairs(stdout) do
		if line == "" then
			table.insert(trees, i, tree)
			tree = {
				main = false,
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
				tree.branch = string.format("[%s]", branch)
			elseif string.find(line, "^detached$") then
				tree.branch = "(detached HEAD)"
			end
		end
	end

	return trees
end

return M
