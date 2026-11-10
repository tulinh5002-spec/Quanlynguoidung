# Quan ly nguoi dung (MongoDB + Express)

Backend cung cap dang ky/dang nhap va REST API CRUD cho cac truong `email`, `matkhau`, `hoten`, `hinhanh`, duoc ung dung Flutter trong `flutter_app` su dung. MongoDB chi luu bon truong nay (ngoai `_id` MongoDB tu tao); mat khau duoc bam bang bcrypt truoc khi luu va khong bao gio tra ve tu API.

## Chay tren may

1. Cai Node.js, sau do mo terminal tai thu muc `backend`.
2. Cai thu vien: `npm install`.
3. Tao file `.env` (khong commit file nay):

   ```env
   PORT=3000
   MONGO_URI=mongodb+srv://<user>:<password>@<cluster>/<database>?retryWrites=true&w=majority
   JWT_SECRET=thay-bang-chuoi-bi-mat-ngau-nhien-it-nhat-32-ky-tu
   CORS_ORIGINS=http://localhost:8080,http://localhost:5173,http://localhost:8081
   ```

   Neu dung MongoDB local, co the thay URI bang `mongodb://127.0.0.1:27017/user_management`.
4. Chay `npm start`; kiem tra `http://localhost:3000/api/health` tra ve `{"status":"ok"}`. De chay giao dien app, xem huong dan tai `../flutter_app/README.md`.

Khong chia se `.env`, URI MongoDB hoac JWT secret trong bao cao/video. MongoDB Atlas can them IP may chay backend vao Network Access va tao database user co quyen doc/ghi tren database.

## API

Tat ca API dung JSON. Dang ky va dang nhap khong can token. Cac API con lai can header `Authorization: Bearer <token>`.

| Method | Duong dan | Muc dich |
| --- | --- | --- |
| POST | `/api/users` | Tao tai khoan |
| POST | `/api/users/login` | Dang nhap, nhan JWT |
| GET | `/api/users/me` | Lay tai khoan dang dang nhap |
| GET | `/api/users` | Liet ke tai khoan |
| PUT | `/api/users/:id` | Sua thong tin (chi gui cac truong can sua) |
| DELETE | `/api/users/:id` | Xoa tai khoan |

Vi du tao tai khoan:

```json
{
  "email": "demo@example.com",
  "matkhau": "demo1234",
  "hoten": "Nguoi dung demo",
  "hinhanh": "https://example.com/avatar.jpg"
}
```

`hinhanh` nhan URL anh hoac data URI (vi du `data:image/jpeg;base64,...`). Flutter app tao data URI tu anh nguoi dung chon, sau do gui vao truong `hinhanh`.

## MongoDB va nop bai

Mongoose tao collection `users` voi cac document co dang:

```json
{
  "_id": "ObjectId do MongoDB tao",
  "email": "demo@example.com",
  "matkhau": "bcrypt hash",
  "hoten": "Nguoi dung demo",
  "hinhanh": "https://example.com/avatar.jpg"
}
```

De nop du lieu, export collection `users` tu MongoDB Compass bang JSON/Extended JSON. Khong dua mat khau that vao file nop; dung tai khoan demo. Schema gioi han bon truong nen khong co role; do do moi tai khoan dang nhap trong ban demo duoc phep CRUD.
