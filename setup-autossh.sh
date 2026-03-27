#!/bin/bash
#
# AutoSSH 一键配置脚本（SOCKS5 代理模式）
# 配置 systemd 用户服务，实现开机自启
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
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

# 获取当前用户
CURRENT_USER=$(whoami)
HOME_DIR=$HOME

echo "=========================================="
echo "  AutoSSH SOCKS5 代理配置"
echo "  用户：$CURRENT_USER"
echo "=========================================="
echo ""

# ============================================
# Step 1: 检查 autossh 是否已安装
# ============================================
print_info "Step 1: 检查 AutoSSH 安装状态"

if ! command -v autossh &> /dev/null; then
    print_warning "AutoSSH 未安装"
    echo ""
    echo "请先运行安装脚本："
    echo "  ./install-autossh.sh"
    echo ""
    exit 1
else
    print_success "AutoSSH 已安装：$(autossh -V 2>&1 | head -1)"
fi

echo ""

# ============================================
# Step 2: 创建配置目录
# ============================================
print_info "Step 2: 创建配置目录"

AUTOSSH_DIR="$HOME_DIR/.autossh"
SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"

mkdir -p "$AUTOSSH_DIR"
mkdir -p "$SYSTEMD_USER_DIR"

print_success "配置目录已创建："
echo "  - $AUTOSSH_DIR"
echo "  - $SYSTEMD_USER_DIR"

echo ""

# ============================================
# Step 3: 选择隧道模式
# ============================================
print_info "Step 3: 选择隧道模式"
echo ""
echo "请选择隧道类型："
echo "  1) SOCKS5 代理（推荐，用于科学上网）"
echo "  2) 端口转发（访问远程特定端口）"
echo ""
read -p "选择 [1-2]: " TUNNEL_MODE

if [ -z "$TUNNEL_MODE" ] || [ "$TUNNEL_MODE" = "1" ]; then
    TUNNEL_MODE="socks5"
    print_info "选择模式：SOCKS5 代理"
elif [ "$TUNNEL_MODE" = "2" ]; then
    TUNNEL_MODE="forward"
    print_info "选择模式：端口转发"
else
    print_error "无效选择"
    exit 1
fi

echo ""

# ============================================
# Step 4: 询问隧道配置
# ============================================
print_info "Step 4: 配置 SSH 隧道参数"
echo ""

# 隧道名称
if [ "$TUNNEL_MODE" = "socks5" ]; then
    read -p "隧道名称（默认 socks5）: " TUNNEL_NAME
    TUNNEL_NAME=${TUNNEL_NAME:-socks5}
else
    read -p "隧道名称（例如 mytunnel）: " TUNNEL_NAME
    TUNNEL_NAME=${TUNNEL_NAME:-default}
fi

# SSH 服务器信息
read -p "SSH 用户名: " SSH_USER
read -p "SSH 服务器地址: " SSH_HOST
read -p "SSH 端口 [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

# 本地端口
if [ "$TUNNEL_MODE" = "socks5" ]; then
    read -p "SOCKS5 代理端口 [1080]: " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-1080}
    REMOTE_PORT=""
else
    read -p "本地监听端口: " LOCAL_PORT
    read -p "远程目标端口: " REMOTE_PORT
fi

# SSH 密钥
echo ""
print_info "SSH 密钥配置"
read -p "SSH 密钥文件路径 [$HOME_DIR/.ssh/id_rsa]: " SSH_KEY
SSH_KEY=${SSH_KEY:-$HOME_DIR/.ssh/id_rsa}

# 检查密钥是否存在
if [ ! -f "$SSH_KEY" ]; then
    print_warning "密钥文件不存在：$SSH_KEY"
    read -p "是否现在生成 SSH 密钥？(y/n): " GENERATE_KEY
    if [ "$GENERATE_KEY" = "y" ]; then
        print_info "生成 SSH 密钥..."
        ssh-keygen -t rsa -b 4096 -f "$HOME_DIR/.ssh/id_rsa" -N ""
        SSH_KEY="$HOME_DIR/.ssh/id_rsa"
        print_success "密钥已生成"
        echo ""
        print_warning "请将公钥 ($SSH_KEY.pub) 复制到远程服务器："
        echo "  ssh-copy-id -i ${SSH_KEY}.pub ${SSH_USER}@${SSH_HOST}"
        echo ""
        read -p "是否现在复制公钥？(y/n): " COPY_KEY
        if [ "$COPY_KEY" = "y" ]; then
            ssh-copy-id -i "${SSH_KEY}.pub" "${SSH_USER}@${SSH_HOST}"
        fi
    else
        print_error "请配置 SSH 密钥后重新运行此脚本"
        exit 1
    fi
fi

echo ""

# ============================================
# Step 5: 创建配置文件
# ============================================
print_info "Step 5: 创建配置文件"

CONFIG_FILE="$AUTOSSH_DIR/${TUNNEL_NAME}.env"

if [ "$TUNNEL_MODE" = "socks5" ]; then
    cat > "$CONFIG_FILE" << EOF
# AutoSSH SOCKS5 代理配置
# 隧道名称：$TUNNEL_NAME
# 创建时间：$(date)

USER="$SSH_USER"
HOST="$SSH_HOST"
PORT="$SSH_PORT"
LOCAL_PORT="$LOCAL_PORT"
SSH_KEY="$SSH_KEY"
EOF
    print_success "SOCKS5 配置文件已创建：$CONFIG_FILE"
else
    cat > "$CONFIG_FILE" << EOF
# AutoSSH 端口转发配置
# 隧道名称：$TUNNEL_NAME
# 创建时间：$(date)

USER="$SSH_USER"
HOST="$SSH_HOST"
PORT="$SSH_PORT"
LOCAL_PORT="$LOCAL_PORT"
REMOTE_PORT="$REMOTE_PORT"
SSH_KEY="$SSH_KEY"
EOF
    print_success "端口转发配置文件已创建：$CONFIG_FILE"
fi

echo ""

# ============================================
# Step 6: 复制 systemd 服务模板
# ============================================
print_info "Step 6: 配置 systemd 用户服务"

# systemd 服务模板目标路径（统一使用 autossh@.service 作为实例化模板）
SERVICE_DEST="$SYSTEMD_USER_DIR/autossh@.service"

if [ "$TUNNEL_MODE" = "socks5" ]; then
    # SOCKS5 模式：优先使用 autossh-socks5@.service 模板
    # 如果不存在，则创建包含企业级参数的内联配置
    SERVICE_TEMPLATE="$(dirname "$0")/autossh-socks5@.service"
    if [ -f "$SERVICE_TEMPLATE" ]; then
        cp "$SERVICE_TEMPLATE" "$SERVICE_DEST"
        print_success "SOCKS5 服务模板已复制"
    else
        print_warning "未找到 SOCKS5 服务模板，创建企业级默认配置..."
        cat > "$SERVICE_DEST" << 'EOF'
[Unit]
Description=AutoSSH SOCKS5 Tunnel Service - %i
Documentation=man:autossh(1)
After=network-online.target
Wants=network-online.target

[Service]
Environment="AUTOSSH_GATETIME=0"
EnvironmentFile=%h/.autossh/%i.env

ExecStartPre=/bin/bash -c 'PORT=${LOCAL_PORT}; if command -v ss &> /dev/null; then if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP "pid=\\K[0-9]+" | head -1); if [ -n "$PID" ]; then PROCESS=$(ps -p $PID -o comm --no-headers 2>/dev/null || echo "unknown"); if [[ "$PROCESS" == *"autossh"* ]] || [[ "$PROCESS" == *"ssh"* ]]; then kill -15 $PID 2>/dev/null || true; sleep 2; kill -9 $PID 2>/dev/null || true; fi; fi; fi; fi; exit 0'

# 启动命令（企业级超稳定配置）
# 总超时 = 15 秒 × 120 次 = 1800 秒 = 30 分钟
ExecStart=/usr/bin/autossh -M 0 -N -T \
    -i ${SSH_KEY} \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=120 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=30 \
    -o ConnectionAttempts=10 \
    -D 0.0.0.0:${LOCAL_PORT} \
    ${USER}@${HOST} -p ${PORT}

Restart=always
RestartSec=10
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal
SyslogIdentifier=autossh-%i

[Install]
WantedBy=default.target
EOF
        print_success "企业级 SOCKS5 服务配置已创建"
    fi
else
    # 端口转发模式：优先使用 autossh@.service 模板
    SERVICE_TEMPLATE="$(dirname "$0")/autossh@.service"
    if [ -f "$SERVICE_TEMPLATE" ]; then
        cp "$SERVICE_TEMPLATE" "$SERVICE_DEST"
        print_success "端口转发服务模板已复制"
    else
        print_warning "未找到服务模板，创建默认配置..."
        cat > "$SERVICE_DEST" << 'EOF'
[Unit]
Description=AutoSSH Tunnel Service - %i
Documentation=man:autossh(1)
After=network-online.target
Wants=network-online.target

[Service]
Environment="AUTOSSH_GATETIME=0"
EnvironmentFile=%h/.autossh/%i.env

ExecStartPre=/bin/bash -c 'PORT=${LOCAL_PORT}; if command -v ss &> /dev/null; then if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP "pid=\\K[0-9]+" | head -1); if [ -n "$PID" ]; then PROCESS=$(ps -p $PID -o comm --no-headers 2>/dev/null || echo "unknown"); if [[ "$PROCESS" == *"autossh"* ]] || [[ "$PROCESS" == *"ssh"* ]]; then kill -15 $PID 2>/dev/null || true; sleep 2; kill -9 $PID 2>/dev/null || true; fi; fi; fi; fi; exit 0'

# 启动命令（企业级超稳定配置）
ExecStart=/usr/bin/autossh -M 0 -N -T \
    -i ${SSH_KEY} \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=120 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=30 \
    -o ConnectionAttempts=10 \
    -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} \
    ${USER}@${HOST} -p ${PORT}

Restart=always
RestartSec=10
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal
SyslogIdentifier=autossh-%i

[Install]
WantedBy=default.target
EOF
        print_success "默认端口转发服务配置已创建"
    fi
fi

echo ""

# ============================================
# Step 7: 端口占用检查和清理
# ============================================
print_info "Step 7: 检查端口占用情况"

# 脚本目录
SCRIPT_DIR="$(dirname "$0")"

# 检查本地端口是否被占用
print_info "检查本地端口 $LOCAL_PORT ..."
if command -v ss &> /dev/null; then
    if ss -tlnp | grep -q ":$LOCAL_PORT "; then
        print_warning "本地端口 $LOCAL_PORT 已被占用"
        echo ""
        echo "占用信息："
        ss -tlnp | grep ":$LOCAL_PORT " || true
        echo ""
        read -p "是否自动清理占用进程？(y/n): " CLEAN_CONFIRM
        if [ "$CLEAN_CONFIRM" = "y" ] || [ "$CLEAN_CONFIRM" = "Y" ]; then
            print_info "执行端口清理..."
            if [ -f "$SCRIPT_DIR/cleanup-port.sh" ]; then
                bash "$SCRIPT_DIR/cleanup-port.sh" "$LOCAL_PORT" || true
            else
                print_warning "cleanup-port.sh 不存在，跳过自动清理"
            fi
        else
            print_warning "未清理端口，服务可能启动失败"
        fi
    else
        print_success "本地端口 $LOCAL_PORT 可用"
    fi
fi

echo ""

# ============================================
# Step 8: 重载 systemd 并启用服务
# ============================================
print_info "Step 8: 启用并启动服务"

# 重载 systemd 用户配置
systemctl --user daemon-reload

# 启用开机自启
systemctl --user enable "autossh@${TUNNEL_NAME}.service"
print_success "服务已启用（开机自启）"

# 启动服务
systemctl --user start "autossh@${TUNNEL_NAME}.service"
print_success "服务已启动"

echo ""

# ============================================
# Step 9: 验证服务状态
# ============================================
print_info "Step 9: 验证服务状态"

sleep 2

if systemctl --user is-active --quiet "autossh@${TUNNEL_NAME}.service"; then
    print_success "服务运行正常"
    echo ""
    echo "服务信息："
    systemctl --user status "autossh@${TUNNEL_NAME}.service" --no-pager
else
    print_warning "服务未正常运行，查看日志："
    echo "  journalctl --user -u autossh@${TUNNEL_NAME}.service -n 50"
fi

echo ""

# ============================================
# 完成
# ============================================
echo "=========================================="
print_success "配置完成！"
echo "=========================================="
echo ""

if [ "$TUNNEL_MODE" = "socks5" ]; then
    echo "🎉 SOCKS5 代理配置完成！"
    echo ""
    echo "快速命令："
    echo "  查看状态：  systemctl --user status autossh@${TUNNEL_NAME}.service"
    echo "  启动服务：  systemctl --user start autossh@${TUNNEL_NAME}.service"
    echo "  停止服务：  systemctl --user stop autossh@${TUNNEL_NAME}.service"
    echo "  重启服务：  systemctl --user restart autossh@${TUNNEL_NAME}.service"
    echo "  查看日志：  journalctl --user -u autossh@${TUNNEL_NAME}.service -f"
    echo ""
    echo "代理配置："
    echo "  代理类型：SOCKS5"
    echo "  代理地址：localhost"
    echo "  代理端口：$LOCAL_PORT"
    echo ""
    echo "使用示例："
    echo "  浏览器：配置 SOCKS5 代理 localhost:$LOCAL_PORT"
    echo "  命令行：curl --socks5-hostname localhost:$LOCAL_PORT https://www.google.com"
    echo "  proxychains: 编辑 /etc/proxychains.conf 添加 socks5 127.0.0.1 $LOCAL_PORT"
    echo ""
    echo "测试代理："
    echo "  curl --socks5-hostname localhost:$LOCAL_PORT https://api.ip.sb/ip"
else
    echo "🎉 端口转发配置完成！"
    echo ""
    echo "快速命令："
    echo "  查看状态：  systemctl --user status autossh@${TUNNEL_NAME}.service"
    echo "  启动服务：  systemctl --user start autossh@${TUNNEL_NAME}.service"
    echo "  停止服务：  systemctl --user stop autossh@${TUNNEL_NAME}.service"
    echo "  重启服务：  systemctl --user restart autossh@${TUNNEL_NAME}.service"
    echo "  查看日志：  journalctl --user -u autossh@${TUNNEL_NAME}.service -f"
    echo ""
    echo "端口清理工具："
    echo "  ./cleanup-port.sh $LOCAL_PORT"
    echo ""
    echo "测试隧道："
    echo "  curl http://localhost:${LOCAL_PORT}"
fi

echo ""
echo "配置文件位置："
echo "  $CONFIG_FILE"
echo ""
