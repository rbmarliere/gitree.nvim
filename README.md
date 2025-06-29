# telescope-gitree.nvim

This is a simple extension to list, select, add, remove and move
[git-worktrees], inspired by [git-worktree.nvim].

[git-worktrees]: https://git-scm.com/docs/git-worktree
[git-worktree.nvim]: https://github.com/ThePrimeagen/git-worktree.nvim

### Installation (lazy.nvim)

```lua
return {
	"https://git.marliere.net/rbm/telescope-gitree.nvim",
	dependencies = {
		"nvim-telescope/telescope.nvim",
		"nvim-lua/plenary.nvim",
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
					log_level = "info",
					on_select = function()
					end,
					on_add = function()
						vim.system({ "git", "submodule", "update", "--init", "--recursive" }):wait()
					end,
				},
			},
		})
	end,
}
```

### Usage

After opening the list() picker, use the default action key maps:

`<CR>` -> select a worktree

`<m-a>` -> add a worktree

`<m-r>` -> remove the worktree under the cursor

`<m-m>` -> move the worktree under the cursor
