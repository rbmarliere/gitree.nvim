local M = {}

local config = require("gitree.config")
local git = require("gitree.git")
local log = require("gitree.log")
local state = require("gitree.state")
local utils = require("gitree.utils")
local picker = require("gitree.picker")

local change_dir = function(worktree_path)
	vim.cmd("cd " .. worktree_path)
	vim.cmd("clearjumps")
	log.info("Changed directory to " .. worktree_path)
end

local add_worktree = function()
	local suffix = state.main_worktree_path:absolute() .. "/"
	if state.new_worktree_opts.remote and state.new_worktree_opts.upstream then
		suffix = string.format("%s%s", suffix, state.new_worktree_opts.upstream)
	elseif state.new_worktree_opts.branch then
		suffix = string.format("%s%s", suffix, state.new_worktree_opts.branch)
	end
	state.new_worktree_opts.path = utils.input("Path to worktree > ", suffix)
	if state.new_worktree_opts.path == nil then
		return
	end
	log.info("Adding worktree...")
	vim.schedule(function()
		if git.add_worktree(state.new_worktree_opts) then
			change_dir(state.new_worktree_opts.path)
			state.new_worktree_opts = nil
			if config.options.on_add and type(config.options.on_add) == "function" then
				config.options.on_add()
			end
		end
	end)
end

M.move = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == state.main_worktree_path:absolute() then
		log.warn("Refusing to move main worktree")
		return
	end
	picker.close(opts)
	if tree.path == vim.uv.cwd() then
		change_dir(state.main_worktree_path:absolute())
	end
	local new_path = utils.input("New path to worktree > ", tree.path)
	if new_path == nil then
		return
	end
	log.info("Moving worktree...")
	vim.schedule(function()
		if git.move_worktree(tree, new_path) then
			if tree.branch == "" then
				log.info("Moved worktree")
				return
			end
			local ok = utils.confirm(string.format("Moved worktree, rename branch %s?", tree.branch))
			if ok == nil then
				return
			end
			if ok then
				local new_branch = utils.input("New branch name > ", tree.branch)
				if new_branch == nil then
					return
				end
				if git.rename_branch(tree.branch, new_branch) then
					log.info("Renamed branch")
				end
			end
		end
	end)
end

M.remove = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if not utils.confirm(string.format("Remove worktree %s?", tree.path)) then
		return
	end
	if tree.path == state.main_worktree_path:absolute() then
		log.warn("Refusing to remove main worktree")
		return
	end
	picker.close(opts)
	if tree.path == vim.uv.cwd() then
		change_dir(state.main_worktree_path:absolute())
	end
	log.info("Removing worktree...")
	vim.schedule(function()
		if git.remove_worktree(tree.path) then
			if tree.branch == "" then
				log.info("Removed worktree")
				return
			end
			local ok = utils.confirm(string.format("Removed worktree, delete branch %s?", tree.branch))
			if ok == nil then
				return
			end
			if ok then
				if git.delete_branch(tree.branch) then
					log.info("Deleted branch")
				end
			end
		end
	end)
end

M.add_from_local_tracking_branch = function(opts)
	local entry = picker.current_branch(opts)
	if entry == nil then
		log.warn("No upstream branch selected")
		return
	end
	picker.close(opts)
	state.new_worktree_opts.upstream = entry
	add_worktree()
end

M.add_from_commit = function(opts)
	local entry = picker.current_commit(opts)
	if entry == nil then
		log.warn("No commit selected")
		return
	end
	picker.close(opts)
	state.new_worktree_opts.commit = entry
	local ok = utils.confirm("Create a new branch?")
	if ok == nil then
		return
	end
	if ok then
		state.new_worktree_opts.branch = utils.input("New branch name > ", "")
		if state.new_worktree_opts.branch == nil then
			return
		end
		ok = utils.confirm("Track an upstream?")
		if ok == nil then
			return
		end
		if ok then
			return picker.git_all_branches()
		end
	end
	add_worktree()
end

M.add_from_local_branch = function(opts)
	local entry = picker.current_branch(opts)
	if entry == nil then
		log.warn("No local branch selected")
		return
	end
	picker.close(opts)
	state.new_worktree_opts.branch = entry
	add_worktree()
end

M.add_from_remote_branch = function(opts)
	local entry = picker.current_branch(opts)
	if entry == nil then
		log.warn("No remote branch selected")
		return
	end
	picker.close(opts)
	state.new_worktree_opts.remote = true
	state.new_worktree_opts.upstream = entry
	state.new_worktree_opts.branch = utils.input("New branch name > ", string.gsub(entry, "/", "_"))
	if state.new_worktree_opts.branch == nil then
		return
	end
	add_worktree()
end

M.add = function()
	state.new_worktree_opts = {
		remote = false,
		upstream = nil,
		branch = nil,
		path = nil,
		commit = nil,
	}

	local ok = utils.confirm("Checkout a commit? (otherwise, an existing branch)")
	if ok == nil then
		return
	end
	if ok then
		return picker.git_commits()
	end

	ok = utils.confirm("Checkout a remote branch?")
	if ok == nil then
		return
	end
	if ok then
		return picker.git_remote_branches()
	end

	return picker.git_local_branches()
end

M.select = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == vim.uv.cwd() then
		return
	end
	picker.close(opts)
	log.info("Selecting worktree...")
	vim.schedule(function()
		change_dir(tree.path)
		if config.options.on_select and type(config.options.on_select) == "function" then
			config.options.on_select()
		end
	end)
end

M.files = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == vim.uv.cwd() then
		return
	end
	picker.close(opts)
	return picker.files(tree)
end

M.grep = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == vim.uv.cwd() then
		return
	end
	picker.close(opts)
	return picker.grep(tree)
end

return M
