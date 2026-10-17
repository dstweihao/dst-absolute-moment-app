# 绝对时刻 (Absolute Moment)

<p align="center">
  <img src="assets/icon/icon.png" width="100" height="100" alt="绝对时刻 Logo" /><br />
  <strong>带你真正吃透现代 C++ 底层机制的闯关式 AI 学习助手</strong>
</p>

<p align="center">
  <a href="https://github.com/dstweihao/dst-absolute-moment-app/releases/latest"><img src="https://img.shields.io/github/v/release/dstweihao/dst-absolute-moment-app?color=007AFF&label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC" alt="Release" /></a>
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Android%20%7C%20iOS%20%7C%20Web-34C759" alt="Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License" />
</p>

---

## 💡 这个 APP 是做什么的？

学习现代 C++ 最痛苦的两件事：
1. **死记硬背语法八股**，面试一问底层内存怎么排布、CPU 怎么执行，脑子一片空白；
2. **问常规 AI 总是“直接给你贴一段代码”**，你复制运行看着跑通了，但其实自己根本没学会（假懂）。

**「绝对时刻」就是为了彻底解决这个问题而设计的。**

它就像一位**坐在你身边的严格技术导师**，为你规划了一条循序渐进的 **38 关通关之路**。在你推导每一关时，它**绝不直接把代码答案喂到你嘴里**，而是通过一步步关键提问，逼你弄明白代码背后的**内存地址、CPU 指令与操作系统调用**。只有当你真正想通并证明自己理解了底层原理，才算通关。

---

## 📥 最新安装包下载 (v1.0.1)

| 平台 | 安装包直接下载 | 运行说明与支持环境 |
| :--- | :--- | :--- |
| **Android** | [absolute-moment-android.apk](https://github.com/dstweihao/dst-absolute-moment-app/releases/download/v1.0.1/absolute-moment-android.apk) | 支持 Android 10+，内置网络权限与完整闯关体验 |
| **macOS** | [absolute-moment-macos-arm64.zip](https://github.com/dstweihao/dst-absolute-moment-app/releases/download/v1.0.1/absolute-moment-macos-arm64.zip) | Apple Silicon (M 系列芯片) 原生极速 App，解压即用 |
| **Windows** | [GitHub Actions 自动构建](https://github.com/dstweihao/dst-absolute-moment-app/actions) | 支持 Windows 10/11 x64 桌面端 |
| **Linux** | [absolute-moment-linux-x64.tar.gz](https://github.com/dstweihao/dst-absolute-moment-app/releases/download/v1.0.1/absolute-moment-linux-x64.tar.gz) | Ubuntu 20.04+ / Arch / Debian x64 解压即用 |
| **iOS** | [absolute-moment-ios-release.ipa](https://github.com/dstweihao/dst-absolute-moment-app/releases/download/v1.0.1/absolute-moment-ios-release.ipa) | 支持 iOS 15+（可通过 TrollStore、爱思或个人证书签名安装） |
| **Web 网页版** | [absolute-moment-web.zip](https://github.com/dstweihao/dst-absolute-moment-app/releases/download/v1.0.1/absolute-moment-web.zip) | 静态网页部署包，解压后用 Nginx / Caddy 即可托管 |
| **Docker 镜像** | [ghcr.io/dstweihao/dst-absolute-moment-app](https://github.com/dstweihao/dst-absolute-moment-app/packages) | 一键启动：`docker run -d -p 8080:80 ghcr.io/dstweihao/dst-absolute-moment-app:latest` |

---

## ✨ 核心特色

### 1. 🎯 38 关体系化主线路线
告别零散和迷茫。从基础到高并发，每一个关卡只专注吃透**一个最小核心机制**：
- **阶段 1：编译链接本质**（源码如何变成 ELF 二进制、文本/数据段分布）
- **阶段 2：内存模型与生命周期**（虚拟内存、堆栈差异、内存对齐 Padding、RAII）
- **阶段 3：类型与多态底层**（虚函数表 vptr 偏移、多重继承对象模型、移动语义）
- **阶段 4：泛型与现代特性**（C++20 Concepts 约束、编译期计算 `if constexpr`）
- **阶段 5：并发编程与多核硬件**（缓存行伪共享、内存屏障与原子操作、协程调度）
- **阶段 6：实战工业工程**（CMake 规范、SIMD 矢量优化、Linux 高性能 I/O）

### 2. 🧠 启发式 AI 导师（拒绝喂饭，带你深度推导）
- **不直接给答案**：向 AI 提问时，它不会偷懒甩给你大段代码，而是指出你思维中的关键漏洞并给出追问。
- **支持深度思考模型**：原生接入 DeepSeek V3、DeepSeek R1（完整渲染 Thinking 思考链）及 Claude。
- **真懂假懂一眼便知**：掌握度结算算法严密，敷衍或含糊回答无法过关；唯有逻辑自洽证明原理，掌握度才达 100%。

### 3. 📂 数据 100% 属于你（纯本地优先，支持同步）
- **不依赖云端私有数据库**：你的所有每日打卡记录、关卡对话与学习笔记，全部以纯文本 **Markdown 文件**保存在你指定的本地电脑文件夹中。
- **无缝多设备同步**：只需将数据文件夹设在**坚果云、iCloud 或本地 Git 仓库**下，即可实现多台电脑和手机之间自动同步，不怕数据丢失，不被平台绑架。

### 4. 🍎 克制优雅的 Apple HIG 视觉设计
- **去 AI 模板味**：全面参照 Apple 人机交互指南（HIG），采用原生分组卡片、0.5px 发丝线分割、精致排版与 Cupertino 弹窗交互。
- **沉浸专注**：界面干净平整，无广告弹窗、无杂乱信息，让你将 100% 的精力聚焦在技术推导上。

---

## 🚀 3 步开始学习

1. **输入你的 API Key**：
   - 打开 App 侧边栏的 **“设置”**，填入你的 DeepSeek API Key（支持一键查询官方实时账户余额）。
2. **挑选关卡开始闯关**：
   - 进入大纲，点击进入今日要攻克的知识点。
3. **推导原理并打卡通关**：
   - 面对关卡提出的核心机制问题，输入你的推理分析；AI 导师会与你展开单点攻防。自证成功后点击完成，生成今日打卡沉淀到本地。

---

## 🛠 本地开发与参与贡献

本项目使用 Flutter 跨平台框架构建，遵循 Clean Architecture 分层架构与 Riverpod 响应式状态管理。

```bash
# 克隆仓库
git clone https://github.com/dstweihao/dst-absolute-moment-app.git
cd dst-absolute-moment-app

# 安装依赖
flutter pub get

# 运行全量单元与组件测试（189/189 绿色测试保障）
flutter test

# 启动本地开发
flutter run -d macos    # macOS 桌面端
flutter run -d chrome   # Web 端
flutter run -d windows  # Windows 桌面端
```

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。欢迎提交 Issue 与 Pull Request 共同完善现代 C++ 闯关学习路线！
