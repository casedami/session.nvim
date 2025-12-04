vim.api.nvim_create_user_command("Session", function(opts)
	local api = require("session.api")
	local subcmd = opts.fargs[1]
	local args = table.remove(opts.fargs, 1)
	print(subcmd)
	print(args[1])

	local cmds = {
		default = api.list,
		delete = api.try_delete,
		list = api.list,
		save = api.save,
		select = api.select,
		source = api.try_source,
	}

	local cmd = subcmd ~= nil and cmds[subcmd] or cmds.default
	cmd(args)
end, { nargs = "*" })
