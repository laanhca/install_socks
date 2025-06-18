import time
import sys
import paramiko
import json
import threading
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel,
    QTextEdit, QPushButton, QLineEdit, QMessageBox
)
from PyQt5.QtCore import QTimer, QObject, QThread, pyqtSignal
from concurrent.futures import ThreadPoolExecutor

SCRIPT_URL = "https://raw.githubusercontent.com/laanhca/install_socks/main/install.sh"

class Worker(QObject):
    finished = pyqtSignal()
    log = pyqtSignal(str)
    result = pyqtSignal(str)

    def __init__(self, ip_list, password):
        super().__init__()
        self.ip_list = ip_list
        self.password = password
        self.results = []
        self.lock = threading.Lock()

    def run(self):
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(self.install_socks5, ip, self.password) for ip in self.ip_list]
            for future in futures:
                try:
                    future.result()
                except Exception as e:
                    self.log.emit(f"[!] Lỗi khi xử lý IP: {e}")

        self.log.emit("\n🎯 Kết quả tổng hợp:")
        for proxy in self.results:
            self.result.emit(proxy)
        self.finished.emit()

    def install_socks5(self, ip, password):
        try:
            self.log.emit(f"[+] Đang kết nối {ip} ...")
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(ip, username="root", password=password, timeout=15)

            commands = [
                f"curl -sSL {SCRIPT_URL} -o /tmp/install.sh",
                "chmod +x /tmp/install.sh",
                "bash /tmp/install.sh"
            ]
            for cmd in commands:
                ssh.exec_command(cmd)

            time.sleep(25)

            stdin, stdout, stderr = ssh.exec_command("cat /root/socks5_info.json")
            output = stdout.read().decode()

            if not output:
                raise Exception("Không lấy được thông tin SOCKS5")

            data = json.loads(output)
            with self.lock:
                self.results.append(data["proxy"])
                self.log.emit(f"[✓] {ip} -> {data['proxy']}")
            ssh.close()

        except Exception as e:
            self.log.emit(f"[✗] {ip} lỗi: {e}")


class Socks5InstallerApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("SOCKS5 VPS Installer")
        self.setGeometry(100, 100, 700, 500)

        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout()

        self.label_ips = QLabel("📥 Nhập danh sách IP (mỗi dòng 1 IP):")
        self.input_ips = QTextEdit()
        self.input_ips.setPlaceholderText("192.0.2.10\n192.0.2.11")

        self.label_pass = QLabel("🔐 Nhập root password:")
        self.input_password = QLineEdit()
        self.input_password.setEchoMode(QLineEdit.Password)

        self.button_start = QPushButton("🚀 Start")
        self.button_start.clicked.connect(self.start_install)

        self.output_box = QTextEdit()
        self.output_box.setReadOnly(True)

        layout.addWidget(self.label_ips)
        layout.addWidget(self.input_ips)
        layout.addWidget(self.label_pass)
        layout.addWidget(self.input_password)
        layout.addWidget(self.button_start)
        layout.addWidget(self.output_box)

        self.setLayout(layout)

    def log_output(self, text):
        QTimer.singleShot(0, lambda: self.output_box.append(text))

    def start_install(self):
        ip_list = self.input_ips.toPlainText().strip().splitlines()
        password = self.input_password.text().strip()

        if not ip_list or not password:
            QMessageBox.warning(self, "Thiếu thông tin", "Vui lòng nhập IP và password.")
            return

        self.output_box.clear()
        self.log_output("⏳ Bắt đầu cài đặt SOCKS5...")

        # Khởi động thread background
        self.worker = Worker(ip_list, password)
        self.thread = QThread()
        self.worker.moveToThread(self.thread)

        # Kết nối tín hiệu
        self.thread.started.connect(self.worker.run)
        self.worker.log.connect(self.log_output)
        self.worker.result.connect(self.log_output)
        self.worker.finished.connect(self.thread.quit)
        self.worker.finished.connect(self.worker.deleteLater)
        self.thread.finished.connect(self.thread.deleteLater)

        self.thread.start()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = Socks5InstallerApp()
    window.show()
    sys.exit(app.exec_())
