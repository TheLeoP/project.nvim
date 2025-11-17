local path = require("project_nvim.utils.path")
local uv = vim.uv
local M = {}

---@type string[]
local recent_projects = {}

---@param project string
function M.delete_project(project)
  for i, v in ipairs(recent_projects) do
    if v == project then
      table.remove(recent_projects, i)
      break
    end
  end
end

---@param project string
function M.add_project(project)
  if path.exists(project) and not path.is_excluded(project) and not vim.list_contains(recent_projects, project) then
    table.insert(recent_projects, project)
  end
end

local function toset()
  local already_seen = {} ---@type table<string, boolean>
  return
  ---@param paths string[]
  ---@param p string
  function(paths, p)
    if not already_seen[p] then
      already_seen[p] = true
      paths[#paths + 1] = p
    end
    return paths
  end
end

local is_reading = false
---@async
function M.read_projects_from_history()
  local co = coroutine.running()
  assert(co)

  if is_reading then return end
  is_reading = true

  uv.fs_stat(path.projectpath, function(err, stat) coroutine.resume(co, err, stat) end)
  local err, dir_stat = coroutine.yield() ---@type string|nil, uv.fs_stat.result|nil
  if err then return vim.notify(err, vim.log.levels.ERROR) end
  ---@cast dir_stat -nil

  if not dir_stat then
    uv.fs_mkdir(path.projectpath, 448, function(err2) coroutine.resume(co, err2) end)
    local err2 = coroutine.yield() ---@type string|nil
    if err2 then return vim.notify(err2, vim.log.levels.ERROR) end
  end

  uv.fs_open(path.historyfile, "r", 438, function(err3, fd) coroutine.resume(co, err3, fd) end)
  local err3, fd = coroutine.yield() ---@type string|nil, integer|nil
  if err3 then return vim.notify(err3, vim.log.levels.ERROR) end
  ---@cast fd -nil

  uv.fs_fstat(fd, function(err4, stat) coroutine.resume(co, err4, stat) end)
  local err4, fd_stat = coroutine.yield() ---@type string|nil, uv.fs_stat.result|nil
  if err4 then return vim.notify(err4, vim.log.levels.ERROR) end
  ---@cast fd_stat -nil

  uv.fs_read(fd, fd_stat.size, 0, function(err5, data) coroutine.resume(co, err5, data) end)
  local err5, data = coroutine.yield() ---@type string|nil, string|nil
  if err5 then return vim.notify(err5, vim.log.levels.ERROR) end
  ---@cast data -nil

  uv.fs_close(fd, function(err6) coroutine.resume(co, err6) end)
  local err6 = coroutine.yield() ---@type string|nil
  if err6 then return vim.notify(err6, vim.log.levels.ERROR) end

  local projects = vim
    .iter(vim.gsplit(data, "[\r\n]+", { trimempty = true }))
    :filter(function(p) return not path.is_excluded(p) and path.dir_exists(p) end)
    :map(path.normalize)
    :fold({}, toset())

  recent_projects = projects
  is_reading = false
end

function M.get_recent_projects() return recent_projects end

function M.write_projects_to_history()
  local dir_stat, err = uv.fs_stat(path.projectpath)
  if err then return vim.notify(err, vim.log.levels.ERROR) end
  if not dir_stat then
    local _, err2 = uv.fs_mkdir(path.projectpath, 448)
    if err2 then return vim.notify(err2, vim.log.levels.ERROR) end
  end

  if not recent_projects then return end

  ---@type {[string]: uv.fs_stat.result}
  local project_stats = vim
    .iter(recent_projects)
    :map(
      ---@param project string
      function(project) return project, uv.fs_stat(project) end
    )
    :fold(
      {},
      ---@param acc {[string]: uv.fs_stat.result}
      function(acc, project, stat)
        acc[project] = stat
        return acc
      end
    )
  -- TODO: maybe order when adding a new project instead
  table.sort(recent_projects, function(a, b)
    local a_stat = project_stats[a]
    local b_stat = project_stats[b]

    return a_stat.mtime.sec < b_stat.mtime.sec
  end)
  local out = table.concat(recent_projects, "\n")

  local file, err5 = uv.fs_open(path.historyfile, "w", 438)
  if err5 then return vim.notify(err5, vim.log.levels.ERROR) end
  ---@cast file -nil
  local _, err3 = uv.fs_write(file, out, -1)
  if err3 then return vim.notify(err3, vim.log.levels.ERROR) end
  local _, err4 = uv.fs_close(file)
  if err4 then return vim.notify(err4, vim.log.levels.ERROR) end
end

local has_started = false
function M.start_history_watcher()
  if has_started then return end
  has_started = true

  local watcher = uv.new_fs_event()
  if not watcher then return end
  watcher:start(path.projectpath, {}, function(err, file, events)
    if err then return vim.notify(err, vim.log.levels.ERROR) end
    if not events.change or file ~= "project_history" then return end

    coroutine.wrap(function() M.read_projects_from_history() end)()
  end)
end

return M
