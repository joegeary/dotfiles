return {
  "m4xshen/hardtime.nvim",
  dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
  event = "LazyFile",
  keys = {
    { "<leader>uH", "<cmd>Hardtime toggle<cr>", desc = "Toggle Hardtime" },
  },
  opts = {
    "lazy",
    "mason",
    "oil",
  },
}
