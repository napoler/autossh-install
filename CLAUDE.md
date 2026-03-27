# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

AutoSSH systemd 用户服务配置仓库，支持两种隧道模式：
- **SOCKS5 代理模式**：使用 `-D 0.0.0.0:${LOCAL_PORT}` 参数（支持局域网访问）
- **端口转发模式**：使用 `-L ${LOCAL_PORT}:localhost:${REMOTE_PORT}` 参数

## 常用命令

**统一入口（推荐）：**
```bash
./autossh.sh help                    # 查看所有可用命令
./autossh.sh install                 # 安装 AutoSSH
./autossh.sh setup                   # 交互式配置隧道
./autossh.sh list                    # 列出所有隧道
./autossh.sh status [隧道名]          # 查看状态（默认 all）
./autossh.sh start <隧道名>           # 启动隧道
./autossh.sh stop <隧道名>            # 停止隧道
./autossh.sh restart <隧道名>         # 重启隧道
./autossh.sh logs <隧道名>             # 跟踪日志
./autossh.sh cleanup <端口>           # 清理端口占用
./autossh.sh enable <隧道名>          # 启用开机自启
./autossh.sh disable <隧道名>         # 禁用开机自启
```

**直接调用子脚本：**
```bash
./install-autossh.sh                 # 安装 AutoSSH
./setup-autossh.sh                   # 交互式配置
./cleanup-port.sh <端口号>            # 清理端口占用
```

## 架构说明

### 配置模板 → 用户配置目录 → systemd 服务

```
tunnel.env.template          # 端口转发配置模板
socks5.env.template          # SOCKS5 配置模板（额外）
~/.autossh/<隧道名>.env      # 用户实际配置
autossh@.service             # 端口转发的 systemd 模板
autossh-socks5@.service      # SOCKS5 的 systemd 模板
~/.config/systemd/user/      # systemd 用户服务目录
```

### 端口清理机制

`ExecStartPre` 在服务启动前自动清理占用端口的旧 autossh/ssh 进程：
- 先发送 SIGTERM 优雅停止
- 2 秒后未响应则 SIGKILL 强制终止
- 仅清理 autossh/ssh 相关进程，避免误杀其他服务

### 企业级稳定性配置（30 分钟超时）

```ini
ServerAliveInterval=15    # 每 15 秒保活
ServerAliveCountMax=120   # 允许 120 次无响应
TCPKeepAlive=yes           # TCP 层双重保活
ConnectTimeout=30          # 连接超时 30 秒
ConnectionAttempts=10      # 重试 10 次
```

## 重要文件

| 文件 | 用途 |
|------|------|
| `autossh.sh` | **统一入口**（推荐使用）|
| `setup-autossh.sh` | 交互式配置主脚本（选择模式 → 填写参数 → 自动部署） |
| `install-autossh.sh` | AutoSSH 安装脚本（支持 Debian/Ubuntu 和 CentOS/RHEL） |
| `pre-start-cleanup.sh` | 独立的端口清理脚本（被 systemd ExecStartPre 调用） |
| `cleanup-port.sh` | 交互式端口清理工具 |
| `autossh@.service` | 端口转发 systemd 模板 |
| `autossh-socks5@.service` | SOCKS5 代理 systemd 模板（已支持局域网访问 0.0.0.0） |
| `tunnel.env.template` | .env 格式配置模板 |
| `socks5.env.template` | SOCKS5 配置模板 |
| `ULTRA-STABLE-CONFIG.md` | 企业级超稳定配置详细说明 |

## 多隧道配置

每个隧道需要：
1. 独立的 `~/.autossh/<名称>.env` 配置文件
2. 独立的服务实例：`autossh@<名称>.service`
3. 服务名格式：`autossh@<隧道名>.service`（%i 参数引用隧道名）
