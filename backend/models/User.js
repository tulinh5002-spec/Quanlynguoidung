const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true
  },

  matkhau: {
    type: String,
    required: true
  },

  hoten: {
    type: String,
    required: true
  },

  gioitinh: {
    type: String,
    enum: ["", "Nam", "Nữ", "Khác"],
    default: ""
  },

  ngaysinh: {
    type: String,
    default: "",
    match: [/^$|^\d{4}-\d{2}-\d{2}$/, "Ngay sinh phai co dang YYYY-MM-DD"]
  },

  diachi: { type: String, trim: true, maxlength: 500, default: "" },
  hinhanh: {
    type: String,
    default: ""
  }
}, {
  versionKey: false
});

module.exports = mongoose.model("User", userSchema);
