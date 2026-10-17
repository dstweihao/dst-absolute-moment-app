<p align="center">
  <img src="assets/icon/icon.png" width="128" height="128" alt="绝对时刻 Logo" />
</p>

# 绝对时刻 (Absolute Moment)

> 基于 Flutter 的现代 C++ 交互式推导工作台。集成 DeepSeek V3 / R1 苏格拉底单点反诘引擎，单关攻坚，闭环推导汇编、内存与系统调用。

---

## 项目简介

- **定位**：跨平台（macOS / Linux / Windows / Web）现代 C++ 底层推导工作台。
- **模式**：苏格拉底式单点反诘，禁直给代码答案，逼迫推导源码到 ELF 目标文件、虚拟内存与寄存器操作物理突变。
- **存储**：本地优先（Local-First），会话独立持久化，打卡与推导支持纯文本 Markdown + YAML FrontMatter 本地落盘。

---

## 核心痛点

- **八股假懂**：背诵语法特性，脱离虚拟地址、内存对齐、虚表偏移与并发缓存行真实开销。
- **大模型喂饭反噬**：常规 AI 直接给代码，跳过推导，缺少系统级排障能力。
- **资产碎片化**：对话窗口随关随失，缺乏关卡递进体系与结构化本地落盘。

---

## 核心机制

### 1. 38 关现代 C++ 路线
- **标准覆盖**：C++23 / C++26 语言演进与系统级工程实践。
- **单点聚焦**：一关一概念、一反诘、一条客观验收标准。
- **本地扩展**：指定本地目录，ResourceScanner 递归解析 YAML 自动挂载项目实战关卡。

### 2. 苏格拉底式 AI 反诘引擎
- **多模型抽象**：统一 AiClient 接口，支持 DeepSeek (OpenAI 兼容协议) 与 Claude (Anthropic 协议)。
- **极度精炼铁律**：零客套、禁直接给代码、单轮唯一追问。强迫学员自证汇编指令与内核调用链路。
- **思考链流式分帧**：SSE 协议封装，UTF-8 跨块增量重组。原生解析渲染 DeepSeek R1 `<think>` 思考过程。
- **标点与排版规范**：引用文本强制使用中文双引号“……”（如“cpp 文件”），代码与路径使用反引号（如 `hello.cpp`）。

### 3. 掌握度防通胀机制 (0-100%)
- **零分死锁**：回答“不知道”、“不会”、“报错”或输入 ≤ 3 字符，掌握度强制锁定 0%，严禁起步同情分。
- **阶梯阻尼**：单次有效交互递增 ≤ 10%，仅全链路自洽证明成立方可确认 100%。
- **历史纠偏**：自动清洗遗留的 ≤ 15% 虚假进度分。

### 4. 关卡会话物理隔离
- **独立持久化**：`node_chat_<id>` 关卡唯一键存储，各关卡上下文互不干扰。
- **无损切换**：跨关卡或大纲跳转，自动持久化当前会话，上下文零重置、零闪烁。

### 5. 本地优先与纯文本落盘
- **会话持久化**：关卡会话基于本地存储（`node_chat_<id>`）即时固化，无外部服务端依赖。
- **纯文本兼容**：打卡沉淀支持 Markdown 正文 + YAML FrontMatter 结构化落盘，本地文本编辑器可直接查阅与修改。

### 6. 安全防御与精准错误流
- **前置守护**：SensitiveContentGuard 拦截情绪与非技术用语，给出理性合规引导。
- **错误精准分流**：区分 TCP RST 合规拦截、未配 Key、401 鉴权失效与上游配额耗尽，杜绝泛化网络误报错。

---

## 课程体系大纲 (37 主线 + 1 综合)

| 阶段 | 核心模块 | 实体与物理验收点 |
| :--- | :--- | :--- |
| **阶段 1：编译链接** | 源码到二进制映射 | ASCII 文本、预处理展开、汇编生成、ELF 目标格式、text/data/bss 段分布、系统调用 `sys_exit` 状态码传递 |
| **阶段 2：内存模型** | 硬件地址与生命周期 | 虚拟内存映射、栈帧寄存器传递、堆分配器、内存对齐 Padding、RAII 资源生命周期绑定 |
| **阶段 3：类型与多态** | 抽象开销与对象模型 | 虚函数表指针（vptr）偏移、多重继承布局、RTTI 机制、移动语义与右值引用、完美转发 |
| **阶段 4：泛型元编程** | 编译期计算与约束 | C++20 Concepts 约束匹配、`if constexpr` 编译期分发、变参模板展开、类型萃取底层原理 |
| **阶段 5：并发与异步** | 硬件多核与指令重排 | 缓存行与伪共享、内存序（acquire/release/relaxed）、无锁队列、`std::jthread` 协作取消、协程帧布局与调度 |
| **阶段 6：系统级工程** | 工业级构建与调优 | CMakePresets 规范、SIMD 矢量优化、Linux `io_uring` 高并发事件循环、动态符号解析与热重载 |

---

## 技术架构与目录

采用 Clean Architecture 分层架构与 Riverpod 响应式依赖注入：

```
lib/
├── core/                  # 主题色彩、间距规范、排版体系、工具类
├── data/
│   ├── ai/                # AI 通信：客户端抽象、SSE 流式解析器、极度精炼提示词
│   ├── credentials/       # 凭证安全存储
│   ├── repositories/      # 仓储实现：路线管理、资源扫描、打卡落盘
│   ├── serialization/     # Markdown / YAML FrontMatter 编解码
│   ├── storage/           # 本地存储抽象（IO / Web 分支实现）
│   └── updates/           # 自动更新检测与分发
├── domain/models/         # 实体模型：Node、Checkin、AiSettings 等
├── features/
│   ├── ai_settings/       # 模型切换、API Key 配置与连接验证
│   ├── dashboard/         # 学习看板与进度分布
│   ├── learn/             # 推导交互主界面：流式气泡、掌握度即时结算
│   ├── onboarding/        # 新用户引导初始化
│   ├── settings/          # 系统设置（存储路径配置、版本更新）
│   ├── sop/               # 结构化推导 SOP 流水线与会话编排
│   ├── stats/             # 攻坚数据统计
│   └── tracks/            # 38 关大纲列表与关卡详情
├── providers.dart         # Riverpod 全局状态注入
├── router.dart            # GoRouter 声明式路由与状态保留容器
└── shell.dart             # 主界面侧边栏骨架
```

---

## 快速上手

### 环境要求
- Flutter SDK `>= 3.24.0`
- Dart SDK `>= 3.5.0`
- 支持平台：macOS、Linux、Windows、Web

### 本地运行
```bash
# 依赖拉取
flutter pub get

# 自动化测试
flutter test

# 启动平台
flutter run -d macos
flutter run -d chrome
flutter run -d windows
flutter run -d linux
```

### AI 服务配置
1. 侧边栏进入 **“设置” -> “AI 服务配置”**。
2. 服务商选择 **DeepSeek**（兼容 OpenAI 协议）。
3. 填入 API Key，选择预设模型（`deepseek-chat` 或 `deepseek-reasoner`）。
4. 点击“测试连接”验证通道。

---

## macOS 原生打包
```bash
chmod +x ./tool/update_apple_app.sh
./tool/update_apple_app.sh
```
自动执行清理缓存、移除 `com.apple.FinderInfo` 扩展属性、深度代码签名并输出发布产物。

---

## 质量验证

测试套件覆盖标准路线自洽性、跨网络块 UTF-8 增量重组、掌握度防暴涨算法、关卡会话隔离与安全错误分流：

```bash
flutter test
```
**执行结果：189/189 测试全部通过 (100% Pass Rate)，`flutter analyze` 零告警。**

---

## 许可证
[MIT License](LICENSE)
