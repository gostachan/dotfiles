return {
  -- UI Select (for nicer vim.ui.select)
  {
    "nvim-telescope/telescope-ui-select.nvim",
  },

  -- Telescope core
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")
      local themes = require("telescope.themes")
      local builtin = require("telescope.builtin")
      local Job = require("plenary.job")

      -- Git 管理ファイル + .env に限定した live_grep ラッパ
	  local function live_grep_git_tracked_with_env()
        Job:new({
          command = "sh",
		  args = { "-c", [[
		    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		  	git ls-files -co --exclude-standard
		  	[ -f .env ] && echo .env
		    else
		  	[ -f .env ] && echo .env
		    fi
		  ]] },
          on_exit = function(j, _)
            local files = j:result() or {}
            if #files == 0 then
              vim.schedule(function()
                vim.notify("[telescope] no git-tracked files (and no .env).", vim.log.levels.WARN)
              end)
              return
            end
            vim.schedule(function()
              require("telescope.builtin").live_grep({
                search_dirs = files, -- 対象を限定
              })
            end)
          end,
        }):start()
      end

      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          sorting_strategy = "ascending",
          layout_config = { prompt_position = "top" },
          preview = {
            treesitter = false,
          },

          -- ここは OFF。未トラッキングを出さないため Git に委ねる
          hidden = false,
          no_ignore = false,

          file_ignore_patterns = {
            "node_modules",
            ".ruff_cache",
            ".git/",
            ".mypy_cache",
          },
        },
        pickers = {
          -- Git でトラッキング済みのファイルのみ + 例外的に .env を含める
          find_files = {
			find_command = {
			  "sh", "-c",
			  [[
				if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
				  git ls-files -co --exclude-standard && [ -f .env ] && echo .env
				else
				  [ -f .env ] && echo .env
				fi
			  ]]
			},
            hidden = false,
            no_ignore = false,
            file_ignore_patterns = {
              "node_modules",
              ".ruff_cache",
              ".git/",
              ".mypy_cache",
            },
          },
          -- live_grep は上のラッパ関数で search_dirs を渡すのでここは最小限
          live_grep = {},
        },
        extensions = {
          ["ui-select"] = themes.get_dropdown({}),
        },
      })

      telescope.load_extension("ui-select")

      -- キーマップ
      -- Git 管理ファイル + .env だけ検索
      vim.keymap.set({ "n", "v" }, "<C-m>", builtin.find_files, { desc = "Find files (git-tracked + .env)" })
      -- Git 管理ファイル + .env だけを対象に grep
      vim.keymap.set({ "n", "v" }, "<C-g>", live_grep_git_tracked_with_env, { desc = "Live grep (git-tracked + .env)" })

      -- 全ファイル検索 (.gitignore / untracked も含む。.git/ のみ除外)
      vim.keymap.set({ "n", "v" }, "<C-S-m>", function()
        builtin.find_files({
          find_command = { "rg", "--files", "--hidden", "--no-ignore", "--glob", "!.git/" },
          hidden = true,
          no_ignore = true,
          file_ignore_patterns = { ".git/" },
        })
      end, { desc = "Find files (all, incl. ignored)" })
      -- 全ファイル対象 grep (.gitignore / untracked も含む)
      vim.keymap.set({ "n", "v" }, "<C-S-g>", function()
        builtin.live_grep({
          additional_args = function() return { "--hidden", "--no-ignore", "--glob", "!.git/" } end,
        })
      end, { desc = "Live grep (all, incl. ignored)" })

      -- LSP 定義ジャンプ（Telescope UI で重複も見やすい）
      vim.keymap.set("n", "gd", function()
        builtin.lsp_definitions({ reuse_win = true })
      end, { desc = "Go to definition (Telescope)" })

      vim.keymap.set({ "n", "v" }, "<C-b>", builtin.buffers, { desc = "Find buffer" })
    end,
  },
}
