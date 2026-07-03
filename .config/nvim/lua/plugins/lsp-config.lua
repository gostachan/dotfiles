return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    priority = 998,
    dependencies = {
      {
        "hrsh7th/nvim-cmp",
        dependencies = {
          "hrsh7th/cmp-buffer",
          "hrsh7th/cmp-nvim-lsp",
          "hrsh7th/cmp-path",
          "L3MON4D3/LuaSnip",
          "saadparwaiz1/cmp_luasnip",
        },
        config = function()
          local cmp = require("cmp")

          cmp.setup({
            mapping = cmp.mapping.preset.insert({
              ["<C-c>"]   = cmp.mapping.complete(),
              ["<CR>"]    = cmp.mapping.confirm({ select = true }),
              ["<Tab>"]   = cmp.mapping.select_next_item(),
              ["<S-Tab>"] = cmp.mapping.select_prev_item(),
            }),
            sources = cmp.config.sources({
              { name = "nvim_lsp" },
              { name = "buffer" },
              { name = "path" },
            }),
          })
        end,
      },
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      capabilities.general = {
        positionEncodings = { "utf-8" },
      }

      vim.diagnostic.config({
        virtual_text = true,
        severity_sort = true,
        update_in_insert = false,
        float = {
          border = "rounded",
          source = "if_many",
        },
      })

      local on_attach = function(_, bufnr)
        local opts = { noremap = true, silent = true, buffer = bufnr }

        vim.keymap.set("n", "gK", function()
          vim.lsp.buf.hover({ border = "rounded" })
        end, opts)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "cd", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      end

      local servers = {
        clangd = {},
        gopls = {},
        pyright = {},
        sqls = {},
        terraformls = {},
      }

      for server, settings in pairs(servers) do
        vim.lsp.config(server, vim.tbl_extend("force", {
          capabilities = capabilities,
          on_attach = on_attach,
        }, settings))
        vim.lsp.enable(server)
      end

      vim.o.updatetime = 100
      vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
          local diags = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
          if vim.tbl_isempty(diags) then
            return
          end

          local msg = table.concat(vim.tbl_map(function(d)
            return d.message
          end, diags), " | ")

          vim.api.nvim_echo({ { msg, "WarningMsg" } }, false, {})
        end,
      })
    end,
  },
}
