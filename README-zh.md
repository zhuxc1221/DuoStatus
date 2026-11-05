<div align="center">

<img src="assets/logo/duostatus-icon.png" width="112" alt="DuoStatus 图标">

# DuoStatus

**电量与 Wi-Fi，合在一个菜单栏图标里。**

[![macOS](https://img.shields.io/badge/macOS-27%2B-555?style=flat-square&logo=apple&logoColor=white)](#运行要求)
[![Apple silicon](https://img.shields.io/badge/Apple_silicon-arm64-555?style=flat-square)](#运行要求)
[![License](https://img.shields.io/badge/license-MIT-2e8c6b?style=flat-square)](LICENSE)
[![English](https://img.shields.io/badge/README-English-d9d9d9?style=flat-square)](README.md)

**[下载](https://github.com/zhuxc1221/DuoStatus/releases/latest)** · [功能](#功能) · [安装与设置](#安装与设置) · [从源码构建](#从源码构建) · [隐私](#隐私)

<br>

<img src="docs/media/overview-zh.png" width="100%" alt="示意图：原本分开的 Wi-Fi 和电池图标合为一个，空出一个菜单栏位置">

</div>

---

DuoStatus 将数字电量、电量圆环和 Wi-Fi 状态合成一个菜单栏图标。关闭系统原有的 Wi-Fi 和电池图标，就能空出一个位置。点击组合图标，通过控制中心打开真正的 macOS Wi-Fi 面板。

## 功能

- **合为一个图标**：外圈显示电量，中间显示 Wi-Fi，顶部只显示电量数字，不带 `%`。
- **接电闪电**：连接外接电源时显示闪电；达到充电上限、暂停充电时也会显示。
- **Wi-Fi 状态**：反映信号强弱、未连接和 Wi-Fi 关闭状态，与电量一起每五秒刷新。
- **系统原生面板**：个人热点、已知网络、其他网络和设置入口都由 macOS 提供。
- **Option 点击**：查看系统提供的连接详细信息。
- **右键菜单**：查看电量状态、打开设置或工具窗口、退出；点击其他位置自动关闭。
- **系统管理位置**：使用标准菜单栏项目，无需叠加窗口或手动对齐。

上方配图使用示例数据绘制，没有使用真实桌面截图。

## 运行要求

- macOS 27 及以上，已在 macOS 27.2 验证。
- 下载版本适用于 Apple 芯片 Mac。
- 控制中心中需要包含 Wi-Fi 控件。

其他 macOS 版本和 Intel 构建尚未验证。

## 安装与设置

1. [下载最新版本](https://github.com/zhuxc1221/DuoStatus/releases/latest)，解压后将 `DuoStatus.app` 放到「应用程序」。替换旧版本前，先退出正在运行的旧副本。
2. 打开 DuoStatus。要使用原生 Wi-Fi 面板，请在 **系统设置 → 隐私与安全 → 设备控制和数据访问** 中允许 DuoStatus。部分 macOS 版本将这个权限称为 **辅助功能**。
3. 在 **系统设置 → 菜单栏** 中关闭原生 **Wi-Fi** 和 **电池**，保留 DuoStatus。原来的两个图标由一个组合图标代替。
4. 保持系统已有的 **控制中心** 入口可用。DuoStatus 通过它打开原生 Wi-Fi 面板，无需保留原生 Wi-Fi 菜单栏图标。

发布包采用临时签名，尚未经过 Apple 公证。若首次打开被拦截，可在 **系统设置 → 隐私与安全** 中对该 App 选择 **仍要打开**，或从源码构建。项目不会要求全局关闭 Gatekeeper。

关闭工具窗口后，菜单栏图标继续运行。再次打开 App，或在右键菜单选择 **显示 DuoStatus 窗口**，即可返回。当前 App 界面为简体中文。

## 隐私

DuoStatus 在本机读取电量和 Wi-Fi 状态，没有账号、分析统计、遥测或由 App 主动发起的网络请求。不扫描附近网络，不读取 Wi-Fi 名称或密码，不录屏，也不监听键盘。

系统的辅助功能权限本身较广，允许读取和操作其他 App 的界面。DuoStatus 只用它查找现有控制中心入口，并执行 Wi-Fi 控件的 **显示详细信息** 动作；不会为了打开面板而按下 Wi-Fi 开关。原生面板以及你在其中选择的网络操作均由 macOS 处理。

读取电量和 Wi-Fi 状态不需要这项权限；打开系统面板需要。

## 从源码构建

安装包含 macOS 27 SDK 的 Xcode Command Line Tools，然后运行：

```sh
git clone https://github.com/zhuxc1221/DuoStatus.git
cd DuoStatus
./build.sh
```

脚本会构建 `dist/DuoStatus.app`、加入应用图标、进行临时签名并运行自检。没有第三方依赖。

单独运行自检：

```sh
./dist/DuoStatus.app/Contents/MacOS/DuoStatus --self-test
```

重新生成 Logo PNG、macOS 应用图标和文档配图：

```sh
./scripts/render-assets.sh
```

可编辑 SVG 位于 `assets/logo/`。位图资源使用 AppKit 绘制，文档配图只包含示例数据。

## 已知限制

- 原生 Wi-Fi 面板从 **控制中心** 下方弹出，而不是从组合图标下方弹出；位置由系统管理。
- 控制中心中需要包含 Wi-Fi 控件。后续系统若改变界面结构，可能需要更新适配。
- 闪电表示 **已连接外接电源**，不等于电池一定正在充电；右键菜单会区分这两种状态。
- 临时签名在重新编译后会改变。若更新后失去辅助功能授权，仅移除 DuoStatus 的旧授权项，再添加当前 App 即可。
- 没有自动设置开机启动；需要时可自行加入系统登录项。

## 验证范围

已在 macOS 27.2、原生 Wi-Fi 和电池图标均隐藏的情况下，验证普通点击、Option 点击和右键菜单。右键菜单点击外部正常关闭，接电暂停充电状态的闪电也已实机验证。

自检覆盖电量计算、无效输入、接电暂停状态、闪电绘制、信号档位，以及避免误触 Wi-Fi 开关的详情动作选择。没有通过实际切换网络或拔插电源来验证。

## 致谢

[BarTap](https://github.com/ChenFangfc/BarTap) 的简洁双语项目展示提供了参考。[baaar](https://github.com/bylaaabs/baaar) 为识别 macOS 27 菜单栏宿主提供了线索。DuoStatus 的 Logo 和文档配图均为本项目原创。

## 许可

[MIT](LICENSE)，包含代码、文档和原创视觉资源。
