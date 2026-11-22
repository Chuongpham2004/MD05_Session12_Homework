# Bài tập 1: Xử lý sự cố sập Nginx

## 1. Thông báo lỗi

```
nginx: [emerg] unexpected "proxy_set_header" in /etc/nginx/sites-enabled/app.conf:7
```

## 2. Cấu hình bị lỗi

```nginx
1  server {
2      listen 80;
3      server_name example.com;
4
5      location / {
6          proxy_pass http://localhost:8080        # <-- THIẾU dấu ;
7          proxy_set_header Host $host;            # <-- Nginx báo lỗi tại đây
8          proxy_set_header X-Real-IP $remote_addr;
9      }
10 }
```

## 3. Nguyên nhân

- Trong Nginx, **mỗi chỉ thị (directive) phải kết thúc bằng dấu chấm phẩy `;`**.
- **Dòng 6** `proxy_pass http://localhost:8080` bị **thiếu dấu `;`** ở cuối.
- Vì không có `;`, Nginx đọc tiếp sang dòng 7 và hiểu thành một chỉ thị duy nhất:

  ```
  proxy_pass http://localhost:8080 proxy_set_header Host $host;
  ```

- Khi gặp từ khóa `proxy_set_header` nằm giữa tham số của `proxy_pass`, Nginx báo lỗi
  `unexpected "proxy_set_header"` tại **dòng 7**. Lỗi thực sự nằm ở **dòng 6**.
- Lỗi **không** do khoảng trắng / thụt lề: Nginx bỏ qua khoảng trắng, thụt lề chỉ giúp dễ đọc.

> Mẹo: Khi Nginx báo `unexpected` ở dòng N, hãy kiểm tra cuối dòng N-1 xem có thiếu `;` không.

## 4. Cách sửa

Thêm dấu `;` vào cuối dòng 6:

```diff
-        proxy_pass http://localhost:8080
+        proxy_pass http://localhost:8080;
```

Cấu hình sau khi sửa (file [`nginx/app.conf`](nginx/app.conf)):

```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 5. Lệnh kiểm tra cấu hình và khởi động lại Nginx

```bash
# 1. Mở file cấu hình để sửa
sudo nano /etc/nginx/sites-enabled/app.conf

# 2. Kiểm tra cú pháp cấu hình (luôn chạy trước khi reload)
sudo nginx -t

# 3. Reload Nginx để áp dụng cấu hình mới (không làm gián đoạn kết nối)
sudo systemctl reload nginx
#    hoặc: sudo nginx -s reload

# 4. Nếu Nginx đã bị dừng hẳn, khởi động lại dịch vụ
sudo systemctl restart nginx

# 5. Kiểm tra trạng thái dịch vụ
sudo systemctl status nginx
```

Kết quả mong đợi khi chạy `sudo nginx -t`:

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

| Lệnh | Ý nghĩa |
|------|---------|
| `nginx -t` | Kiểm tra cú pháp cấu hình, không ảnh hưởng dịch vụ đang chạy |
| `systemctl reload nginx` | Nạp lại cấu hình, giữ nguyên các kết nối hiện tại |
| `systemctl restart nginx` | Dừng hẳn rồi khởi động lại dịch vụ |
| `systemctl status nginx` | Xem trạng thái dịch vụ |
