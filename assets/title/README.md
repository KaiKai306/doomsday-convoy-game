# 标题页素材

原版标题视频来自用户提供的 `末日车队_标题页_成片_1920x1080.mp4`，作为素材留档。

- `convoy_title.ogv`：Godot 原生支持的 Ogg Theora，1920×1080、30 fps、5.033 秒，无音轨。
- `convoy_title.png`：从原视频提取的首帧，启动和关闭动态封面时使用。
- 当前主菜单位于 `src/ui/main_menu.gd`，已改用 `assets/settings/settings_background.ogv` 和静态首帧，标题 / 菜单独立绘制，避免原视频内嵌文字与新 UI 重叠。仍以 1280×720 为设计画布。
- `icon_journey.svg`、`icon_archive.svg`、`icon_exit.svg`：本项目绘制的菜单图标；设置入口共用设置页图标。

转码使用本机 DataTool 附带的 FFmpeg 2025-04-14 构建：

```powershell
& 'C:\Users\t6275\AppData\Local\Programs\DataTool\resources\extraResources\ffmpeg.exe' -i '<原始视频路径>' -an -c:v libtheora -q:v 8 -pix_fmt yuv420p 'assets/title/convoy_title.ogv'
```

当前本机 FFmpeg 8.1.2 构建生成的 Theora 在 FFmpeg 解码及 Godot 实际渲染中均出现错误与彩色块；改用上述构建后完整解码正常，并通过首轮 / 循环播放截图验证。更换转码器时须检查完整视频解码和 Godot 实际画面。
