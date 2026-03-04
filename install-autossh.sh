#!/bin/bash
#
# AutoSSH 安装脚本
# 支持 Debian/Ubuntu 和 CentOS/RHEL 系统
#

set -e

echo "=========================================="
echo "  AutoSSH 安装脚本"
echo "=========================================="
echo ""

# 检测系统类型
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
    echo "检测到 Debian/Ubuntu 系统"
elif [ -f /etc/redhat-release ]; then
    DISTRO="redhat"
    echo "检测到 CentOS/RHEL 系统"
else
    echo "警告：未识别的系统类型，尝试使用通用方法安装"
    DISTRO="unknown"
fi

# 安装函数
install_debian() {
    echo "正在更新软件包列表..."
    sudo apt-get update -qq
    echo "正在安装 autossh..."
    sudo apt-get install -y autossh ssh
}

install_redhat() {
    echo "正在安装 EPEL 仓库..."
    sudo yum install -y epel-release
    echo "正在安装 autossh..."
    sudo yum install -y autossh ssh
}

install_unknown() {
    echo "警告：无法自动安装，请手动安装 autossh"
    echo "Debian/Ubuntu: sudo apt-get install autossh"
    echo "CentOS/RHEL:   sudo yum install autossh"
    exit 1
}

# 检查是否已安装
if command -v autossh &> /dev/null; then
    echo "AutoSSH 已安装，版本："
    autossh -V
    echo ""
else
    # 根据系统类型安装
    case $DISTRO in
        debian)
            install_debian
            ;;
        redhat)
            install_redhat
            ;;
        *)
            install_unknown
            ;;
    esac
    
    echo ""
    echo "AutoSSH 安装完成，版本："
    autossh -V
fi

echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
