local M = {}

local config = require("gitree.config")
local git = require("gitree.git")
local log = require("gitree.log")
local s = require("gitree.state")
local utils = require("gitree.utils")
local picker = require("gitree.picker")

local Path = require("plenary.path")

M.pick_upstream_branch = function(opts)
	local entry = picker.current_branch(opts)
	if entry == nil then
		log.warn("No upstream branch selected")
		return
	end
	picker.close(opts)
	s.new.upstream = entry
	M.add()
end

M.pick_commit = function(opts)
	local entry = picker.current_commit(opts)
	if entry == nil then
		log.warn("No commit selected")
		return
	end
	picker.close(opts)
	s.new.commit = entry
	M.add()
end

M.pick_local_branch = function(opts)
	local entry = picker.current_branch(opts)
	if entry == nil then
		log.warn("No local branch selected")
		return
	end
	picker.close(opts)
	for _, tree in ipairs(s.worktrees) do
		if tree.branch == entry then
			log.warn("Branch", entry, "already in use in", tree.path)
			s.new = {}
			return false
		end
	end
	s.new.branch = entry
	M.add()
end

M.pick_remote_branch = function(opts)
	local entry = picker.current_branch(opts)
	if entry == nil then
		log.warn("No remote branch selected")
		return
	end
	picker.close(opts)
	s.new.remote = true
	s.new.upstream = entry
	s.new.branch = utils.input("New branch name > ", string.gsub(entry, "/", "_"))
	if s.new.branch == nil then
		return
	end
	M.add()
end

M.add = function()
	local ok
	if next(s.new) == nil then
		ok = utils.confirm("Checkout a commit? (otherwise, an existing branch)")
		if ok == nil then
			s.new = {}
			return
		end
		if ok then
			ok = utils.confirm("Checkout a specific tag?")
			if ok == nil then
				s.new = {}
				return
			end
			if ok then
				return picker.git_tags()
			else
				return picker.git_commits()
			end
		end
		ok = utils.confirm("Checkout a remote branch?")
		if ok == nil then
			s.new = {}
			return
		end
		if ok then
			return picker.git_remote_branches()
		end
		return picker.git_local_branches()
	end

	if s.new.branch == nil then
		ok = utils.confirm("Create a new branch?")
		if ok == nil then
			s.new = {}
			return
		end
		if ok then
			s.new.branch = utils.input("New branch name > ", "")
			if s.new.branch == nil then
				s.new = {}
				return
			end
		end
	end
	if s.new.commit == nil and s.new.upstream == nil then
		ok = utils.confirm("Checkout a commit?")
		if ok == nil then
			s.new = {}
			return
		end
		if ok then
			ok = utils.confirm("Checkout a specific tag?")
			if ok == nil then
				s.new = {}
				return
			end
			if ok then
				return picker.git_tags()
			else
				return picker.git_commits()
			end
		end
	end
	if s.new.commit == nil and s.new.branch ~= nil and not s.new.remote and s.new.upstream == nil then
		ok = utils.confirm("Track an upstream?")
		if ok == nil then
			s.new = {}
			return
		end
		if ok then
			return picker.git_all_branches()
		end
	end

	local suffix = s.main_worktree_path:absolute() .. "/"
	if s.new.remote and s.new.upstream then
		suffix = string.format("%s%s", suffix, s.new.upstream)
	elseif s.new.branch then
		suffix = string.format("%s%s", suffix, s.new.branch)
	end
	local new_path = utils.input("Path to worktree > ", suffix)
	if new_path == nil then
		s.new = {}
		return
	end
	if not utils.is_worktree_path_valid(new_path) then
		s.new = {}
		return
	end
	s.new.path = Path:new(new_path):absolute()
	log.info("Adding worktree...")
	vim.schedule(function()
		if git.add_worktree(s.new) then
			utils.change_dir(s.new.path)
			if config.options.on_add and type(config.options.on_add) == "function" then
				config.options.on_add()
			end
		end
		s.new = {}
	end)
end

M.move = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == s.main_worktree_path:absolute() then
		log.warn("Refusing to move main worktree")
		return
	end
	picker.close(opts)
	if tree.path == vim.uv.cwd() then
		utils.change_dir(s.main_worktree_path:absolute())
	end
	local new_path = utils.input("New path to worktree > ", tree.path)
	if new_path == nil then
		return
	end
	if not utils.is_worktree_path_valid(new_path) then
		return
	end
	s.new.path = Path:new(new_path):absolute()
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
	if tree.path == s.main_worktree_path:absolute() then
		log.warn("Refusing to remove main worktree")
		return
	end
	picker.close(opts)
	if tree.path == vim.uv.cwd() then
		utils.change_dir(s.main_worktree_path:absolute())
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
		utils.change_dir(tree.path)
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
