# AutoSSH 企业级超稳定配置

## 🎯 配置目标

为网络波动大、需要极高稳定性的场景设计的**企业级超稳定配置**。

**总超时时间：30 分钟**（适用于极端网络环境）

## 📊 配置对比

| 配置版本 | 保活间隔 | 容错次数 | 总超时 | 适用场景 |
|---------|---------|---------|--------|---------|
| 初始配置 | 60 秒 | 3 次 | 3 分钟 | ❌ 不稳定 |
| 优化配置 | 30 秒 | 10 次 | 5 分钟 | ⭐⭐⭐ 一般网络 |
| **企业级** | **15 秒** | **120 次** | **30 分钟** | ⭐⭐⭐⭐⭐ 极端网络 |

## 🔧 企业级配置参数

### 核心参数

```ini
# 每 15 秒发送一次保活消息
ServerAliveInterval=15

# 允许 120 次无响应（15 秒 × 120 = 30 分钟）
ServerAliveCountMax=120

# 启用 TCP 层保活（双重保护）
TCPKeepAlive=yes

# 连接超时 30 秒
ConnectTimeout=30

# 连接失败重试 10 次
ConnectionAttempts=10
```

### 总超时计算

```
总超时 = ServerAliveInterval × ServerAliveCountMax
       = 15 秒 × 120 次
       = 1800 秒
       = 30 分钟
```

## 📝 服务文件内容

### autossh-socks5@.service

```ini
[Unit]
Description=AutoSSH SOCKS5 Tunnel Service - %i
Documentation=man:autossh(1)
After=network-online.target
Wants=network-online.target

[Service]
Environment="AUTOSSH_GATETIME=0"
EnvironmentFile=%h/.autossh/%i.env

ExecStartPre=/bin/bash -c 'PORT=${LOCAL_PORT}; if command -v ss &> /dev/null; then if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP "pid=\\K[0-9]+" | head -1); if [ -n "$PID" ]; then PROCESS=$(ps -p $PID -o comm --no-headers 2>/dev/null || echo "unknown"); if [[ "$PROCESS" == *"autossh"* ]] || [[ "$PROCESS" == *"ssh"* ]]; then kill -15 $PID 2>/dev/null || true; sleep 2; kill -9 $PID 2>/dev/null || true; fi; fi; fi; fi; exit 0'

ExecStart=/usr/bin/autossh -M 0 -N -T \
    -i ${SSH_KEY} \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=120 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=30 \
    -o ConnectionAttempts=10 \
    -D ${LOCAL_PORT} \
    ${USER}@${HOST} -p ${PORT}

Restart=always
RestartSec=10
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal
SyslogIdentifier=autossh-%i

[Install]
WantedBy=default.target
```

## 🚀 应用更新

### 方法 1: 使用更新后的模板

```bash
# 复制到用户配置目录
cp /home/terry/dev/ai-flow/autossh-install/autossh-socks5@.service ~/.config/systemd/user/autossh@.service

# 重载 systemd
systemctl --user daemon-reload

# 重启服务
systemctl --user restart autossh@socks5.service
```

### 方法 2: 手动编辑

编辑 `~/.config/systemd/user/autossh@.service`，修改 `ExecStart` 行：

```ini
ExecStart=/usr/bin/autossh -M 0 -N -T \
    -i ${SSH_KEY} \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=120 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=30 \
    -o ConnectionAttempts=10 \
    -D ${LOCAL_PORT} \
    ${USER}@${HOST} -p ${PORT}
```

然后：
```bash
systemctl --user daemon-reload
systemctl --user restart autossh@socks5.service
```

## 📈 性能影响分析

### 网络流量

```
保活消息频率：每 15 秒一次
每小时消息数：240 次
每天消息数：5,760 次
每月消息数：172,800 次

单次保活消息大小：~64 字节
每月保活流量：~11MB
```

**结论**：流量影响可以忽略不计

### CPU 使用

- 保活消息处理：极低 CPU 占用（<0.1%）
- 连接重建：仅在真正断开时发生
- 总体影响：可忽略

### 内存使用

- 每个 SSH 连接：~5-10MB
- 保活参数不影响内存
- 与之前配置相同

## 🎯 适用场景

### ✅ 推荐使用

- **网络波动大** - WiFi、4G/5G 网络
- **跨国连接** - 长距离国际链路
- **关键业务** - 需要 24/7 不间断连接
- **远程监控** - 偏远地区设备连接
- **移动环境** - 车辆、船舶等移动场景

### ⚠️ 谨慎使用

- **流量受限** - 按流量计费的链路
- **电池供电** - 移动设备电池续航重要
- **局域网** - 稳定的本地网络（不需要）

## 🔍 监控和验证

### 检查服务状态

```bash
# 查看服务状态
systemctl --user status autossh@socks5.service

# 查看运行时间
systemctl --user show autossh@socks5.service | grep ActiveEnterTimestamp
```

### 查看连接统计

```bash
# 查看进程
ps aux | grep autossh

# 查看端口监听
ss -tlnp | grep 1081

# 查看日志
journalctl --user -u autossh@socks5.service -f
```

### 测试连接稳定性

```bash
# 持续测试（运行 1 小时）
watch -n 60 'curl --socks5-hostname localhost:1081 -s -o /dev/null -w "时间：%{time_total}s, 状态：%{http_code}\n" https://www.google.com'
```

## 📊 与其他配置对比

### 家庭/办公网络（推荐配置）

```ini
ServerAliveInterval=30
ServerAliveCountMax=10
# 总超时：5 分钟
```

### 一般不稳定网络（优化配置）

```ini
ServerAliveInterval=20
ServerAliveCountMax=30
# 总超时：10 分钟
```

### 极端不稳定网络（企业级配置）⭐

```ini
ServerAliveInterval=15
ServerAliveCountMax=120
# 总超时：30 分钟
```

### 卫星/军事级（极端配置）

```ini
ServerAliveInterval=10
ServerAliveCountMax=600
# 总超时：100 分钟（1 小时 40 分钟）
```

## ⚙️ 自定义配置

### 调整超时时间

```bash
# 10 分钟超时
ServerAliveInterval=20
ServerAliveCountMax=30

# 1 小时超时
ServerAliveInterval=15
ServerAliveCountMax=240

# 2 小时超时
ServerAliveInterval=15
ServerAliveCountMax=480
```

### 调整保活频率

```bash
# 更频繁（网络极差）
ServerAliveInterval=5
ServerAliveCountMax=120

# 适中（一般不稳定）
ServerAliveInterval=30
ServerAliveCountMax=60

# 较少（节省流量）
ServerAliveInterval=60
ServerAliveCountMax=30
```

## 📚 参考资料

- OpenSSH 官方文档：ServerAliveInterval 最大可设置值
- AutoSSH 最佳实践：生产环境推荐配置
- 企业 SSH 隧道管理指南
- 远程基础设施连接方案

## 💡 故障排查

### 连接仍然断开

1. **检查日志**
   ```bash
   journalctl --user -u autossh@socks5.service -n 100
   ```

2. **检查网络质量**
   ```bash
   ping -c 100 your.server.com
   ```

3. **检查路由器 NAT 超时**
   - 登录路由器
   - 增加 TCP 超时时间到 3600 秒或更长

4. **尝试更频繁的保活**
   ```ini
   ServerAliveInterval=10
   ServerAliveCountMax=180
   ```

### 服务重启频繁

检查是否是网络问题还是配置问题：

```bash
# 查看重启次数
systemctl --user show autossh@socks5.service | grep -E "(NRestarts|Restart)"

# 查看断开原因
journalctl --user -u autossh@socks5.service | grep -i "disconnect\|timeout\|error"
```

## 📞 获取帮助

如果遇到问题：

1. 查看日志找出问题
2. 检查网络连接质量
3. 确认 SSH 密钥配置正确
4. 尝试不同的超时配置组合
