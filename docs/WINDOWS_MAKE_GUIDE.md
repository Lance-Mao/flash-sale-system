# Windows 下使用 Make 指南

## 方案1: WSL2（推荐）⭐⭐⭐⭐⭐

### 安装 WSL2

```powershell
# 1. 以管理员身份打开 PowerShell，安装 WSL2
wsl --install

# 2. 重启电脑

# 3. 重启后，会自动安装 Ubuntu，设置用户名密码

# 4. 更新系统
sudo apt update && sudo apt upgrade -y

# 5. 安装开发工具
sudo apt install -y make gcc git curl wget
```

### 在 WSL2 中使用项目

```bash
# 进入 Windows 项目目录（自动挂载在 /mnt/）
cd /mnt/d/project/go/flash-sale-system

# 现在可以使用 make 了
make install-tools
make lint
make test
```

### VSCode 集成（推荐）

```bash
# 1. 在 VSCode 中安装扩展：Remote - WSL
# 2. 按 F1，输入 "WSL: Connect to WSL"
# 3. 在 WSL 中打开项目文件夹
# 4. 终端自动使用 WSL2 环境
```

**优点**:
- ✅ 完整 Linux 环境
- ✅ 性能好
- ✅ 与 Linux 服务器一致
- ✅ Docker 可以直接用

**缺点**:
- ❌ 需要 Windows 10 2004+ 或 Windows 11

---

## 方案2: Git Bash（快速方案）⭐⭐⭐⭐

### 检查 Git Bash 是否已安装 make

```bash
# 打开 Git Bash
make --version

# 如果没有，下载 make for Git Bash
```

### 手动安装 make 到 Git Bash

```bash
# 1. 下载 make (选择适合你的版本)
# https://sourceforge.net/projects/ezwinports/files/

# 下载: make-4.4.1-without-guile-w32-bin.zip

# 2. 解压到 Git 安装目录
# 例如: C:\Program Files\Git\mingw64\

# 3. 验证
make --version
```

### 使用

```bash
# 在 Git Bash 中
cd /d/project/go/flash-sale-system
make lint
```

**优点**:
- ✅ 快速，如果已有 Git
- ✅ 轻量级

**缺点**:
- ❌ 部分 Linux 命令不支持
- ❌ 可能有兼容性问题

---

## 方案3: Chocolatey（Windows 包管理器）⭐⭐⭐

### 安装 Chocolatey

```powershell
# 以管理员身份打开 PowerShell，执行:
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### 安装 Make

```powershell
# 安装 make
choco install make -y

# 验证
make --version
```

### 使用

```powershell
# 在 PowerShell 或 CMD 中
cd D:\project\go\flash-sale-system
make lint
```

**优点**:
- ✅ 原生 Windows 环境
- ✅ 可用 PowerShell

**缺点**:
- ❌ 可能需要调整 Makefile

---

## 方案4: 不使用 Make，直接运行命令⭐⭐⭐

如果不想安装 make，可以直接运行 Makefile 中的命令。

### 我为你创建一个 Windows 脚本

看下面的文件...

**优点**:
- ✅ 不需要安装任何工具
- ✅ 简单直接

**缺点**:
- ❌ 需要手动维护两份脚本（Makefile + bat）

---

## 我的推荐

### 如果你是长期开发（推荐）:
**使用 WSL2** - 一次配置，终身受益

### 如果你想快速开始:
**使用方案4（PowerShell 脚本）** - 无需安装，立即可用

### 如果你已经有 Git:
**Git Bash + make** - 折中方案

---

## 快速决策

**你的情况**:
- Windows 10/11: → WSL2
- 只是偶尔用: → PowerShell 脚本
- 已有 Git Bash: → 给 Git Bash 装 make

需要我帮你选择并执行吗？
