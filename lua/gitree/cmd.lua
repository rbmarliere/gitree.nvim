local M = {}

local log = require("gitree.log")

local Job = require("plenary.job")

local log_job_exit = function(cmd_str, j, ret)
	log.debug("exit code:", ret)
	log.debug("stdout:", vim.inspect(j:result()))
	log.debug("stderr:", vim.inspect(j:stderr_result()))
	if ret ~= 0 then
		log.error("`", cmd_str, "` exited with", ret)
	end
end

local safe_log_job_exit = function(cmd_str, j, ret)
	local ok, err = pcall(log_job_exit, cmd_str, j, ret)
	if not ok then
		pcall(vim.api.nvim_err_writeln, string.format("[gitree] Unable to log job exit for `%s`: %s", cmd_str, err))
	end
end

local create_job = function(cmd)
	local cmd_str = table.concat(cmd, " ")
	log.debug("creating job:", cmd_str)
	return Job:new({
		command = cmd[1],
		args = { unpack(cmd, 2) },
		cwd = vim.uv.cwd(),
		on_exit = function(j, ret)
			vim.schedule(function()
				safe_log_job_exit(cmd_str, j, ret)
			end)
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
	job:after(vim.schedule_wrap(function(j, ret)
		cb(ret, j:result(), j:stderr_result())
	end)):start()
end

return M
