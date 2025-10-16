data:extend(
{
  {
    type = "custom-input",
    name = "toggle-player-auto-build",
    key_sequence = "SHIFT + C",
    consuming = "game-only"
  },
  {
    type = "shortcut",
    name = "toggle-player-auto-build",
    order = "c[toggles]-c[my-toggle]",
    action = "lua",
    localised_name = {"shortcut.toggle-player-auto-build"},
    toggleable = true,
    icons = {
        {
            icon = "__base__/graphics/icons/shortcut-toolbar/mip/toggle-personal-roboport-x56.png",
            icon_size = 56,
            scale = 0.5,
            flags = {"gui-icon"}
        }
    },
    small_icons = {
        {
            icon = "__base__/graphics/icons/shortcut-toolbar/mip/toggle-personal-roboport-x24.png",
            icon_size = 24,
            scale = 0.5,
            flags = {"gui-icon"}
        }
    },
    disabled_icons = {
        {
            icon = "__base__/graphics/icons/shortcut-toolbar/mip/toggle-personal-roboport-x56-white.png",
            priority = "extra-high-no-scale",
            icon_size = 56,
            scale = 0.5,
            flags = {"gui-icon"}
        }
    },
    disabled_small_icons = {
        {
            icon = "__base__/graphics/icons/shortcut-toolbar/mip/toggle-personal-roboport-x24-white.png",
            priority = "extra-high-no-scale",
            icon_size = 24,
            scale = 0.5,
            flags = {"gui-icon"}
        }
    }
  }
})