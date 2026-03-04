#!/bin/bash
#
# AutoSSH 启动前端口清理脚本
# 用于 systemd 服务启动前自动清理端口占用
#

# 参数：端口号
PORT=$1

if [ -z "$PORT" ]; then
    echo "用法：$0 <端口号>"
    exit 1
fi

# 检查端口是否被占用
if command -v ss &> /dev/null; then
    if ss -tlnp | grep -q ":$PORT "; then
        # 获取占用进程的 PID
        PID=$(ss -tlnp | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
        
        if [ -n "$PID" ]; then
            # 检查是否是旧的 autossh 进程
            PROCESS_NAME=$(ps -p "$PID" -o comm --no-headers 2>/dev/null || echo "unknown")
            
            if [[ "$PROCESS_NAME" == *"autossh"* ]] || [[ "$PROCESS_NAME" == *"ssh"* ]]; then
                # 优雅停止旧的 autossh 进程
                kill -15 "$PID" 2>/dev/null || true
                sleep 2
                
                # 如果还在运行，强制终止
                if ps -p "$PID" &> /dev/null; then
                    kill -9 "$PID" 2>/dev/null || true
                fi
                
                sleep 1
            else
                # 非 autossh 进程，仅记录日志
                echo "端口 $PORT 被非 autossh 进程占用 (PID: $PID, 进程：$PROCESS_NAME)，跳过清理"
                exit 1
            fi
        fi
    fi
fi

exit 0
