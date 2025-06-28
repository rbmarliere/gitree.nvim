local M = {}

local config = require("gitree.config")
local log = require("gitree.log")

local telescope_actions = require("telescope.actions")
local telescope_action_state = require("telescope.actions.state")

M.move = function(prompt_bufnr)
end

M.remove = function(prompt_bufnr)
end

M.add = function(prompt_bufnr)
end

M.select = function(prompt_bufnr)
	telescope_actions.close(prompt_bufnr)
	local entry = telescope_action_state.get_selected_entry()
	if entry == nil then
		log.warn("No worktree selected")
		return
	end
	log.info("Selecting worktree...")
	vim.defer_fn(function()
		vim.cmd("cd " .. entry.ordinal)
		vim.cmd("clearjumps")
		if config.options.on_select and type(config.options.on_select) == "function" then
			config.options.on_select()
		end
		log.info("Changed directory to " .. entry.ordinal)
	end, 10)
end

return M
