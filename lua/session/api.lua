local M = {}
vim.g.sessions_dir = vim.env.HOME .. "/.local/sessions"

local Notify = {}
Notify.unknown = function(id)
    vim.notify(string.format("Unknown session: '%s'", id), vim.log.levels.INFO)
end

Notify.saved = function(id)
    vim.notify(string.format("Saved session: '%s'", id), vim.log.levels.INFO)
end

Notify.deleted = function(id)
    vim.notify(string.format("Deleted session: '%s'", id), vim.log.levels.INFO)
end

Notify.deleted_count = function(n)
    vim.notify(string.format("Deleted %n sessions'", n), vim.log.levels.INFO)
end

Notify.none = function()
    vim.notify(
        "No sessions for current project/directory",
        vim.log.levels.INFO
    )
end

Notify.invalid = function(subcmd)
    vim.notify(
        string.format("Must specify argument for subcommand: %s", subcmd),
        vim.log.levels.INFO
    )
end

---Attempts to delete a session file/directory.
---
---Can be provided an optional scope to delete:
--- * id(name) => delete an id by name
--- * dir(prefix) => delete all sessions with a prefix in the session directory
--- * dir => delete session directory
--- * all => delete all session directories
---
---If no scope is given, then deletes the current session.
---
---## Examples
---
---`:Session delete id main` delete session with id 'main' in session directory
---`:Session delete prefix branch` delete all sessions with branch prefix in session directory
---`:Session delete prefix user` delete all sessions with user prefix in session directory
---`:Session delete dir` delete all sessions in session directory
---`:Session delete all` delete all sessions
---@param scope string?
---@param target string?
M.try_delete = function(scope, target)
    local Path = require("session.path")
    local valid = {
        id = target and string.format("%s/*-%s.vim", Path.context.dir, target)
            or false,
        dir = Path.context.dir,
        prefix = target and string.format(
            "%s/%s-*.vim",
            Path.context.dir,
            Path.prefixes[target]
        ) or false,
        all = vim.g.sessions_dir,
        default = Path.path(),
    }

    local to_delete = valid[scope]
    if to_delete == false then
        Notify.invalid(scope)
        return
    end
    to_delete = to_delete or valid.default
    local out = vim.system({ "rm", "-r", to_delete })
    if out.code == 0 then
        Notify.deleted(to_delete)
    else
        Notify.unknown(to_delete)
    end
end

---Prints out all sessions in the session directory, with an optional prefix
---filter.
---@param p string?
M.list = function(p)
    local Path = require("session.path")
    local prefix = Path.prefixes[p] or Path.prefixes.default
    Path.ids(prefix, function(ids)
        if #ids > 0 then
            print(table.concat(ids, "\n"))
        else
            Notify.none()
        end
    end)
end

---Creates a session with an optional user ID.
---
---If no ID is given, then tries to use the git branch as the ID. If the
---current directory is not in a git repository, then the global fallback ID is
---used.
---@param user_id string?
M.save = function(user_id)
    local Path = require("session.path")
    ---@type SessionPath
    local p = Path.path(user_id)
    vim.system({ "mkdir", "-p", vim.fs.dirname(p.full) }):wait()
    vim.cmd(string.format("mksession! %s", p.full))
    Notify.saved(p.id)
end

---Opens a selection window to choose a session to source.
---
---Note, if there is only one session available, then it is automatically
---sourced.
M.select = function()
    local Path = require("session.path")
    Path.ids(Path.prefixes.all, function(ids)
        if #ids == 1 then
            M.try_source(ids[1])
        else
            vim.ui.select(
                ids,
                { prompt = "Choose session:" },
                function(choice_id)
                    M.try_source(choice_id)
                end
            )
        end
    end)
end

---Attempts to source a session (if it exists) with an optional ID.
---@param id string?
M.try_source = function(id)
    local Path = require("session.path")

    local to_source
    if id ~= nil then
        local search_dir = Path.as_path(vim.g.sessions_dir, Path.context.hash)
        local pattern = string.format("*%s.vim", id)
        local matches = vim.fn.globpath(search_dir, pattern, false, true)

        if #matches > 0 then
            to_source = matches[1]
        else
            Notify.unknown(id)
            return
        end
    else
        to_source = Path.path().full
    end
    vim.cmd(string.format("source %s", to_source))
end

---Syncs the session directory with the git repository.
---
---If there are any sessions associated with branches that have intermittently
---been deleted, then those sessions are deleted.
M.sync = function()
    local branches =
        vim.fn.systemlist("git branch --format='%(refname:short)'")
    local live_branches = {}
    for _, b in ipairs(branches) do
        live_branches[b] = true
    end
    local Path = require("session.path")
    Path.ids(Path.prefixes.branch, function(ids)
        local deleted = 0
        for _, branch in ipairs(ids) do
            if not M.exclude_ids[branch] and live_branches[branch] == nil then
                M.try_delete(branch)
                deleted = deleted + 1
            end
        end
        Notify.deleted_count(deleted)
    end)
end

return M
