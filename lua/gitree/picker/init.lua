local config = require("gitree.config")

local get_backend = function()
	if config.options.backend == "telescope" then
		return require("gitree.picker.telescope")
	elseif config.options.backend == "snacks" then
		return require("gitree.picker.snacks")
	end
end

return setmetatable({}, {
	__index = function(_, k)
		return get_backend()[k]
	end,
})
