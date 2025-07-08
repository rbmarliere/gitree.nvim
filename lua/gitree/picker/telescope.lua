local M = {}

local actions = require("gitree.actions")
local git = require("gitree.git")
local state = require("gitree.state")

local telescope_action_state = require("telescope.actions.state")
local telescope_actions = require("telescope.actions")
local telescope_builtin = require("telescope.builtin")
local telescope_config = require("telescope.config")
local telescope_entry_display = require("telescope.pickers.entry_display")
local telescope_finders = require("telescope.finders")
local telescope_pickers = require("telescope.pickers")

M.current = function(_)
	return telescope_action_state.get_selected_entry()
end

M.current_branch = function(picker)
	local entry = M.current(picker)
	if entry and entry.value then
		return entry.value
	end
end

M.current_commit = function(picker)
	local entry = M.current(picker)
	if entry and entry.value then
		return entry.value
	end
end

M.close = function(prompt_bufnr)
	telescope_actions.close(prompt_bufnr)
end

M.list = function()
	state.worktrees = git.get_worktrees()
	if not state.worktrees then
		return
	end

	telescope_pickers
		.new({}, {
			prompt_title = "Git Worktrees",
			finder = telescope_finders.new_table({
				results = state.worktrees,
				entry_maker = function(entry)
					entry.value = entry.text
					entry.ordinal = entry.text
					entry.display = entry.text
					return entry
				end,
			}),
			sorter = telescope_config.values.generic_sorter({}),
			attach_mappings = function(_, map)
				telescope_actions.select_default:replace(actions.select)
				map({ "i", "n" }, "<M-a>", actions.add)
				map({ "i", "n" }, "<M-r>", actions.remove)
				map({ "i", "n" }, "<M-m>", actions.move)
				map({ "i", "n" }, "<M-p>", actions.files)
				map({ "i", "n" }, "<M-g>", actions.grep)
				return true
			end,
		})
		:find()
end

M.git_all_branches = function()
	local opts = {}
	opts.attach_mappings = function(_, _)
		telescope_actions.select_default:replace(actions.add_from_local_tracking_branch)
		return true
	end
	opts.pattern = nil
	return telescope_builtin.git_branches(opts)
end

M.git_remote_branches = function()
	local opts = {}
	opts.attach_mappings = function(_, _)
		telescope_actions.select_default:replace(actions.add_from_remote_branch)
		return true
	end
	opts.pattern = "refs/remotes/"
	return telescope_builtin.git_branches(opts)
end

M.git_local_branches = function()
	local opts = {}
	opts.attach_mappings = function(_, _)
		telescope_actions.select_default:replace(actions.add_from_local_branch)
		return true
	end
	opts.pattern = "refs/heads/"
	return telescope_builtin.git_branches(opts)
end

M.git_commits = function()
	local opts = {}
	opts.attach_mappings = function(_, _)
		telescope_actions.select_default:replace(actions.add_from_commit)
		return true
	end
	opts.git_command = {
		"git",
		"-C",
		state.main_worktree_path:absolute(), -- grab all commits by targeting the main worktree
		"log",
		"--pretty=oneline",
		"--abbrev-commit",
		"--decorate=short", -- show tags for searching
	}
	return telescope_builtin.git_commits(opts)
end

M.files = function(tree)
	return telescope_builtin.find_files({ cwd = tree.path })
end

M.grep = function(tree)
	return telescope_builtin.live_grep({ search_dirs = { tree.path }})
end

M.git_tags = function()
	local tags = git.get_tags()
	if not tags then
		return
	end

	telescope_pickers
		.new({}, {
			prompt_title = "Git Tags",
			finder = telescope_finders.new_table({
				results = tags,
				entry_maker = function(entry)
					entry.value = entry.text
					entry.ordinal = entry.text
					entry.display = entry.text
					return entry
				end,
			}),
			sorter = telescope_config.values.generic_sorter(),
			attach_mappings = function(_, _)
				telescope_actions.select_default:replace(actions.add_from_commit)
				return true
			end,
		})
		:find()
end

return M
