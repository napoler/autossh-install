# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

AutoSSH systemd 用户服务配置仓库，支持两种隧道模式：
- **SOCKS5 代理模式**：使用 `-D ${LOCAL_PORT}` 参数
- **端口转发模式**：使用 `-L ${LOCAL_PORT}:localhost:${REMOTE_PORT}` 参数

## 常用命令

```bash
# 安装 AutoSSH
./install-autossh.sh

# 一键配置（交互式）
./setup-autossh.sh

# 手动清理端口占用
./cleanup-port.sh <端口号>

# systemd 服务管理
systemctl --user status autossh@<隧道名>.service
systemctl --user restart autossh@<隧道名>.service
journalctl --user -u autossh@<隧道名>.service -f

# 启用开机自启
sudo loginctl enable-linger $USER
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
| `setup-autossh.sh` | 交互式配置主脚本（选择模式 → 填写参数 → 自动部署） |
| `install-autossh.sh` | AutoSSH 安装脚本（支持 Debian/Ubuntu 和 CentOS/RHEL） |
| `pre-start-cleanup.sh` | 独立的端口清理脚本（被 systemd ExecStartPre 调用） |
| `cleanup-port.sh` | 交互式端口清理工具 |
| `autossh@.service` | 端口转发 systemd 模板 |
| `autossh-socks5@.service` | SOCKS5 代理 systemd 模板 |
| `tunnel.env.template` | .env 格式配置模板 |
| `ULTRA-STABLE-CONFIG.md` | 企业级超稳定配置详细说明 |

## 多隧道配置

每个隧道需要：
1. 独立的 `~/.autossh/<名称>.env` 配置文件
2. 独立的服务实例：`autossh@<名称>.service`
3. 服务名格式：`autossh@<隧道名>.service`（%i 参数引用隧道名）
