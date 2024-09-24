return {
  {
    "arnarg/todotxt.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    opts = function(_, opts)
      opts.todo_file = "~/.todo/todo.txt"
    end,
    keys = {
      { "<leader>Tt", "<cmd>ToDoTxtTasksToggle<CR>", desc = "Open Todo Task List" },
      { "<leader>Ta", "<cmd>ToDoTxtCapture<CR>", desc = "Add Todo Task" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>T", group = "todo", icon = "" },
      },
    },
  },
}
