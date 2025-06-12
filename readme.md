# SOCKS5 Proxy Server Auto Installer

Tự động cài đặt và cấu hình SOCKS5 proxy server (Dante) trên Ubuntu/Debian với authentication ngẫu nhiên.

## Cài đặt nhanh - Ubuntu

Chạy lệnh sau để clone repository và cài đặt SOCKS5 server:

```bash
git clone https://github.com/laanhca/install_socks.git && cd install_socks && chmod +x install.sh && sudo ./install.sh
```

## Tính năng

- ✅ Tự động detect hệ điều hành (Ubuntu/Debian/RedHat)
- ✅ Tự động tạo username, password và port ngẫu nhiên
- ✅ Cấu hình firewall tự động
- ✅ Khởi động cùng hệ thống
- ✅ Hiển thị thông tin kết nối định dạng URI

## Sau khi cài đặt

Script sẽ hiển thị thông tin kết nối dạng:
```
socks5://IP:PORT:USERNAME:PASSWORD
```

Sử dụng thông tin này để cấu hình proxy client của bạn.

## Yêu cầu hệ thống

- Ubuntu 18.04+ / Debian 9+ / CentOS 7+ / RHEL 7+
- Quyền root (sudo)
- Kết nối internet

## Hỗ trợ

https://www.facebook.com/av.auto4game/