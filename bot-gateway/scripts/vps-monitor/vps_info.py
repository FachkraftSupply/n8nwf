#!/usr/bin/env python3
"""Thu thap thong tin he thong (CPU load, RAM, disk, top container Docker theo
dung luong) cho lenh /vps cua Telebot Admin System. Chi dung Python stdlib,
khong can cai them thu vien. In JSON ra stdout."""
import json
import os
import shutil
import subprocess


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
            ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.Status}}"],
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
        cols = (line.split("\t") + ["", "", ""])[:3]
        name, image, status = cols
        size = sizes.get(name, "?")
        containers.append({
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


def main():
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
