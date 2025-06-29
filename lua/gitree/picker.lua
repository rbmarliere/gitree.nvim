local M = {}

local actions = require("gitree.actions")
local git = require("gitree.git")
local state = require("gitree.state")

local telescope_actions = require("telescope.actions")
local telescope_config = require('telescope.config')
local telescope_entry_display = require("telescope.pickers.entry_display")
local telescope_finders = require("telescope.finders")
local telescope_pickers = require("telescope.pickers")
local telescope_utils = require("telescope.utils")

local Path = require("plenary.path")

M.list = function(opts)
	opts = opts or {}
	state.worktrees = git.get_worktrees()
	if not state.worktrees then
		return
	end
	state.main_worktree_path = Path:new(state.worktrees[1].path)

	opts.path_display = function(_, path)
		if path == state.main_worktree_path:absolute() then
			return path
		end
		return string.format("%s", path:sub(#state.main_worktree_path:absolute() + 2))
	end

	local path_width = 0
	for _, tree in ipairs(state.worktrees) do
		if #tree.path > path_width then
			path_width = #tree.path + 4
		end
	end

	local displayer = telescope_entry_display.create({
		separator = " ",
		items = {
			{ width = path_width },
			{ width = 12 },
			{ remaining = true },
		},
	})

	local make_display = function(entry)
		local path = telescope_utils.transform_path(opts, entry.path)
		if entry.path == vim.loop.cwd() then
			path = string.format("[.] %s", path)
		end
		return displayer({
			{ path, "TelescopeResultsIdentifier" },
			{ entry.head },
			{ entry.label },
		})
	end

	telescope_pickers
		.new(opts, {
			prompt_title = "Git Worktrees",
			finder = telescope_finders.new_table({
				results = state.worktrees,
				entry_maker = function(entry)
					entry.value = entry.path
					entry.ordinal = entry.path
					entry.display = make_display
					return entry
				end,
			}),
			sorter = telescope_config.values.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				telescope_actions.select_default:replace(actions.select)
				map({ "i", "n" }, "<m-a>", actions.add)
				map({ "i", "n" }, "<m-r>", actions.remove)
				map({ "i", "n" }, "<m-m>", actions.move)
				return true
			end,
		})
		:find()
end

return M
