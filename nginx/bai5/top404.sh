#!/usr/bin/env bash
# Top 5 IP gây ra nhiều response HTTP 404 nhất trong access log của Nginx.
# Cách dùng: ./top404.sh [đường-dẫn-log]   (mặc định /var/log/nginx/access.log)
LOG="${1:-/var/log/nginx/access.log}"

grep '" 404 ' "$LOG" \
  | awk '{print $1}' \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -n 5
