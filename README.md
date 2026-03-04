# AutoSSH 快速安装配置指南

将 AutoSSH 配置为 systemd 用户服务，实现开机自启，无需手动操作。

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `install-autossh.sh` | AutoSSH 安装脚本（支持 Debian/Ubuntu 和 CentOS/RHEL） |
| `setup-autossh.sh` | 一键配置脚本（自动完成所有配置，含端口清理） |
| `cleanup-port.sh` | 端口占用清理工具（交互式） |
| `pre-start-cleanup.sh` | 启动前自动端口清理脚本（systemd 使用） |
| `autossh@.service` | systemd 用户服务模板（含自动端口清理） |
| `tunnel.env.template` | 配置文件模板（.env 格式） |
| `autossh.conf.template` | 配置文件模板（完整格式） |

## 🚀 快速开始

### 步骤 1: 安装 AutoSSH

```bash
# 赋予执行权限
chmod +x install-autossh.sh

# 运行安装脚本
./install-autossh.sh
```

### 步骤 2: 运行一键配置

```bash
# 赋予执行权限
chmod +x setup-autossh.sh

# 运行配置脚本（需要交互式输入参数）
./setup-autossh.sh
```

配置脚本会自动完成：
- ✅ 创建配置目录 `~/.autossh/`
- ✅ 创建 systemd 用户服务
- ✅ 配置开机自启
- ✅ 启动服务
- ✅ 端口占用检测和清理

## 🔧 端口占用自动清理

### 功能说明

当遇到端口被占用时，系统会自动清理：

1. **配置时清理** - `setup-autossh.sh` 会在启动服务前检查端口
2. **启动前清理** - systemd 服务每次启动前自动检查并清理旧进程
3. **手动清理** - 使用 `cleanup-port.sh` 工具手动清理

### 清理策略

- ✅ 仅清理 autossh/ssh 相关进程
- ✅ 先优雅停止（SIGTERM），后强制终止（SIGKILL）
- ✅ 非 autossh 进程不清理，避免误杀
- ✅ 清理后等待 2 秒确保端口释放

### 手动清理端口

```bash
# 赋予执行权限
chmod +x cleanup-port.sh

# 清理指定端口
./cleanup-port.sh 8080
```

## 📝 手动配置（可选）

如果不想使用一键配置脚本，可以手动配置。

### 1. 创建配置文件

```bash
# 创建配置目录
mkdir -p ~/.autossh
mkdir -p ~/.config/systemd/user

# 创建配置文件（复制模板）
cp tunnel.env.template ~/.autossh/mytunnel.env

# 编辑配置文件
vim ~/.autossh/mytunnel.env
```

### 2. 编辑配置

```bash
# ~/.autossh/mytunnel.env
USER="your_username"
HOST="your.server.com"
PORT="22"
LOCAL_PORT="8080"
REMOTE_PORT="8080"
SSH_KEY="$HOME/.ssh/id_rsa"
```

### 3. 配置 systemd 服务

```bash
# 复制服务模板
cp autossh@.service ~/.config/systemd/user/autossh@.service
```

### 4. 启用服务

```bash
# 重载 systemd 配置
systemctl --user daemon-reload

# 启用并启动服务
systemctl --user enable autossh@mytunnel.service
systemctl --user start autossh@mytunnel.service
```

## 🔧 服务管理命令

```bash
# 查看服务状态
systemctl --user status autossh@mytunnel.service

# 启动服务
systemctl --user start autossh@mytunnel.service

# 停止服务
systemctl --user stop autossh@mytunnel.service

# 重启服务
systemctl --user restart autossh@mytunnel.service

# 查看服务日志
journalctl --user -u autossh@mytunnel.service

# 实时查看日志
journalctl --user -u autossh@mytunnel.service -f

# 禁用开机自启
systemctl --user disable autossh@mytunnel.service
```

## 🔍 常见问题

### Q1: 服务启动失败？

查看日志排查问题：

```bash
journalctl --user -u autossh@mytunnel.service -n 50 --no-pager
```

常见原因：
- SSH 密钥权限不对（应为 600）
- 远程服务器 SSH 配置不允许端口转发
- 端口已被占用（会自动清理）

### Q2: 如何配置 SSH 密钥认证？

```bash
# 生成 SSH 密钥
ssh-keygen -t rsa -b 4096

# 复制公钥到远程服务器
ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote.host

# 设置正确的权限
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### Q3: 如何配置多个隧道？

创建多个配置文件和服务：

```bash
# 隧道 1: Web 服务
cp tunnel.env.template ~/.autossh/web.env
# 编辑 web.env 配置 Web 隧道

# 隧道 2: 数据库
cp tunnel.env.template ~/.autossh/database.env
# 编辑 database.env 配置数据库隧道

# 分别启用服务
systemctl --user enable autossh@web.service
systemctl --user enable autossh@database.service

systemctl --user start autossh@web.service
systemctl --user start autossh@database.service
```

### Q4: 如何实现反向隧道（暴露本地服务到远程）？

修改配置文件中的 `ExecStart` 参数，使用 `-R` 替代 `-L`：

```bash
# 编辑 ~/.config/systemd/user/autossh@.service
# 将 -L 改为 -R
ExecStart=/usr/bin/autossh -M 0 -N -T -C \
    -i ${SSH_KEY} \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} \
    ${USER}@${HOST} -p ${PORT}
```

### Q5: 开机后服务未自动启动？

确保已启用 linger：

```bash
# 启用用户 linger（允许用户服务在开机时启动）
sudo loginctl enable-linger $USER

# 验证
loginctl show-user $USER | grep Linger
```

### Q6: 端口被占用怎么办？

系统会自动清理，也可以手动清理：

```bash
# 自动清理（交互式）
./cleanup-port.sh 8080

# 查看端口占用
ss -tlnp | grep :8080

# 手动杀死进程
kill $(ss -tlnp | grep :8080 | grep -oP 'pid=\K[0-9]+')
```

## 📊 配置示例

### 示例 1: 访问远程 Web 服务

```bash
# ~/.autossh/web.env
USER="admin"
HOST="192.168.1.100"
PORT="22"
LOCAL_PORT="8080"
REMOTE_PORT="80"
SSH_KEY="$HOME/.ssh/id_rsa"
```

访问：`http://localhost:8080` → 远程服务器的 80 端口

### 示例 2: 访问远程数据库

```bash
# ~/.autossh/mysql.env
USER="admin"
HOST="db.server.com"
PORT="22"
LOCAL_PORT="3306"
REMOTE_PORT="3306"
SSH_KEY="$HOME/.ssh/id_rsa"
```

访问：`mysql -h localhost -u root -p`

### 示例 3: 暴露本地开发服务器

```bash
# ~/.autossh/dev.env（需要修改服务模板使用 -R）
USER="admin"
HOST="public.server.com"
PORT="22"
LOCAL_PORT="3000"
REMOTE_PORT="8080"
SSH_KEY="$HOME/.ssh/id_rsa"
```

远程访问：`http://public.server.com:8080` → 本地的 3000 端口

## 🔐 安全建议

1. **使用密钥认证**：不要使用密码认证
2. **限制 SSH 密钥权限**：`chmod 600 ~/.ssh/id_rsa`
3. **使用非标准端口**：修改 SSH 默认端口（22）
4. **配置防火墙**：限制远程服务器的监听地址
5. **定期轮换密钥**：定期更新 SSH 密钥

## 📋 系统要求

- Linux 系统（Debian/Ubuntu/CentOS/RHEL）
- systemd 支持
- root 权限（仅安装时需要）
- SSH 访问权限
- `ss` 或 `netstat` 命令（用于端口检测）

## 📞 故障排查

### 检查网络连接

```bash
# 测试 SSH 连接
ssh -i ~/.ssh/id_rsa user@host

# 测试端口连通性
nc -zv host port
```

### 检查 systemd 服务

```bash
# 检查服务是否启用
systemctl --user list-unit-files | grep autossh

# 检查服务依赖
systemctl --user list-dependencies autossh@mytunnel.service
```

### 检查 autossh 进程

```bash
# 查看进程
ps aux | grep autossh

# 查看端口监听
ss -tlnp | grep LOCAL_PORT
```

### 端口清理日志

```bash
# 查看服务启动日志（包含端口清理信息）
journalctl --user -u autossh@mytunnel.service -n 100 --no-pager
```

## 📄 License

MIT License
