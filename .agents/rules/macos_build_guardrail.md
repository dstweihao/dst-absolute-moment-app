# macOS 构建与 CodeSign Detritus 免疫规范 (macOS Detritus Guardrail)

适用范围：macOS 平台桌面应用构建、打包脚本与签名流程（尤其是工程位于 Documents、iCloud 或坚果云等云同步盘时）。

## 1. 签名失败根因防范
- 在 macOS 同步目录中，系统会自动为 `.bundle`、`.framework` 与 App 目录附加 `com.apple.FinderInfo` 扩展属性。
- codesign 工具执行时会因上述属性报错：`resource fork, Finder information, or similar detritus not allowed`。
- 普通的 `xattr -c` 有时无法穿透所有子 bundle 的 FinderInfo，必须显式递归剥离。

## 2. 终极签名免疫清洗流水线
在应用构建完成、执行 codesign 前，**必须严格执行以下原子清洗命令**：
```bash
# 1. 彻底清除隐藏废料文件
find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true

# 2. 显式递归剥离 FinderInfo（核心致命关键）
xattr -r -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
find "$APP_BUNDLE" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true

# 3. 剥离所有常规扩展属性并合并
find "$APP_BUNDLE" -type f -exec xattr -c {} + 2>/dev/null || true
find "$APP_BUNDLE" -type d -exec xattr -c {} + 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
dot_clean -m "$APP_BUNDLE" 2>/dev/null || true

# 4. 深度签名
codesign --force --deep --sign - "$APP_BUNDLE"
```

## 3. Xcode 配置配合
在 Xcode 项目配置中，Release 配置可设置 `CODE_SIGNING_ALLOWED = NO;`，跳过 Xcode 内部带严格 detritus 检查的提前中断，由外部打包分发脚本在清理后再行自签名。
