# Bài tập 2: Tối ưu Timeout cho Proxy

## 1. Tình huống

- API `/api/export/` của Spring Boot cần khoảng **90 giây** để xuất báo cáo.
- Request qua Nginx bị ngắt sau khoảng **60 giây** với lỗi `504 Gateway Time-out`.

## 2. Nguyên nhân

- Cấu hình ban đầu không khai báo timeout, nên Nginx dùng **giá trị mặc định là 60 giây** cho
  `proxy_connect_timeout`, `proxy_send_timeout`, `proxy_read_timeout` và `send_timeout`.
- Backend nhận request rồi xử lý ~90 giây **mà không gửi byte nào về**. Sau 60 giây chờ đọc
  response, `proxy_read_timeout` hết hạn → Nginx ngắt kết nối upstream và trả **504** cho client.

```nginx
server {
    listen 80;
    server_name api.example.com;

    location /api/export/ {
        proxy_pass http://localhost:8080;
        # Chưa có cấu hình timeout  -> mặc định 60s -> 504 sau 60s
    }
}
```

## 3. Cấu hình sau khi cập nhật

File [`nginx/export.conf`](nginx/export.conf):

```nginx
server {
    listen 80;
    server_name api.example.com;

    location /api/export/ {
        proxy_pass http://localhost:8080;

        # Timeout cho API export báo cáo (~90s xử lý) -> cho phép tối đa 120s
        proxy_connect_timeout 60s;   # Thời gian chờ thiết lập kết nối tới backend
        proxy_send_timeout    120s;  # Thời gian chờ giữa 2 lần ghi request tới backend
        proxy_read_timeout    120s;  # Thời gian chờ giữa 2 lần đọc response từ backend (nguyên nhân 504)
        send_timeout          120s;  # Thời gian chờ giữa 2 lần gửi response về client
    }
}
```

Các chỉ thị được đặt **trong `location /api/export/`** nên chỉ áp dụng cho API export,
các API khác vẫn giữ timeout mặc định 60s (tránh giữ kết nối treo quá lâu trên toàn hệ thống).

## 4. Ý nghĩa các thông số timeout

| Chỉ thị | Mặc định | Giá trị mới | Ý nghĩa |
|---------|----------|-------------|---------|
| `proxy_read_timeout` | 60s | **120s** | Thời gian Nginx chờ **đọc response** từ backend. Tính giữa **2 lần đọc liên tiếp**, không phải tổng thời gian. Đây là chỉ thị **quan trọng nhất** để sửa lỗi 504 khi backend xử lý lâu. |
| `proxy_send_timeout` | 60s | 120s | Thời gian chờ giữa 2 lần **ghi request** (header/body) lên backend. Hữu ích khi request body lớn hoặc backend nhận chậm. |
| `proxy_connect_timeout` | 60s | 60s | Thời gian chờ **thiết lập kết nối TCP** với backend. Không liên quan đến thời gian xử lý, thường không nên vượt quá 75s (giới hạn của Nginx). Backend chạy `localhost` có thể đặt thấp hơn (vd 5–10s) để phát hiện backend chết nhanh hơn. |
| `send_timeout` | 60s | 120s | Thời gian chờ giữa 2 lần **gửi response về client**. Nếu client không nhận dữ liệu trong khoảng này, kết nối bị đóng. Tăng để client tải file báo cáo lớn/chậm không bị ngắt. |

> Lưu ý: các timeout trên đều là **khoảng thời gian giữa hai thao tác đọc/ghi liên tiếp**,
> không phải tổng thời gian của cả request. Với 120s, backend xử lý 90s vẫn còn 30s dư phòng.

## 5. Áp dụng cấu hình

```bash
sudo nginx -t                  # kiểm tra cú pháp
sudo systemctl reload nginx    # nạp lại cấu hình, không gián đoạn kết nối
```

Kiểm tra (đo thời gian, kỳ vọng HTTP 200 sau ~90s thay vì 504 sau 60s):

```bash
curl -o report.xlsx -w "HTTP %{http_code} - %{time_total}s\n" http://api.example.com/api/export/report
```

## 6. Lưu ý thêm

- Nếu phía trước Nginx còn **Load Balancer / CDN** (AWS ALB, Cloudflare, ...) thì timeout ở các
  lớp đó cũng phải ≥ 120s, nếu không request vẫn bị ngắt ở lớp ngoài.
- Về lâu dài, tác vụ chạy lâu nên chuyển sang **xử lý bất đồng bộ**: API trả về `202 Accepted`
  kèm `jobId`, client poll trạng thái rồi tải file khi xong — thay vì giữ kết nối HTTP 90 giây.
