require("dotenv").config();
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const User = require("../models/User");

const demoUsers = [
  ["Nguyễn Minh Anh", "minh.anh.demo01@example.com"],
  ["Trần Quốc Bảo", "quoc.bao.demo02@example.com"],
  ["Lê Thu Hà", "thu.ha.demo03@example.com"],
  ["Phạm Gia Huy", "gia.huy.demo04@example.com"],
  ["Võ Ngọc Linh", "ngoc.linh.demo05@example.com"],
  ["Đặng Hoàng Nam", "hoang.nam.demo06@example.com"],
  ["Bùi Khánh Vy", "khanh.vy.demo07@example.com"],
  ["Đỗ Đức Thành", "duc.thanh.demo08@example.com"],
  ["Hoàng Mai Phương", "mai.phuong.demo09@example.com"],
  ["Vũ Nhật Minh", "nhat.minh.demo10@example.com"],
];

async function seedDemoUsers() {
  if (!process.env.MONGO_URI) {
    throw new Error("Thiếu MONGO_URI trong backend/.env");
  }

  await mongoose.connect(process.env.MONGO_URI);
  const passwordHash = await bcrypt.hash("Demo@12345", 12);
  let created = 0;
  let skipped = 0;

  for (const [hoten, email] of demoUsers) {
    const normalizedEmail = email.toLowerCase();
    const existing = await User.findOne({ email: normalizedEmail });
    if (existing) {
      skipped += 1;
      continue;
    }

    await User.create({
      email: normalizedEmail,
      matkhau: passwordHash,
      hoten,
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
