# 绝对时刻 (Absolute Moment App)

<p align="center">
  <strong>专为硬核工程师打造的 C++ 专属苏格拉底式 AI 拆塔学习引擎</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-macOS%20|%20Web%20|%20iOS%20|%20Android-lightgrey" alt="Platform" />
  <img src="https://img.shields.io/badge/AI%20Engine-DeepSeek%20V3%20/%20R1-blue" alt="DeepSeek" />
  <img src="https://img.shields.io/badge/Tests-189%20Passed-success" alt="Tests" />
  <img src="https://img.shields.io/badge/Style-Extreme%20Concision-orange" alt="Concision" />
</p>

---

## 📖 项目简介

**【绝对时刻】(Absolute Moment App)** 是专为正在攻坚现代 C++ 底层真相的开发者打造的苏格拉底式智能学习终端。

不同于传统“给答案、抄代码”的教学工具，【绝对时刻】搭载冷酷严密的**「AI 拆塔官」**：
- **绝不直接给代码**：只通过层层递进的单点反诘与底层物理现实，逼迫学员自己推导出编译器行为、汇编指令、ELF 格式及操作系统内核系统调用链路。
- **长出自己的肌肉**：让概念从虚幻的八股文直降为内存、寄存器与总线级别的物理事实。

---

## ✨ 核心特性

### 1. 38 关现代 C++ 硬核标准路线
- **紧贴现代标准**：全面覆盖 C++23 / C++26 语言特性与底层工程现实。
- **单核心点攻坚**：一关只讲一个知识块，拒绝泛泛而谈（从 `int main` 底层退出到模板元编程、协程调度、内存模型）。
- **个性化扩展能力**：支持本地工作目录递归扫描，无缝挂载自定义项目代码与专项 SOP。

### 2. 苏格拉底式 AI 拆塔引擎 (Socratic AI Engine)
- **DeepSeek 官方工程风格 (Extreme Concision)**：
  - 严格践行 *Sacrifice grammar for the sake of concision* 极度精炼铁律，零套话、零客套、高信息密度。
  - 标点规范严谨：规范使用中文双引号“……”与代码反引号 \`hello.cpp\`。
- **物理现实直击**：揭示从 ASCII 源码到 ELF 目标文件、虚拟地址空间映射与寄存器操作的物理突变。
- **深度思考链流式渲染**：原生支持 DeepSeek R1 `<think>` 思考过程折叠与渐显动画。

### 3. 掌握度评判与平滑防暴涨系统 (Anti-Inflation Progression)
- **严禁虚假起步分**：
  - 当学员回答“不知道”、“不会”、“报错”或输入字数 ≤ 3 时，**掌握度强制死锁在 0%**，杜绝起步同情分。
- **阶梯平滑成长**：
  - 未达到完全推导闭环（直通 100%）前，单次有效对话递增严格限制在 **≤ 10%**（如 0% → 10% → 20%），必须经过层层深挖反诘才能升级。
- **历史虚分清洗**：
  - 自动识别并纠正历史遗留的 ≤ 15% 虚假进度分，回归纯净 0%。

### 4. 关卡会话无损持久化隔离
- **独立关卡会话**：每个关卡拥有专属的会话存储键（`node_chat_<id>`），各关卡推导历史彼此隔离互不覆盖。
- **随时切换，永不丢失**：
  - 侧边栏/路线图点击当前正在攻坚的关卡：直接返回，保持会话原样，零重置、零闪烁。
  - 切换其他关卡：自动持久化当前会话并加载目标关卡历史，随时往返续写推导。

### 5. 智能安全合规与敏感词安全守护 (`SensitiveContentGuard`)
- **前置文明引导**：
  - 本地前置识别不当词汇、辱骂与违禁用语，直接以沉稳理性的口吻提示合规保护，引导使用技术术语探讨。
- **告别误导性报错**：
  - 捕获服务商网络防火墙连接重置（TCP RST）并精准归类为合规拦截，彻底告别“AI 服务连接失败，请检查网络”等误导性假异常。
- **精准按键呈现**：
  - 仅在未配置 Key 或明确 401 鉴权失败时展示“前往设置 DeepSeek Key”引导按键，违禁词拦截、网络波动绝不滥弹按钮。

---

## 🏗️ 架构与技术栈

```
lib/
├── core/                  # 主题色板 (AppColors)、间距规范 (AppSpacing)、排版体系
├── data/
│   ├── ai/                # AI 引擎核心协议
│   │   ├── ai_client.dart           # 抽象协议与错误模型 (AiErrorKind)
│   │   ├── base_ai_client.dart      # HTTP/SSE 分帧与错误流分发
│   │   ├── openai_client.dart       # DeepSeek / OpenAI 兼容实现
│   │   ├── anthropic_client.dart    # Claude / Anthropic 实现
│   │   ├── sensitive_content_guard.dart # 敏感词与合规安全防线
│   │   └── prompts/                 # 拆塔官系统提示词体系 (Personas)
│   ├── repositories/      # 路线仓储、资源扫描器、打卡记录
│   └── storage/           # 本地持久化与文件存取抽象
├── domain/models/         # 关卡模型 (Node)、打卡记录 (Checkin)、配置实体
├── features/
│   ├── learn/             # 学习推导主界面 (LearnPage) 与气泡渲染体系
│   ├── tracks/            # 38 关路线大纲与关卡详情
│   ├── dashboard/         # 今日攻坚看板与进度统计
│   ├── ai_settings/       # 模型选择、API Key 配置与额度查询
│   └── sop/               # 深度思维推导 SOP 会话流水线
├── providers.dart         # Riverpod 状态流与全局依赖注入
├── router.dart            # GoRouter 导航声明与多分支状态保留 (AppShell)
└── app.dart               # 根应用定义
```

---

## 🚀 快速开始

### 依赖环境
- Flutter SDK >= 3.24.0
- Dart SDK >= 3.5.0
- macOS (Xcode 15+) / Chrome (Web 平台)

### 本地运行
```bash
# 1. 获取依赖
flutter pub get

# 2. 运行自动化全量测试
flutter test

# 3. macOS 原生端调试
flutter run -d macos

# 4. Web 平台调试
flutter run -d chrome
```

### 一键构建与签名 (macOS 原生发布)
项目内置全自动构建脚本，可自动完成清除缓存、剥离 `com.apple.FinderInfo` 扩展属性、深度代码签署与分发：
```bash
./tool/update_apple_app.sh
```

---

## 🧪 自动化测试验证

全工程拥有高覆盖率的自动化测试套件（覆盖标准路线自洽性、SSE 流式增量分帧、UTF-8 跨块解码、敏感词拦截、防暴涨平滑算法与跨页面状态隔离等）：

```bash
flutter test
```
**当前状态：189/189 测试全部通过 (100% Pass Rate)**。

---

## 📄 License
MIT License.
