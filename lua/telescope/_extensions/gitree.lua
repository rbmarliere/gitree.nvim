return require("telescope").register_extension({
	setup = require("gitree").setup,
	exports = {
		list = require("gitree.picker.telescope").list,
	},
})
