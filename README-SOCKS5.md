# AutoSSH SOCKS5 代理快速配置指南

将 AutoSSH 配置为 systemd 用户服务，创建 SOCKS5 代理隧道，实现开机自启，无需手动操作。

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `install-autossh.sh` | AutoSSH 安装脚本（支持 Debian/Ubuntu 和 CentOS/RHEL） |
| `setup-autossh.sh` | 一键配置脚本（支持 SOCKS5 和端口转发模式） |
| `cleanup-port.sh` | 端口占用清理工具（交互式） |
| `pre-start-cleanup.sh` | 启动前自动端口清理脚本（systemd 使用） |
| `autossh-socks5@.service` | SOCKS5 代理服务模板 |
| `autossh@.service` | 端口转发服务模板 |
| `socks5.env.template` | SOCKS5 配置文件模板 |
| `tunnel.env.template` | 端口转发配置文件模板 |

## 🚀 快速开始

### 步骤 1: 安装 AutoSSH

```bash
chmod +x install-autossh.sh
./install-autossh.sh
```

### 步骤 2: 运行一键配置（推荐 SOCKS5 模式）

```bash
chmod +x setup-autossh.sh
./setup-autossh.sh
```

脚本会提示选择模式：
```
请选择隧道类型：
  1) SOCKS5 代理（推荐，用于科学上网）
  2) 端口转发（访问远程特定端口）
选择 [1-2]: 1
```

## 🌐 SOCKS5 代理模式

### 配置示例

运行配置脚本后，会创建如下配置：

```bash
# ~/.autossh/socks5.env
USER="your_username"
HOST="your.vps.com"
PORT="22"
LOCAL_PORT="1080"
SSH_KEY="$HOME/.ssh/id_rsa"
```

### 使用方式

#### 1. 系统代理设置

**Linux (Gnome):**
- 设置 → 网络 → 网络代理
- 手动 → SOCKS 主机：`127.0.0.1` 端口：`1080`

**Linux (KDE):**
- 系统设置 → 网络 → 代理
- 手动配置 → SOCKS 主机：`127.0.0.1` 端口：`1080`

**Windows:**
- 使用 Proxifier 等工具
- 代理地址：`127.0.0.1:1080`，协议：`SOCKS5`

**MacOS:**
- 系统偏好设置 → 网络 → 高级 → 代理
- SOCKS 代理：`127.0.0.1` 端口：`1080`

#### 2. 浏览器代理设置

**Firefox:**
- 设置 → 网络设置 → 手动代理配置
- SOCKS 主机：`127.0.0.1` 端口：`1080`
- 勾选 "SOCKS v5"

**Chrome (使用扩展):**
- 安装 Proxy SwitchyOmega
- 添加 SOCKS5 代理：`127.0.0.1:1080`

#### 3. 命令行使用

```bash
# 使用 curl
curl --socks5-hostname localhost:1080 https://www.google.com

# 检查 IP
curl --socks5-hostname localhost:1080 https://api.ip.sb/ip

# 使用 wget
wget --socks5=localhost:1080 https://example.com/file.zip
```

#### 4. 使用 proxychains（推荐）

```bash
# 安装 proxychains
sudo apt-get install proxychains4  # Debian/Ubuntu
sudo yum install proxychains-ng    # CentOS/RHEL

# 配置
echo "socks5 127.0.0.1 1080" | sudo tee -a /etc/proxychains.conf

# 使用
proxychains curl https://www.google.com
proxychains firefox
proxychains git clone https://github.com/user/repo.git
```

## 📝 手动配置

### 1. 创建 SOCKS5 配置文件

```bash
mkdir -p ~/.autossh
mkdir -p ~/.config/systemd/user

# 创建配置文件
cat > ~/.autossh/socks5.env << EOF
USER="your_username"
HOST="your.vps.com"
PORT="22"
LOCAL_PORT="1080"
SSH_KEY="$HOME/.ssh/id_rsa"
EOF
```

### 2. 复制服务模板

```bash
cp autossh-socks5@.service ~/.config/systemd/user/autossh@.service
```

### 3. 启用服务

```bash
systemctl --user daemon-reload
systemctl --user enable autossh@socks5.service
systemctl --user start autossh@socks5.service
```

## 🔧 服务管理命令

```bash
# 查看服务状态
systemctl --user status autossh@socks5.service

# 启动服务
systemctl --user start autossh@socks5.service

# 停止服务
systemctl --user stop autossh@socks5.service

# 重启服务
systemctl --user restart autossh@socks5.service

# 查看日志
journalctl --user -u autossh@socks5.service

# 实时日志
journalctl --user -u autossh@socks5.service -f

# 禁用开机自启
systemctl --user disable autossh@socks5.service
```

## 🔍 常见问题

### Q1: 测试代理是否工作？

```bash
# 查看本机 IP（不使用代理）
curl https://api.ip.sb/ip

# 使用代理查看 IP（应该显示 VPS 的 IP）
curl --socks5-hostname localhost:1080 https://api.ip.sb/ip
```

### Q2: 代理速度很慢？

1. **关闭压缩** - 编辑 `~/.config/systemd/user/autossh@.service`，去掉 `-C` 参数
2. **选择更近的 VPS** - 物理距离越近速度越快
3. **检查 VPS 带宽** - 确认 VPS 网络质量

```bash
# 测试延迟
ping your.vps.com

# 测试速度
curl --socks5-hostname localhost:1080 -o /dev/null -s -w '%{speed_download}\n' http://speedtest.net
```

### Q3: 端口被占用？

```bash
# 查看端口占用
ss -tlnp | grep :1080

# 清理端口
./cleanup-port.sh 1080

# 或修改配置文件使用其他端口
# 编辑 ~/.autossh/socks5.env，修改 LOCAL_PORT="1081"
```

### Q4: 如何配置多个 SOCKS5 代理？

```bash
# 创建多个配置文件
cp ~/.autossh/socks5.env ~/.autossh/socks5-us.env
cp ~/.autossh/socks5.env ~/.autossh/socks5-jp.env

# 修改端口
# socks5-us.env: LOCAL_PORT="1080"
# socks5-jp.env: LOCAL_PORT="1081"

# 启用多个服务
systemctl --user enable autossh@socks5-us.service
systemctl --user enable autossh@socks5-jp.service

systemctl --user start autossh@socks5-us.service
systemctl --user start autossh@socks5-jp.service
```

### Q5: 开机后服务未自动启动？

```bash
# 启用 linger（允许用户服务开机启动）
sudo loginctl enable-linger $USER

# 验证
loginctl show-user $USER | grep Linger
```

## 📊 配置示例

### 示例 1: 基础 SOCKS5 代理

```bash
# ~/.autossh/socks5.env
USER="root"
HOST="vps.example.com"
PORT="22"
LOCAL_PORT="1080"
SSH_KEY="$HOME/.ssh/id_rsa"
```

### 示例 2: 非标准 SSH 端口

```bash
# ~/.autossh/socks5.env
USER="admin"
HOST="192.168.1.100"
PORT="2222"
LOCAL_PORT="1080"
SSH_KEY="$HOME/.ssh/id_rsa"
```

### 示例 3: 多线路代理

```bash
# 美国线路
# ~/.autossh/socks5-us.env
USER="root"
HOST="us.vps.com"
PORT="22"
LOCAL_PORT="1080"
SSH_KEY="$HOME/.ssh/id_rsa"

# 日本线路
# ~/.autossh/socks5-jp.env
USER="root"
HOST="jp.vps.com"
PORT="22"
LOCAL_PORT="1081"
SSH_KEY="$HOME/.ssh/id_rsa"

# 香港线路
# ~/.autossh/socks5-hk.env
USER="root"
HOST="hk.vps.com"
PORT="22"
LOCAL_PORT="1082"
SSH_KEY="$HOME/.ssh/id_rsa"
```

## 🔐 安全建议

1. **使用密钥认证** - 不要使用密码
2. **限制 SSH 密钥权限** - `chmod 600 ~/.ssh/id_rsa`
3. **使用非标准 SSH 端口** - 减少被扫描风险
4. **配置防火墙** - 仅允许信任的 IP 连接 VPS
5. **定期轮换密钥** - 提高安全性
6. **使用 SSH 证书** - 更高安全性

## 📋 系统要求

- Linux 系统（Debian/Ubuntu/CentOS/RHEL）
- systemd 支持
- SSH 访问权限（远程 VPS）
- `ss` 或 `netstat` 命令

## 📞 故障排查

### 检查服务状态

```bash
# 查看服务是否运行
systemctl --user status autossh@socks5.service

# 查看进程
ps aux | grep autossh
```

### 检查 SSH 连接

```bash
# 手动测试 SSH 连接
ssh -i ~/.ssh/id_rsa user@host

# 测试 SOCKS5 代理
curl -v --socks5-hostname localhost:1080 https://www.google.com
```

### 查看日志

```bash
# 查看系统日志
journalctl --user -u autossh@socks5.service -n 100

# 实时日志
journalctl --user -u autossh@socks5.service -f
```

### DNS 泄漏测试

```bash
# 使用 SOCKS5 查询 DNS（应该使用 VPS 的 DNS）
curl --socks5-hostname localhost:1080 https://dnsleaktest.com
```

## 📄 License

MIT License
