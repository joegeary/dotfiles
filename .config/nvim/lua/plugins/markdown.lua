return {
  -- {
  --   "preservim/vim-markdown",
  --   dependencies = {
  --     "godlygeek/tabular",
  --   },
  --   ft = { "markdown" },
  -- },
  --
  -- Markdown previewing - change key binding
  {
    "iamcco/markdown-preview.nvim",
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown preview" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>m", group = "markdown", icon = { name = "markdown", cat = "filetype" } },
      },
    },
  },
}
