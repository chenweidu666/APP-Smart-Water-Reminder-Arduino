#!/bin/bash

echo "=== ARM工具链安装脚本 ==="

# 检查下载是否完成
if [ ! -f "arm-toolchain.tar.bz2" ]; then
    echo "正在下载ARM工具链..."
    curl -L -o arm-toolchain.tar.bz2 "https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi.tar.bz2"
fi

# 检查文件大小（完整文件应该约128MB）
FILE_SIZE=$(stat -f%z arm-toolchain.tar.bz2 2>/dev/null || echo "0")
if [ "$FILE_SIZE" -lt 100000000 ]; then
    echo "文件下载不完整，请等待下载完成或手动下载"
    echo "下载地址: https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-rm/downloads"
    exit 1
fi

echo "文件下载完成，开始安装..."

# 解压到Applications目录
sudo tar -xjf arm-toolchain.tar.bz2 -C /Applications/

# 创建符号链接
sudo ln -sf /Applications/arm-gnu-toolchain-14.2.rel1/arm-none-eabi/bin/* /usr/local/bin/

# 添加到PATH
echo 'export PATH="/Applications/arm-gnu-toolchain-14.2.rel1/arm-none-eabi/bin:$PATH"' >> ~/.zshrc

echo "✓ ARM工具链安装完成"
echo "请运行: source ~/.zshrc"
echo "然后验证: arm-none-eabi-gcc -v"
