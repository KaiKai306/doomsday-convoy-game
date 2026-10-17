# 许宁 · 人物姿势图片

按用户最新要求，改为直接生成姿势插画并抠图。交付图片全部提供纯绿幕背景 RGB(0,255,0)，透明裁切PNG另存。人物与椅子分开。本轮只做许宁，等待样张反馈后再制作其他人物。

![朝右站姿、坐姿、蹲姿](preview_green.png)

## 五张图片

| 姿势 | 原尺寸绿幕图 | 透明裁切图 |
| --- | --- | --- |
| 正面站姿，护住药包 | [查看](green/standing_front.png) | [查看](cutouts/standing_front.png) |
| 朝右斜侧站姿，安静倾听 | [查看](green/standing_right.png) | [查看](cutouts/standing_right.png) |
| 正面坐姿，整理绷带 | [查看](green/seated_front.png) | [查看](cutouts/seated_front.png) |
| 朝右斜侧坐姿，整理绷带 | [查看](green/seated_right.png) | [查看](cutouts/seated_right.png) |
| 朝右斜侧单膝蹲姿，检查药包 | [查看](green/crouching_right.png) | [查看](cutouts/crouching_right.png) |

高清细节预览：[detail_green.png](detail_green.png)。五张全览：[all_poses_green.png](all_poses_green.png)。两者均使用纯绿幕背景。

## 文件使用

- `green/`：五张1024×1536原尺寸绿幕图，背景已统一为纯RGB(0,255,0)。
- `cutouts/`：五张保持原生细节的紧边透明PNG，四周保留24像素安全边距。
- `aligned/`：统一1024×1536透明画布，按站位或座面锚点放置。
- `aligned_green/`：对应的统一画布绿幕版。
- `manifest.json`：每张图的来源、校验值、裁切框、锚点和缩放记录。

统一画布的站姿脚底锚点为(512,1440)，坐姿座面锚点为(512,1080)。坐姿锚点按臀部接触座面的部位人工标注，不按人物包围盒中心替换。紧边图片使用manifest中各自的锚点。坐姿、蹲姿保留自然高度，椅子由场景单独提供；实际场景尚未接入这些图片。

## 制作与检查

沿用Harness既有的参考图编辑接口后台制作，模型`gpt-image-2.5-flare`。保留前轮两张高质量站坐原图，再以许宁站姿图为真实身份参考生成三张新姿势。所有图片直接来自生图。

绿幕图使用sprite-gen的`cutout --key green --decontam palette`处理发丝、手部和衣服边缘。其中朝右坐姿由服务直接返回原生透明PNG，保留该透明轮廓并清除1/255的背景透明度噪声，再合成纯绿幕交付；不把透明结果当作绿幕原始返回。

已检查完整头发和鞋底、安全边距、透明通道、裁切画布以及预览。五张图的半透明边缘均未检测到强绿色残留；此数值检查不能代替用户对造型和姿势的验收。提示词、生成记录和原始返回保存在`.docs/美术/许宁角色姿势图片_20261016/`；两张复用原图保存在前轮样张目录。
