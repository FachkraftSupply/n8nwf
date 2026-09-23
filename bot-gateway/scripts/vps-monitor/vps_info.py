#!/usr/bin/env python3
"""Thu thap thong tin he thong (CPU load, RAM, disk, top container Docker theo
dung luong) cho lenh /vps cua Telebot Admin System. Chi dung Python stdlib,
khong can cai them thu vien. In JSON ra stdout.

Che do CLI:
  python3 vps_info.py                          -> tong quan he thong (mac dinh)
  python3 vps_info.py container-info <id>      -> chi tiet 1 container
  python3 vps_info.py container-restart <id>   -> restart 1 container
<id> la Docker container ID (12-64 ky tu hex, lay tu output cua che do mac dinh)."""
import json
import os
import re
import shutil
import subprocess
import sys

CONTAINER_ID_RE = re.compile(r"^[a-f0-9]{12,64}$")


def get_load():
    one, five, fifteen = os.getloadavg()
    return {"1m": round(one, 2), "5m": round(five, 2), "15m": round(fifteen, 2)}


def get_ram():
    # /proc/meminfo chi co tren Linux - dung cho VPS thuc te. Neu chay tren
    # may khac (vd test tren macOS) tra ve gia tri rong thay vi crash.
    if not os.path.exists("/proc/meminfo"):
        return {"total_mb": None, "used_mb": None, "free_mb": None, "used_pct": None}
    meminfo = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, val = line.split(":", 1)
            meminfo[key] = int(val.strip().split()[0])  # kB
    total = meminfo["MemTotal"]
    free = meminfo.get("MemAvailable", meminfo.get("MemFree", 0))
    used = total - free
    return {
        "total_mb": round(total / 1024, 1),
        "used_mb": round(used / 1024, 1),
        "free_mb": round(free / 1024, 1),
        "used_pct": round(used / total * 100, 1) if total else 0,
    }


def get_disk(path="/"):
    total, used, free = shutil.disk_usage(path)
    gb = 1024 ** 3
    return {
        "total_gb": round(total / gb, 1),
        "used_gb": round(used / gb, 1),
        "free_gb": round(free / gb, 1),
        "used_pct": round(used / total * 100, 1) if total else 0,
    }


def get_docker_containers(limit=10):
    """Tra ve danh sach container sap xep theo dung luong disk giam dan.
    Tra {"available": False} neu docker CLI khong co san (vd goi tu ben trong
    container khong mount docker socket)."""
    if shutil.which("docker") is None:
        return {"available": False, "containers": []}

    try:
        ps_out = subprocess.run(
            ["docker", "ps", "-a", "--format", "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"],
            capture_output=True, text=True, timeout=10, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return {"available": False, "containers": []}

    sizes = {}
    try:
        size_out = subprocess.run(
            ["docker", "system", "df", "-v", "--format", "{{json .}}"],
            capture_output=True, text=True, timeout=15, check=True,
        ).stdout.strip()
        for line in size_out.splitlines():
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            # docker system df -v: cac dong container co ca "Names" va "Size"
            if isinstance(obj, dict) and "Names" in obj and "Size" in obj:
                sizes[obj["Names"]] = obj["Size"]
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        pass

    def parse_size(raw):
        try:
            num_str = "".join(c for c in raw if (c.isdigit() or c == "."))
            unit = raw[len(num_str):].strip().upper()
            num = float(num_str)
        except (ValueError, AttributeError):
            return -1.0
        mult = {"B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}.get(unit, 1)
        return num * mult

    containers = []
    for line in ps_out.splitlines():
        if not line:
            continue
        cols = (line.split("\t") + ["", "", "", ""])[:4]
        container_id, name, image, status = cols
        size = sizes.get(name, "?")
        containers.append({
            "id": container_id,
            "name": name,
            "image": image,
            "status": status,
            "size": size,
            "_size_bytes": parse_size(size),
        })

    containers.sort(key=lambda c: c["_size_bytes"], reverse=True)
    for c in containers:
        del c["_size_bytes"]

    return {"available": True, "containers": containers[:limit]}


def get_container_detail(container_id):
    """Tra ve thong tin chi tiet 1 container (docker inspect + docker stats tuc thoi).
    Tra {"error": "..."} neu id sai dinh dang, docker CLI khong co, hoac container
    khong ton tai."""
    if not CONTAINER_ID_RE.match(container_id or ""):
        return {"error": "invalid_id"}
    if shutil.which("docker") is None:
        return {"error": "docker_unavailable"}

    try:
        inspect_out = subprocess.run(
            ["docker", "inspect", container_id],
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        return {"error": str(exc)}
    if inspect_out.returncode != 0:
        return {"error": "not_found"}
    try:
        info = json.loads(inspect_out.stdout)[0]
    except (json.JSONDecodeError, IndexError, KeyError):
        return {"error": "inspect_parse_failed"}

    state = info.get("State", {})
    ports_raw = (info.get("NetworkSettings") or {}).get("Ports") or {}
    ports = []
    for container_port, bindings in ports_raw.items():
        if not bindings:
            continue
        for b in bindings:
            ports.append(f"{b.get('HostIp', '')}:{b.get('HostPort', '')} -> {container_port}")

    stats = {}
    try:
        stats_out = subprocess.run(
            ["docker", "stats", container_id, "--no-stream", "--format", "{{json .}}"],
            capture_output=True, text=True, timeout=10,
        )
        if stats_out.returncode == 0 and stats_out.stdout.strip():
            stats = json.loads(stats_out.stdout.strip().splitlines()[0])
    except (subprocess.TimeoutExpired, OSError, json.JSONDecodeError, IndexError):
        pass

    return {
        "id": container_id,
        "name": (info.get("Name") or "").lstrip("/"),
        "image": (info.get("Config") or {}).get("Image"),
        "status": state.get("Status"),
        "running": state.get("Running", False),
        "started_at": state.get("StartedAt"),
        "restart_count": info.get("RestartCount"),
        "created": info.get("Created"),
        "ports": ports,
        "cpu_pct": stats.get("CPUPerc"),
        "mem_usage": stats.get("MemUsage"),
        "mem_pct": stats.get("MemPerc"),
    }


def restart_container(container_id):
    """Restart 1 container qua `docker restart`. Tra {"success": bool, "name": ..., ...}.
    Lay ten container qua docker inspect TRUOC khi restart (chi de hien thi ten dep
    trong tin nhan ket qua - khong anh huong ket qua thanh cong/that bai)."""
    if not CONTAINER_ID_RE.match(container_id or ""):
        return {"success": False, "error": "invalid_id"}
    if shutil.which("docker") is None:
        return {"success": False, "error": "docker_unavailable"}

    name = container_id
    try:
        name_out = subprocess.run(
            ["docker", "inspect", "--format", "{{.Name}}", container_id],
            capture_output=True, text=True, timeout=10,
        )
        if name_out.returncode == 0 and name_out.stdout.strip():
            name = name_out.stdout.strip().lstrip("/")
    except (subprocess.TimeoutExpired, OSError):
        pass

    try:
        result = subprocess.run(
            ["docker", "restart", container_id],
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        return {"success": False, "name": name, "error": str(exc)}
    if result.returncode != 0:
        return {"success": False, "name": name, "error": result.stderr.strip() or "restart_failed"}
    return {"success": True, "name": name}


def main():
    argv = sys.argv[1:]
    if len(argv) >= 2 and argv[0] == "container-info":
        print(json.dumps(get_container_detail(argv[1])))
        return
    if len(argv) >= 2 and argv[0] == "container-restart":
        print(json.dumps(restart_container(argv[1])))
        return

    payload = {
        "load": get_load(),
        "cpu_cores": os.cpu_count(),
        "ram": get_ram(),
        "disk": get_disk("/"),
        "docker": get_docker_containers(),
    }
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
