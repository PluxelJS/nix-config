#!/usr/bin/python3
"""Local n2n console; privileged operations use a root-owned, bounded helper."""

import concurrent.futures
import http.server
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import socket
import statistics
import struct
import subprocess
import sys
import threading
import time
import urllib.request
import urllib.parse

PORT = 11212
ORIGIN = f"http://127.0.0.1:{PORT}"
UNIT = "n2n-lan.service"
ROOT = Path("/var/lib/n2n-lan")
SERVERS = [
    "n2n.s2.plus.bugxia.com:39662",
    "n2n.s4.plus.bugxia.com:50111",
    "n2n.s9.plus.bugxia.com:43058",
    "n2n.s10.plus.bugxia.com:53295",
    "n2n.s13.plus.bugxia.com:37125",
]
DEFAULT = dict(community="my-lan", server=SERVERS[0], address="", key="")


def endpoint(value):
    if not isinstance(value, str) or len(value) > 260:
        raise ValueError("请输入域名或 IPv4 地址:端口")
    match = re.fullmatch(r"([A-Za-z0-9][A-Za-z0-9.-]*):([0-9]{1,5})", value.strip())
    if not match or not 1 <= int(match[2]) <= 65535:
        raise ValueError("请输入域名或 IPv4 地址:端口，端口范围为 1–65535")
    host = match[1].lower().rstrip(".")
    if len(host) > 253 or any(
        not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label)
        for label in host.split(".")
    ):
        raise ValueError("服务器域名格式无效")
    return f"{host}:{int(match[2])}"


def parse_subscription(body):
    try:
        rows = json.loads(body)
        if not isinstance(rows, list) or not 1 <= len(rows) <= 256:
            raise ValueError()
        result = []
        for row in rows:
            if (
                not isinstance(row, dict)
                or not isinstance(row.get("server"), str)
                or isinstance(row.get("port"), bool)
            ):
                raise ValueError()
            result.append(endpoint(f"{row['server']}:{row.get('port', '')}"))
        return list(dict.fromkeys(result))
    except (ValueError, TypeError):
        raise ValueError(
            "订阅须为包含 server、port 字段的 JSON 数组（1–256 项）"
        ) from None


def subscription_url(value):
    if (
        not isinstance(value, str)
        or len(value) > 2048
        or any(c.isspace() or ord(c) < 32 for c in value)
    ):
        raise ValueError("请输入有效的 HTTPS 订阅地址")
    url = urllib.parse.urlsplit(value)
    if (
        url.scheme != "https"
        or not url.hostname
        or url.username
        or url.password
        or url.fragment
    ):
        raise ValueError("订阅地址须使用 HTTPS，不能含登录信息或片段")
    return value


class HTTPSRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        subscription_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_subscription(url):
    url = subscription_url(url)
    try:
        opener = urllib.request.build_opener(HTTPSRedirect())
        with opener.open(
            urllib.request.Request(url, headers={"Accept": "application/json"}),
            timeout=15,
        ) as response:
            body = response.read(1024 * 1024 + 1)
        if len(body) > 1024 * 1024:
            raise ValueError("订阅超过 1 MiB 大小限制")
    except (OSError, ValueError):
        # Remote exceptions can include the private subscription URL.
        raise ValueError("订阅下载失败，请检查地址和网络；原有列表已保留") from None
    return parse_subscription(body)


def catalog(path):
    return (
        json.loads(path.read_text())
        if path.exists()
        else dict(manual=SERVERS[:], subscription="", subscribed=[])
    )


def catalog_view(data):
    return dict(
        servers=list(dict.fromkeys(data["manual"] + data["subscribed"])),
        manual=data["manual"],
        subscribed=data["subscribed"],
        subscription=data["subscription"],
    )


def probe_server(address, community):
    """n2n v3 QUERY_PEER with a null target MAC is its native PING.

    Wire layout: ntop/n2n tag 3.0 src/wire.c, include/n2n_define.h.
    This does not register an edge, allocate a TAP, or join the community.
    """
    host, port = endpoint(address).rsplit(":", 1)
    group = community.encode("ascii").ljust(20, b"\0")
    mac = bytes([2]) + secrets.token_bytes(5)
    packet = struct.pack("!BBH20s6s6sH", 3, 2, 11, group, mac, bytes(6), 0)
    timings = []
    error = "timeout"
    for _ in range(2):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.settimeout(1.5)
                sock.connect((host, int(port)))
                start = time.monotonic()
                sock.send(packet)
                deadline = start + 1.5
                while time.monotonic() < deadline:
                    sock.settimeout(max(0.001, deadline - time.monotonic()))
                    reply = sock.recv(2048)
                    flags = int.from_bytes(reply[2:4], "big")
                    if (
                        len(reply) >= 54
                        and reply[0] == 3
                        and flags & 31 == 10
                        and flags & 32
                        and reply[4:24] == group
                        and reply[32:38] == bytes(6)
                    ):
                        timings.append((time.monotonic() - start) * 1000)
                        break
        except socket.gaierror:
            error = "dns_error"
        except TimeoutError:
            pass
        except OSError:
            error = "unreachable"
    return dict(
        ms=round(statistics.median(timings), 1) if timings else None,
        status="ok" if timings else error,
        received=len(timings),
        sent=2,
        checked=time.time(),
    )


class Probes:
    def __init__(self):
        self.lock = threading.Lock()
        self.results = {}
        self.started = 0
        self.running = False
        self.signature = None

    def request(self, servers, community, force=False):
        signature = (tuple(servers), community)
        with self.lock:
            elapsed = time.monotonic() - self.started
            if not self.running and (
                signature != self.signature or elapsed >= (3 if force else 30)
            ):
                if signature != self.signature:
                    self.results = {}
                self.signature = signature
                self.running = True
                self.started = time.monotonic()
                threading.Thread(
                    target=self.measure, args=(servers, community), daemon=True
                ).start()
            return dict(
                results=self.results.copy(),
                running=self.running,
                community=self.signature[1],
            )

    def measure(self, servers, community):
        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                futures = {
                    pool.submit(probe_server, server, community): server
                    for server in servers
                }
                for future in concurrent.futures.as_completed(futures):
                    result = future.result()
                    with self.lock:
                        self.results[futures[future]] = result
        finally:
            with self.lock:
                self.running = False


def validate(data):
    if not isinstance(data, dict):
        raise ValueError("配置必须是对象")
    result = {k: data.get(k, "") for k in DEFAULT}
    if not all(isinstance(v, str) for v in result.values()):
        raise ValueError("配置字段必须为文字")
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,16}", result["community"]):
        raise ValueError("小组名须为 1–16 个英文字母、数字、下划线、点或短横线")
    result["server"] = endpoint(result["server"])
    if result["address"]:
        addr = ipaddress.IPv4Interface(result["address"])
        if (
            not addr.ip.is_private
            or addr.ip.is_loopback
            or addr.ip.is_link_local
            or addr.ip.is_unspecified
            or addr.ip.is_multicast
        ):
            raise ValueError("请使用私有 IPv4 地址及掩码，例如 10.42.0.20/24")
        if addr.network.prefixlen > 30 or addr.ip in (
            addr.network.network_address,
            addr.network.broadcast_address,
        ):
            raise ValueError("请输入可用的主机地址和 /1–/30 掩码")
        result["address"] = str(addr)
    if len(result["key"]) > 128 or any(
        ord(c) < 33 or ord(c) > 126 for c in result["key"]
    ):
        raise ValueError("密钥请使用最多 128 个不含空格的 ASCII 字符")
    return result


def run(args, **kwargs):
    return subprocess.run(
        args,
        text=True,
        capture_output=True,
        timeout=kwargs.pop("timeout", 15),
        **kwargs,
    )


def save(path, data):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    with open(temp, "w", opener=lambda p, f: os.open(p, f, 0o600)) as out:
        json.dump(data, out)
    os.replace(temp, path)


def privileged(action):
    if os.geteuid() != 0:
        raise ValueError("需要管理员认证")
    if action == "connect":
        data = validate(json.loads(sys.stdin.read(4097)))
        save(ROOT / "config.json", data)
        p = run(["/usr/bin/systemctl", "restart", UNIT], timeout=30)
    elif action == "disconnect":
        p = run(["/usr/bin/systemctl", "stop", UNIT], timeout=30)
    elif action == "run":
        data = validate(json.loads((ROOT / "config.json").read_text()))
        edge = "/usr/local/lib/n2n-lan/runtime/bin/edge"
        args = [
            edge,
            "-f",
            "-d",
            "n2n0",
            "-c",
            data["community"],
            "-l",
            data["server"],
            "-E",
            "-t",
            "15644",
            "-I",
            socket.gethostname()[:15],
            "--management-password",
            secrets.token_hex(24),
        ]
        if data["address"]:
            args += ["-a", data["address"]]
        env = dict(os.environ)
        env.pop("N2N_KEY", None)
        env.pop("N2N_COMMUNITY", None)
        env.pop("N2N_PASSWORD", None)
        if data["key"]:
            env["N2N_KEY"] = data["key"]
            args += ["-A3"]
        else:
            args += ["-A1"]
        os.execve(edge, args, env)
    else:
        raise ValueError("未知操作")
    if p.returncode:
        raise ValueError(p.stderr.strip() or "systemd 操作失败")
    print(json.dumps({"ok": True}))


def query(method):
    tag = secrets.token_hex(4)
    rows = []
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(0.8)
        sock.connect(("127.0.0.1", 15644))
        sock.send(f"r {tag} {method}\n".encode())
        deadline = time.monotonic() + 1.5
        try:
            while time.monotonic() < deadline and len(rows) < 256:
                row = json.loads(sock.recv(65535))
                if row.get("_tag") != tag:
                    continue
                if row.get("_type") == "end":
                    break
                if row.get("_type") == "row":
                    rows.append({k: v for k, v in row.items() if not k.startswith("_")})
        except (OSError, ValueError):
            pass
    return rows


def status():
    active = run(["/usr/bin/systemctl", "is-active", UNIT]).stdout.strip()
    p = run(["/usr/bin/ip", "-j", "-4", "addr", "show", "dev", "n2n0"])
    addresses = [
        f"{a['local']}/{a['prefixlen']}"
        for i in json.loads(p.stdout or "[]")
        for a in i.get("addr_info", [])
    ]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        sn, peers, stats = list(pool.map(query, ["supernodes", "edges", "packetstats"]))
    registered = any(
        s.get("current") == 1 and time.time() - s.get("last_seen", 0) < 90 for s in sn
    )
    log = run(
        ["/usr/bin/journalctl", "-u", UNIT, "-n", "18", "--no-pager", "-o", "cat"]
    ).stdout
    return dict(
        active=active,
        registered=registered,
        addresses=addresses,
        servers=sn,
        peers=peers,
        stats=stats,
        log=log,
    )


class Handler(http.server.BaseHTTPRequestHandler):
    def reply(self, code, data, kind="application/json"):
        body = (
            data.encode()
            if isinstance(data, str)
            else json.dumps(data, ensure_ascii=False).encode()
        )
        self.send_response(code)
        self.send_header("Content-Type", kind + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
        )
        self.end_headers()
        self.wfile.write(body)

    def allowed(self, api=False):
        return (
            self.headers.get("Host") == f"127.0.0.1:{PORT}"
            and self.headers.get("Origin", ORIGIN) == ORIGIN
            and (
                not api
                or secrets.compare_digest(
                    self.headers.get("X-N2N-Token", ""), self.server.token
                )
            )
        )

    def do_GET(self):
        if not self.allowed(self.path.startswith("/api/")):
            return self.reply(403, {"error": "本机访问校验失败，请重新打开页面"})
        if self.path == "/":
            return self.reply(
                200,
                (Path(__file__).with_name("index.html"))
                .read_text()
                .replace("__TOKEN__", self.server.token),
                "text/html",
            )
        if self.path == "/api/config":
            data = (
                json.loads(self.server.config.read_text())
                if self.server.config.exists()
                else DEFAULT
            )
            return self.reply(
                200, {"config": data, **catalog_view(catalog(self.server.catalog))}
            )
        if self.path == "/api/status":
            return self.reply(200, status())
        self.reply(404, {"error": "未找到"})

    def do_POST(self):
        if not self.allowed(True):
            return self.reply(403, {"error": "本机访问校验失败"})
        if self.path not in (
            "/api/connect",
            "/api/disconnect",
            "/api/server-add",
            "/api/server-remove",
            "/api/subscription",
            "/api/probe",
        ):
            return self.reply(404, {"error": "未知操作"})
        if not self.server.lock.acquire(blocking=False):
            return self.reply(409, {"error": "正在处理上一次操作，请完成桌面认证"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if (
                not 0 < length <= 4096
                or self.headers.get("Content-Type") != "application/json"
            ):
                raise ValueError("无效请求")
            data = json.loads(self.rfile.read(length))
            action = self.path.rsplit("/", 1)[1]
            if not isinstance(data, dict):
                raise ValueError("请求必须为对象")
            if action == "probe":
                community = validate(dict(DEFAULT, community=data.get("community")))[
                    "community"
                ]
                entries = catalog_view(catalog(self.server.catalog))["servers"]
                return self.reply(
                    200,
                    self.server.probes.request(
                        entries, community, data.get("force") is True
                    ),
                )
            if action in ("server-add", "server-remove", "subscription"):
                entries = catalog(self.server.catalog)
                if action == "subscription":
                    url = subscription_url(data.get("url"))
                    entries["subscribed"] = fetch_subscription(url)
                    if not self.server.catalog.exists():
                        entries["manual"] = []
                    entries["subscription"] = url
                else:
                    address = endpoint(data.get("server"))
                    if action == "server-add" and address not in entries["manual"]:
                        if len(entries["manual"]) >= 256:
                            raise ValueError("手动服务器最多 256 项")
                        entries["manual"].append(address)
                    elif action == "server-remove":
                        entries["manual"] = [
                            v for v in entries["manual"] if v != address
                        ]
                save(self.server.catalog, entries)
                return self.reply(200, catalog_view(entries))
            config = validate(data) if action == "connect" else {}
            p = run(
                ["/usr/bin/pkexec", "/usr/local/lib/n2n-lan/helper", action],
                input=json.dumps(config),
                timeout=180,
            )
            if p.returncode:
                raise ValueError(p.stderr.strip() or "认证取消或连接操作失败")
            if action == "connect":
                save(self.server.config, config)
            self.reply(200, {"ok": True})
        except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
            self.reply(400, {"error": str(exc)})
        finally:
            self.server.lock.release()

    def log_message(self, fmt, *args):
        pass


def main():
    os.umask(0o077)
    if len(sys.argv) == 2:
        privileged(sys.argv[1])
        return
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    server.probes = Probes()
    server.token = secrets.token_hex(32)
    server.lock = threading.Lock()
    server.config = (
        Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
        / "n2n-web/config.json"
    )
    server.catalog = server.config.with_name("servers.json")
    server.serve_forever()


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
