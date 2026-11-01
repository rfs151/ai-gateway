# edgebot.vip 统一入口网关

VPS（141.164.45.82）上的 Caddy，占用 80/443，按子域名转发到各项目，根域名是导航页。部署在 `/opt/gateway`。

| 域名 | 转发到 | Cloudflare |
|---|---|---|
| `edgebot.vip` | 导航页（`site/`）+ `/status/{qt,scada,vision}` | 橙色云朵 |
| `www.edgebot.vip` | 301 跳到 `edgebot.vip` | 橙色云朵 |
| `qt.edgebot.vip` | Qt 作品集 `127.0.0.1:8080`（`/root/qt-showcase`） | 橙色云朵 |
| `scada.edgebot.vip` | PowerGrid SCADA `127.0.0.1:8088`（`/opt/ai-scada`） | 橙色云朵 |
| `vision.edgebot.vip` | ai-vision `127.0.0.1:8090`；播放路径转给 ZLMediaKit `127.0.0.1:8081`（`/opt/ai-vision`） | **灰色云朵**（视频流量、长连接不走 Cloudflare） |
| `medlens.edgebot.vip` | MedLens `127.0.0.1:8010`（`/root/medlens`，Python 服务：页面 + API + WebSocket）；`/cpp/*` 去掉前缀转给 C++ 后端 `127.0.0.1:8091` | 灰色云朵 |
| 直接用 IP | 302 跳到 `edgebot.vip` | |

## 部署

```bash
cd /opt/gateway && docker compose up -d
docker compose logs -f caddy                                            # 证书申请情况
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile    # 改了 Caddyfile 后
```

**注意**：Caddyfile 是单文件挂载。用 `vi` 或 `cp` 原地修改后 `caddy reload` 即可；用 `tar`、`scp`、`mv` 替换文件会换成新文件，容器里还是旧内容，要 `docker compose restart`。

导航页 `site/index.html` 改了直接生效。在线状态灯每 30 秒请求一次 `/status/<项目>`，网关只返回 `ok` / `down`，不暴露各项目健康检查的详细内容。

## 各项目需要的配置

- **ai-vision**（`/opt/ai-vision/.env`）：`ZLM_HTTP_PORT=8081`（让出 80）、`PLAY_HTTP_PORT=80`。
  - 经过网关（`https://vision.edgebot.vip`）访问时，API 看到 `X-Forwarded-Proto`，生成同域名的 https 播放地址，没有混合内容问题。
  - 直接打开 `http://141.164.45.82:8090` 时，播放地址是 `http://141.164.45.82/...`，由网关 80 端口的 IP 站点转给 ZLM。
  - WebRTC 媒体流两种方式都走 UDP/TCP 8000 直连。
- **ai-scada**、**qt-showcase**：不用改。

## 直连端口（保留）

`http://141.164.45.82:8090`（ai-vision）、`:8088`（SCADA）、`:8080`（Qt）、`:8010`（MedLens）继续可以直接打开，和域名入口并存。

| 端口 | 用途 | 放行方式 |
|---|---|---|
| 22 | SSH | ufw |
| 80、443（tcp），443（udp，HTTP/3） | 网关 | ufw |
| 8000（tcp + udp） | ZLM WebRTC 媒体流 | ufw |
| 8090 | ai-vision 直连 | ufw |
| 8080、8088、8443、8010、8091 | qt、SCADA、MedLens（Python / C++）直连 | Docker 端口映射（不受 ufw 控制） |
| 8081 | ZLM HTTP | **不放行**，只经过网关访问 |

## Cloudflare

- DNS：`@`、`www`、`qt`、`scada`、`vision`、`medlens` 六条 A 记录指向 141.164.45.82。
- **先全部用灰色云朵**，等 Caddy 拿到证书（`docker compose logs caddy` 里看到 `certificate obtained successfully`），再把除 `vision` 外的改成橙色。
- SSL/TLS 模式：**Full (strict)**。
- **不要开 "Always Use HTTPS"**：Caddy 自己做 http → https 跳转，并且续期证书要用 http 的验证路径。

## 回退

```bash
cd /opt/gateway && docker compose down
# /opt/ai-vision/.env 改回 ZLM_HTTP_PORT=80，然后 docker compose --profile demo up -d
# 各项目 .env 的备份在 /root/backup-gateway-20261031/
```
