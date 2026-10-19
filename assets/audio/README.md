# 界面音效与主页面音乐

## 0.7.0场景音乐

`data/music_catalog.json`现管理29首曲目，含原有主菜单曲及28首新增音乐。新曲来自提供的最新版工程；`src/audio/music_director.gd`负责场景切换、音量、静音和循环交接。码率高于110kbps的新增曲目采用Vorbis质量1、44.1kHz重新编码，声道数保持，逐首时长差异不超过30毫秒。高码率原件留在提供的工程中，仓库保存实际运行的优化版。

下文保留原有主菜单曲与程序合成音效的制作记录。

`music_mainmenu_loop.ogg` 来自用户提供的 `C:/Users/t6275/Desktop/music_mainmenu_loop.wav`（原长228.85秒、48 kHz、16 bit、立体声）。准确移除前240000帧，即前5秒，裁剪后223.85秒。无损裁剪副本保存于 `.docs/音频/主页面BGM_20261016/music_mainmenu_loop_trimmed.wav`，原始文件保留。

游戏版本使用 Ogg Vorbis quality 5，大小约3.08 MB。原音频综合响度约-34.4 LUFS，游戏版本固定增益12 dB，并对两端各做20毫秒淡入淡出以抑制循环接点的突变；不改变音频长度。主菜单循环播放，进入设置时继续，进入游戏时0.2秒淡出停止，回到主页时0.5秒淡入。总音量、背景音乐、全部静音及恢复默认即时生效；设置数值目前仍按项目现有方式仅保留于本次运行。

裁剪使用 Python `wave` 按采样帧复制。游戏版本转换命令：

```text
ffmpeg -i music_mainmenu_loop_trimmed.wav -af "volume=12dB,afade=t=in:st=0:d=0.02,afade=t=out:st=223.83:d=0.02" -c:a libvorbis -q:a 5 music_mainmenu_loop.ogg
```

`ui_tactical_click.wav` 为本项目程序合成的 115 毫秒点击音：低频短击、快速衰减的双频金属声与少量滤波噪声。PCM 16 bit、单声道、44.1 kHz，没有外部录音或第三方音效素材。

主菜单、设置页及退出确认共用 `src/ui/ui_feedback.gd`。按下立即播放，四个声音通道支持快速连续操作。实际播放增益为总音量 × 音效音量，再降低 7 dB；全部静音或任一音量为 0 时不播放。滑杆拖动结束后播放一次，避免连续噪声。
