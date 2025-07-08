# gitree.nvim

This is a simple extension to list, select, add, remove and move
[git-worktrees], inspired by [git-worktree.nvim].

[git-worktrees]: https://git-scm.com/docs/git-worktree
[git-worktree.nvim]: https://github.com/ThePrimeagen/git-worktree.nvim

### Default Configuration

```lua
{
	log_level = "info",
	backend = "telescope",
	on_select = nil,
	on_add = nil,
}
```

### Installation for Telescope (lazy.nvim)

```lua
return {
	"https://git.marliere.net/rbm/gitree.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope.nvim", branch = "0.1.x" },
	},
	keys = {
		{
			"<Leader>gw",
			function()
				require("telescope").extensions.gitree.list()
			end,
		},
	},
	init = function()
		require("telescope").setup({
			extensions = {
				gitree = {
					on_add = function()
						vim.system({ "git", "submodule", "update", "--init", "--recursive" }):wait()
					end,
				},
			},
		})
		require("telescope").load_extension("gitree")
	end,
}
```

### Installation for Snacks (lazy.nvim)

```lua
return {
	"https://git.marliere.net/rbm/gitree.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"folke/snacks.nvim",
	},
	keys = {
		{
			"<Leader>gw",
			function()
				require("gitree.picker.snacks").list()
			end,
		},
	},
	opts = {
		backend = "snacks",
		on_add = function()
			vim.system({ "git", "submodule", "update", "--init", "--recursive" }):wait()
		end,
	}
}
```

### Usage

After opening the list() picker, use the default action key maps:

`<CR>` -> Select a worktree

`<M-a>` -> Add a worktree

`<M-r>` -> Remove the worktree under the cursor

`<M-m>` -> Move the worktree under the cursor

`<M-g>` -> Grep in the worktree under the cursor

`<M-p>` -> Find files in the worktree under the cursor
