# Changelog

## 1.0.0 (2024-07-29)


### ⚠ BREAKING CHANGES

* refactor
* Bring up minimal version to Neovim 0.8
* initial rewrite dropping old apis and vimscript

### Features

* Allow projects to be removed from the list ([#34](https://github.com/TheLeoP/project.nvim/issues/34)) ([b374afa](https://github.com/TheLeoP/project.nvim/commit/b374afa0f3d3382e2d89bc325ec7f51d2d74c341))
* custom callback on_project_selection ([95907bb](https://github.com/TheLeoP/project.nvim/commit/95907bbaf1de5fce03dbd54fae2ff1cf9fa9d31e))
* **lsp-root:** take into account workspaces when finding root ([a1cae80](https://github.com/TheLeoP/project.nvim/commit/a1cae80941c7d3b751948a2d1b9a25be7d09a0f9))
* **project:** adds config setting for the scope of the directory change ([eb2f690](https://github.com/TheLeoP/project.nvim/commit/eb2f6907e5e90f097c7dbb26991eca4dd102ea95))


### Bug Fixes

* 26: finding project root directory does not work on windows ([#27](https://github.com/TheLeoP/project.nvim/issues/27)) ([79c0cf2](https://github.com/TheLeoP/project.nvim/commit/79c0cf2e842b592736756817eb4609e2d20565b5))
* Attempt to normalise paths for Windows ([#37](https://github.com/TheLeoP/project.nvim/issues/37)) ([1a6843a](https://github.com/TheLeoP/project.nvim/commit/1a6843aeda8f0fe3d8086350cc3b8fe45e2591bb))
* file_browser action ([713ed64](https://github.com/TheLeoP/project.nvim/commit/713ed644b546fcdd9882ed141864a80b2e93c53b))
* Ignore invalid file paths ([e366fce](https://github.com/TheLeoP/project.nvim/commit/e366fcede23e265b682f38977aaec3dd2b40d42d))
* incorrectly premature return in on_buf_enter ([cb5641f](https://github.com/TheLeoP/project.nvim/commit/cb5641f2869664e41837c8bd31e56beb88ebdbc9))
* Lowercase first character on Windows ([#38](https://github.com/TheLeoP/project.nvim/issues/38)) ([3a1f75b](https://github.com/TheLeoP/project.nvim/commit/3a1f75b18f214064515ffba48d1eb7403364cc6a))
* **lsp-root:** Don't match paths similar to cwd ([e0479e3](https://github.com/TheLeoP/project.nvim/commit/e0479e3aeae97aba552e36c32f18764c1c2e8ec0))
* move init to setup ([dcab508](https://github.com/TheLeoP/project.nvim/commit/dcab50809f9057a2398767dfe2ed3a36f4742ea9))
* require('telescope.actions').get_selected_entry() is deprecated ([#33](https://github.com/TheLeoP/project.nvim/issues/33)) ([c845128](https://github.com/TheLeoP/project.nvim/commit/c8451285b5038bf3ed7efbc27efa443fbf14211e))
* **typo:** {} -&gt; config.options.ignore_lsp ([11f6de6](https://github.com/TheLeoP/project.nvim/commit/11f6de6a6d3d273f792c064f0b6db50b55d45d47))
* use uppercase drive name for paths on windows ([07c4ab5](https://github.com/TheLeoP/project.nvim/commit/07c4ab5cf621bcaba0979d62e27ece34034c8496))
* **win:** normalize paths case-insensitive ([c21d8b1](https://github.com/TheLeoP/project.nvim/commit/c21d8b1b0c4b39759afd5ff5c17f68a800abe2bf))
* wrong root check on Windows ([b832c84](https://github.com/TheLeoP/project.nvim/commit/b832c843aae2b29bd9f2fb9651cea0d380d08832))


### Miscellaneous Chores

* Bring up minimal version to Neovim 0.8 ([bbfac21](https://github.com/TheLeoP/project.nvim/commit/bbfac21435efa5eefd9b4071102332c69e9903d2))
* initial rewrite dropping old apis and vimscript ([723b251](https://github.com/TheLeoP/project.nvim/commit/723b251f78f47f933802a938ef3d5b71677140df))
* refactor ([3fa3f19](https://github.com/TheLeoP/project.nvim/commit/3fa3f197277528ae9fef75c2d6bf9fe147611e65))
