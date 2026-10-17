# 设置页背景与控件

源素材为用户提供的 `示界面/正式版.mp4`，不含主菜单标题与菜单字样。

- 原视频：7680×4316、120 fps、约五秒，带音轨。
- `settings_background.ogv`：转码到 1920×1080、30 fps 的 Ogg Theora。微量等比裁切适配 16:9，移除音轨，仅作动态背景。
- `settings_background.png`：静态首帧。
- `tactical_knob.svg`：当前使用的暖金色矩形刻槽滑杆手柄。
- `icon_sound.svg`、`icon_display.svg`、`icon_controls.svg`、`icon_general.svg`：分类图标。
- `slider_knob.svg`：第一版保留的滑杆手柄，当前设置页不再使用。

视频使用本机 DataTool 附带的 FFmpeg 2025-04-14 构建，以 `fps=30,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080` 滤镜和 `libtheora -q:v 7 -pix_fmt yuv420p` 转码，并检查完整解码与 Godot 实际画面。

设置页在 `src/ui/settings_screen.gd`。按用户选择的 A 方案，将 ARWES 的 Kranox / Nefrex 边框移植到 Godot 原生绘制，使用深蓝与暖金色配色。原始源码及 MIT 许可保存在 `third_party/arwes/`，移植代码为 `src/ui/arwes_frame.gd`。

面板默认不透明度为 42%，画面分类可调至 0%，只改变主面板填充，文字与边框保留。背景视频独立于面板，循环播放；关闭动态背景时使用静态首帧。

按钮使用 `src/ui/ui_feedback.gd` 提供下压、回弹和边框闪亮；页面与分类内容使用淡入 / 滑入。返回先淡出再关闭。点击音来自 `assets/audio/ui_tactical_click.wav`，由总音量、音效和全部静音实际控制，滑杆拖动结束时播放一次。

当前为可操作设计预览，各项值仅在内存中保存。动态背景、面板不透明度和 UI 点击音的音量设置已实际生效；音乐、环境音和游戏音效，以及其他渲染、触控和存档设置尚未接入系统。
