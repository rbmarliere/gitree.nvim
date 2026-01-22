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
	utils.input("New branch name", entry:gsub("^[^/]+/", ""), function(ans)
		for _, tree in ipairs(s.worktrees) do
			if tree.branch == ans then
				log.warn("Branch", ans, "already in use in", tree.path)
				s.new = {}
				return false
			end
		end
		s.new.branch = ans
		M.add()
	end)
end

M.add = function()
	if next(s.new) == nil then
		utils.confirm("Checkout a commit? (otherwise, an existing branch)", function(ans)
			if ans == "Yes" then
				utils.confirm("Checkout a specific tag?", function(ans)
					if ans == "Yes" then
						picker.git_tags()
					else
						picker.git_commits()
					end
				end)
			else
				utils.confirm("Checkout a remote branch?", function(ans)
					if ans == "Yes" then
						picker.git_remote_branches()
					else
						picker.git_local_branches()
					end
				end)
			end
		end)
		return
	end

	if s.new.branch == nil and not s.new.detached then
		utils.confirm("Create a new branch?", function(ans)
			if ans == "Yes" then
				utils.input("New branch name", "", function(ans)
					s.new.branch = ans
					M.add()
				end)
			else
				s.new.detached = true
				M.add()
			end
		end)
		return
	end

	if s.new.commit == nil and s.new.upstream == nil and not s.new.no_reset then
		utils.confirm("Checkout a commit?", function(ans)
			if ans == "Yes" then
				utils.confirm("Checkout a specific tag?", function(ans)
					if ans == "Yes" then
						picker.git_tags()
					else
						picker.git_commits()
					end
				end)
			else
				s.new.no_reset = true
				M.add()
			end
		end)
		return
	end

	if
		s.new.branch ~= nil
		and not s.new.remote
		and s.new.upstream == nil
		and not s.new.no_upstream
	then
		utils.confirm("Track an upstream?", function(ans)
			if ans == "Yes" then
				picker.git_all_branches()
			else
				s.new.no_upstream = true
				M.add()
			end
		end)
		return
	end

	if s.new.path == nil then
		local suffix = s.main_worktree_path:absolute() .. "/"
		if s.new.branch then
			suffix = string.format("%s%s", suffix, s.new.branch)
		end
		utils.input("Path to worktree", suffix, function(ans)
			if not utils.is_worktree_path_valid(ans) then
				s.new = {}
				return
			end
			s.new.path = Path:new(ans):absolute()
			M.add()
		end)
		return
	end

	log.info("Adding worktree...")
	git.add_worktree(s.new, function(ret, _, _)
		if ret == 0 then
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
	if tree.prunable then
		log.warn("Refusing to move prunable worktree")
		return
	end
	picker.close(opts)
	utils.input("New path to worktree", tree.path, function(new_path)
		if not utils.is_worktree_path_valid(new_path) then
			return
		end
		new_path = Path:new(new_path):absolute()
		log.info("Moving worktree...")
		if git.move_worktree(tree, new_path) then
			if tree.path == vim.uv.cwd() then
				utils.change_dir(new_path)
			end
			if tree.detached then
				log.info("Moved worktree")
			else
				utils.confirm(string.format("Moved worktree, rename branch %s?", tree.branch), function(ans)
					if ans == "Yes" then
						utils.input("New branch name", tree.branch, function(new_branch)
							if git.rename_branch(tree.branch, new_branch) then
								log.info("Renamed branch")
							end
						end)
					end
				end)
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
	utils.confirm(string.format("Remove worktree %s?", tree.path), function(ans)
		if ans == "Yes" then
			if tree.path == s.main_worktree_path:absolute() then
				log.warn("Refusing to remove main worktree")
				return
			end
			picker.close(opts)
			if tree.path == vim.uv.cwd() then
				utils.change_dir(s.main_worktree_path:absolute())
			end
			log.info("Removing worktree...")
			git.remove_worktree(tree.path, function()
				if tree.detached then
					log.info("Removed worktree")
				else
					utils.confirm(string.format("Removed worktree, delete branch %s?", tree.branch), function(ans)
						if ans == "Yes" then
							if git.delete_branch(tree.branch) then
								log.info("Deleted branch")
							end
						end
					end)
				end
			end)
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
	if tree.prunable then
		log.warn("Refusing to select prunable worktree")
		return
	end
	picker.close(opts)
	log.info("Selecting worktree...")
	utils.change_dir(tree.path)
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

M.select_file = function(opts)
	local tree = picker.current(opts)
	if tree == nil then
		log.warn("No worktree selected")
		return
	end
	if tree.path == vim.uv.cwd() then
		return
	end
	picker.close(opts)
	vim.cmd(string.format("vsplit %s/%s", tree.path, s.cur_file))
	s.cur_file = nil
end

return M
