local M = {}

local config = require("gitree.config")
local git = require("gitree.git")
local log = require("gitree.log")
local state = require("gitree.state")
local utils = require("gitree.utils")

local telescope_action_state = require("telescope.actions.state")
local telescope_actions = require("telescope.actions")
local telescope_builtin = require("telescope.builtin")

local change_dir = function(worktree_path)
	vim.cmd("cd " .. worktree_path)
	vim.cmd("clearjumps")
	log.info("Changed directory to " .. worktree_path)
end

local add_worktree = function()
	state.new_worktree_opts.path = utils.ask_input("Path to worktree > ", state.main_worktree_path:absolute())
	log.info("Adding worktree...")
	vim.defer_fn(function()
		if git.add_worktree(state.new_worktree_opts) then
			change_dir(state.new_worktree_opts.path)
			state.new_worktree_opts = nil
			if config.options.on_add and type(config.options.on_add) == "function" then
				config.options.on_add()
			end
		end
	end, 10)
end

M.move = function(prompt_bufnr) end

M.remove = function(prompt_bufnr)
	local tree = telescope_action_state.get_selected_entry()
	telescope_actions.close(prompt_bufnr)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == state.main_worktree_path:absolute() then
		log.warn("Refusing to remove main worktree")
		return
	end
	if tree.path == vim.loop.cwd() then
		change_dir(state.main_worktree_path:absolute())
	end
	log.info("Removing worktree...")
	vim.defer_fn(function()
		if git.remove_worktree(tree.path) then
			if tree.branch ~= "" and utils.confirm(string.format("Removed worktree, delete branch %s?", tree.branch)) then
				if git.delete_branch(tree.branch) then
					log.info("Deleted branch")
				end
			else
				log.info("Removed worktree")
			end
		else
			log.info("Did not remove worktree")
		end
	end, 10)
end

local add_from_local_tracking_branch = function(prompt_bufnr)
	local entry = telescope_action_state.get_selected_entry()
	telescope_actions.close(prompt_bufnr)
	if entry == nil then
		log.warn("No upstream branch selected")
		return
	end
	state.new_worktree_opts.upstream = entry.value
	add_worktree()
end

local add_from_commit = function(prompt_bufnr)
	local entry = telescope_action_state.get_selected_entry()
	telescope_actions.close(prompt_bufnr)
	if entry == nil then
		log.warn("No commit selected")
		return
	end
	state.new_worktree_opts.commit = entry.value
	if utils.confirm("Create a new branch?") then
		state.new_worktree_opts.branch = utils.ask_input("New branch name > ", "")
		if utils.confirm("Track an upstream?") then
			local opts = {}
			opts.attach_mappings = function(prompt_bufnr, map)
				telescope_actions.select_default:replace(add_from_local_tracking_branch)
				return true
			end
			opts.pattern = nil
			return telescope_builtin.git_branches(opts)
		end
	end
	add_worktree()
end

local add_from_local_branch = function(prompt_bufnr)
	local entry = telescope_action_state.get_selected_entry()
	telescope_actions.close(prompt_bufnr)
	if entry == nil then
		log.warn("No local branch selected")
		return
	end
	state.new_worktree_opts.branch = entry.value
	add_worktree()
end

local add_from_remote_branch = function(prompt_bufnr)
	local entry = telescope_action_state.get_selected_entry()
	telescope_actions.close(prompt_bufnr)
	if entry == nil then
		log.warn("No remote branch selected")
		return
	end
	state.new_worktree_opts.upstream = entry.value
	state.new_worktree_opts.branch = utils.ask_input("New branch name > ", "")
	add_worktree()
end

M.add = function()
	state.new_worktree_opts = {}
	local opts = {}

	if utils.confirm("Checkout a commit? (otherwise, an existing branch)") then
		opts.attach_mappings = function(prompt_bufnr, map)
			telescope_actions.select_default:replace(add_from_commit)
			return true
		end
		return telescope_builtin.git_commits(opts)
	end

	if utils.confirm("Checkout a remote branch?") then
		opts.attach_mappings = function(prompt_bufnr, map)
			telescope_actions.select_default:replace(add_from_remote_branch)
			return true
		end
		opts.pattern = "refs/remotes/"
		return telescope_builtin.git_branches(opts)
	end

	opts.attach_mappings = function(prompt_bufnr, map)
		telescope_actions.select_default:replace(add_from_local_branch)
		return true
	end
	opts.pattern = "refs/heads/"
	return telescope_builtin.git_branches(opts)
end

M.select = function(prompt_bufnr)
	local tree = telescope_action_state.get_selected_entry()
	telescope_actions.close(prompt_bufnr)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	log.info("Selecting worktree...")
	vim.defer_fn(function()
		change_dir(tree.path)
		if config.options.on_select and type(config.options.on_select) == "function" then
			config.options.on_select()
		end
	end, 10)
end

return M
