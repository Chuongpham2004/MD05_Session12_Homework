# Bài tập 5: Phân tích Log Truy Cập Nâng Cao

## 1. Yêu cầu

Hệ thống bị nghi ngờ có bot tự động dò quét file nhạy cảm (`.env`, file cấu hình...).
Viết pipeline lệnh Linux phân tích `/var/log/nginx/access.log` để tìm **Top 5 địa chỉ IP
gửi request dẫn tới mã lỗi HTTP `404` nhiều nhất**.

## 2. Câu lệnh

```bash
grep '" 404 ' /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 5
```

Bản script có thể chạy lại: [`top404.sh`](top404.sh)

```bash
./top404.sh                      # mặc định đọc /var/log/nginx/access.log
./top404.sh access.log           # chạy với file log mẫu trong thư mục này
```

## 3. Tác dụng của từng lệnh trong pipeline

Một dòng log (định dạng `combined` mặc định của Nginx), tách theo khoảng trắng:

```
192.168.1.15 - - [10/Oct/2023:13:55:36 +0000] "GET /.env HTTP/1.1" 404 153 "-" "Mozilla/5.0"
     $1      $2 $3        $4           $5      $6    $7     $8      $9  $10
  (IP client)                                (method)(path)        (status)(bytes)
```

| # | Lệnh | Tác dụng | Kết quả sau bước này |
|---|------|----------|----------------------|
| 1 | `grep '" 404 '` | Lọc chỉ giữ các dòng có **status code = 404**. Mẫu `" 404 ` (dấu `"` + cách + `404` + cách) khớp đúng vị trí status nằm ngay sau dấu `"` đóng của request line. | Các dòng log bị 404 |
| 2 | `awk '{print $1}'` | Tách mỗi dòng theo khoảng trắng và in ra **cột 1 = IP client**. | Danh sách IP, mỗi dòng 1 IP (có trùng) |
| 3 | `sort` | Sắp xếp IP để các IP giống nhau **nằm liền kề nhau** — bắt buộc vì `uniq` chỉ gộp các dòng trùng *liên tiếp*. | IP đã sắp xếp |
| 4 | `uniq -c` | Gộp các dòng trùng liên tiếp và **đếm số lần xuất hiện** (`-c` = count), in dạng `<số lần> <IP>`. | `6 192.168.1.15`, `5 10.0.0.5`... |
| 5 | `sort -rn` | Sắp xếp lại theo số đếm: `-n` so sánh **theo số** (không phải theo chữ, tránh `9 > 10`), `-r` **giảm dần**. | IP nhiều 404 nhất lên đầu |
| 6 | `head -n 5` | Lấy **5 dòng đầu** = Top 5. | Kết quả cuối |

### Vì sao không dùng `grep 404` đơn giản?

`grep 404` khớp **bất kỳ đâu** trong dòng nên dễ đếm nhầm:

- Kích thước response = 404 byte: `"GET /logo.png HTTP/1.1" 200 404 ...`
- URL chứa `404`: `"GET /icons/404.svg HTTP/1.1" 200 ...`
- Timestamp, User-Agent... chứa chuỗi `404`.

Mẫu `'" 404 '` chỉ khớp khi `404` đứng ngay sau request line, tức là đúng cột status.

## 4. Kiểm chứng với file log mẫu

File [`access.log`](access.log) gồm 4 dòng của đề bài + thêm các dòng mô phỏng bot dò quét
(`/.git/config`, `/wp-config.php`, `/.aws/credentials`...) và các dòng **bẫy** (status 200 nhưng
size = 404 byte hoặc URL chứa `404`).

```console
$ grep '" 404 ' access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 5
      6 192.168.1.15
      5 10.0.0.5
      4 203.0.113.7
      3 198.51.100.23
      2 45.33.32.156
```

So sánh với cách lọc sai `grep '404'` — IP `172.16.0.2` (chỉ có request **200**) bị lọt vào Top 5:

```console
$ grep '404' access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 5
      6 192.168.1.15
      5 10.0.0.5
      4 203.0.113.7
      3 198.51.100.23
      3 172.16.0.2      <-- sai: đây là 3 request 200 có số 404 trong size/URL
```

## 5. Mở rộng (tham khảo)

```bash
# Cách chỉ dùng awk, so sánh chính xác cột status ($9) — không cần grep
awk '$9 == 404 {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -n 5

# Bao gồm cả các file log đã rotate (access.log.1, access.log.2.gz...)
zcat -f /var/log/nginx/access.log* | grep '" 404 ' | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 5

# Chỉ xét các request dò file .env
grep '" 404 ' /var/log/nginx/access.log | grep '\.env' | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 5
```

Sau khi xác định được IP bot, có thể chặn bằng UFW (`sudo ufw deny from <IP>`) hoặc `deny <IP>;`
trong cấu hình Nginx, hoặc dùng `fail2ban` để tự động hoá.
