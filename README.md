# yamlmatter.nvim
Enhancing the display of YAML front matter in Markdown files

## WIP

Instead see this in markdown file

```markdown
---
title: algebra
author: ray
date: 2024-05-05
id: 1714834956
tags:
  - algebra
  - math
category: note
type: post
---
```

You see this:

```markdown
 title       algebra
 author      ray
 date        2024-05-05
 id          1714834956
 tags        { 'algebra', 'math' }
 category    note
 type        post
```

![image](https://github.com/ray-x/files/blob/master/img/others/frontmatter.jpg)

## Prerequisites

- Neovim 0.9+
- nvim-treesitter for markdown and yaml
- A patched font with Nerd Font glyphs

## Configuration

```lua
require('yamlmatter').setup({
  icon_mappings = {
    title = '',
    idea = '',
    default = '󰦨',
  },
  highlight_groups = {
    icon = 'MyIconHighlight',
    key = 'MyKeyHighlight',
    value = 'MyValueHighlight',
  },
  key_value_padding = 4, -- Less space
  conceallevel = 1, -- on what level start conceal the yaml text

})
```

## Commands

By default if plugin setup, you can use `:YamlMatter` to toggle the display of YAML front matter and use
`:YamlMatterDisable` to disable it.

## License

This plugin is licensed under the MIT License.

