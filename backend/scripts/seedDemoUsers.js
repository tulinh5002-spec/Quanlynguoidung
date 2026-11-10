require("dotenv").config();
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const User = require("../models/User");

const demoUsers = [
  ["Nguyễn Minh Anh", "minh.anh.demo01@example.com", "Nữ", "2001-04-12"],
  ["Trần Quốc Bảo", "quoc.bao.demo02@example.com", "Nam", "1998-09-23"],
  ["Lê Thu Hà", "thu.ha.demo03@example.com", "Nữ", "2002-01-17"],
  ["Phạm Gia Huy", "gia.huy.demo04@example.com", "Nam", "1999-06-08"],
  ["Võ Ngọc Linh", "ngoc.linh.demo05@example.com", "Nữ", "2000-11-30"],
  ["Đặng Hoàng Nam", "hoang.nam.demo06@example.com", "Nam", "1997-03-05"],
  ["Bùi Khánh Vy", "khanh.vy.demo07@example.com", "Nữ", "2003-08-19"],
  ["Đỗ Đức Thành", "duc.thanh.demo08@example.com", "Nam", "1996-12-02"],
  ["Hoàng Mai Phương", "mai.phuong.demo09@example.com", "Nữ", "2001-07-26"],
  ["Vũ Nhật Minh", "nhat.minh.demo10@example.com", "Nam", "2000-02-14"],
];

async function seedDemoUsers() {
  if (!process.env.MONGO_URI) {
    throw new Error("Thiếu MONGO_URI trong backend/.env");
  }

  await mongoose.connect(process.env.MONGO_URI);
  const passwordHash = await bcrypt.hash("Demo@12345", 12);
  let created = 0;
  let skipped = 0;

  for (const [hoten, email, gioitinh, ngaysinh] of demoUsers) {
    const normalizedEmail = email.toLowerCase();
    const existing = await User.findOne({ email: normalizedEmail });
    if (existing) {
      const updates = {};
      if (!existing.gioitinh) updates.gioitinh = gioitinh;
      if (!existing.ngaysinh) updates.ngaysinh = ngaysinh;
      if (Object.keys(updates).length) await User.updateOne({ _id: existing._id }, { $set: updates });
      skipped += 1;
      continue;
    }

    await User.create({
      email: normalizedEmail,
      matkhau: passwordHash,
      hoten,
      gioitinh,
      ngaysinh,
      hinhanh: "",
    });
    created += 1;
  }

  console.log(`Đã tạo ${created} tài khoản mẫu; bỏ qua ${skipped} tài khoản đã có.`);
  console.log("Mật khẩu dùng chung cho tài khoản mẫu: Demo@12345");
}

seedDemoUsers()
  .catch((error) => {
    console.error("Không thể tạo dữ liệu mẫu:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
