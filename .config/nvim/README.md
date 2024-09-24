<!-- markdownlint-disable MD033 MD013 -->

# NeoVim Config

NeoVim configuration for Linux, MacOS, and Windows. Based off of [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to add any additional customizations.

## Install and Setup

Clone the repository to your nvim config directory (on \*nix this is `~/.config/nvim`)

## Plugins

- Colorschemes via [catppuccin](https://github.com/catppuccin/nvim).
- Markdown writing and previewing via [vim-markdown](https://github.com/preservim/vim-markdown) and [markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim).
- LSP and debugging support for:
  - Dotnet/C# via [omnisharp-roslyn](https://github.com/OmniSharp/omnisharp-roslyn) and [netcoredbg](https://github.com/Samsung/netcoredbg)
  - Typescript/JavaScript via [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server)

## Keymaps

Using the built-in keymaps from [LazyVim](https://www.lazyvim.org/keymaps) with noted exceptions below.

`<leader>` is set to a single space. Pressing the leader key with a delay will show a browsable shortcut menu.

### General

| Shortcut    | Mode   | Description            |
| ----------- | ------ | ---------------------- |
| \<leader>jk | Insert | Escapes to normal mode |
| \<C-a>      | Normal | Select all             |

### Searching

| Shortcut    | Mode   | Description                  |
| ----------- | ------ | ---------------------------- |
| \<leader>fr | Normal | Fuzzy find recent files      |
| \<leader>fs | Normal | Fuzzy find text              |
| \<leader>fc | Normal | Fuzzy find text under cursor |

### Markdown (.md files only)

| Shortcut    | Mode   | Description                                    |
| ----------- | ------ | ---------------------------------------------- |
| \<leader>mp | Normal | Opens a preview of current file in the browser |

## Debugging

All of the debugging shortcuts can be found under the `<leader>d` menu. To start a debugging session, use `<leader>da`. You will be prompted to

### Dotnet

To start a debugging session, use `<leader>da`. You will be prompted to

### JS/TS

## Acknowledgements

- <https://github.com/ChristianChiarulli/nvim/>
- <https://github.com/nikolovlazar/dotfiles/tree/main/.config/nvim>
- <https://github.com/NicholasMata/nvim-dap-cs>
- <https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/>
