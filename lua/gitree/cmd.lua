local M = {}

local log = require("gitree.log")

local Job = require("plenary.job")

local create_job = function(cmd)
	local cmd_str = table.concat(cmd, " ")
	log.debug("creating job:", cmd_str)
	local command = cmd[1]
	table.remove(cmd, 1)
	return Job:new({
		command = command,
		args = cmd,
		cwd = vim.uv.cwd(),
		on_exit = function(j, ret)
			log.debug("exit code:", ret)
			log.debug("stdout:", vim.inspect(j:result()))
			log.debug("stderr:", vim.inspect(j:stderr_result()))
			if ret ~= 0 then
				log.error("`", cmd_str, "` exited with", ret)
			end
		end,
	})
end

M.run = function(cmd)
	local job = create_job(cmd)
	local stdout, ret = job:sync(20000)
	return ret, stdout
end

M.run_async = function(cmd, cb)
	local job = create_job(cmd)
	job:after(function(j, ret)
		cb(ret, j:result(), j:stderr_result())
	end):start()
end

return M
