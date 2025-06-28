local M = {}

local log = require("gitree.log")

local job = require("plenary.job")

local cmd = function(cmd, ...)
	local args = { ... }
	if #args == 1 and type(args[1]) == "table" then
		args = args[1]
	end
	log.debug("running:", cmd, ...)
	local stderr = {}
	local stdout, ret = job:new({
		command = cmd,
		args = args,
		cwd = vim.loop.cwd(),
		on_stderr = function(_, data)
			table.insert(stderr, data)
		end,
		on_exit = function(j, ret)
			log.debug("exit code:", ret)
			log.debug("stdout:", vim.inspect(j:result()))
			log.debug("stderr:", vim.inspect(j:stderr_result()))
			if ret ~= 0 then
				log.error("`", cmd, args, "` exited with", ret)
			end
		end,
	}):sync(20000)
	return ret, stdout, stderr
end

M.git = function(...)
	return cmd("git", ...)
end

return M
