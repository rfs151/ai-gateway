#!/usr/bin/env bash
# gateway 统一入口 / 导航页 —— 启停 / 查看状态
# 部署方式：纯 Docker（Caddy，network_mode: host，restart: unless-stopped，随 Docker 开机自启）
#   服务器（/opt/gateway，Vultr）：Caddyfile，占 80/443，按子域名转发到各项目，自动申请证书
#   本机（其他目录）：叠加 docker-compose.local.yml 用 Caddyfile.local，监听 8880/8843，
#                     国内 VPS 121.41.221.119 的 80/443 经 frp 原样转发过来，同样按子域名转发、自动证书
#
#   ./ctl.sh start | stop | restart | status | logs | reload（改了 Caddyfile 后，不中断服务）
set -euo pipefail
cd "$(dirname "$0")"
case $PWD in
  /opt/*) DC=(docker compose);                                          URL=https://edgebot.vip/ ;;
  *)      DC=(docker compose -f docker-compose.yml -f docker-compose.local.yml); URL=http://127.0.0.1:8880/ ;;
esac

case ${1:-status} in
  start)   "${DC[@]}" up -d ;;
  stop)    "${DC[@]}" stop ;;
  restart) "${DC[@]}" restart ;;
  reload)  "${DC[@]}" exec caddy caddy reload --config /etc/caddy/Caddyfile ;;
  status)
    "${DC[@]}" ps -a --format 'table {{.Service}}\t{{.Status}}'
    echo "导航页 $URL -> $(curl -s --noproxy '*' -m 5 -o /dev/null -w '%{http_code}' "$URL" || true)"
    for k in qt scada ems vision medlens; do
      printf '  %-8s %s\n' "$k" "$(curl -s --noproxy '*' -m 6 "${URL%/}/status/$k" || echo down)"
    done ;;
  logs)    "${DC[@]}" logs -f --tail 100 ;;
  *)       sed -n '2,8p' "$0"; exit 1 ;;
esac
