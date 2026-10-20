# 三关共用自由镜头

三章正式关卡共用自由镜头，旧开发演示默认不启用镜头。

## 操作与配置

| 操作 | 行为 |
| --- | --- |
| WASD | 平移；斜向归一化，世界速度除以缩放倍率 |
| 按住鼠标中键 | 地图跟随拖动，松开即停，不添加惯性 |
| 鼠标滚轮 | 以鼠标下世界点为锚，每格乘／除 1.1 |
| macOS 双指／捏合 | PanGesture 平移，MagnifyGesture 按 factor 缩放 |
| Home／HUD 视角复位 | 恢复本关初始化位置与倍率 |

`scripts/gameplay/colony_camera.gd` 可配置：移动速度 600 逻辑屏幕像素/秒，缩放步长 0.1，最小 0.75，最大 2.0，初始 1.0，手势平移系数 1.0。键盘采用按下/松开状态，不轮询全局 Input，失焦清空状态，重新聚焦后必须重新按下。

Camera2D 使用 ALWAYS，关卡通过明确的许可回调控制输入。Space 规划暂停允许观察；菜单、失败待结算、终局、重开、切关及场景退出禁止操作。中键松开在 HUD 区域判断之前收尾；拖动期间的鼠标点击不进入建造/选择控制器。获得键盘焦点的控件优先接收键盘输入。

三关根节点分别配置 `free_camera_enabled = true` 和独立的世界坐标 `camera_bounds`：

| 关卡 | camera_bounds（x, y, width, height） |
| --- | --- |
| 第一关 | (-560, -400, 2320, 1720) |
| 第二关 | (-560, -400, 2320, 1800) |
| 第三关 | (-580, -420, 2360, 1840) |

这些范围包含完整地图及供边缘对象避开 HUD 的留白，不借用建造/寻路范围。根据实际视口和倍率约束中心；地图某方向小于视口时居中。三关完成 1200×920 窗口配置和 HUD 创建后初始化，默认保持原画布构图。缩放强制更新实际画布变换后修正锚点，边界约束优先。窗口变化重新约束视野，Ground 扩展覆盖可见范围，World 根节点不缩放或平移。

macOS 手势分发依据 [Godot 4.7 macOS 输入后端](https://github.com/godotengine/godot/blob/4.7/platform/macos/godot_content_view.mm)：有手势阶段的滚动走 PanGesture，普通滚轮走 MouseButton；本控制器不额外将手势映射成滚轮，滚轮松开也不会再次缩放。

## 文件改动

- 新增 `scripts/gameplay/colony_camera.gd`：控制、边界、锚点缩放、复位、失焦处理。
- `scenes/gameplay/colony_gameplay.tscn`：新增与 World、Systems、HUD 同级的 Camera2D，默认禁用。
- `scenes/levels/{first_level,second_level,third_level}.tscn`：显式启用及各关边界。
- `scripts/{first_level,second_level,third_level}.gd`：窗口配置之后初始化、统一前置输入分发和状态许可。
- `scripts/gameplay/colony_runtime.gd`：共用展示刷新、地面覆盖和生命周期；`colony_operations_runtime.gd`：T/M 预览刷新。
- `scripts/compact_colony_hud.gd`：复位按钮、帮助文字、纸张面板内的火力提示；`frontier_status.gd`：保留世界路线，正式关卡不再在世界节点绘制屏幕提示文字。
- `scripts/level_menu_layer.gd`：开菜单立即清空按键和拖动状态。
- `scripts/{growth_target,connection_target}.gd`：镜头变化刷新预览/活跃目标标签，保持屏幕字号并约束边缘位置。
- 新增 `tests/colony_camera_test.gd` 和 `tests/colony_camera_visual_test.gd`；更新 `tests/{remote_cultivation_input,connection_input}_test.gd` 的标签矩形计算，使原边界断言使用标签自身的实际变换。

## 验证记录（2026-10-20）

引擎：Godot `4.7.2.stable.official.ed1daf0bf`。

| 测试 | 检查数 | 结果 |
| --- | ---: | --- |
| colony_camera_test | 187 | 通过 |
| growth_input_test | 131 | 通过 |
| remote_cultivation_input_test | 227 | 通过 |
| connection_input_test | 165 | 通过 |
| construction_queue_input_test | 82 | 通过 |
| compact_hud_test | 122 | 通过 |
| stage11_pause_ui_test | 55 | 通过 |
| second_level_test | 51 | 通过 |
| third_level_test | 102 | 通过 |
| 合计 | 1122 | 0 项断言失败 |

新增测试在真实 SceneTree/Viewport 中覆盖三关开局、归一化与速度补偿、缩放极限、锚点稳定性、复位、边界、小地图居中、实际窗口变宽、Ground 覆盖、活跃标签、HUD 隔离、详情滚动、中键跨 HUD 松开、拖动中禁止误点击、手势、键盘焦点、失焦、G/B/L/T/M 暂停预览、预算/计时/队列冻结、转换后的选择/放置/连接/修复/改向/搬迁，以及真实 reload/change_scene 后的状态清理。

三关通过 Apple M4 / OpenGL Compatibility 实际渲染，检查默认、0.75 边界、2.0 预览、1.35 帮助页、暂停菜单、火力提示和结算共 21 张画面。截图夹具等待动态界面重绘与 GPU 同步；不能使用 headless 截图替代。第一关额外通过原生窗口操作检查规划暂停中的键盘移动、滚轮缩放、缩放后选择、复位按钮和菜单锁定。

复跑示例（工程根目录，`godot` 替换为本机引擎可执行文件）：

```sh
godot --headless --fixed-fps 60 --path . --script res://tests/colony_camera_test.gd
godot --path . --script res://tests/colony_camera_visual_test.gd
```

图形脚本默认输出到 `/tmp/fungi-camera-visual/`，截图与日志属于本地验收产物，不加入游戏资源。

## 验证边界

- 未操作实体 macOS 触控板，双指/捏合的真实硬件手感仍待用户实测；事件分发、数值与界面隔离已用合成事件验证。
- 部分关卡测试和图形验收进程退出时仍打印音频资源残留提示。`battle.mp3` / `AudioStreamPlaybackMP3` 已在不含镜头的独立音频夹具中复现，未修改音频模块；图形验收退出码为 0，相关提示保留在完整日志中。
- 此次验证是镜头和相关交互回归，不代表完成三关战斗通关；结算截图使用测试伤害触发。
