# Godot Parallax2D 参考

这些目录只保存用于实现研究的开源代码，不会作为游戏插件启用，也没有使用其中的美术素材。

- [Godot demo projects / 2d/platformer/level/background/parallax_background.tscn](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer/level/background)，MIT，官方 Parallax2D 场景示例。
- [KoBeWi/Godot-Parallax2D-Preview](https://github.com/KoBeWi/Godot-Parallax2D-Preview)，MIT，用于检查 Parallax2D 滚动效果的编辑器预览插件。
- [nklbdev/godot-4-previewing-parallax-background](https://github.com/nklbdev/godot-4-previewing-parallax-background)，MIT，Godot 4 Parallax2D 预览示例。

本项目实际营地使用 Godot 内置 `Parallax2D`，滚动倍率为天空 `0.05`、山脊 `0.45`、地面 `1.0`。第三方目录使用 `.gdignore` 隔离，避免研究插件注册全局类。
