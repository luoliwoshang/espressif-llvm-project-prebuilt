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

### 构建脚本关键逻辑

#### 环境变量配置 (release.sh:6-13)
```bash
set -e                                    # 遇到错误立即退出
TAG="${TAG:-19.1.2_20250312}"           # TAG 默认值，可通过环境变量覆盖
VERSION_STRING="$TAG"                    # 版本字符串
LLVM_PROJECTDIR="${LLVM_PROJECTDIR:-llvm-project}"  # LLVM 源码目录默认
BUILD_DIR_BASE="${BUILD_DIR_BASE:-build}"           # 构建目录默认
```

#### 分支名自动推导 (release.sh:14-16)
```bash
LLVM_VERSION_FROM_TAG="${TAG%%_*}"       # 从 TAG 提取版本号 (19.1.2_20250312 → 19.1.2)
LLVM_BRANCH="xtensa_release_${LLVM_VERSION_FROM_TAG}"  # 生成分支名 (xtensa_release_19.1.2)
```

#### macOS SDK 配置 (release.sh:27-33)
```bash
if [[ "$HOST_OS" == "Darwin" ]]; then
    if [[ -z "$SDKROOT" ]]; then
        export SDKROOT="$(xcrun --show-sdk-path)"  # 自动获取 macOS SDK 路径
        echo "Setting SDKROOT to: $SDKROOT"
    fi
fi
```

### 使用示例
```bash
# 默认构建
./release.sh x86_64-linux-gnu

# 自定义版本
TAG=19.1.3_20250401 ./release.sh x86_64-linux-gnu

# 自定义多参数
TAG=19.1.3_20250401 LLVM_PROJECTDIR=my-llvm BUILD_DIR_BASE=mybuild ./release.sh x86_64-linux-gnu
```