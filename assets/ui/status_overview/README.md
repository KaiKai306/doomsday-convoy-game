# 状态总览素材

正式入口：每日游戏右上角“状态总览”，实现 `src/ui/status_overview.gd`。

参考为用户提供的 `02_新项目_末日车队/示界面/02_状态总览.jpg`。环境保留月夜、煤油灯、旧地图桌与磨损器物，三栏和交互内容由 Godot 绘制。

## 生成与处理

复用 Harness 既有 `gen_camp_21x9.mjs` 的后台 HTTP 图片编辑流程，真实 JPG 作为 multipart 附件提交，模型参数 `gpt-image-2.5-flare`，每类请求一张。未操控 Harness 桌面窗口，未通过 DeepSeek 聊天转发。本地凭据只从原有私有文件读取，不保存在项目中。

| 文件 | 实际原始尺寸 | 用途 |
| --- | --- | --- |
| background_source.png | 2048×1152 | 指挥室完整无字背景 |
| terrain_source.png | 1254×1254 | 无标记地图底图；请求尺寸为1024×1024，返回实际尺寸如左 |
| portraits_source.png | 2048×1152 | 五列两行图集，使用第一行五个身份头像 |

提示词与请求尺寸保存在 `generation_plan.json`，三份 `*_generation.json` 记录初版生成状态。`asset_sizes.json` 记录环境原图尺寸和当前正式头像尺寸。原始图片保留，环境和地图另输出 JPEG；初版五人头像按图集列裁切为 PNG，现已被下述独立头像替换。面板磨损纹理与图标由 `tools/prepare_status_art.py` 确定性生成，不包含预烘焙文字。

环境生成脚本为 `tools/generate_status_art.mjs`；已保存的图片或既有请求记录会阻止自动重复提交。预处理脚本可以独立重跑。

## 五人头像修订（2026-10-13）

初版图集的角色造型与用户提供的五张四视图不一致，现用真实四视图分别制作头像。Codex 向桌面 DeepSeek Harness 的“末日车队角色四视图设计”会话提交联动任务，Harness 查看真实参考、拼接单人肩胸与脸部参考并调用 `gpt-image-2.5-flare` 图片编辑接口。大附件并行上传出现连接中断后，Harness 改用压缩参考并逐张提交。

生成原图、上传参考、生成脚本、实际模型与尺寸、完整提示词和结果记录均保存在 `portrait_revision_20261013/`，原始四视图保留在项目外的用户原路径。`manifest.json` 为生成实录，`READY.json` 表示五张输出齐全；`installed.json` 记录正式头像尺寸与 SHA-256。`previous_portraits/` 保存替换前五张正式头像。

`tools/prepare_status_portraits.py` 检查五张原图后以完整画面缩至 512×512，安装为 `captain.png`（主角）、`mechanic.png`（老张）、`medic.png`（艾琳）、`scout.png`（阿杰）、`quartermaster.png`（索菲亚）。状态总览列表和成员详情共用这一映射。`prepare_status_art.py` 优先使用该修订，避免重新裁切旧图集覆盖新头像；旧 `portraits_source.png` 仅保留为历史来源。

2026-10-14 安装完成：主角原图 1024×1024，其余四张原图 1254×1254。`records/` 内艾琳和索菲亚保留实际服务响应记录；主角、老张和阿杰在逐张日志修复前已生成，其元数据由 `tools/recover_status_portrait_records.py` 根据实际文件及 Harness 脚本补录，明确标记 `record_recovered`，未伪造遗失的 URL、HTTP 状态或请求耗时。修订目录有 `.gdignore`，原图、备份和 QA 截图不作为运行素材导入。

新头像实际验收在 `portrait_revision_20261013/qa/`：五人详情、总览、960×600 和 1560×720 适配截图。Godot OpenGL 渲染测试结果为 `STATUS_OVERVIEW_TEST_PASS checks=80 failures=0`；五张详情已逐一查看，头顶、帽子和眼镜无截断。`five_portraits_preview.jpg` 为正式素材总览。

## 数据与版式

1280×720 设计画布按原有每日页面等比适配。库存没有虚构上限；资源条参考初始库存，数值显示实际数量。十处地点每页五处，路线为示意，不代表游戏地理坐标。五名成员沿用现有岗位和健康 / 疲劳 / 信任 / 最近记忆，不从参考图片复制人数或状态。

验收截图见 `.docs/开发记录/素材/2026-10-13/状态总览/`。截图来自实际 Godot OpenGL 渲染的离屏视口，使用不可见 Windows 宿主窗口，不捕获或操控桌面。
