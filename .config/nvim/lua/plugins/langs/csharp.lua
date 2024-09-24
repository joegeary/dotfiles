return {
  -- disable csharpier formatter
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        cs = {},
      },
    },
  },
  -- setup netcoredbg debugger
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      local dap_utils = require("dap.utils")

      -- get the netcoredbg executable from the mason installation
      local mason = require("mason-registry")
      local pkg = mason.get_package("netcoredbg")
      local command = pkg:get_install_path() .. "/bin/netcoredbg"

      vim.g.dotnet_build_project = function()
        local default_path = vim.fn.getcwd() .. "/"
        if vim.g["dotnet_last_proj_path"] ~= nil then
          default_path = vim.g["dotnet_last_proj_path"]
        end

        local path = vim.fn.input("Path to your csproj file", default_path, "file")
        vim.g["dotnet_last_proj_path"] = path

        local cmd = "dotnet build -c Debug " .. path .. " > /dev/null"
        print("")
        print("Cmd to execute: " .. cmd)

        local f = os.execute(cmd)
        if f == 0 then
          print("\nBuild: ✔️ ")
        else
          print("\nBuild: ❌ (code: " .. f .. ")")
        end
      end

      local number_indices = function(array)
        local result = {}
        for i, value in ipairs(array) do
          result[i] = i .. ": " .. value
        end
        return result
      end

      local display_options = function(prompt_title, options)
        options = number_indices(options)
        table.insert(options, 1, prompt_title)

        local choice = vim.fn.inputlist(options)

        if choice > 0 then
          return options[choice + 1]
        else
          return ""
        end
      end

      local file_selection = function(cmd, opts)
        local results = vim.fn.systemlist(cmd)

        if #results == 0 then
          print(opts.empty_message)
          return ""
        end

        -- if opts.allow_multiple then
        --   return results
        -- end

        local result = results[1]
        if #results > 1 then
          result = display_options(opts.multiple_title_message, results)
        end

        return result
      end

      local project_selection = function(project_path, allow_multiple)
        local check_csproj_cmd = string.format('find %s -type f -name "*.csproj"', project_path)
        local project_file = file_selection(check_csproj_cmd, {
          empty_message = "No csproj files found in " .. project_path,
          multiple_title_message = "Select project:",
          allow_multiple = allow_multiple,
        })
        return project_file
      end

      local select_dll = function(project_path)
        local bin_path = project_path .. "/bin"
        local check_net_folders_cmd = string.format('find %s -type d -name "net*"', bin_path)
        local net_bin = file_selection(check_net_folders_cmd, {
          empty_message = 'No dotnet directories found in the "bin" directory. Please ensure the project has been built.',
          multiple_title_message = "Select .NET version:",
        })
        if net_bin == "" then
          return
        end

        local project_file = project_selection(project_path)
        if project_file == "" then
          return
        end
        local project_name = vim.fn.fnamemodify(project_file, ":t:r")

        local dll_path = net_bin .. "/" .. project_name .. ".dll"
        return dll_path
      end

      --- Attempts to pick a process smartly.
      ---
      --- Does the following:
      --- 1. Gets all project files
      --- 2. Build filter
      --- 2a. If a single project is found then will filter for processes ending with project name.
      --- 2b. If multiple projects found then will filter for processes ending with any of the project file names.
      --- 2c. If no project files found then will filter for processes starting with "dotnet"
      --- 3. If a single process matches then auto selects it. If multiple found then displays it user for selection.
      local smart_pick_process = function(project_path)
        local project_file = project_selection(project_path, true)
        if project_file == nil then
          return
        end

        local filter = function(proc)
          if type(project_file) == "table" then
            for _, file in pairs(project_file) do
              local project_name = vim.fn.fnamemodify(file, ":t:r")
              if vim.endswith(proc.name, project_name) then
                return true
              end
            end
            return false
          elseif type(project_file) == "string" then
            local project_name = vim.fn.fnamemodify(project_file, ":t:r")
            return vim.startswith(proc.name, project_name or "dotnet")
          end
        end

        local processes = dap_utils.get_processes()
        processes = vim.tbl_filter(filter, processes)

        if #processes == 0 then
          print("No dotnet processes could be found automatically. Try 'Attach' instead")
          return
        end

        if #processes > 1 then
          return dap_utils.pick_process({
            filter = filter,
          })
        end

        return processes[1].pid
      end

      dap.adapters.coreclr = {
        type = "executable",
        command = command,
        args = { "--interpreter=vscode" },
      }

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Launch",
          request = "launch",
          program = function()
            local cwd = vim.fn.getcwd()
            return select_dll(cwd) or dap.ABORT
          end,
        },
        {
          type = "coreclr",
          name = "Attach",
          request = "attach",
          processId = dap_utils.pick_process,
        },
        {
          type = "coreclr",
          name = "Attach (Smart)",
          request = "attach",
          processId = function()
            local cwd = vim.fn.getcwd()
            return smart_pick_process(cwd) or dap.ABORT
          end,
        },
        -- divider for any launch.json derived configs
        {
          name = "----- ↓ launch.json configs ↓ -----",
          type = "",
          request = "launch",
        },
      }
    end,
  },
}
