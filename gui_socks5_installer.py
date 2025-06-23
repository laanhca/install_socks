import time
import sys
import paramiko
import json
import threading
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel,
    QTextEdit, QPushButton, QLineEdit, QMessageBox,
    QComboBox
)
from PyQt5.QtCore import QTimer, QObject, QThread, pyqtSignal
from concurrent.futures import ThreadPoolExecutor


class Worker(QObject):
    finished = pyqtSignal()
    log = pyqtSignal(str)
    result = pyqtSignal(str)

    def __init__(self, ip_list, username, password, proxy_type):
        super().__init__()
        self.ip_list = ip_list
        self.username = username
        self.password = password
        self.proxy_type = proxy_type
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
            ssh.connect(ip, username=self.username, password=password, timeout=15)

            script_url = {
                "socks5": "https://raw.githubusercontent.com/laanhca/install_socks/main/install_socks5.sh",
                "http": "https://raw.githubusercontent.com/laanhca/install_socks/main/install_http.sh"
            }.get(self.proxy_type.lower())

            if not script_url:
                self.log.emit(f"[!] Proxy type không hợp lệ: {self.proxy_type}")
                return

            # Gửi và chạy script tự động (đồng bộ)
            script_exec = f"""
            curl -sSL {script_url} -o /tmp/install.sh &&
            chmod +x /tmp/install.sh &&
            bash /tmp/install.sh > /tmp/proxy_install.log 2>&1
            """
            stdin, stdout, stderr = ssh.exec_command(script_exec)
            exit_code = stdout.channel.recv_exit_status()

            if exit_code != 0:
                install_log = ssh.exec_command("cat /tmp/proxy_install.log")[1].read().decode()
                raise Exception(f"Script lỗi (exit code {exit_code}):\n{install_log}")

            # Đọc file JSON output
            stdin, stdout, stderr = ssh.exec_command("cat /root/proxy_info.json")
            output = stdout.read().decode().strip()

            if not output:
                raise Exception("Không lấy được thông tin PROXY (file trống hoặc không tồn tại)")

            try:
                data = json.loads(output)
            except Exception:
                raise Exception(f"Dữ liệu JSON không hợp lệ:\n{output}")

            with self.lock:
                self.results.append(data["proxy"])
                self.log.emit(f"[✓] {ip} -> {data['proxy']}")

            ssh.close()

        except Exception as e:
            self.log.emit(f"[✗] {ip} lỗi: {e}")



class Socks5InstallerApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PROXY VPS Installer zalo:0333571998")
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

        self.label_user = QLabel("👤 Nhập SSH username (mặc định: root):")
        self.input_user = QLineEdit()
        self.input_user.setPlaceholderText("root")

        self.label_type = QLabel("🧭 Chọn loại proxy:")
        self.combo_type = QComboBox()
        self.combo_type.addItems(["SOCKS5", "HTTP"])

        self.button_start = QPushButton("🚀 Start")
        self.button_start.clicked.connect(self.start_install)

        self.output_box = QTextEdit()
        self.output_box.setReadOnly(True)

        layout.addWidget(self.label_ips)
        layout.addWidget(self.input_ips)
        layout.addWidget(self.label_user)
        layout.addWidget(self.input_user)
        layout.addWidget(self.label_pass)
        layout.addWidget(self.input_password)
        layout.addWidget(self.label_type)
        layout.addWidget(self.combo_type)
        
        layout.addWidget(self.button_start)
        layout.addWidget(self.output_box)

        self.setLayout(layout)

    def log_output(self, text):
        QTimer.singleShot(0, lambda: self.output_box.append(text))

    def start_install(self):
        username = self.input_user.text().strip() or "root"
        ip_list = self.input_ips.toPlainText().strip().splitlines()
        password = self.input_password.text().strip()
        proxy_type = self.combo_type.currentText()


        if not ip_list or not password:
            QMessageBox.warning(self, "Thiếu thông tin", "Vui lòng nhập IP và password.")
            return

        self.output_box.clear()
        self.log_output("⏳ Bắt đầu cài đặt PROXY...")

        # Khởi động thread background
        self.worker = Worker(ip_list, username, password, proxy_type)
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
