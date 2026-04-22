vim.api.nvim_create_user_command("Session", function(opts)
	local api = require("session.api")
	local subcmd = opts.fargs[1]
	table.remove(opts.fargs, 1)

	local cmds = {
		default = api.list,
		d = api.try_delete,
		delete = api.try_delete,
		l = api.list,
		list = api.list,
		s = api.save,
		save = api.save,
		c = api.select,
		choose = api.select,
		x = api.try_source,
		source = api.try_source,
	}

	local cmd = subcmd ~= nil and cmds[subcmd] or cmds.default
	cmd(unpack(opts.fargs))
end, { nargs = "*" })
