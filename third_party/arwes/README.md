# ARWES 边框来源

上游：[arwes/arwes](https://github.com/arwes/arwes)，下载分支 `next`。许可为 MIT，版权声明与全文保存在本目录 `LICENSE`。

本目录保留上游 `createFrameKranoxSettings.ts` 和 `createFrameNefrexSettings.ts`，用于追溯几何实现。项目的 `src/ui/arwes_frame.gd` 将主面板 Kranox 与按钮 Nefrex 的形状移植为 Godot 原生绘制，并调整颜色、填充透明度和装饰细节；导航轨道为本项目实现。

项目运行不依赖 React 或 ARWES 的网页运行时。没有下载或使用 ARWES 社区展示游戏的截图、背景或其他游戏美术资产。背景使用用户提供的车队视频，分类图标与滑杆手柄为本项目 SVG。
