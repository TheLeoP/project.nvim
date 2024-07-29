local path = require("project_nvim.utils.path")
local uv = vim.loop
local M = {}

---@type string[]
M.recent_projects = nil -- projects from previous neovim sessions
M.session_projects = {} -- projects from current neovim session
M.has_watch_setup = false

---@param mode string
---@param callback? function
local function open_history(mode, callback)
  if callback ~= nil then -- async
    path.create_scaffolding(function(_, _) uv.fs_open(path.historyfile, mode, 438, callback) end)
  else -- sync
    path.create_scaffolding()
    return uv.fs_open(path.historyfile, mode, 438)
  end
end

---@param dir string
---@return boolean
local function dir_exists(dir)
  local stat = uv.fs_stat(dir)
  if stat ~= nil and stat.type == "directory" then return true end
  return false
end

---@param tbl string[]
---@return string[]
local function delete_duplicates(tbl)
  ---@type table<string, boolean>
  local cache = {}
  ---@type string[]
  local output = {}

  for _, v in ipairs(tbl) do
    local normalised_path = path.normalize(v)
    if not cache[normalised_path] then
      cache[normalised_path] = true
      table.insert(output, normalised_path)
    end
  end

  return output
end

---@param project string
function M.delete_project(project)
  for k, v in ipairs(M.recent_projects) do
    if v == project then M.recent_projects[k] = nil end
  end
end

---@param history_data string|nil
local function deserialize_history(history_data)
  if not history_data then return end

  ---@type string[]
  local projects = {}
  for s in history_data:gmatch("[^\r\n]+") do
    if not path.is_excluded(s) and dir_exists(s) then table.insert(projects, s) end
  end

  projects = delete_duplicates(projects)

  M.recent_projects = projects
end

local function setup_watch()
  -- Only runs once
  if M.has_watch_setup then return end

  M.has_watch_setup = true
  local event = uv.new_fs_event()
  if event == nil then return end
  event:start(path.projectpath, {}, function(err, _, events)
    if err ~= nil then return end
    if events["change"] then
      M.recent_projects = nil
      M.read_projects_from_history()
    end
  end)
end

function M.read_projects_from_history()
  open_history("r", function(_, fd)
    setup_watch()
    if fd ~= nil then
      uv.fs_fstat(fd, function(_, stat)
        if stat ~= nil then
          uv.fs_read(fd, stat.size, -1, function(_, data)
            uv.fs_close(fd, function(_, _) end)
            deserialize_history(data)
          end)
        end
      end)
    end
  end)
end

---@return string[]
local function sanitize_projects()
  local projects = {}
  if M.recent_projects ~= nil then
    vim.list_extend(projects, M.recent_projects)
    vim.list_extend(projects, M.session_projects)
  else
    projects = M.session_projects
  end

  projects = delete_duplicates(projects)

  local output = {}
  for _, dir in ipairs(projects) do
    if dir_exists(dir) then table.insert(output, dir) end
  end

  return output
end

function M.get_recent_projects() return sanitize_projects() end

function M.write_projects_to_history()
  -- Unlike read projects, write projects is synchronous
  -- because it runs when vim ends
  local mode = "w"
  if M.recent_projects == nil then mode = "a" end
  local file = open_history(mode)

  if file ~= nil then
    local output = sanitize_projects()

    -- Trim table to last 100 entries
    local len_res = #output
    ---@type string[]
    local tbl_out
    if #output > 100 then
      tbl_out = vim.list_slice(output, len_res - 100, len_res)
    else
      tbl_out = output
    end

    -- Transform table to string
    local out = ""
    for _, v in ipairs(tbl_out) do
      out = out .. v .. "\n"
    end

    -- Write string out to file and close
    uv.fs_write(file, out, -1)
    uv.fs_close(file)
  end
end

return M
