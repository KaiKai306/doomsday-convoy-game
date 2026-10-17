# 主角移动与站立

使用2026年10月14日已确认的右行v1和B版站姿。右行42帧、24 FPS、1.75秒循环；左行在运行时镜像同一动画，沿用已确认的镜像方案。站立左右各一张静态图，不含呼吸动画。

素材与原始来源校验值见 manifest.json。tools/install_captain_animation.py 可从相邻项目 approved 目录重新安装；游戏运行不依赖外部目录。

src/game/camp_walk.gd 在所有地点的正式行走页面使用 AnimatedSprite2D：实际位移驱动行走，停止保留朝向，抵达点击目标、到达边界或失去窗口焦点后站立。统一483像素画布，底部为脚底锚点；显示高度96像素。角色位置使用现有场景地面与中景坐标变换。

验证：tests/run_captain_animation.gd 图形模式13项通过，检查实际播放推进、左右切换、站姿、点击移动、边界停止和镜头移动后脚底对齐；tests/run_location_integration.gd 的12处地点129项通过。实际运行截图位于 .godot/captain-qa/。
