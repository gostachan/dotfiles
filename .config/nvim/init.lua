require("config.lazy")
require("config.keymap")

vim.opt.ttimeoutlen = 0
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.number = true
vim.g.neovide_input_use_logo = true
vim.opt.ignorecase = true  -- 通常は大文字小文字を無視
vim.opt.smartcase  = true  -- 大文字を含むときのみ区別
vim.opt.wrap = false
vim.opt.autoread = true

vim.api.nvim_create_autocmd(
  { "FocusGained", "BufEnter", "CursorHold" },
  { command = "checktime" }
)

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end,
})

vim.keymap.set('n', '<C-z>', '<Nop>', { noremap = true, silent = true })
vim.keymap.set('i', '<C-z>', '<Nop>', { noremap = true, silent = true })
vim.keymap.set('v', '<C-z>', '<Nop>', { noremap = true, silent = true })

-- 永続 undo を有効化
vim.opt.undofile = true
local undo_dir = "/tmp/nvim-undo"
vim.opt.undodir = undo_dir
if vim.fn.isdirectory(undo_dir) == 0 then
  vim.fn.mkdir(undo_dir, "p")
end


