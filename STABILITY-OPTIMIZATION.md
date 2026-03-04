# AutoSSH 连接稳定性优化

## 🔍 问题分析

### 原配置的问题

```ini
# 原配置（不稳定）
-o ServerAliveInterval=60
-o ServerAliveCountMax=3
```

**问题**：
- 总超时时间 = 60 × 3 = **180 秒（3 分钟）**
- 网络波动时，3 分钟内无响应就会断开
- 对于不稳定的网络环境，这个时间太短了

### 新配置（稳定）

```ini
# 新配置（稳定）
-o ServerAliveInterval=30
-o ServerAliveCountMax=10
-o TCPKeepAlive=yes
-o ConnectTimeout=30
-o ConnectionAttempts=5
```

**改进**：
- 总超时时间 = 30 × 10 = **300 秒（5 分钟）**
- 更频繁的保活（30 秒 vs 60 秒）
- 更多的容错次数（10 次 vs 3 次）
- TCP 层保活 + 应用层保活双重保护
- 连接失败自动重试 5 次

## 📊 参数详解

### ServerAliveInterval=30

**含义**：每 30 秒向服务器发送一次保活消息

**为什么是 30 秒**：
- ✅ 足够频繁，能及时发现连接断开
- ✅ 不会太频繁，减少网络负担
- ✅ 行业推荐值：30-60 秒

**对比**：
- ❌ 60 秒：间隔太长，断开检测慢
- ✅ 30 秒：平衡了及时性和开销

### ServerAliveCountMax=10

**含义**：允许连续 10 次保活无响应后才断开

**为什么是 10 次**：
- ✅ 总超时 = 30 × 10 = 300 秒（5 分钟）
- ✅ 能容忍短暂的网络中断
- ✅ 行业推荐值：5-10 次

**对比**：
- ❌ 3 次：总超时仅 3 分钟，太激进
- ✅ 10 次：总超时 5 分钟，更稳定

### TCPKeepAlive=yes

**含义**：启用 TCP 层保活

**作用**：
- 检测 TCP 连接是否仍然有效
- 与应用层保活（ServerAlive）双重保护
- 在 SSH 保活之前就能发现问题

### ConnectTimeout=30

**含义**：SSH 连接超时 30 秒

**作用**：
- 避免长时间等待无响应的服务器
- 快速失败，触发 AutoSSH 重启

### ConnectionAttempts=5

**含义**：连接失败时自动重试 5 次

**作用**：
- 临时网络问题自动恢复
- 减少服务中断时间

### 移除 -C 压缩选项

**原配置**：
```bash
autossh -M 0 -N -T -C ...  # -C 启用压缩
```

**新配置**：
```bash
autossh -M 0 -N -T ...     # 移除 -C
```

**原因**：
- ❌ 压缩增加 CPU 负担
- ❌ 在慢速连接上可能导致延迟累积
- ❌ 现代网络通常不需要压缩
- ✅ 移除后连接更稳定，延迟更低

## 🔧 应用更新

### 方法 1: 重新运行配置脚本

```bash
./setup-autossh.sh
# 会自动使用新的稳定配置
```

### 方法 2: 手动更新服务文件

```bash
# 复制新的服务模板
cp autossh-socks5@.service ~/.config/systemd/user/autossh@.service

# 重载配置
systemctl --user daemon-reload

# 重启服务
systemctl --user restart autossh@socks5.service
```

### 方法 3: 修改现有配置

编辑 `~/.config/systemd/user/autossh@.service`：

```ini
[Service]
# 修改 ExecStart 行
ExecStart=/usr/bin/autossh -M 0 -N -T \
    -i ${SSH_KEY} \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=10 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=30 \
    -o ConnectionAttempts=5 \
    -D ${LOCAL_PORT} \
    ${USER}@${HOST} -p ${PORT}
```

然后：
```bash
systemctl --user daemon-reload
systemctl --user restart autossh@socks5.service
```

## 📈 性能对比

| 配置 | 总超时 | 保活间隔 | 容错次数 | 稳定性 |
|------|--------|----------|----------|--------|
| 原配置 | 3 分钟 | 60 秒 | 3 次 | ⭐⭐ |
| 新配置 | 5 分钟 | 30 秒 | 10 次 | ⭐⭐⭐⭐⭐ |

## 🔍 测试连接稳定性

### 测试命令

```bash
# 持续测试代理连接
watch -n 5 'curl --socks5-hostname localhost:1080 -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" https://www.google.com'
```

### 查看连接状态

```bash
# 查看服务状态
systemctl --user status autossh@socks5.service

# 查看日志
journalctl --user -u autossh@socks5.service -f

# 查看进程
ps aux | grep autossh
```

### 监控断开次数

```bash
# 查看重启次数（每次重启可能意味着一次断开）
systemctl --user show autossh@socks5.service | grep Restart
```

## ⚙️ 自定义配置

### 更激进（更频繁保活）

```ini
-o ServerAliveInterval=15
-o ServerAliveCountMax=20
```
总超时：5 分钟，保活更频繁

### 更保守（更少网络流量）

```ini
-o ServerAliveInterval=60
-o ServerAliveCountMax=5
```
总超时：5 分钟，保活间隔更长

### 极不稳定网络

```ini
-o ServerAliveInterval=10
-o ServerAliveCountMax=30
-o TCPKeepAlive=yes
```
总超时：5 分钟，最大容错

## 📚 参考资料

- OpenSSH 官方文档：ServerAliveInterval 推荐 30-60 秒
- AutoSSH 最佳实践：生产环境推荐 5 分钟以上超时
- TCP 保活：启用 TCPKeepAlive 提供双重保护

## 💡 其他优化建议

1. **使用有线网络** - WiFi 波动会导致断开
2. **避免 NAT 超时** - 路由器 NAT 表超时时间应大于 SSH 超时
3. **配置路由器** - 保持长连接，禁用激进的空闲超时
4. **使用静态 IP** - 避免 IP 变化导致连接中断
5. **监控日志** - 定期检查日志发现问题
