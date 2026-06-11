# BMUD

## Adaptive authentication migration

After pulling the adaptive-authentication changes, update `backend/.env` with
separate long random values for `JWT_SECRET`, `JWT_REFRESH_SECRET`, and
`OTP_SECRET`, then run:

```powershell
cd backend
npm install
npm run migrate
npm run dev
```

The first successful password check from a new device returns HTTP `202` and
requires OTP verification before tokens are issued. In development, when SMTP
is not configured, the OTP is returned as `debug_otp`; production never returns
the OTP in the API response.

Password recovery and account unlock use one-time email OTP codes:

```text
POST /api/auth/forgot-password
POST /api/auth/reset-password
POST /api/auth/request-unlock
POST /api/auth/unlock-account
```

Recovery OTP codes contain six digits, expire after five minutes, and allow at
most five incorrect submissions. A successful password reset unlocks the
account and revokes every existing refresh token.

Brute-force protection uses separate limits in a 15-minute window:

- Five failures for one account lock that account for 15 minutes.
- Five failures for the same email and IP temporarily block that pair.
- Twenty-five failures from a non-loopback IP temporarily block that IP.
- Loopback IPs are excluded from the global IP block for local emulator use.

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
- `login_attempts`: audit đăng nhập, điểm và mức rủi ro.
- `devices`: thiết bị đã xác thực và trạng thái tin cậy.
- `auth_otps`: thử thách OTP có thời hạn.
- `refresh_tokens`: refresh token đã băm và trạng thái thu hồi.

## 6. API endpoints

### Auth API

`POST /api/auth/register`

```json
{
  "full_name": "Nguyen Van A",
  "email": "a@example.com",
  "password": "TestPass123!"
}
```

`POST /api/auth/login`

```json
{
  "email": "a@example.com",
  "password": "TestPass123!",
  "device_fingerprint": "<sha256-64-hex-characters>"
}
```

Response LOW thành công:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "user": {},
  "risk_score": 0,
  "risk_level": "LOW",
  "message": "Đăng nhập thành công"
}
```

Response MEDIUM trả HTTP `202` và yêu cầu gọi
`POST /api/auth/verify-otp` trước khi cấp token.

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
2. Đăng nhập lần đầu; Flutter tự gửi `device_fingerprint`.
3. Thiết bị mới nhận 30 điểm, API trả HTTP `202`.
4. Nhập OTP để tin cậy thiết bị và nhận access/refresh token.

### Demo 2: Đăng nhập từ thiết bị mới

1. Đăng xuất.
2. Đăng nhập từ một thiết bị hoặc bản cài đặt ứng dụng khác.
3. Backend phát hiện thiết bị mới.
4. `risk_level = MEDIUM`, hệ thống bắt buộc xác thực OTP.

### Demo 3: Đăng nhập từ IP/User-Agent mới

1. Gọi API từ trình duyệt/Postman hoặc thiết bị khác để User-Agent thay đổi.
2. Có thể đổi mạng hoặc gửi header `X-Forwarded-For` khi test sau proxy.
3. Backend phát hiện IP mới hoặc User-Agent mới.
4. `risk_level = MEDIUM`; nếu IP mới kết hợp thiết bị mới thì `risk_level = HIGH`.

### Demo 4: Sai mật khẩu nhiều lần

1. Nhập sai mật khẩu 5 lần trong 15 phút.
2. Backend lưu các lần thất bại vào `login_attempts`.
3. Sau 5 lần sai, tài khoản bị khóa 15 phút và API trả HTTP `423`.
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
