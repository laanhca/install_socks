import paramiko
import threading
import json
from concurrent.futures import ThreadPoolExecutor

# Cấu hình
VPS_LIST = [
    "192.0.2.10",
    "192.0.2.11",
    "192.0.2.12"
]
ROOT_PASSWORD = "your_root_password"
SCRIPT_URL = "https://raw.githubusercontent.com/laanhca/install_socks/main/install_socks5.sh"  # URL script bash (hoặc tự host)

lock = threading.Lock()
results = []

def install_socks5(ip):
    try:
        print(f"[+] Đang kết nối {ip} ...")
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip, username="root", password=ROOT_PASSWORD, timeout=10)

        commands = [
            f"curl -sSL {SCRIPT_URL} -o /tmp/install.sh",
            "chmod +x /tmp/install.sh",
            "bash /tmp/install.sh"
        ]

        for cmd in commands:
            ssh.exec_command(cmd)

        # Đợi file socks5_info.json tạo xong
        stdin, stdout, stderr = ssh.exec_command("cat /root/socks5_info.json")
        output = stdout.read().decode()

        if not output:
            raise Exception("Không đọc được socks5_info.json")

        data = json.loads(output)

        with lock:
            results.append(data["proxy"])
            print(f"[✓] Thành công: {ip} -> {data['proxy']}")
        ssh.close()
    except Exception as e:
        with lock:
            print(f"[✗] Lỗi với {ip}: {e}")

def main():
    with ThreadPoolExecutor(max_workers=5) as executor:
        executor.map(install_socks5, VPS_LIST)

    print("\n🎯 Danh sách SOCKS5:")
    for proxy in results:
        print(proxy)

if __name__ == "__main__":
    main()
