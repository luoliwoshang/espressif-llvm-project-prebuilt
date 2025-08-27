#!/bin/bash
# Espressif LLVM Cross-Platform Release Builder
# Usage: ./release.sh <platform>
# Based on the working Makefile and build script

# 遇到任何错误立即退出脚本（命令返回非零退出码时）
# 防止错误发生后继续执行，避免连锁失败
set -e

# Configuration
# 版本标签：如果环境变量 TAG 存在则使用它，否则使用默认值 19.1.2_20250312
TAG="${TAG:-19.1.2_20250312}"
VERSION_STRING="$TAG"
# LLVM 源码目录名：如果环境变量 LLVM_PROJECTDIR 存在则使用它，否则使用默认值 "llvm-project"
LLVM_PROJECTDIR="${LLVM_PROJECTDIR:-llvm-project}"
# 构建目录基础名：如果环境变量 BUILD_DIR_BASE 存在则使用它，否则使用默认值 "build"
BUILD_DIR_BASE="${BUILD_DIR_BASE:-build}"

# Extract version from TAG to determine branch name
# 从版本标签中提取版本号：bash字符串截取操作 ${TAG%%_*}
# %%_* 表示从右边开始删除第一个 _ 及其后面的所有字符 (19.1.2_20250312 → 19.1.2)
LLVM_VERSION_FROM_TAG="${TAG%%_*}"
# 生成 LLVM 分支名：bash字符串拼接 "xtensa_release_${变量名}"
# 将版本号拼接到 xtensa_release_ 后面 (xtensa_release_19.1.2)
LLVM_BRANCH="xtensa_release_${LLVM_VERSION_FROM_TAG}"

# Detect host system
# 检测当前系统类型：通过检查 bash 内置变量 $OSTYPE 和环境变量 $WINDIR
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
    # Windows 系统：msys(MSYS2环境) 或 win32 或存在 WINDIR 环境变量
    HOST_OS="Windows_NT"
    EXE=".exe"  # Windows 可执行文件后缀
else
    # 非 Windows 系统：使用 uname -s 命令获取内核名称 (Linux/Darwin等)
    HOST_OS="$(uname -s)"  # 命令替换：执行 uname -s 并将输出赋给变量
    EXE=""  # Linux/macOS 可执行文件无后缀
fi

# Set macOS SDK root if on macOS
# 如果是 macOS 系统 (Darwin)，设置 SDK 根路径
if [[ "$HOST_OS" == "Darwin" ]]; then
    # 检查 SDKROOT 环境变量是否为空 (-z 表示字符串为空或不存在)
    if [[ -z "$SDKROOT" ]]; then
        # 使用 xcrun 命令自动获取当前 macOS SDK 路径并导出为环境变量
        export SDKROOT="$(xcrun --show-sdk-path)"  # 命令替换：获取 SDK 路径
        echo "Setting SDKROOT to: $SDKROOT"  # 显示设置的 SDK 路径
    fi
fi

# Supported build targets (native builds only)
VALID_TARGETS="aarch64-apple-darwin aarch64-linux-gnu x86_64-apple-darwin x86_64-linux-gnu"

# Function to show usage
show_usage() {
    echo "Espressif LLVM Cross-Platform Release Builder"
    echo ""
    echo "Usage: $0 <platform>"
    echo ""
    echo "Supported platforms:"
    for target in $VALID_TARGETS; do
        echo "  - $target"
    done
    echo ""
    echo "Environment variables:"
    echo "  TAG              - Version tag (default: $TAG)"
    echo "  LLVM_PROJECTDIR  - LLVM source directory (default: $LLVM_PROJECTDIR)"
    echo "  BUILD_DIR_BASE   - Build directory base (default: $BUILD_DIR_BASE)"
    echo ""
}

# Function to download LLVM source
download_llvm_source() {
    if [[ ! -d "$LLVM_PROJECTDIR" ]]; then
        echo "Cloning LLVM project branch $LLVM_BRANCH..."
        git clone -b "$LLVM_BRANCH" --depth=1 https://github.com/espressif/llvm-project "$LLVM_PROJECTDIR"
    else
        echo "LLVM project directory already exists."
    fi
}

# Base CMake arguments - common to all platforms
# bash 函数：返回所有平台通用的 CMake 配置参数
# 调用方式：$(get_base_cmake_args) 或 get_base_cmake_args
get_base_cmake_args() {
    # Here Document 语法：将 EOF 之间的内容输出到标准输出
    cat << 'EOF'
-G Ninja
-DCMAKE_BUILD_TYPE=Release
-DLLVM_TARGETS_TO_BUILD=X86;ARM;AArch64;AVR;Mips;RISCV;WebAssembly
-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Xtensa
-DLLVM_ENABLE_PROJECTS=clang;lld
-DLLVM_ENABLE_RUNTIMES=compiler-rt;libcxx;libcxxabi;libunwind
-DLLVM_POLLY_LINK_INTO_TOOLS=ON
-DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON
-DLLVM_ENABLE_EH=ON
-DLLVM_ENABLE_RTTI=ON
-DLLVM_INCLUDE_DOCS=OFF
-DLLVM_INCLUDE_EXAMPLES=OFF
-DLLVM_INCLUDE_TESTS=OFF
-DLLVM_INCLUDE_BENCHMARKS=OFF
-DLLVM_BUILD_DOCS=OFF
-DLLVM_ENABLE_DOXYGEN=OFF
-DLLVM_INSTALL_UTILS=ON
-DLLVM_ENABLE_Z3_SOLVER=OFF
-DLLVM_OPTIMIZED_TABLEGEN=ON
-DLLVM_USE_RELATIVE_PATHS_IN_FILES=ON
-DLLVM_SOURCE_PREFIX=.
-DLIBCXX_INSTALL_MODULES=ON
-DCLANG_FORCE_MATCHING_LIBCLANG_SOVERSION=OFF
-DCOMPILER_RT_BUILD_SANITIZERS=OFF
-DCOMPILER_RT_BUILD_XRAY=OFF
-DCOMPILER_RT_BUILD_LIBFUZZER=OFF
-DCOMPILER_RT_BUILD_PROFILE=OFF
-DCOMPILER_RT_BUILD_MEMPROF=OFF
-DCOMPILER_RT_BUILD_ORC=OFF
-DCOMPILER_RT_BUILD_GWP_ASAN=OFF
-DCOMPILER_RT_BUILD_CTX_PROFILE=OFF
-DCMAKE_POSITION_INDEPENDENT_CODE=ON
-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF
-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON
-DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON
-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
-DLIBCXX_STATICALLY_LINK_ABI_IN_SHARED_LIBRARY=OFF
-DLIBCXX_STATICALLY_LINK_ABI_IN_STATIC_LIBRARY=ON
-DLIBCXX_USE_COMPILER_RT=ON
-DLIBCXX_HAS_ATOMIC_LIB=OFF
-DLIBCXXABI_ENABLE_STATIC_UNWINDER=ON
-DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_SHARED_LIBRARY=OFF
-DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_STATIC_LIBRARY=ON
-DLIBCXXABI_USE_COMPILER_RT=ON
-DLIBCXXABI_USE_LLVM_UNWINDER=ON
-DLIBUNWIND_USE_COMPILER_RT=ON
-DSANITIZER_CXX_ABI=libc++
-DSANITIZER_TEST_CXX=libc++
-DLLVM_LINK_LLVM_DYLIB=ON
-DCLANG_LINK_CLANG_DYLIB=ON
-DCMAKE_STRIP=/usr/bin/strip
EOF
}

# macOS-specific CMake arguments
# bash 函数：返回 macOS 特定的 CMake 配置参数
# 参数：$1 目标平台 (aarch64-apple-darwin 或 x86_64-apple-darwin)
get_macos_cmake_args() {
    local target="$1"  # 本地变量：目标平台
    local arch         # 本地变量：CPU 架构

    # 根据目标平台确定 CPU 架构
    if [[ "$target" == "aarch64-apple-darwin" ]]; then
        arch="arm64"    # Apple Silicon (M1/M2等)
    else
        arch="x86_64"   # Intel Mac
    fi

    # Here Document：输出 macOS 特定的 CMake 参数
    cat << EOF
-DLLVM_BUILD_LLVM_C_DYLIB=ON
-DLLVM_ENABLE_LIBCXX=ON
-DLIBCXX_PSTL_BACKEND=libdispatch
-DCMAKE_OSX_SYSROOT=$SDKROOT
-DCMAKE_OSX_ARCHITECTURES=$arch
-DLIBCXXABI_USE_SYSTEM_LIBS=ON
EOF
}

# Linux-specific CMake arguments
get_linux_cmake_args() {
    cat << 'EOF'
-DLLVM_ENABLE_LIBXML2=OFF
-DLLVM_ENABLE_LIBCXX=OFF
-DCLANG_DEFAULT_CXX_STDLIB=libstdc++
-DLLVM_BUILD_LLVM_DYLIB=ON
-DCOMPILER_RT_USE_LLVM_UNWINDER=ON
EOF
}

# Function to get platform-specific CMake arguments
# bash 函数：根据目标平台自动选择相应的 CMake 配置函数
# 参数：$1 目标平台 (如 x86_64-apple-darwin, aarch64-linux-gnu)
get_platform_cmake_args() {
    local target="$1"  # 本地变量：目标平台

    # case 语句：bash 的模式匹配，类似 switch-case
    case "$target" in
        *-apple-darwin)     # 通配符模式：匹配以 -apple-darwin 结尾的字符串
            get_macos_cmake_args "$target"
            ;;              # 分支结束符，必须有
        *-linux-gnu*)       # 通配符模式：匹配包含 -linux-gnu 的字符串
            get_linux_cmake_args
            ;;
        *)                  # 默认情况：匹配所有其他值
            echo "Unknown target platform: $target" >&2  # 输出到错误流
            return 1        # 返回错误码
            ;;
    esac                    # case 结束 (case 反写)
}

# Function to set up build environment (native builds only)
setup_build_env() {
    local target="$1"

    # All builds are native, no cross-compilation setup needed
    echo "Setting up native build environment for $target"
}

# Function to get number of CPU cores
# bash 函数：根据操作系统获取 CPU 核心数，用于并行编译优化
get_cpu_cores() {
    if [[ "$HOST_OS" == "Darwin" ]]; then
        # macOS：使用 sysctl 查询系统信息
        sysctl -n hw.ncpu  # hw.ncpu=硬件CPU核心数, -n=只输出数值
    elif [[ "$HOST_OS" == "Linux" ]]; then
        # Linux：使用 nproc 命令直接获取可用处理器核心数
        nproc
    elif [[ "$HOST_OS" == "Windows_NT" ]]; then
        # Windows：使用环境变量，如果不存在则默认4核
        echo "${NUMBER_OF_PROCESSORS:-4}"  # bash 参数扩展：变量不存在时使用默认值
    else
        # 其他未知系统：使用保守的默认值
        echo "4"
    fi
}

# Function to create release directory structure
# bash 函数：创建发布包，将编译好的 LLVM 工具链打包成最终的发布文件
# 参数：$1 目标平台, $2 安装目录路径
create_release_structure() {
    local target="$1"      # 目标平台 (如 x86_64-linux-gnu)
    local install_dir="$2" # 编译安装的源目录
    local release_dir="dist/${target}/esp-clang"  # 发布目录路径

    echo "Creating release structure in $release_dir..."

    # 第一步：准备目录结构
    rm -rf "dist/${target}"     # 删除旧的发布目录，确保干净环境
    mkdir -p "$release_dir"     # 创建新的发布目录结构

    # 第二步：复制安装文件
    if [[ -d "$install_dir" ]]; then
        # 将编译安装的所有文件复制到发布目录 (bin/, lib/, include/ 等)
        cp -r "$install_dir"/* "$release_dir"/
    else
        echo "Warning: Install directory $install_dir not found"
        return 1    # 返回错误码
    fi

    echo "Release directory created: $release_dir"
    echo "Contents:"
    ls -la "$release_dir"   # 显示发布目录内容

    # 第三步：创建压缩包 (GitHub Releases 页面上的 .tar.xz 文件)
    echo "Creating tarball package..."
    mkdir -p dist
    cd "dist/${target}"     # 切换到目标平台目录
    # tar 命令：-c=创建, -J=xz压缩, -f=指定文件名
    tar -cJf "../clang-esp-${VERSION_STRING}-${target}.tar.xz" esp-clang/
    cd - > /dev/null        # 返回上级目录，> /dev/null 隐藏输出

    echo "Tarball created: dist/clang-esp-${VERSION_STRING}-${target}.tar.xz"
    echo "Package size: $(du -h "dist/clang-esp-${VERSION_STRING}-${target}.tar.xz" | cut -f1)"
}

# Main build function (native builds only)
build_platform() {
    local target="$1"

    echo "Building LLVM for platform: $target"
    echo "Version: $VERSION_STRING"
    echo "Host OS: $HOST_OS"
    echo "LLVM Branch: $LLVM_BRANCH"
    echo ""

    # Create build and install directories
    local build_dir="$BUILD_DIR_BASE/$target"
    local install_dir="$PWD/install/$target"

    mkdir -p "$build_dir"
    mkdir -p "$install_dir"

    # Set up build environment
    setup_build_env "$target"

    # Prepare CMake arguments
    # 准备 CMake 配置参数：创建临时文件存储所有参数
    local cmake_args_file=$(mktemp)  # 创建临时文件
    # 花括号语法：将多个命令的输出重定向到同一个文件
    {
        get_base_cmake_args              # 获取基础 CMake 参数 (48个通用配置)
        get_platform_cmake_args "$target"  # 获取平台特定参数 (macOS/Linux差异)
        echo "-DCMAKE_INSTALL_PREFIX=$install_dir"  # 添加安装路径参数
    } > "$cmake_args_file"  # 所有输出重定向到临时文件

    # 显示最终的 CMake 配置供调试查看
    echo "CMake configuration:"
    cat "$cmake_args_file"  # 输出完整的参数列表
    echo ""

    # Configure
    echo "Configuring build for $target..."
    cd "$build_dir"  # 切换到构建目录 (如 build/x86_64-linux-gnu/)
    # CMake 配置：指向 LLVM 源码入口，传入所有参数
    # ../../$LLVM_PROJECTDIR/llvm = 从构建目录向上两级，进入 llvm-project/llvm/
    # $(cat ... | tr '\n' ' ') = 将多行参数转换为单行空格分隔
    cmake "../../$LLVM_PROJECTDIR/llvm" $(cat "$cmake_args_file" | tr '\n' ' ')

    # Build
    # 开始编译阶段：使用 Ninja 构建工具编译 LLVM 项目
    echo "Building $target..."
    local cores=$(get_cpu_cores)  # 获取 CPU 核心数用于并行编译
    echo "Using $cores CPU cores for build"
    # Ninja 并行编译：-j$cores 使用所有可用核心加速构建
    # 这是最耗时的步骤，可能需要数小时完成
    ninja -j"$cores"

    # Install
    echo "Installing $target..."
    ninja install

    # Return to original directory
    cd - > /dev/null

    # Clean up temporary file
    rm -f "$cmake_args_file"

    # Create release directory structure
    create_release_structure "$target" "$install_dir"

    echo ""
    echo "Build completed successfully for $target!"
    echo "Release directory: dist/${target}/esp-clang"
    echo "Install directory: $install_dir"
    echo "Tarball: dist/clang-esp-${VERSION_STRING}-${target}.tar.xz"
}

# Main script logic
main() {
    if [[ $# -ne 1 ]]; then
        show_usage
        exit 1
    fi

    local target="$1"

    # Validate target
    local target_valid=0
    for valid_target in $VALID_TARGETS; do
        if [[ "$target" == "$valid_target" ]]; then
            target_valid=1
            break
        fi
    done

    if [[ $target_valid -eq 0 ]]; then
        echo "Error: Invalid target '$target'"
        echo ""
        show_usage
        exit 1
    fi

    # Check for required tools
    if ! command -v cmake >/dev/null 2>&1; then
        echo "Error: cmake is required but not installed"
        exit 1
    fi

    if ! command -v ninja >/dev/null 2>&1; then
        echo "Error: ninja is required but not installed"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required but not installed"
        exit 1
    fi

    # Download LLVM source
    download_llvm_source

    # Build the platform
    build_platform "$target"
}

# Run main function
main "$@"
