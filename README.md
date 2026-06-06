# BMUD

# Hệ thống phát hiện hành vi đăng nhập bất thường trên Web/Mobile

## 1. Giới thiệu đề tài

Đồ án xây dựng một hệ thống đăng nhập cho ứng dụng Web/Mobile có khả năng ghi nhận lịch sử đăng nhập, phân tích hành vi bất thường và gửi email cảnh báo khi phát hiện rủi ro. Backend cung cấp REST API bằng NodeJS/ExpressJS, frontend là ứng dụng Flutter mobile đơn giản gọi API qua HTTP.

## 2. Mục tiêu

- Đăng ký, đăng nhập và xác thực người dùng bằng JWT.
- Mã hóa mật khẩu bằng bcrypt.
- Lưu lịch sử đăng nhập, thiết bị tin cậy và các lần đăng nhập thất bại.
- Phân loại rủi ro đăng nhập theo `LOW`, `MEDIUM`, `HIGH`.
- Gửi email cảnh báo khi phát hiện đăng nhập bất thường.
- Hiển thị lịch sử đăng nhập và dashboard bảo mật trên Flutter.

## 3. Công nghệ sử dụng

Backend:

- NodeJS, ExpressJS
- MySQL, mysql2
- JWT Authentication
- bcrypt
- nodemailer
- express-rate-limit
- cors, dotenv

Frontend:

- Flutter
- HTTP API
- shared_preferences để lưu token và user cục bộ

Database:

- MySQL

## 4. Kiến trúc hệ thống

```text
Flutter Mobile App
        |
        | HTTP + JWT Bearer Token
        v
NodeJS Express Backend
        |
        | mysql2/promise
        v
MySQL Database
```

Backend được tách theo các lớp:

- `routes`: khai báo endpoint.
- `controllers`: nhận request, validate dữ liệu đầu vào.
- `services`: xử lý nghiệp vụ đăng nhập, phát hiện bất thường, gửi email.
- `middleware`: JWT auth và rate limit.
- `config`: cấu hình MySQL và nodemailer.
- `utils`: tạo JWT và device fingerprint.

## 5. Cơ sở dữ liệu

File schema nằm tại:

```text
backend/database.sql
```

Các bảng chính:

- `users`: thông tin tài khoản.
- `login_history`: lịch sử đăng nhập và mức rủi ro.
- `failed_login_attempts`: các lần đăng nhập thất bại.
- `trusted_devices`: thiết bị đã từng đăng nhập thành công.

## 6. API endpoints

### Auth API

`POST /api/auth/register`

```json
{
  "full_name": "Nguyen Van A",
  "email": "a@example.com",
  "password": "123456"
}
```

`POST /api/auth/login`

```json
{
  "email": "a@example.com",
  "password": "123456",
  "device_name": "iPhone 15"
}
```

Response thành công:

```json
{
  "token": "...",
  "user": {},
  "risk_level": "LOW",
  "message": "Đăng nhập thành công"
}
```

### User API

`GET /api/users/me`

Header:

```text
Authorization: Bearer <token>
```

### Security API

`GET /api/security/login-history`

Trả về danh sách lịch sử đăng nhập của user hiện tại.

`GET /api/security/dashboard`

Trả về tổng số lần đăng nhập, số lượng `LOW`, `MEDIUM`, `HIGH`, lần đăng nhập gần nhất và danh sách cảnh báo.

## 7. Cách cài đặt backend

```bash
cd /Users/Shared/abnormal-login-detection/backend
npm install
cp .env.example .env
```

Sửa file `.env`:

```env
PORT=5000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=abnormal_login_detection
JWT_SECRET=replace_with_a_long_random_secret
EMAIL_USER=your_gmail_address@gmail.com
EMAIL_PASS=your_gmail_app_password
```

Tạo database:

```bash
mysql -u root -p < database.sql
```

Chạy backend:

```bash
npm run dev
```

Backend lắng nghe tại `0.0.0.0:5000`, vì vậy Flutter trên điện thoại thật có thể gọi bằng IP LAN của máy tính, ví dụ:

```text
http://192.168.1.10:5000/api
```

## 8. Cách chạy Flutter

```bash
cd /Users/Shared/abnormal-login-detection/frontend
flutter pub get
flutter run
```

Trước khi chạy trên điện thoại thật, mở:

```text
frontend/lib/config/api_config.dart
```

Đổi `baseUrl` sang IP LAN của máy đang chạy backend:

```dart
static const String baseUrl = 'http://192.168.1.10:5000/api';
```

## 9. Kịch bản demo

### Demo 1: Đăng nhập bình thường

1. Đăng ký tài khoản mới.
2. Đăng nhập lần đầu với email, password và `device_name`.
3. Backend lưu lịch sử đăng nhập, tạo thiết bị tin cậy ban đầu.
4. `risk_level = LOW`.

### Demo 2: Đăng nhập từ thiết bị mới

1. Đăng xuất.
2. Đăng nhập lại cùng tài khoản nhưng đổi `device_name`, ví dụ từ `My Phone` sang `Laptop`.
3. Backend phát hiện thiết bị mới.
4. `risk_level = MEDIUM`, hệ thống gửi email cảnh báo nếu SMTP đã cấu hình.

### Demo 3: Đăng nhập từ IP/User-Agent mới

1. Gọi API từ trình duyệt/Postman hoặc thiết bị khác để User-Agent thay đổi.
2. Có thể đổi mạng hoặc gửi header `X-Forwarded-For` khi test sau proxy.
3. Backend phát hiện IP mới hoặc User-Agent mới.
4. `risk_level = MEDIUM`; nếu IP mới kết hợp thiết bị mới thì `risk_level = HIGH`.

### Demo 4: Sai mật khẩu nhiều lần

1. Nhập sai mật khẩu 5 lần trong 15 phút.
2. Backend lưu các lần thất bại vào `failed_login_attempts`.
3. API trả về cảnh báo brute force với HTTP `429`.
4. Lần đăng nhập đúng sau đó vẫn xét lịch sử thất bại gần đây để tăng rủi ro.

### Demo 5: Dashboard bảo mật

1. Đăng nhập thành công.
2. Vào màn hình `Dashboard bảo mật`.
3. Kiểm tra tổng login, số lần `LOW`, `MEDIUM`, `HIGH` và cảnh báo gần đây.

## 10. Hướng phát triển

- Bổ sung xác thực 2 lớp OTP khi `risk_level = HIGH`.
- Lưu vị trí địa lý từ IP để phát hiện đăng nhập khác quốc gia.
- Tạo trang admin quản lý cảnh báo toàn hệ thống.
- Thêm push notification cho mobile.
- Dùng Redis để tối ưu kiểm tra brute force theo thời gian thực.
- Tích hợp machine learning để học hành vi đăng nhập theo từng user.
