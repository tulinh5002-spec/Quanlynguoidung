const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();
const publicUser = (user) => ({
  id: user._id,
  email: user.email,
  hoten: user.hoten,
  hinhanh: user.hinhanh || "",
});
// Tao tai khoan. Mat khau luon duoc bam truoc khi luu MongoDB.
router.post("/", async (req, res) => {
  try {
    const { email, matkhau, hoten, hinhanh = "" } = req.body;
    if (![email, matkhau, hoten].every((value) => typeof value === "string" && value.trim())) {
      return res.status(400).json({ message: "Vui long nhap email, mat khau va ho ten" });
    }
    if (matkhau.length < 6) {
      return res.status(400).json({ message: "Mat khau phai co it nhat 6 ky tu" });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return res.status(400).json({ message: "Email khong hop le" });
    const normalizedEmail = email.trim().toLowerCase();
    if (await User.exists({ email: normalizedEmail })) {
      return res.status(409).json({ message: "Email da ton tai" });
    }
    const user = await User.create({
      email: normalizedEmail,
      matkhau: await bcrypt.hash(matkhau, 12),
      hoten: hoten.trim(),
      hinhanh: typeof hinhanh === "string" ? hinhanh.trim() : "",
    });
    return res.status(201).json({ message: "Tao tai khoan thanh cong", user: publicUser(user) });
  } catch (error) {
    if (error.code === 11000) return res.status(409).json({ message: "Email da ton tai" });
    console.error("Create user:", error);
    return res.status(500).json({ message: "Loi tao nguoi dung" });
  }
});

// Dang nhap va cap JWT cho cac API quan ly.
router.post("/login", async (req, res) => {
  try {
    const { email, matkhau } = req.body;
    if (typeof email !== "string" || typeof matkhau !== "string" || !email.trim() || !matkhau) {
      return res.status(400).json({ message: "Vui long nhap email va mat khau" });
    }
    const user = await User.findOne({ email: email.trim().toLowerCase() });
    if (!user || !(await bcrypt.compare(matkhau, user.matkhau))) {
      return res.status(401).json({ message: "Email hoac mat khau khong dung" });
    }
    const token = jwt.sign({ userId: user._id.toString() }, process.env.JWT_SECRET, { expiresIn: "1d" });
    return res.json({ message: "Dang nhap thanh cong", token, user: publicUser(user) });
  } catch (error) {
    console.error("Login:", error);
    return res.status(500).json({ message: "Loi dang nhap" });
  }
});

router.use(authMiddleware);

router.get("/me", async (req, res) => {
  try {
    const user = await User.findById(req.userId).select("email hoten hinhanh");
    if (!user) return res.status(404).json({ message: "Khong tim thay nguoi dung" });
    return res.json({ user: publicUser(user) });
  } catch (error) {
    return res.status(500).json({ message: "Loi lay thong tin nguoi dung" });
  }
});

// Danh sach, chi tra ve dung cac truong duoc phep hien thi.
router.get("/", async (_req, res) => {
  try {
    const users = await User.find().select("email hoten hinhanh").sort({ hoten: 1 });
    return res.json(users.map(publicUser));
  } catch (error) {
    console.error("List users:", error);
    return res.status(500).json({ message: "Loi lay danh sach nguoi dung" });
  }
});

router.put("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: "ID khong hop le" });
    const { email, matkhau, matkhauCu, hoten, hinhanh } = req.body;
    const updates = {};
    if (email !== undefined) {
      if (typeof email !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return res.status(400).json({ message: "Email khong hop le" });
      updates.email = email.trim().toLowerCase();
    }
    if (hoten !== undefined) {
      if (typeof hoten !== "string" || !hoten.trim()) return res.status(400).json({ message: "Ho ten khong hop le" });
      updates.hoten = hoten.trim();
    }
    if (hinhanh !== undefined) {
      if (typeof hinhanh !== "string") return res.status(400).json({ message: "Hinh anh phai la chuoi URL hoac data URI" });
      updates.hinhanh = hinhanh.trim();
    }
    if (matkhau !== undefined && matkhau !== "") {
      if (req.params.id !== req.userId) {
        return res.status(403).json({ message: "Ban chi co the tu doi mat khau cua minh" });
      }
      if (typeof matkhau !== "string" || matkhau.length < 6) return res.status(400).json({ message: "Mat khau phai co it nhat 6 ky tu" });
      if (typeof matkhauCu !== "string" || !matkhauCu) {
        return res.status(400).json({ message: "Vui long nhap mat khau hien tai" });
      }
      const currentUser = await User.findById(req.userId).select("matkhau");
      if (!currentUser || !(await bcrypt.compare(matkhauCu, currentUser.matkhau))) {
        return res.status(401).json({ message: "Mat khau hien tai khong dung" });
      }
      updates.matkhau = await bcrypt.hash(matkhau, 12);
    }
    if (!Object.keys(updates).length) return res.status(400).json({ message: "Khong co thong tin de cap nhat" });
    const user = await User.findByIdAndUpdate(req.params.id, { $set: updates }, { new: true, runValidators: true }).select("email hoten hinhanh");
    if (!user) return res.status(404).json({ message: "Khong tim thay nguoi dung" });
    return res.json({ message: "Cap nhat thanh cong", user: publicUser(user) });
  } catch (error) {
    if (error.code === 11000) return res.status(409).json({ message: "Email da ton tai" });
    console.error("Update user:", error);
    return res.status(400).json({ message: "Loi cap nhat nguoi dung" });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: "ID khong hop le" });
    if (req.params.id === req.userId) return res.status(400).json({ message: "Khong the xoa tai khoan dang dang nhap" });
    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ message: "Khong tim thay nguoi dung" });
    return res.json({ message: "Xoa nguoi dung thanh cong" });
  } catch (error) {
    console.error("Delete user:", error);
    return res.status(500).json({ message: "Loi xoa nguoi dung" });
  }
});

module.exports = router;
