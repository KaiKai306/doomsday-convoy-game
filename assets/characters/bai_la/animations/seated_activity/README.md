# 白蜡：坐姿动态

全程自然低头，颈部前屈、下巴收下，双眼始终看右手垫片及腿上交易袋。右手缓慢转动同一枚金属垫片检查正反面，靠近袋口比较，再回到初始手位；左手始终扶袋，袋中两枚垫片不动。头不抬起、不看前方或镜头，神态专注从容。

本地 ComfyUI / MiniMax H3 生成视频，sprite-gen 逐帧抠绿幕及检查首尾循环。123 帧，24 FPS，5.125 秒循环。所有预览为纯绿幕。

- `bai_la_seated_activity_green.gif`：绿幕 GIF 动作预览。
- `frames/`：331 × 600 RGBA 透明序列。
- `seated_activity.tres`：Godot 4 SpriteFrames，动画 `seated_activity`。
- `seated_activity.tscn`：可实例化的人物动画，原点为臀部座面接触点。椅子另放；替换人物时保持实例原点和整体缩放。座面至最近鞋底统一为 240 像素。
- `seated_reference_green.png`：原生高清绿幕静态底图。
- `动作提示词.txt` 与 `manifest.json`：动作要求、原稿依据、补充外观设计及处理记录。

保持目录位于 `res://assets/characters/bai_la/animations/seated_activity/`，即可加载 prefab 或将 SpriteFrames 指定给 AnimatedSprite2D。尚未修改正式场景。源视频、原生透明帧、ComfyUI 工作流与循环报告保存在 `.docs/美术/陆芷白蜡低头修正_20261016/bai_la/`。

剧情原稿未限定的年龄、外貌和性格细节属于本次美术设计。座面锚点是源图上的制作标注，并非用户手动验收参数；实际场景构图尚未验收。
