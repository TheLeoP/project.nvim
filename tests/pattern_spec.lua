local project = require("project_nvim.project")
local config = require("project_nvim.config")
local project_nvim = require("project_nvim")

describe("pattern_spec", function()
  it("Find project root with default patterns", function()
    config.options = {}
    project_nvim.setup()

    local root = project.find_pattern_root()
    local expected = vim.loop.cwd()
    assert.equals(expected, root)
  end)
  it("Find project root, stop on root directory", function()
    config.options = {}
    project_nvim.setup({ patterns = {} })

    local root = project.find_pattern_root()
    assert.is_nil(root)
  end)
end)
