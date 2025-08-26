# Espressif LLVM 项目文档

## 二进制发布机制 (2025-08-26)

### 核心发现
通过 GitHub Actions 自动构建和发布 espclang 工具链到 GitHub Releases 页面

### 发布流程
1. **触发条件**: Git 标签推送 / PR 更新 / 手动触发
2. **构建矩阵**: 4个平台并行构建 (Linux x86_64/ARM64, macOS x86_64/ARM64)
3. **构建过程**: 下载 Espressif LLVM 源码 → CMake 配置 → Ninja 编译 → 打包
4. **发布机制**: 自动创建 GitHub Release 并上传二进制包

### 关键文件
- 工作流配置: `.github/workflows/release.yml:3-26` (触发条件)
- 构建脚本: `release.sh:218-226` (打包逻辑)  
- Release 创建: `.github/workflows/release.yml:162-169`

### 标签推送方式
- **命令行**: `git tag 版本号 && git push origin 版本号`
- **GitHub 网页**: "Create a new release" 自动创建标签并推送
- **效果**: 触发自动构建 → 生成 `clang-esp-{版本}-{平台}.tar.xz`

### 输出产物
4个平台的压缩包发布到 GitHub Releases 页面：
- `clang-esp-{版本}-x86_64-linux-gnu.tar.xz`
- `clang-esp-{版本}-aarch64-linux-gnu.tar.xz`
- `clang-esp-{版本}-x86_64-apple-darwin.tar.xz`
- `clang-esp-{版本}-aarch64-apple-darwin.tar.xz`

### 构建时间
几十分钟到几小时 (视平台而定)

### 版本格式
`19.1.2_20250312` → 对应 LLVM 分支 `xtensa_release_19.1.2`

### 构建平台详情
- **Linux x86_64**: Ubuntu 22.04
- **Linux ARM64**: Ubuntu 22.04 ARM 
- **macOS x86_64**: macOS 13
- **macOS ARM64**: macOS 14

### 工作流程详解
1. **prepare job**: 确定版本标签和上传设置
2. **build job**: 4个平台并行构建，执行 `./release.sh {platform}`
3. **release job**: 仅在标签推送时创建 GitHub Release 并上传构建产物