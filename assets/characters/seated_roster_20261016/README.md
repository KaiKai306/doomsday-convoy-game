# 其余七人坐姿动态

每人一个约 5.125 秒、24 FPS、123 帧的职业动作循环。绿幕 GIF 用于预览，透明 PNG 序列用于 Godot。所有动画已通过本地 ComfyUI 生成、sprite-gen 抠图与循环检查、Godot 4.7.2 资源加载检查。

![绿幕总览](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/seated_roster_20261016/seven_seated_activities_green.gif)

| 人物 | 动作 | 预览 | Godot |
| --- | --- | --- | --- |
| 陈川 | 检修电机 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/chen_chuan/animations/seated_activity/chen_chuan_seated_activity_green.gif) | [Godot 场景](../chen_chuan/animations/seated_activity/seated_activity.tscn) |
| 杜衡 | 查看路线 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/du_heng/animations/seated_activity/du_heng_seated_activity_green.gif) | [Godot 场景](../du_heng/animations/seated_activity/seated_activity.tscn) |
| 林悦 | 清点绑带 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/lin_yue/animations/seated_activity/lin_yue_seated_activity_green.gif) | [Godot 场景](../lin_yue/animations/seated_activity/seated_activity.tscn) |
| 岑柏 | 练习绳结 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/cen_bai/animations/seated_activity/cen_bai_seated_activity_green.gif) | [Godot 场景](../cen_bai/animations/seated_activity/seated_activity.tscn) |
| 许卫 | 抚平毯子 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/xu_wei/animations/seated_activity/xu_wei_seated_activity_green.gif) | [Godot 场景](../xu_wei/animations/seated_activity/seated_activity.tscn) |
| 陆芷 | 整理腕布 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/lu_zhi/animations/seated_activity/lu_zhi_seated_activity_green.gif) | [Godot 场景](../lu_zhi/animations/seated_activity/seated_activity.tscn) |
| 白蜡 | 检查交易品 | [绿幕 GIF](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/bai_la/animations/seated_activity/bai_la_seated_activity_green.gif) | [Godot 场景](../bai_la/animations/seated_activity/seated_activity.tscn) |

## 使用

保持资源原目录，实例化各人的 `seated_activity.tscn`。实例原点是臀部座面接触点，同一座位换人时保持原点和整体缩放；椅子、场景保持独立。座面至最近鞋底统一为 240 像素，人物动作使用固定画布，未逐帧自动居中。具体场景构图尚未调整或验收。

每人目录包含高清静态绿幕图、绿幕 GIF、透明 PNG 序列、SpriteFrames、可实例化场景、动作提示词和 manifest。原生视频、源图、工作流、生成记录及检查报告在 `.docs/美术/其余七人坐姿动画_20261016/`。

原稿未限定的年龄、外观与性格表现由本次美术设计补充，详细依据见 [七人动作提示词](七人动作提示词.md)。没有更改剧情文本或正式游戏场景。

## 低头修正版

陆芷与白蜡已重新生成静态参考图和完整视频，动作全程低头看手中物件；GIF、透明帧与 Godot 资源同步替换。修正源图、视频、提示词及逐帧检查在 `.docs/美术/陆芷白蜡低头修正_20261016/`。其余五人图片和动图保持原样。

![两人低头修正预览](../../../../../../临时文件/2026-10-16/convoy-cleanup/隔离归档/assets/characters/seated_roster_20261016/lu_zhi_bai_la_head_down_green.gif)
