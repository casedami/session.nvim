vim.g.session_id_fallback = "local"
local M = {
	Prefix = { user = "lo", branch = "br" },
}

---@alias LocalizedDir { is_repo: boolean, hash: string, dir: string }

---Returns the localized directory for the session.
---@return LocalizedDir
local function session_dir()
	local repo = vim.fs.root(0, ".git")
	local is_repo = repo ~= nil and true or false
	local dir = repo or vim.fn.getcwd()
	local hash = vim.fn.sha256(dir):sub(1, 8)
	return { is_repo = is_repo, hash = hash, dir = dir }
end

---@type LocalizedDir
M.locdir = session_dir()

---Formats parameters as a '/' separated string.
---@param ... any
---@return string
local function as_path(...)
	return table.concat({ ... }, "/")
end

---Returns the git branch, if available.
---Note: assumes git command won't fail.
---@return string?
local git_branch = function()
	local out = vim.system({ "git", "branch", "--show-current" }, { text = true }):wait()
	if out.code ~= 0 then
		return nil
	end

	local branch = vim.trim(out.stdout):gsub("/", "_")
	return #branch > 0 and branch or nil
end

---Builds and returns the session name.
---
---The session name has two components:
--- * The session prefix
--- * The session ID
---
---The prefix is 'lo' if a user ID is provided or the fallback ID is used,
---otherwise the prefix is 'br' if the git branch is used.
---
---The session ID is determined by priority:
--- 1. User provided ID
--- 2. Git branch
--- 3. Fallback ID
---@param user_id string?
---@return string
local function session_fname(user_id)
	local prefix = user_id and M.Prefix.user or M.locdir.is_repo and M.Prefix.branch or M.Prefix.user
	local id = user_id or (M.locdir.is_repo and git_branch() or nil) or vim.g.session_id_fallback
	return string.format("%s-%s.vim", prefix, id)
end

---Builds and returns the full session path.
---
---The session path has three components:
--- * The global session directory
--- * The localized hash
--- * The session name
---
---The localized hash is determined by the following priority:
--- 1. Git project root
--- 2. Current working directory (vim)
---@param user_id string?
---@return string
M.path = function(user_id)
	local session = session_fname(user_id)
	return as_path(vim.g.sessions_dir, M.locdir.hash, session)
end

---Returns all the session IDs in the session directory with a given prefix.
---
---If any matching IDs are found, the `on_ids` callback is invoked.
---@param prefix string
---@param on_ids fun(ids: table): nil
M.ids = function(prefix, on_ids)
	local pattern = string.format("%s-*.vim", prefix)
	local sessions = vim.fn.globpath(as_path(vim.g.sessions_dir, M.locdir.hash), pattern, false, true)

	if #sessions == 0 then
		vim.notify(string.format("No sessions found for directory: '%s'", M.locdir.dir), vim.log.levels.INFO)
		return
	end

	local ids = {}
	for _, s in ipairs(sessions) do
		ids[#ids + 1] = s:match("%-(.+)%.vim")
	end
	table.sort(ids)
	on_ids(ids)
end

return M
