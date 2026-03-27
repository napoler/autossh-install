#!/bin/bash
#
# AutoSSH 统一管理入口
# 用法: ./autossh.sh <命令> [参数]
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 显示帮助
show_help() {
    cat << EOF
${CYAN}AutoSSH 统一管理工具${NC}

${GREEN}用法:${NC}
  ./autossh.sh <命令> [参数]

${GREEN}命令:${NC}
  ${CYAN}install${NC}             安装 AutoSSH（需要 sudo）
  ${CYAN}setup${NC}                交互式配置隧道
  ${CYAN}status${NC} [隧道名]      查看服务状态（默认 all）
  ${CYAN}start${NC} <隧道名>       启动隧道服务
  ${CYAN}stop${NC} <隧道名>        停止隧道服务
  ${CYAN}restart${NC} <隧道名>    重启隧道服务
  ${CYAN}logs${NC} <隧道名>        查看日志（实时跟踪）
  ${CYAN}cleanup${NC} <端口>        清理占用端口的进程
  ${CYAN}list${NC}                 列出所有隧道配置
  ${CYAN}enable${NC} <隧道名>      启用开机自启
  ${CYAN}disable${NC} <隧道名>      禁用开机自启
  ${CYAN}help${NC}                 显示本帮助

${GREEN}示例:${NC}
  ./autossh.sh install            # 安装 AutoSSH
  ./autossh.sh setup             # 配置新隧道
  ./autossh.sh status            # 查看所有隧道状态
  ./autossh.sh status mytunnel   # 查看指定隧道状态
  ./autossh.sh logs socks5       # 跟踪 socks5 隧道日志
  ./autossh.sh cleanup 1080      # 清理 1080 端口

EOF
}

# 检查命令
check_command() {
    command -v "$1" &> /dev/null
}

# 安装 AutoSSH
cmd_install() {
    print_info "开始安装 AutoSSH..."
    if [ -f "$SCRIPT_DIR/install-autossh.sh" ]; then
        bash "$SCRIPT_DIR/install-autossh.sh"
    else
        print_error "安装脚本不存在: $SCRIPT_DIR/install-autossh.sh"
        exit 1
    fi
}

# 配置隧道
cmd_setup() {
    print_info "开始配置隧道..."
    if [ -f "$SCRIPT_DIR/setup-autossh.sh" ]; then
        bash "$SCRIPT_DIR/setup-autossh.sh"
    else
        print_error "配置脚本不存在: $SCRIPT_DIR/setup-autossh.sh"
        exit 1
    fi
}

# 查看状态
cmd_status() {
    local tunnel="${1:-all}"

    if [ "$tunnel" = "all" ]; then
        print_info "查看所有隧道状态..."
        systemctl --user list-units --type=service --all | grep autossh || print_info "没有运行的 AutoSSH 服务"
    else
        print_info "查看隧道 [$tunnel] 状态..."
        systemctl --user status "autossh@${tunnel}.service" --no-pager || true
    fi
}

# 启动服务
cmd_start() {
    local tunnel="$1"
    if [ -z "$tunnel" ]; then
        print_error "请指定隧道名称"
        echo "用法: ./autossh.sh start <隧道名>"
        exit 1
    fi
    print_info "启动隧道 [$tunnel]..."
    systemctl --user start "autossh@${tunnel}.service"
    print_success "隧道已启动"
}

# 停止服务
cmd_stop() {
    local tunnel="$1"
    if [ -z "$tunnel" ]; then
        print_error "请指定隧道名称"
        echo "用法: ./autossh.sh stop <隧道名>"
        exit 1
    fi
    print_info "停止隧道 [$tunnel]..."
    systemctl --user stop "autossh@${tunnel}.service"
    print_success "隧道已停止"
}

# 重启服务
cmd_restart() {
    local tunnel="$1"
    if [ -z "$tunnel" ]; then
        print_error "请指定隧道名称"
        echo "用法: ./autossh.sh restart <隧道名>"
        exit 1
    fi
    print_info "重启隧道 [$tunnel]..."
    systemctl --user restart "autossh@${tunnel}.service"
    print_success "隧道已重启"
}

# 查看日志
cmd_logs() {
    local tunnel="$1"
    if [ -z "$tunnel" ]; then
        print_error "请指定隧道名称"
        echo "用法: ./autossh.sh logs <隧道名>"
        exit 1
    fi
    print_info "跟踪隧道 [$tunnel] 日志 (Ctrl+C 退出)..."
    journalctl --user -u "autossh@${tunnel}.service" -f
}

# 清理端口
cmd_cleanup() {
    local port="$1"
    if [ -z "$port" ]; then
        print_error "请指定端口号"
        echo "用法: ./autossh.sh cleanup <端口>"
        exit 1
    fi
    print_info "清理端口 [$port]..."
    if [ -f "$SCRIPT_DIR/cleanup-port.sh" ]; then
        bash "$SCRIPT_DIR/cleanup-port.sh" "$port"
    else
        print_error "清理脚本不存在: $SCRIPT_DIR/cleanup-port.sh"
        exit 1
    fi
}

# 列出所有隧道
cmd_list() {
    print_info "隧道配置列表:"
    echo ""
    local config_dir="$HOME/.autossh"
    if [ -d "$config_dir" ]; then
        ls -1 "$config_dir"/*.env 2>/dev/null | while read config; do
            local name=$(basename "$config" .env)
            local enabled=$(systemctl --user is-enabled "autossh@${name}.service" 2>/dev/null || echo "disabled")
            local active=$(systemctl --user is-active "autossh@${name}.service" 2>/dev/null || echo "inactive")

            if [ "$active" = "active" ]; then
                echo -e "  ${GREEN}●${NC} $name (enabled: $enabled)"
            else
                echo -e "  ${YELLOW}○${NC} $name (enabled: $enabled, status: $active)"
            fi
        done
    else
        print_warning "没有找到隧道配置"
        echo "  使用 ./autossh.sh setup 创建第一个隧道"
    fi
}

# 启用开机自启
cmd_enable() {
    local tunnel="$1"
    if [ -z "$tunnel" ]; then
        print_error "请指定隧道名称"
        echo "用法: ./autossh.sh enable <隧道名>"
        exit 1
    fi
    print_info "启用隧道 [$tunnel] 开机自启..."
    systemctl --user enable "autossh@${tunnel}.service"
    print_success "已启用开机自启"
}

# 禁用开机自启
cmd_disable() {
    local tunnel="$1"
    if [ -z "$tunnel" ]; then
        print_error "请指定隧道名称"
        echo "用法: ./autossh.sh disable <隧道名>"
        exit 1
    fi
    print_info "禁用隧道 [$tunnel] 开机自启..."
    systemctl --user disable "autossh@${tunnel}.service"
    print_success "已禁用开机自启"
}

# 主入口
main() {
    local command="${1:-help}"

    case "$command" in
        install)    cmd_install ;;
        setup)      cmd_setup ;;
        status)     cmd_status "$2" ;;
        start)      cmd_start "$2" ;;
        stop)       cmd_stop "$2" ;;
        restart)    cmd_restart "$2" ;;
        logs)       cmd_logs "$2" ;;
        cleanup)    cmd_cleanup "$2" ;;
        list)       cmd_list ;;
        enable)     cmd_enable "$2" ;;
        disable)    cmd_disable "$2" ;;
        help|--help|-h) show_help ;;
        *)
            print_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
