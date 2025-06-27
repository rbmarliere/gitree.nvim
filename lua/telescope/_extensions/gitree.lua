local config = require("gitree.config")

return require("telescope").register_extension({
	setup = config.setup,
	exports = {
		list = require("gitree.picker").list,
	},
})
