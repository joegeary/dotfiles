return {
  "nvimdev/dashboard-nvim",
  event = "VimEnter",
  opts = function(_, opts)
    local logo = [[
              	   ``                           
             	  ```                             
            `    ``                `            
             ``  _ `      `       ``            
            `   |_| `  `` ``    `  `            
           ``  -___-_` `   `` ``   ``           
         ``   /      )      ``      `           
        `____/| (0) (0)_()    ``     ``         
       /|   | |   ^____)      ``      ``        
       ||   |_|    \_//     Uɔ````   `` ``      
       ||    || |    |    ========`  ``  ``     
       ||    || |    |      ||     ``   `       
       ||     \\_\   |\     ||   ```    `       
       =========||====||    ||  ``       `      
         || ||   \Ɔ || \Ɔ   ||   ``    ``       
         || ||      ||      ||  `     ``        
         -------------------------------------  
        	         This is fine.                
      ]]

    logo = string.rep("\n", 8) .. logo .. "\n\n"

    opts.theme = "doom"
    opts.config.header = vim.split(logo, "\n")

    --opts.preview = {
    --  command = "sh",
    --  file_path = "/home/joe/.config/nvim/thisisfine.sh",
    --  file_height = 24,
    --  file_width = 45,
    --}
  end,
}
