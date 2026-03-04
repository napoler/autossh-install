#!/bin/bash
#
# AutoSSH 端口清理脚本
# 检查并清理占用指定端口的进程
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 用法
usage() {
    echo "用法：$0 <端口号>"
    echo ""
    echo "示例："
    echo "  $0 8080"
    echo ""
    echo "功能："
    echo "  1. 检查指定端口是否被占用"
    echo "  2. 如果占用，显示占用进程信息"
    echo "  3. 询问是否清理（杀死）占用进程"
    echo ""
    exit 1
}

# 检查参数
if [ $# -lt 1 ]; then
    usage
fi

PORT=$1

# 检查端口是否为数字
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    print_error "端口号必须是数字"
    exit 1
fi

# 检查端口范围
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    print_error "端口号必须在 1-65535 范围内"
    exit 1
fi

echo "=========================================="
echo "  端口占用检查工具"
echo "  端口：$PORT"
echo "=========================================="
echo ""

# 检查端口占用
check_port() {
    # 使用 ss 命令检查端口占用（比 netstat 更快）
    if command -v ss &> /dev/null; then
        ss -tlnp | grep ":$PORT " 2>/dev/null || true
    elif command -v netstat &> /dev/null; then
        netstat -tlnp | grep ":$PORT " 2>/dev/null || true
    else
        print_error "未找到 ss 或 netstat 命令"
        exit 1
    fi
}

# 获取占用进程的 PID
get_pid() {
    if command -v ss &> /dev/null; then
        ss -tlnp | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1
    elif command -v netstat &> /dev/null; then
        netstat -tlnp | grep ":$PORT " | awk '{print $7}' | cut -d'/' -f1 | head -1
    fi
}

# 获取进程信息
get_process_info() {
    local pid=$1
    if [ -n "$pid" ]; then
        ps -p "$pid" -o pid,ppid,user,%cpu,%mem,etime,cmd --no-headers 2>/dev/null || true
    fi
}

# 主逻辑
print_info "正在检查端口 $PORT ..."
echo ""

OCCUPIED=$(check_port)

if [ -z "$OCCUPIED" ]; then
    print_success "端口 $PORT 未被占用，可以使用"
    exit 0
else
    print_warning "端口 $PORT 已被占用"
    echo ""
    echo "占用信息："
    echo "$OCCUPIED"
    echo ""
    
    PID=$(get_pid)
    
    if [ -n "$PID" ]; then
        echo "进程详情："
        get_process_info "$PID"
        echo ""
        
        # 检查是否是 autossh 相关进程
        PROCESS_NAME=$(ps -p "$PID" -o comm --no-headers 2>/dev/null || echo "unknown")
        
        if [[ "$PROCESS_NAME" == *"autossh"* ]] || [[ "$PROCESS_NAME" == *"ssh"* ]]; then
            print_info "检测到是 SSH/AutoSSH 进程占用"
        fi
        
        # 询问是否清理
        echo ""
        read -p "是否清理（杀死）该进程？(y/n): " CONFIRM
        
        if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
            print_info "正在停止进程 $PID ..."
            
            # 先尝试优雅停止
            kill -15 "$PID" 2>/dev/null || true
            
            # 等待 3 秒
            sleep 3
            
            # 检查进程是否还在
            if ps -p "$PID" &> /dev/null; then
                print_warning "进程未响应，强制终止..."
                kill -9 "$PID" 2>/dev/null || true
            fi
            
            # 再次等待
            sleep 1
            
            # 验证端口是否已释放
            REMAINING=$(check_port)
            if [ -z "$REMAINING" ]; then
                print_success "端口 $PORT 已清理完成"
            else
                print_error "端口仍然被占用，可能需要手动处理"
                echo "$REMAINING"
                exit 1
            fi
        else
            print_info "已取消操作"
            exit 0
        fi
    else
        print_warning "无法获取进程 PID，请手动处理"
        exit 1
    fi
fi
