# 许宁：坐姿整理医疗包

来自用户提供的视频，选用 sprite-gen 验证通过的动作循环。绿幕 GIF 用于预览；透明 PNG 和 SpriteFrames 用于 Godot 4。

- 动画：123 帧，24 FPS，5.125 秒循环。
- 画布：340 × 640，每帧使用同一裁切框与缩放，人物和椅子分开。
- `xu_ning_seated_medical_bag_green.gif`：纯绿幕预览，RGB(0,255,0)，无限循环。
- `frames/`：RGBA 透明 PNG，保留柔和边缘，供游戏使用。
- `seated_medical_bag.tres`：Godot 4 SpriteFrames，动画名 `seated_medical_bag`。

## Godot 使用

把本目录保留在 `res://assets/characters/xu_ning/animations/seated_medical_bag/`。新增 AnimatedSprite2D，将 `seated_medical_bag.tres` 设为 Sprite Frames，播放 `seated_medical_bag`。GIF 留作动作预览，实际入景使用透明 PNG 动画。

尚未接入具体场景。坐高、位置和人物显示大小在实际入景时设置；不要逐帧自动居中，也不要把人物和椅子合并。每帧共享相同画布，因此场景中只需设置一次位置。源视频自身的细微身体移动保持原样。

源视频、原生尺寸抠图帧和循环检测报告存于 `.docs/美术/许宁整理医疗包动画_20261016/`，需要更高分辨率时可从原生帧重新导出。导出仅做了统一裁切、缩放、绿幕合成及 Godot 资源适配，没有手工补帧。
