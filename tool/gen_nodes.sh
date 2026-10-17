#!/usr/bin/env bash
# 生成全部 C++ 学习路线节点 YAML 文件
set -e
DIR="assets/seed/tracks/cpp/nodes"
rm -f "$DIR"/*.yaml

write() {
  local file="$DIR/$1"
  cat > "$file"
}

# ─────────────────────────────────────────────
# 阶段1：入门基础（1-10）
# ─────────────────────────────────────────────

write "a01-first-program.yaml" << 'YAML'
id: "a01-first-program"
title: "第一个程序"
progress_range: [0, 2]
phase: 1
phase_name: "入门基础"
order: 1
description: >
  一个 .cpp 文件从编辑到跑起来经历了哪几步。这一关只讲这条最短路径。
core_concepts:
  - "main 函数是程序入口；g++ 把源码编译成可执行文件；运行才是执行"
socratic_questions:
  - id: Q0_compile
    level: "编译运行"
    text: "你写完 cout << \"hello\" 后保存了文件，但程序还没有跑 —— 此刻发生了什么，什么时候才会有字出现在屏幕上？"
interception:
  minimum_pass_line: "能说出编译和运行是两个独立的步骤，main 是程序执行的起点"
  on_failure: "AI 画出从源文件到终端输出的全链路，通过后回归本节点"
acceptance_criteria:
  - "能独立写出、编译、运行一个打印任意文字的 C++ 程序"
next_node: "a02-types"
prerequisites: []
YAML

write "a02-types.yaml" << 'YAML'
id: "a02-types"
title: "基本类型"
progress_range: [2, 4]
phase: 1
phase_name: "入门基础"
order: 2
description: >
  类型不是数据的标签，而是对同一串 0/1 的解释方式。这一关只讲内置类型
  到底规定了什么、又把什么留给了平台。
core_concepts:
  - "类型决定位模式如何被解读：char 的符号性是实现定义的，不同平台结果可以不同"
socratic_questions:
  - id: Q0_char_signedness
    level: "实现定义"
    text: "同一个 char 变量存了 200，在有的编译器上打印出 -56，换一个编译器却是 200 —— 标准明明写了 char，为什么它允许两个答案都对？"
interception:
  minimum_pass_line: "能说出 char 的符号性是实现定义的，标准没有规定它一定有符号还是无符号"
  on_failure: "AI 列出各平台整型宽度对照表演示差异，通过后回归本节点"
acceptance_criteria:
  - "能解释为什么同一个字面量在不同编译器上打印出不同的数值是标准允许的行为"
next_node: "a03-variables"
prerequisites: ["a01-first-program"]
YAML

write "a03-variables.yaml" << 'YAML'
id: "a03-variables"
title: "变量与初始化"
progress_range: [4, 6]
phase: 1
phase_name: "入门基础"
order: 3
description: >
  定义一个变量和给它一个值在 C++ 里是两件独立的事。这一关只讲那些
  没人替你清零的地方。
core_concepts:
  - "自动变量不被零初始化：函数体内的 int x; 拿到的是栈上的垃圾值"
socratic_questions:
  - id: Q0_uninitialized
    level: "初始化"
    text: "int x; 写在函数体里是随机的垃圾值，写成全局变量却一定是 0 —— 同一行代码，位置换了结果就变了，标准为什么要这么规定？"
interception:
  minimum_pass_line: "能说出自动变量默认不初始化，读取它的值是未定义行为"
  on_failure: "AI 用内存快照演示自动变量里的垃圾值从哪里来，通过后回归本节点"
acceptance_criteria:
  - "能说出哪些变量会被自动零初始化，哪些不会，并说明读未初始化变量的后果"
next_node: "a04-operators"
prerequisites: ["a02-types"]
YAML

write "a04-operators.yaml" << 'YAML'
id: "a04-operators"
title: "运算符"
progress_range: [6, 8]
phase: 1
phase_name: "入门基础"
order: 4
description: >
  运算符是编译器内置的函数。这一关只讲优先级和整数运算中最常踩的坑。
core_concepts:
  - "整数除法截断小数部分：5/2 得 2 不得 2.5，类型决定运算方式"
socratic_questions:
  - id: Q0_int_div
    level: "运算"
    text: "两个 int 相除永远得 int，5 / 2 就是 2 —— 如果你需要 2.5，在哪一步介入才能让它变成浮点除法？"
interception:
  minimum_pass_line: "能说出整数除法的截断规则，并指出在哪里显式转换可以改变行为"
  on_failure: "AI 列出整型除法的三个典型陷阱，通过后回归本节点"
acceptance_criteria:
  - "能预测任意一个混合整型和浮点型运算表达式的最终类型和值"
next_node: "a05-control-flow"
prerequisites: ["a03-variables"]
YAML

write "a05-control-flow.yaml" << 'YAML'
id: "a05-control-flow"
title: "控制流"
progress_range: [8, 10]
phase: 1
phase_name: "入门基础"
order: 5
description: >
  if、for、while 控制程序走哪条路。这一关只讲循环变量的作用域和
  无限循环的成因。
core_concepts:
  - "for 循环的初始化、条件、后置表达式各在什么时刻执行，条件为假时立刻退出"
socratic_questions:
  - id: Q0_infinite_loop
    level: "控制流"
    text: "for (int i = 0; i < 10; i++) 能正常结束，while (true) 永远不停 —— 两者的区别只在「什么决定了循环的出口」这件事上，你能指出来吗？"
interception:
  minimum_pass_line: "能说出循环的三要素：初始状态、终止条件、状态推进，缺少任意一个会有什么后果"
  on_failure: "AI 用流程图演示三要素如何构成循环，通过后回归本节点"
acceptance_criteria:
  - "能写出一个用 for 循环打印 1 到 100 的程序，并说明循环变量的作用域范围"
next_node: "a06-functions"
prerequisites: ["a04-operators"]
YAML

write "a06-functions.yaml" << 'YAML'
id: "a06-functions"
title: "函数"
progress_range: [10, 13]
phase: 1
phase_name: "入门基础"
order: 6
description: >
  函数是把一段代码切出来、给它起个名字、让它能被反复调用的机制。
  这一关只讲调用时栈帧发生了什么。
core_concepts:
  - "每次函数调用都建立一个新的栈帧；递归调用就是不断压栈，栈空间耗尽即溢出"
socratic_questions:
  - id: Q0_recursion
    level: "调用栈"
    text: "一个递归函数忘了写终止条件，程序不会返回一个错误码，而是直接崩掉 —— 在这之间它一直在做什么，又是哪一步撑不住了？"
interception:
  minimum_pass_line: "能说出每次调用都压入一个栈帧，返回时弹出，栈空间耗尽即栈溢出"
  on_failure: "AI 用调用栈快照演示递归展开到溢出的全过程，通过后回归本节点"
acceptance_criteria:
  - "能说出每次函数调用压入一个栈帧、返回时弹出，并指出递归溢出在哪一步发生"
next_node: "a07-pass-by-value"
prerequisites: ["a05-control-flow"]
YAML

write "a07-pass-by-value.yaml" << 'YAML'
id: "a07-pass-by-value"
title: "按值传参"
progress_range: [13, 15]
phase: 1
phase_name: "入门基础"
order: 7
description: >
  实参是怎么变成形参的，决定了函数能不能改到调用方的东西。这一关只讲
  C++ 默认的按值传递是什么意思。
core_concepts:
  - "按值传递：形参是实参的一份独立拷贝，改形参不会影响调用方的实参"
socratic_questions:
  - id: Q0_pass_by_value
    level: "传参方式"
    text: "在函数里把形参重新赋值，调用方的实参纹丝不动 —— 既然两者长得一模一样，它们到底是什么关系？"
interception:
  minimum_pass_line: "能说出按值传递时形参是实参的独立拷贝，两者在内存里是两个不同的对象"
  on_failure: "AI 用内存地址演示形参独立存在的事实，通过后回归本节点"
acceptance_criteria:
  - "能预测任意一段按值传参的代码执行后，调用方的变量是否发生了变化"
next_node: "a08-arrays"
prerequisites: ["a06-functions"]
YAML

write "a08-arrays.yaml" << 'YAML'
id: "a08-arrays"
title: "数组"
progress_range: [15, 17]
phase: 1
phase_name: "入门基础"
order: 8
description: >
  数组是一段连续的同类型内存。这一关只讲数组名是什么、越界访问会
  发生什么。
core_concepts:
  - "数组名退化为指向首元素的指针；下标越界是未定义行为，编译器不会替你检查"
socratic_questions:
  - id: Q0_oob
    level: "内存安全"
    text: "int arr[5]; arr[10] = 0; 编译不报错，有时能跑，有时崩溃 —— 编译器为什么不替你检查这个，程序到底在写哪里的内存？"
interception:
  minimum_pass_line: "能说出数组越界是未定义行为，编译器不做运行时检查，后果由硬件和内存布局决定"
  on_failure: "AI 画出越界写入覆盖相邻变量的内存快照，通过后回归本节点"
acceptance_criteria:
  - "能说出为什么数组越界在有些情况下沉默通过、在有些情况下崩溃，并指出谁才能真正检测它"
next_node: "a09-pointers"
prerequisites: ["a07-pass-by-value"]
YAML

write "a09-pointers.yaml" << 'YAML'
id: "a09-pointers"
title: "指针"
progress_range: [17, 20]
phase: 1
phase_name: "入门基础"
order: 9
description: >
  指针就是一个装着地址的变量。这一关只讲取地址和解引用这对互逆操作，
  以及没有指向的指针意味着什么。
core_concepts:
  - "& 取出对象的地址，* 按地址访问那个对象；指针只保存地址，不追踪对象是否还活着"
socratic_questions:
  - id: Q0_dangling
    level: "指针有效性"
    text: "int* p; 之后紧接着 *p = 1; 编译毫无怨言，运行时才出事 —— 编译器在这一行到底检查了什么，又为什么查不出问题？"
interception:
  minimum_pass_line: "能说出指针只保存地址、编译器不追踪它是否指向有效对象，解引用无效指针是未定义行为"
  on_failure: "AI 演示未初始化指针被解引用的崩溃现场，通过后回归本节点"
acceptance_criteria:
  - "能说出 * 解引用操作在指针未指向有效对象时会发生什么，以及如何用 nullptr 表示空指针"
next_node: "a10-references"
prerequisites: ["a08-arrays"]
YAML

write "a10-references.yaml" << 'YAML'
id: "a10-references"
title: "引用"
progress_range: [20, 22]
phase: 1
phase_name: "入门基础"
order: 10
description: >
  引用不是对象，是已经存在对象的另一个名字。这一关只讲这个别名意味着什么，
  以及用引用传参如何让函数修改到调用方的变量。
core_concepts:
  - "引用是别名：绑定后不可改绑；按引用传参让形参直接操作调用方的对象"
socratic_questions:
  - id: Q0_ref_param
    level: "引用传参"
    text: "void swap(int& a, int& b) 能真正交换两个变量，而 void swap(int a, int b) 什么都没改 —— 同样的函数体，差别只在参数声明的一个 &，它做了什么？"
interception:
  minimum_pass_line: "能说出引用参数让形参成为实参的别名，对形参的任何操作都直接反映在实参上"
  on_failure: "AI 画出引用参数与按值参数的内存关系图，通过后回归本节点"
acceptance_criteria:
  - "能写出一个通过引用参数真正交换两个变量值的 swap 函数"
next_node: "b01-const"
prerequisites: ["a09-pointers"]
YAML

# ─────────────────────────────────────────────
# 阶段2：类型系统（11-20）
# ─────────────────────────────────────────────

write "b01-const.yaml" << 'YAML'
id: "b01-const"
title: "const 与常量"
progress_range: [22, 24]
phase: 2
phase_name: "类型系统"
order: 11
description: >
  const 不是注释，而是写进类型里的约束。这一关只讲 const 的约束由谁在
  什么阶段来执行。
core_concepts:
  - "const 是编译期类型约束：任何试图修改 const 变量的操作在编译期就会报错"
socratic_questions:
  - id: Q0_const_check
    level: "const 语义"
    text: "const int n = 5; 之后任何一行改它的代码都编译不过 —— 这个检查发生在什么阶段，为什么不需要把程序跑起来就能发现？"
interception:
  minimum_pass_line: "能说出 const 的约束是编译期类型检查，不是运行时保护"
  on_failure: "AI 演示 const 违约的编译期报错点，通过后回归本节点"
acceptance_criteria:
  - "能说出 const 修饰一个变量时，编译器对你做出了什么保证，以及 const 指针和指向 const 的指针有何不同"
next_node: "b02-string"
prerequisites: ["a10-references"]
YAML

write "b02-string.yaml" << 'YAML'
id: "b02-string"
title: "std::string"
progress_range: [24, 26]
phase: 2
phase_name: "类型系统"
order: 12
description: >
  std::string 自己管理字符缓冲区的生死。这一关只讲 string 扩容时
  早先持有的指针会发生什么。
core_concepts:
  - "string 扩容时整块重新分配缓冲区，之前通过 c_str() 取出的指针随即失效"
socratic_questions:
  - id: Q0_cstr_invalidation
    level: "缓冲区所有权"
    text: "const char* p = s.c_str(); 之后给 s 追加内容，p 看起来还在手里 —— 它指向的那块内存什么时候就不是原来那块了？"
interception:
  minimum_pass_line: "能说出 string 扩容会重新分配缓冲区，早先取出的 c_str() 指针随即失效"
  on_failure: "AI 用两次内存快照对比扩容前后的缓冲区地址，通过后回归本节点"
acceptance_criteria:
  - "能说出为什么对 string 追加内容后，之前保存的 c_str() 指针可能随时失效"
next_node: "b03-vector"
prerequisites: ["b01-const"]
YAML

write "b03-vector.yaml" << 'YAML'
id: "b03-vector"
title: "std::vector"
progress_range: [26, 28]
phase: 2
phase_name: "类型系统"
order: 13
description: >
  vector 是「一段连续内存 + 长度 + 容量」。这一关只讲扩容这件事
  对所有指向元素的指针做了什么。
core_concepts:
  - "push_back 触发扩容时整块搬家，所有指向旧缓冲区的迭代器和指针全部失效"
socratic_questions:
  - id: Q0_iterator_invalidation
    level: "迭代器失效"
    text: "for (auto& x : v) { v.push_back(x); } 看起来只是把元素复制一份追加到末尾，为什么随时可能读到已经不属于自己的内存？"
interception:
  minimum_pass_line: "能说出 range-for 持有指向旧缓冲区的迭代器，扩容搬家后它就成了悬垂引用"
  on_failure: "AI 用扩容前后两块缓冲区图演示迭代器失效，通过后回归本节点"
acceptance_criteria:
  - "能说出 vector 扩容时整块搬家会导致所有指向旧缓冲区的指针和迭代器失效"
next_node: "b04-map"
prerequisites: ["b02-string"]
YAML

write "b04-map.yaml" << 'YAML'
id: "b04-map"
title: "std::map 与哈希表"
progress_range: [28, 30]
phase: 2
phase_name: "类型系统"
order: 14
description: >
  map 按键有序查找，unordered_map 按哈希桶查找。这一关只讲
  为什么查找复杂度不同，以及什么情况下选哪个。
core_concepts:
  - "map 基于红黑树保证有序、查找 O(log n)；unordered_map 基于哈希桶、查找平均 O(1)"
socratic_questions:
  - id: Q0_map_vs_hash
    level: "容器选择"
    text: "同样是键值查找，map 和 unordered_map 内部结构完全不同 —— 当你只关心「找到了没有」而不在乎顺序，选哪个，为什么？"
interception:
  minimum_pass_line: "能说出 map 保证键有序而 unordered_map 不保证，并指出查找复杂度的差异"
  on_failure: "AI 画出红黑树与哈希桶的结构图，通过后回归本节点"
acceptance_criteria:
  - "能根据「是否需要有序遍历」和「查找性能要求」选出合适的容器并说明理由"
next_node: "b05-class"
prerequisites: ["b03-vector"]
YAML

write "b05-class.yaml" << 'YAML'
id: "b05-class"
title: "类与对象"
progress_range: [30, 33]
phase: 2
phase_name: "类型系统"
order: 15
description: >
  class 是把数据和操作它的函数打包在一起的机制。这一关只讲
  public 和 private 的边界意味着什么。
core_concepts:
  - "private 成员只能被本类的成员函数访问，封装把实现细节隐藏在类的边界内"
socratic_questions:
  - id: Q0_encapsulation
    level: "封装"
    text: "为什么把数据成员设为 private、只暴露 public 方法，反而比直接访问成员更安全 —— 这个「安全」到底体现在哪里？"
interception:
  minimum_pass_line: "能说出 private 让外部代码无法直接修改内部状态，对象始终通过方法维护自身不变式"
  on_failure: "AI 演示直接修改数据成员破坏不变式的场景，通过后回归本节点"
acceptance_criteria:
  - "能设计一个有 private 数据和 public 接口的简单类，并说明为什么不直接暴露数据成员"
next_node: "b06-constructor"
prerequisites: ["b04-map"]
YAML

write "b06-constructor.yaml" << 'YAML'
id: "b06-constructor"
title: "构造函数"
progress_range: [33, 36]
phase: 2
phase_name: "类型系统"
order: 16
description: >
  构造函数是把一块裸内存变成有效对象的唯一入口。这一关只讲
  初始化列表和函数体赋值发生在对象生命周期的哪两个不同时刻。
core_concepts:
  - "初始化列表在对象诞生时执行；进入函数体时成员已初始化完毕，函数体内写的是赋值"
socratic_questions:
  - id: Q0_init_list
    level: "初始化顺序"
    text: "一个成员是 const，写在函数体里赋值编译不过，写进初始化列表就行 —— 编译器在这两种写法之间看到的差别到底是什么？"
interception:
  minimum_pass_line: "能说出初始化列表在对象诞生时执行，进入函数体时成员已经初始化完毕"
  on_failure: "AI 按成员声明顺序逐条展开构造过程的时间线，通过后回归本节点"
acceptance_criteria:
  - "能说出成员初始化的实际顺序由声明顺序决定，而非初始化列表的书写顺序"
next_node: "b07-destructor"
prerequisites: ["b05-class"]
YAML

write "b07-destructor.yaml" << 'YAML'
id: "b07-destructor"
title: "析构函数"
progress_range: [36, 38]
phase: 2
phase_name: "类型系统"
order: 17
description: >
  析构函数是对象消失前最后一次执行代码的机会。这一关只讲它由谁触发，
  以及裸指针为什么不会触发它。
core_concepts:
  - "析构由对象的生命周期结束自动触发；new 出来的裸内存没有对象负责，不会自动释放"
socratic_questions:
  - id: Q0_missed_destructor
    level: "析构时机"
    text: "函数里 new 了一块内存，在后面 return 了 —— return 会触发局部对象的析构，那块 new 出来的内存却不会有事。同样是「函数结束」，差别从哪来？"
interception:
  minimum_pass_line: "能说出析构由对象生命周期结束自动触发，而 new 出来的是裸内存、没有对象替它负责"
  on_failure: "AI 用时间线演示裸内存如何在函数返回后永不释放，通过后回归本节点"
acceptance_criteria:
  - "能列举触发析构的三种时机，并说明为什么裸指针离开作用域时不会释放它指向的内存"
next_node: "b08-enum-namespace"
prerequisites: ["b06-constructor"]
YAML

write "b08-enum-namespace.yaml" << 'YAML'
id: "b08-enum-namespace"
title: "枚举与命名空间"
progress_range: [38, 40]
phase: 2
phase_name: "类型系统"
order: 18
description: >
  enum class 把一组相关常量封装成独立的类型。这一关只讲 enum class
  比老式 enum 多了哪一层保护。
core_concepts:
  - "enum class 的枚举值不会隐式转换为整数，不同枚举类型之间无法混用"
socratic_questions:
  - id: Q0_enum_class
    level: "类型安全"
    text: "老式 enum 的枚举值可以直接和 int 比较，enum class 的却不行 —— 这个限制是负担还是保护，它防止了什么？"
interception:
  minimum_pass_line: "能说出 enum class 的枚举值不会隐式转换为整数，防止不同枚举值被意外混用"
  on_failure: "AI 演示老式 enum 隐式转换导致的 bug 场景，通过后回归本节点"
acceptance_criteria:
  - "能用 enum class 定义一组状态常量，并说明它比 const int 和老式 enum 多了什么类型保证"
next_node: "b09-operator-overload"
prerequisites: ["b07-destructor"]
YAML

write "b09-operator-overload.yaml" << 'YAML'
id: "b09-operator-overload"
title: "运算符重载"
progress_range: [40, 42]
phase: 2
phase_name: "类型系统"
order: 19
description: >
  运算符重载让自定义类型能用 +、==、<< 等符号。这一关只讲
  什么时候重载是有意义的，以及不应该重载的情况。
core_concepts:
  - "运算符重载让类型融入语言的表达式语法，但语义必须与内置行为保持直觉一致"
socratic_questions:
  - id: Q0_overload_semantics
    level: "设计语义"
    text: "为什么 std::string 重载了 + 让人觉得自然，但如果一个 Money 类的 * 操作符乘出了另一个 Money，反而会让人困惑？"
interception:
  minimum_pass_line: "能说出运算符重载必须保持用户对该运算符的直觉期待，语义混乱的重载比不重载更危险"
  on_failure: "AI 举出两个好的和两个糟糕的运算符重载案例，通过后回归本节点"
acceptance_criteria:
  - "能为一个二维向量类实现 + 和 == 运算符，并说明为什么这两个值得重载"
next_node: "b10-inheritance"
prerequisites: ["b08-enum-namespace"]
YAML

write "b10-inheritance.yaml" << 'YAML'
id: "b10-inheritance"
title: "继承"
progress_range: [42, 45]
phase: 2
phase_name: "类型系统"
order: 20
description: >
  继承让子类复用基类的实现。这一关只讲 public 继承在语义上承诺了什么，
  以及什么情况下继承是一个糟糕的选择。
core_concepts:
  - "public 继承表达「是一种」关系：派生类对象可以当作基类对象使用"
socratic_questions:
  - id: Q0_liskov
    level: "继承语义"
    text: "如果 Square 继承自 Rectangle，在代码里用 Rectangle 指针操作 Square 时 setWidth 可能破坏它的不变式 —— 这说明继承关系在设计上出了什么问题？"
interception:
  minimum_pass_line: "能说出 public 继承要求派生类满足基类的所有契约，派生类不能弱化基类的行为保证"
  on_failure: "AI 演示 Square 继承 Rectangle 导致不变式被破坏的场景，通过后回归本节点"
acceptance_criteria:
  - "能说出什么时候应该用继承、什么时候应该用组合来表达两个类之间的关系"
next_node: "c01-virtual"
prerequisites: ["b09-operator-overload"]
YAML

# ─────────────────────────────────────────────
# 阶段3：语言核心机制（21-32）
# ─────────────────────────────────────────────

write "c01-virtual.yaml" << 'YAML'
id: "c01-virtual"
title: "虚函数与多态"
progress_range: [45, 48]
phase: 3
phase_name: "语言核心"
order: 21
description: >
  virtual 让同一行调用在运行时根据对象的真实类型执行不同的代码。
  这一关只讲虚表是什么，以及基类析构函数为什么必须是虚函数。
core_concepts:
  - "虚函数通过虚表在运行时分派调用；基类析构函数不加 virtual 会导致派生类的析构函数不被调用"
socratic_questions:
  - id: Q0_vtable
    level: "动态分派"
    text: "Base* p = new Derived(); p->func(); 调用的是 Derived::func 还是 Base::func —— 如果 func 是虚函数，决定调哪个的信息存在哪里，什么时候确定下来？"
interception:
  minimum_pass_line: "能说出虚表指针存在对象内，虚函数调用在运行时通过虚表找到实际函数"
  on_failure: "AI 画出对象内存布局中虚表指针的位置，通过后回归本节点"
acceptance_criteria:
  - "能说出为什么通过基类指针 delete 派生类对象时，基类析构函数必须是 virtual"
next_node: "c02-object-lifetime"
prerequisites: ["b10-inheritance"]
YAML

write "c02-object-lifetime.yaml" << 'YAML'
id: "c02-object-lifetime"
title: "对象生命周期"
progress_range: [48, 51]
phase: 3
phase_name: "语言核心"
order: 22
description: >
  对象从诞生到消亡，编译器保证析构一定会被调用。这一关只讲
  生命周期由作用域严格控制这一事实。
core_concepts:
  - "栈上对象的生命周期由作用域严格界定，退出作用域时析构函数一定被调用"
socratic_questions:
  - id: Q0_scope_lifetime
    level: "生命周期"
    text: "在一个 if 块里创建了一个对象，if 结束时它会被析构 —— 这件事是由谁在哪里决定的，你能绕过它吗？"
interception:
  minimum_pass_line: "能说出栈上对象的生命周期由作用域严格决定，编译器在退出作用域时自动插入析构调用"
  on_failure: "AI 用作用域嵌套图标出每个对象的构造和析构时刻，通过后回归本节点"
acceptance_criteria:
  - "能预测一段包含多个嵌套作用域的代码中，各对象构造和析构的先后顺序"
next_node: "c03-raii"
prerequisites: ["c01-virtual"]
YAML

write "c03-raii.yaml" << 'YAML'
id: "c03-raii"
title: "RAII"
progress_range: [51, 54]
phase: 3
phase_name: "语言核心"
order: 23
description: >
  RAII 是 C++ 与垃圾回收语言最本质的分水岭：把资源绑到对象的生命周期上。
  这一关只讲为什么这个模式能消灭大多数资源泄露。
core_concepts:
  - "RAII 把资源的获取放在构造函数、释放放在析构函数，作用域退出时资源自动释放"
socratic_questions:
  - id: Q0_raii
    level: "资源管理"
    text: "为什么用 RAII 管理文件句柄，即使函数中途抛出异常，文件也一定会被关闭 —— 如果用裸 fopen/fclose，你需要在哪些地方加 fclose 才能保证这一点？"
interception:
  minimum_pass_line: "能说出 RAII 利用析构函数的确定性调用来保证资源在任何退出路径上都被释放"
  on_failure: "AI 对比 RAII 和裸 fopen/fclose 在异常情况下的资源释放路径，通过后回归本节点"
acceptance_criteria:
  - "能写一个 RAII 包装类，把一个裸资源（如文件句柄）的获取和释放绑到对象的构造和析构上"
next_node: "c04-copy-semantics"
prerequisites: ["c02-object-lifetime"]
YAML

write "c04-copy-semantics.yaml" << 'YAML'
id: "c04-copy-semantics"
title: "拷贝语义"
progress_range: [54, 57]
phase: 3
phase_name: "语言核心"
order: 24
description: >
  编译器免费送给你的拷贝构造函数，做的事比你想象的少。这一关只讲
  浅拷贝在持有资源的类上为什么会产生双重释放。
core_concepts:
  - "默认拷贝构造是逐成员浅拷贝：指针成员拷的是地址，两个对象共享同一块资源"
socratic_questions:
  - id: Q0_shallow_copy
    level: "浅拷贝"
    text: "一个持有 int* 的类用默认拷贝构造，两个对象先后析构时同一块内存被 delete 两次 —— 默认拷贝到底复制了什么，又漏掉了什么？"
interception:
  minimum_pass_line: "能说出默认拷贝是逐成员浅拷贝，两个对象的指针成员指向同一块资源会导致双重释放"
  on_failure: "AI 画出拷贝前后两块对象与共享资源的关系图，标出双重释放点，通过后回归本节点"
acceptance_criteria:
  - "能说出持有资源的类为什么必须自定义拷贝构造函数，以及什么是深拷贝"
next_node: "c05-move-semantics"
prerequisites: ["c03-raii"]
YAML

write "c05-move-semantics.yaml" << 'YAML'
id: "c05-move-semantics"
title: "移动语义"
progress_range: [57, 60]
phase: 3
phase_name: "语言核心"
order: 25
description: >
  移动语义让资源所有权从一个对象转给另一个对象，而不是拷贝资源。
  这一关只讲右值引用是什么，以及移动后被移对象的状态。
core_concepts:
  - "移动构造接管资源所有权，被移对象进入「有效但未指定」状态，不能再假设它持有任何资源"
socratic_questions:
  - id: Q0_move
    level: "移动语义"
    text: "把一个 string 移动给另一个变量后，原变量还在 —— 它现在是什么状态，你还能对它做什么操作是安全的？"
interception:
  minimum_pass_line: "能说出移动后被移对象处于有效但未指定状态，只能对它赋值或析构，不能假设它包含原来的数据"
  on_failure: "AI 演示移动后访问被移对象导致的 bug，通过后回归本节点"
acceptance_criteria:
  - "能说出为什么 vector::push_back 优先使用移动而非拷贝，以及这个选择的前提条件"
next_node: "c06-object-layout"
prerequisites: ["c04-copy-semantics"]
YAML

write "c06-object-layout.yaml" << 'YAML'
id: "c06-object-layout"
title: "对象内存布局"
progress_range: [60, 63]
phase: 3
phase_name: "语言核心"
order: 26
description: >
  内存里的字节怎么排布，决定了 sizeof、序列化和跨库调用的行为。
  这一关只讲 padding 从哪里来。
core_concepts:
  - "每个成员要求对齐到自身大小的整数倍地址，编译器在成员之间插入 padding 以满足对齐要求"
socratic_questions:
  - id: Q0_layout
    level: "对齐"
    text: "两个成员完全相同的结构体，只调换声明顺序，sizeof 就可能不一样 —— 编译器在哪些位置插进了你看不见的字节？"
interception:
  minimum_pass_line: "能对一个给定结构体逐字段说出每处 padding 从哪个成员的对齐要求产生"
  on_failure: "AI 逐字段画出内存格子图演示 padding 的来源，通过后回归本节点"
acceptance_criteria:
  - "能指出一个结构体中每一处 padding 是因为哪个字段的对齐要求插进来的，并说明如何通过重排字段减少 padding"
next_node: "c07-exceptions"
prerequisites: ["c05-move-semantics"]
YAML

write "c07-exceptions.yaml" << 'YAML'
id: "c07-exceptions"
title: "异常处理"
progress_range: [63, 66]
phase: 3
phase_name: "语言核心"
order: 27
description: >
  异常是跨越调用栈传递错误的机制。这一关只讲栈展开发生时析构函数
  如何保证资源不泄露。
core_concepts:
  - "抛出异常时栈展开依次调用局部对象的析构函数，这是 RAII 能在异常路径上保证资源释放的原因"
socratic_questions:
  - id: Q0_stack_unwinding
    level: "栈展开"
    text: "函数 A 调用 B，B 调用 C，C 抛出异常，A 里的 catch 捕获了它 —— 从 C 到 A 之间的这段路上，哪些析构函数被调用了，按什么顺序？"
interception:
  minimum_pass_line: "能说出栈展开按调用栈的逆序调用局部对象的析构函数，直到找到匹配的 catch 块"
  on_failure: "AI 画出多层调用栈展开时析构函数的调用顺序，通过后回归本节点"
acceptance_criteria:
  - "能说出为什么析构函数里抛出异常是危险的，以及 noexcept 的含义"
next_node: "c08-smart-pointers"
prerequisites: ["c06-object-layout"]
YAML

write "c08-smart-pointers.yaml" << 'YAML'
id: "c08-smart-pointers"
title: "智能指针"
progress_range: [66, 69]
phase: 3
phase_name: "语言核心"
order: 28
description: >
  智能指针是把裸指针包进 RAII 对象里的标准做法。这一关只讲
  unique_ptr 的独占所有权意味着什么。
core_concepts:
  - "unique_ptr 独占资源所有权：不能拷贝，只能移动；离开作用域时自动 delete"
socratic_questions:
  - id: Q0_unique_ptr
    level: "所有权"
    text: "unique_ptr 不能拷贝，但可以移动 —— 为什么允许移动但禁止拷贝，它在保护什么？"
interception:
  minimum_pass_line: "能说出 unique_ptr 的不可拷贝性保证了同一时刻只有一个 unique_ptr 拥有某块资源"
  on_failure: "AI 演示禁止拷贝如何防止双重释放，通过后回归本节点"
acceptance_criteria:
  - "能说出 unique_ptr、shared_ptr 各自适合哪种所有权场景，以及 weak_ptr 解决了什么问题"
next_node: "c09-lambda"
prerequisites: ["c07-exceptions"]
YAML

write "c09-lambda.yaml" << 'YAML'
id: "c09-lambda"
title: "Lambda 表达式"
progress_range: [69, 72]
phase: 3
phase_name: "语言核心"
order: 29
description: >
  Lambda 是可以捕获局部变量的匿名函数对象。这一关只讲按值捕获和
  按引用捕获在悬垂引用上的区别。
core_concepts:
  - "按引用捕获的 lambda 如果比被捕获的变量活得更长，引用就变成悬垂引用"
socratic_questions:
  - id: Q0_capture
    level: "捕获语义"
    text: "auto f = [&x]() { return x; }; 如果这个 lambda 被存进一个 vector 传到别处使用，x 已经离开作用域了 —— 调用 f 时会发生什么？"
interception:
  minimum_pass_line: "能说出按引用捕获的变量离开作用域后 lambda 仍持有悬垂引用，调用它是未定义行为"
  on_failure: "AI 演示悬垂引用捕获的崩溃现场，通过后回归本节点"
acceptance_criteria:
  - "能说出在哪种情况下必须用按值捕获而不是按引用捕获，并解释 mutable lambda 的用途"
next_node: "c10-templates"
prerequisites: ["c08-smart-pointers"]
YAML

write "c10-templates.yaml" << 'YAML'
id: "c10-templates"
title: "模板基础"
progress_range: [72, 75]
phase: 3
phase_name: "语言核心"
order: 30
description: >
  模板是编译器手里的代码生成器，不是运行时的多态。这一关只讲
  实例化在什么阶段发生，以及模板定义为什么必须在头文件里。
core_concepts:
  - "模板实例化发生在编译期：每个类型参数各自生成一份独立代码，因此定义必须对使用方可见"
socratic_questions:
  - id: Q0_instantiation
    level: "实例化时机"
    text: "一个函数模板分别被 int 和 double 调用，编译出来的目标文件里躺着两个函数 —— 这件事是在什么阶段发生的，又是谁把它们写进去的？"
interception:
  minimum_pass_line: "能说出实例化发生在编译期，因此模板定义必须对使用它的翻译单元完全可见"
  on_failure: "AI 对比模板源码与实例化后的符号表，演示两处调用如何变成两个函数，通过后回归本节点"
acceptance_criteria:
  - "能说出模板实例化发生在什么阶段，以及为什么模板定义通常要写在头文件里"
next_node: "c11-concepts"
prerequisites: ["c09-lambda"]
YAML

write "c11-concepts.yaml" << 'YAML'
id: "c11-concepts"
title: "Concepts 泛型约束"
progress_range: [75, 78]
phase: 3
phase_name: "语言核心"
order: 31
description: >
  Concepts 让你把对模板参数的要求写进类型系统。这一关只讲
  为什么 Concepts 的报错比 SFINAE 清晰。
core_concepts:
  - "concept 把模板参数的约束显式写出来，违反约束时编译器直接指出哪个需求没满足"
socratic_questions:
  - id: Q0_concept
    level: "约束表达"
    text: "同样是模板参数不满足要求，SFINAE 给你几屏幕的模板展开报错，Concepts 只给你一行 —— 这个差别是从哪里来的？"
interception:
  minimum_pass_line: "能说出 concept 把约束变成类型系统的一部分，编译器可以直接报告哪个约束未满足"
  on_failure: "AI 并排展示同一错误的 SFINAE 报错和 Concepts 报错，通过后回归本节点"
acceptance_criteria:
  - "能写一个要求类型支持 < 运算符的 concept，并把它用在一个排序函数的模板参数上"
next_node: "c12-modern-frontier"
prerequisites: ["c10-templates"]
YAML

write "c12-modern-frontier.yaml" << 'YAML'
id: "c12-modern-frontier"
title: "C++20 核心新特性"
progress_range: [78, 80]
phase: 3
phase_name: "语言核心"
order: 32
description: >
  C++20 带来了 Ranges、协程框架、std::span 等重要工具。这一关只讲
  std::span 解决了什么问题。
core_concepts:
  - "std::span 是对一段连续内存的非拥有视图，消除了裸指针加长度这对参数的传递模式"
socratic_questions:
  - id: Q0_span
    level: "视图"
    text: "函数接收数组时，你通常需要同时传 T* 和 size_t —— std::span 把这两者合成一个参数，它是怎么表达「我不拥有这段内存」这件事的？"
interception:
  minimum_pass_line: "能说出 std::span 是非拥有视图，不管理内存的生命周期，只是对一段已存在内存的引用"
  on_failure: "AI 对比旧式指针加长度与 span 的参数风格，通过后回归本节点"
acceptance_criteria:
  - "能用 std::span 重写一个接收 C 风格数组的函数，并说明这样做的好处"
next_node: "d01-threads"
prerequisites: ["c11-concepts"]
YAML

# ─────────────────────────────────────────────
# 阶段4：并发编程（33-38）
# ─────────────────────────────────────────────

write "d01-threads.yaml" << 'YAML'
id: "d01-threads"
title: "线程生命周期"
progress_range: [80, 83]
phase: 4
phase_name: "并发编程"
order: 33
description: >
  线程是独立的执行流，共享进程的内存。这一关只讲线程的创建、join 的必要性，
  以及忘记 join 会发生什么。
core_concepts:
  - "std::thread 析构时如果既未 join 也未 detach，程序会调用 std::terminate"
socratic_questions:
  - id: Q0_thread_lifetime
    level: "线程生命周期"
    text: "创建了一个 std::thread 对象，函数结束时它析构了 —— 如果线程还在跑，这个析构会做什么？"
interception:
  minimum_pass_line: "能说出 thread 析构时若既未 join 也未 detach 程序会终止，join 的语义是等待线程完成"
  on_failure: "AI 演示未 join 的线程在析构时导致程序终止的场景，通过后回归本节点"
acceptance_criteria:
  - "能说出 join 和 detach 在语义上的区别，以及什么情况下该用哪个"
next_node: "d02-mutex"
prerequisites: ["c12-modern-frontier"]
YAML

write "d02-mutex.yaml" << 'YAML'
id: "d02-mutex"
title: "互斥锁"
progress_range: [83, 86]
phase: 4
phase_name: "并发编程"
order: 34
description: >
  mutex 保护共享数据的访问，lock_guard 用 RAII 保证锁一定被释放。
  这一关只讲死锁是如何产生的。
core_concepts:
  - "死锁发生在两个线程各持一把锁并等待对方的锁，打破方法是统一加锁顺序"
socratic_questions:
  - id: Q0_deadlock
    level: "死锁"
    text: "线程 A 持有锁 1 等锁 2，线程 B 持有锁 2 等锁 1 —— 两者都在等对方，程序永远不前进。要打破这个局面，最简单的规则是什么？"
interception:
  minimum_pass_line: "能说出死锁的四个必要条件，并指出统一加锁顺序如何打破循环等待"
  on_failure: "AI 画出死锁的资源等待图，通过后回归本节点"
acceptance_criteria:
  - "能写出一个会导致死锁的最小代码示例，并说明如何通过调整加锁顺序来修复它"
next_node: "d03-async-coroutine"
prerequisites: ["d01-threads"]
YAML

write "d03-async-coroutine.yaml" << 'YAML'
id: "d03-async-coroutine"
title: "协程与异步"
progress_range: [86, 89]
phase: 4
phase_name: "并发编程"
order: 35
description: >
  协程把函数切成可挂起的片段，co_await 把控制权交还给调用方。这一关只讲
  协程帧里的局部变量为什么会比线程上的更容易产生悬垂引用。
core_concepts:
  - "协程帧在堆上分配，co_await 挂起后局部变量仍存在；跨越 co_await 传引用危险在于对象可能在恢复前已析构"
socratic_questions:
  - id: Q0_coroutine
    level: "协程"
    text: "co_await 挂起之后，这个函数的局部变量存在哪里 —— 为什么『悬垂引用』在协程里比在普通函数里更难被发现？"
interception:
  minimum_pass_line: "能说出协程帧在堆上存活，挂起期间局部变量依然有效，但引用可能指向已析构的外部对象"
  on_failure: "AI 画出协程帧与事件循环的交接时序，通过后回归本节点"
acceptance_criteria:
  - "能指出跨越 co_await 传递的引用为什么能在寻常代码里难以发现的时刻变成悬垂引用"
next_node: "d04-memory-order"
prerequisites: ["d02-mutex"]
YAML

write "d04-memory-order.yaml" << 'YAML'
id: "d04-memory-order"
title: "原子操作与内存序"
progress_range: [89, 92]
phase: 4
phase_name: "并发编程"
order: 36
description: >
  原子操作保证单个读写不被撕裂，内存序控制不同线程看到写入的顺序。
  这一关只讲 release/acquire 如何建立 happens-before。
core_concepts:
  - "release 写入在 acquire 读取之前的所有写操作对后者可见，这就是 happens-before 关系"
socratic_questions:
  - id: Q0_memory_order
    level: "内存序"
    text: "在 relaxed 下两个线程看到的写入顺序可以互相矛盾，release/acquire 这一对凭什么建立 happens-before —— 它究竟约束了谁、禁止了哪一次重排？"
interception:
  minimum_pass_line: "能说出 release/acquire 凭什么建立 happens-before，以及它禁止了哪一次编译器或 CPU 的重排"
  on_failure: "AI 用两个线程的指令重排图演示可见性问题，通过后回归本节点"
acceptance_criteria:
  - "能为一个简单的 producer/consumer 场景选出正确的内存序，并说明换成 relaxed 会坏在哪"
next_node: "e01-build-system"
prerequisites: ["d03-async-coroutine"]
YAML

# ─────────────────────────────────────────────
# 阶段5：工程实践（39-46）
# ─────────────────────────────────────────────

write "e01-build-system.yaml" << 'YAML'
id: "e01-build-system"
title: "编译链接过程"
progress_range: [92, 94]
phase: 5
phase_name: "工程实践"
order: 37
description: >
  一个 .cpp 文件要经历预处理、编译、汇编、链接四步才能变成可执行文件。
  这一关只讲符号解析发生在链接期而不是编译期。
core_concepts:
  - "编译器按翻译单元独立编译，符号解析由链接器完成，这就是为什么 undefined reference 是链接错误"
socratic_questions:
  - id: Q0_linker
    level: "链接"
    text: "你在一个 .cpp 里调用了一个别的文件里定义的函数，编译顺利通过，链接却报 undefined reference —— 编译器明明看见了这次调用，为什么它当时不报错？"
interception:
  minimum_pass_line: "能说出编译器只处理当前翻译单元，符号解析留到链接期，链接器才知道所有翻译单元的符号表"
  on_failure: "AI 用四步流水线图解释符号解析在哪步发生，通过后回归本节点"
acceptance_criteria:
  - "能画出从 hello.cpp 到可执行文件的四步流水线，并标出符号解析发生在哪一步"
next_node: "e02-cmake"
prerequisites: ["d04-memory-order"]
YAML

write "e02-cmake.yaml" << 'YAML'
id: "e02-cmake"
title: "CMake 构建系统"
progress_range: [94, 96]
phase: 5
phase_name: "工程实践"
order: 38
description: >
  CMake 用 target 模型描述构建目标之间的依赖关系。这一关只讲
  全局 include_directories 为什么随着依赖增多会变成灾难。
core_concepts:
  - "target 级依赖精确描述哪个目标需要什么，全局配置把所有目标的依赖摊平成了难以追踪的隐式关系"
socratic_questions:
  - id: Q0_target
    level: "构建"
    text: "CMakePresets 把跟着机器走的配置搬出了 CMakeLists，而全局 include_directories 却把一切摊平给所有目标 —— 为什么依赖一多，后者就变成了灾难？"
interception:
  minimum_pass_line: "能把一处全局配置改写成 target 级依赖，并说清它解决了什么传递性问题"
  on_failure: "AI 并排展示全局配置与 target 级配置的依赖图，通过后回归本节点"
acceptance_criteria:
  - "能把一处全局 include_directories 改写成 target_include_directories，并说明传递性 PUBLIC/PRIVATE 的区别"
next_node: "e03-sanitizers"
prerequisites: ["e01-build-system"]
YAML

write "e03-sanitizers.yaml" << 'YAML'
id: "e03-sanitizers"
title: "调试工具与消毒器"
progress_range: [96, 97]
phase: 5
phase_name: "工程实践"
order: 39
description: >
  AddressSanitizer 和 Valgrind 能找到运行时才暴露的内存错误。这一关只讲
  消毒器能发现什么、又必然漏掉什么。
core_concepts:
  - "ASan 通过影子内存检测越界和释放后使用，但不能检测逻辑错误和并发数据竞争"
socratic_questions:
  - id: Q0_sanitizer
    level: "工具"
    text: "AddressSanitizer 能抓到越界和 use-after-free，却对数据竞争束手无策 —— 这两类错误在检测机制上的本质差别是什么？"
interception:
  minimum_pass_line: "能说出 ASan 检测内存访问模式、TSan 检测线程间访问模式，它们针对的是不同类别的错误"
  on_failure: "AI 给出一个带缺陷的最小样例和消毒器输出，通过后回归本节点"
acceptance_criteria:
  - "能说出 ASan、TSan、UBSan 各自能发现哪一类缺陷，以及如何在编译时启用它们"
next_node: "e04-testing"
prerequisites: ["e02-cmake"]
YAML

write "e04-testing.yaml" << 'YAML'
id: "e04-testing"
title: "自动化测试"
progress_range: [97, 98]
phase: 5
phase_name: "工程实践"
order: 40
description: >
  测试不是写完代码之后的补充，而是对代码行为的可执行文档。这一关只讲
  模糊测试如何在没有断言的情况下发现缺陷。
core_concepts:
  - "模糊测试通过崩溃、超时、消毒器报告来判断自己撞出了缺陷，不依赖预设断言"
socratic_questions:
  - id: Q0_fuzzing
    level: "测试"
    text: "一个函数的单元测试全部通过，模糊测试还能替你发现什么 —— 它在没有断言的情况下，凭什么判断自己撞出了缺陷？"
interception:
  minimum_pass_line: "能说出模糊测试依赖崩溃或消毒器报告来检测缺陷，单元测试只覆盖你已知的输入空间"
  on_failure: "AI 用一个解析函数演示崩溃输入如何被模糊测试撞出来，通过后回归本节点"
acceptance_criteria:
  - "能为一个解析函数写出一个真正能撞出崩溃输入的模糊测试入口"
next_node: "e05-design-patterns"
prerequisites: ["e03-sanitizers"]
YAML

write "e05-design-patterns.yaml" << 'YAML'
id: "e05-design-patterns"
title: "依赖方向"
progress_range: [98, 99]
phase: 5
phase_name: "工程实践"
order: 41
description: >
  设计模式的名字不重要，依赖指向哪边才重要。这一关只讲
  依赖倒置让测试不必启动真实依赖项。
core_concepts:
  - "依赖倒置：高层模块依赖抽象接口，低层模块实现抽象接口，测试可以注入假实现"
socratic_questions:
  - id: Q0_dip
    level: "依赖方向"
    text: "为什么让业务层直接 include 数据库头文件，会逼得测试必须启动一个真数据库 —— 把依赖反过来，究竟是哪一行代码发生了移动？"
interception:
  minimum_pass_line: "能说清依赖倒置改变了哪条编译期依赖，而不只是多了一层接口"
  on_failure: "AI 画出两种依赖方向的模块图，通过后回归本节点"
acceptance_criteria:
  - "能把一处编译期耦合改写成可替换的接口边界，并说明测试因此得到了什么"
next_node: "f01-networking"
prerequisites: ["e04-testing"]
YAML

# ─────────────────────────────────────────────
# 阶段6：系统编程（42-50）
# ─────────────────────────────────────────────

write "f01-networking.yaml" << 'YAML'
id: "f01-networking"
title: "TCP 字节流"
progress_range: [99, 100]
phase: 6
phase_name: "系统编程"
order: 42
description: >
  TCP 只交给你一段字节流，结构和边界都得自己造。这一关只讲
  消息定界是应用层的责任，不是内核的责任。
core_concepts:
  - "TCP 字节流没有内置消息边界，应用层必须自己定义定界方案"
socratic_questions:
  - id: Q0_framing
    level: "网络"
    text: "TCP 只交给你字节流，内核从不标记边界，一次 send 可能被拆成几段到达 —— 那么「一条完整消息」这个概念，只能由谁在什么位置造出来？"
interception:
  minimum_pass_line: "能说清 TCP 字节流中一条完整消息的定界由应用层在接收端造出来"
  on_failure: "AI 画出一次发送在接收端被拆分的过程，通过后回归本节点"
acceptance_criteria:
  - "能说出至少两种消息定界方案（固定长度、长度前缀、分隔符），并指出各自的适用场景"
next_node: "f02-process"
prerequisites: ["e05-design-patterns"]
YAML

write "f02-process.yaml" << 'YAML'
id: "f02-process"
title: "进程与信号"
progress_range: [100, 101]
phase: 6
phase_name: "系统编程"
order: 43
description: >
  进程边界是地址空间的硬边界，信号是唯一能异步越过它的中断。这一关只讲
  信号处理函数里哪些操作是安全的。
core_concepts:
  - "信号处理函数只能调用 async-signal-safe 函数，printf 和 malloc 都不在此列"
socratic_questions:
  - id: Q0_signal
    level: "系统"
    text: "信号处理函数被调用的那一刻，主线程可能正持有某把锁 —— 为什么 printf 和 malloc 在这里都不安全，它们共同依赖的那个保证是什么？"
interception:
  minimum_pass_line: "能指出信号处理函数只能调用 async-signal-safe 函数，并说明为什么 printf 不是"
  on_failure: "AI 演示信号打断临界区导致死锁的现场，通过后回归本节点"
acceptance_criteria:
  - "能列出信号处理函数中的安全操作边界，并写出一个只做标记的信号处理器"
next_node: "f03-performance"
prerequisites: ["f01-networking"]
YAML

write "f03-performance.yaml" << 'YAML'
id: "f03-performance"
title: "性能与缓存"
progress_range: [101, 102]
phase: 6
phase_name: "系统编程"
order: 44
description: >
  性能问题的答案几乎总在内存访问模式上，而不是在算法常数里。这一关只讲
  先测量、再优化，以及缓存行如何决定访问顺序的重要性。
core_concepts:
  - "缓存行一次加载 64 字节：顺序访问命中缓存，跳跃访问每次都要等内存，这就是访问顺序比运算次数更决定性能的原因"
socratic_questions:
  - id: Q0_cache
    level: "性能"
    text: "同一个二维数组，只是把内外层循环调换顺序，耗时就能差好几倍 —— 缓存行在这中间到底做了什么，以至于访问顺序比运算次数更决定性能？"
interception:
  minimum_pass_line: "能解释访问顺序为什么比运算次数更决定性能，并说清缓存行在其中的作用机制"
  on_failure: "AI 展示同一算法的两种遍历顺序的性能计数器差异，通过后回归本节点"
acceptance_criteria:
  - "能用基线对比的数据证明一次访问模式优化确实有效，而不是凭感觉说快了"
next_node: "f04-comprehensive"
prerequisites: ["f02-process"]
YAML

write "f04-comprehensive.yaml" << 'YAML'
id: "f04-comprehensive"
title: "综合实战：高并发服务"
progress_range: [102, 105]
phase: 6
phase_name: "系统编程"
order: 45
description: >
  把前面所有机制整合成一个真实系统。这一关是对所有阶段的综合验证，
  不讲新知识，只验证能否把内存安全、并发、性能、工程实践整合使用。
core_concepts:
  - "工程能力：能把内存安全、并发模型、I/O 模型、构建系统、测试整合进一个可运行的服务"
socratic_questions:
  - id: Q0_design
    level: "综合"
    text: "从零设计一个处理并发 TCP 连接的服务，你需要在内存管理、线程模型、I/O 模型、消息定界上各做出一个选择 —— 说出你的选择以及理由。"
interception:
  minimum_pass_line: "能对上述四个维度各说出一个合理的设计选择及其权衡"
  on_failure: "AI 提供一个最小可运行的高并发服务骨架，通过后回归本节点"
acceptance_criteria:
  - "能独立写出一个能处理并发连接、正确管理内存、不会泄露资源的 TCP 服务最小实现"
next_node: null
prerequisites: ["f03-performance"]
YAML

echo "=== 生成完成，共 $(ls $DIR/*.yaml | wc -l) 个节点 ==="
