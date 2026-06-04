#!/bin/bash
# Common utilities for hosting panel

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/hosting-panel.log
}

is_port_available() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 1
    fi
    return 0
}
