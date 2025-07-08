local M = {}

local actions = require("gitree.actions")
local git = require("gitree.git")
local state = require("gitree.state")
local log = require("gitree.log")

local Snacks = require("snacks")

M.current = function(picker)
	return picker:current()
end

M.current_branch = function(picker)
	local entry = M.current(picker)
	if entry and entry.branch then
		return entry.branch:gsub("^remotes/", "")
	end
end

M.current_commit = function(picker)
	local entry = M.current(picker)
	if entry and entry.commit then
		return entry.commit
	end
end

M.close = function(picker)
	picker:close()
end

M.list = function(_)
	state.worktrees = git.get_worktrees()
	if not state.worktrees then
		return
	end

	return Snacks.picker({
		title = "Git Worktrees",
		items = state.worktrees,
		layout = { preview = false },
		confirm = actions.select,
		format = "text",
		win = {
			input = {
				keys = {
					["<M-a>"] = { "add", mode = { "i", "n" } },
					["<M-m>"] = { "move", mode = { "i", "n" } },
					["<M-r>"] = { "remove", mode = { "i", "n" } },
					["<M-p>"] = { "files", mode = { "i", "n" } },
					["<M-g>"] = { "grep", mode = { "i", "n" } },
				},
			},
		},
		actions = {
			add = actions.add,
			move = actions.move,
			remove = actions.remove,
			files = actions.files,
			grep = actions.grep,
		},
	})
end

M.git_all_branches = function()
	return Snacks.picker.git_branches({
		all = true,
		confirm = actions.add_from_local_tracking_branch,
	})
end

M.git_remote_branches = function()
	return Snacks.picker.git_branches({
		all = true,
		confirm = actions.add_from_remote_branch,
	})
end

M.git_local_branches = function()
	return Snacks.picker.git_branches({
		confirm = actions.add_from_local_branch,
	})
end

M.git_commits = function()
	return Snacks.picker.git_log({
		confirm = actions.add_from_commit,
	})
end

M.files = function(tree)
	return Snacks.picker.files({ cwd = tree.path })
end

M.grep = function(tree)
	return Snacks.picker.grep({ dirs = { tree.path } })
end

M.git_tags = function()
	local tags = git.get_tags()
	if not tags then
		return
	end

	return Snacks.picker({
		title = "Git Tags",
		items = tags,
		preview = "git_show",
		confirm = actions.add_from_commit,
		format = "text",
	})
end

return M
