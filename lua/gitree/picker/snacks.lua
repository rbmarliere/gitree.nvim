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

M.list = function(cur_file)
	state.new = {}
	state.worktrees = git.get_worktrees()
	if not state.worktrees then
		return
	end

	local confirm
	local keys = {}
	if cur_file then
		state.cur_file = cur_file
		confirm = actions.select_file
	else
		confirm = actions.select
		keys = {
			["<M-a>"] = { "add", mode = { "i", "n" } },
			["<M-m>"] = { "move", mode = { "i", "n" } },
			["<M-r>"] = { "remove", mode = { "i", "n" } },
			["<M-p>"] = { "files", mode = { "i", "n" } },
			["<M-g>"] = { "grep", mode = { "i", "n" } },
		}
	end

	return Snacks.picker({
		title = "Git Worktrees",
		items = state.worktrees,
		layout = { preview = false },
		confirm = confirm,
		format = "text",
		win = {
			input = {
				keys = keys,
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
		confirm = actions.pick_upstream_branch,
	})
end

M.git_remote_branches = function()
	return Snacks.picker.git_branches({
		all = true,
		confirm = actions.pick_remote_branch,
		pattern = "remotes/",
	})
end

M.git_local_branches = function()
	return Snacks.picker.git_branches({
		confirm = actions.pick_local_branch,
	})
end

M.git_commits = function()
	return Snacks.picker.git_log({
		confirm = actions.pick_commit,
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
		confirm = actions.pick_commit,
		format = "text",
	})
end

return M
