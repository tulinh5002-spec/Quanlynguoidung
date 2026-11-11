const path = require('node:path');
const fs = require('node:fs');
const mongoose = require('mongoose');
require('dotenv').config({ path: path.join(__dirname, '.env'), quiet: true });

async function exportDatabase() {
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 15000 });
    const users = await mongoose.connection.db.collection('users')
      .find({}, { projection: { _id: 0, email: 1, matkhau: 1, hoten: 1, hinhanh: 1 } })
      .sort({ email: 1 }).toArray();
    const fields = ['email', 'matkhau', 'hoten', 'hinhanh'];
    const output = users.map(user => Object.fromEntries(fields.map(field => [field, user[field] ?? ''])));
    const outputPath = path.join(__dirname, 'NovaID_MongoDB_Database.json');
    fs.writeFileSync(outputPath, JSON.stringify(output, null, 2) + '\n', 'utf8');
    console.log(`Da xuat ${output.length} nguoi dung voi dung 4 truong: ${fields.join(', ')}`);
  } catch (error) {
    console.error('Khong the xuat du lieu:', error.code || error.name);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
}
exportDatabase();
