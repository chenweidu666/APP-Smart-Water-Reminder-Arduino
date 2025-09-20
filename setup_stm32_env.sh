#!/bin/bash

echo "=== STM32开发环境配置脚本 ==="

# 1. 检查并安装必要软件
echo "1. 检查软件安装状态..."

# 检查OpenOCD
if command -v openocd &> /dev/null; then
    echo "✓ OpenOCD已安装: $(openocd -v | head -1)"
else
    echo "✗ OpenOCD未安装，正在安装..."
    brew install open-ocd
fi

# 检查ARM工具链
if command -v arm-none-eabi-gcc &> /dev/null; then
    echo "✓ ARM工具链已安装: $(arm-none-eabi-gcc -v | head -1)"
else
    echo "✗ ARM工具链未安装"
    echo "请手动下载并安装: https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-rm/downloads"
fi

# 2. 创建STM32工作目录
echo "2. 创建STM32工作目录..."
mkdir -p ~/STM32_Projects
cd ~/STM32_Projects

# 3. 创建OpenOCD配置文件
echo "3. 创建OpenOCD配置文件..."
cat > STM32F103C8T6.cfg << 'CFG_EOF'
# STM32F103C8T6 OpenOCD配置文件
source [find interface/stlink.cfg]
source [find target/stm32f1x.cfg]

# 设置工作频率
adapter speed 1000

# 复位配置
reset_config srst_only
CFG_EOF

echo "✓ OpenOCD配置文件已创建: STM32F103C8T6.cfg"

# 4. 创建示例Makefile
echo "4. 创建示例Makefile..."
cat > Makefile << 'MAKEFILE_EOF'
# STM32项目Makefile示例
TARGET = stm32_project

# 源文件
C_SOURCES = \
src/main.c \
src/stm32f1xx_it.c \
src/stm32f1xx_hal_msp.c \
src/system_stm32f1xx.c

# 包含路径
C_INCLUDES = \
-IInc \
-IDrivers/STM32F1xx_HAL_Driver/Inc \
-IDrivers/STM32F1xx_HAL_Driver/Inc/Legacy \
-IDrivers/CMSIS/Device/ST/STM32F1xx/Include \
-IDrivers/CMSIS/Include

# 编译选项
CFLAGS = -mcpu=cortex-m3 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS += -DSTM32F103xB -DUSE_HAL_DRIVER
CFLAGS += $(C_INCLUDES) -Wall -fdata-sections -ffunction-sections

# 链接选项
LDFLAGS = -mcpu=cortex-m3 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
LDFLAGS += -specs=nano.specs -TSTM32F103C8Tx_FLASH.ld
LDFLAGS += -Wl,--gc-sections -Wl,--print-memory-usage

# 目标文件
OBJECTS = $(addprefix build/,$(notdir $(C_SOURCES:.c=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))

# 默认目标
all: $(TARGET).elf

# 编译规则
build/%.o: %.c Makefile | build
	arm-none-eabi-gcc $(CFLAGS) -c $< -o $@

# 链接
$(TARGET).elf: $(OBJECTS) Makefile
	arm-none-eabi-gcc $(OBJECTS) $(LDFLAGS) -o $@
	arm-none-eabi-objcopy -O ihex $@ $@.hex
	arm-none-eabi-objcopy -O binary $@ $@.bin
	arm-none-eabi-size $@

# 创建build目录
build:
	mkdir -p build

# 烧录
flash: $(TARGET).elf
	openocd -f STM32F103C8T6.cfg -c "program $(TARGET).elf verify reset exit"

# 清理
clean:
	rm -rf build
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).bin

.PHONY: all clean flash
MAKEFILE_EOF

echo "✓ 示例Makefile已创建"

# 5. 创建VSCode配置
echo "5. 创建VSCode配置..."
mkdir -p .vscode

# c_cpp_properties.json
cat > .vscode/c_cpp_properties.json << 'CPP_EOF'
{
    "configurations": [
        {
            "name": "STM32",
            "includePath": [
                "${workspaceFolder}/**",
                "${workspaceFolder}/Inc",
                "${workspaceFolder}/Drivers/STM32F1xx_HAL_Driver/Inc",
                "${workspaceFolder}/Drivers/STM32F1xx_HAL_Driver/Inc/Legacy",
                "${workspaceFolder}/Drivers/CMSIS/Device/ST/STM32F1xx/Include",
                "${workspaceFolder}/Drivers/CMSIS/Include"
            ],
            "defines": [
                "USE_HAL_DRIVER",
                "STM32F103xB"
            ],
            "cStandard": "c17",
            "cppStandard": "c++17",
            "compilerPath": "/usr/local/bin/arm-none-eabi-gcc",
            "intelliSenseMode": "gcc-arm"
        }
    ],
    "version": 4
}
CPP_EOF

# launch.json
cat > .vscode/launch.json << 'LAUNCH_EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Cortex Debug",
            "cwd": "${workspaceFolder}",
            "executable": "${workspaceFolder}/stm32_project.elf",
            "request": "launch",
            "type": "cortex-debug",
            "runToEntryPoint": "main",
            "servertype": "openocd",
            "configFiles": [
                "interface/stlink.cfg",
                "target/stm32f1x.cfg"
            ],
            "searchDir": [],
            "showDevDebugOutput": "raw"
        }
    ]
}
LAUNCH_EOF

echo "✓ VSCode配置文件已创建"

echo ""
echo "=== 配置完成 ==="
echo "下一步："
echo "1. 安装VSCode插件：C/C++, Cortex-Debug"
echo "2. 下载STM32CubeMX并生成项目代码"
echo "3. 将生成的代码复制到此目录"
echo "4. 运行 'make' 编译项目"
echo "5. 运行 'make flash' 烧录程序"
echo ""
echo "工作目录: $(pwd)"
