const assert = require('node:assert/strict');
const User = require('../backend/models/User');

async function main() {
  const user = new User({ hoten: 'Test', email: 'test@example.com', matkhau: 'hashed', hinhanh: '', diachi: 'ignored', gioitinh: 'ignored', ngaysinh: 'ignored' });
  await user.validate();
  assert.deepEqual(Object.keys(user.toObject()).sort(), ['_id', 'email', 'matkhau', 'hoten', 'hinhanh'].sort());
  for (const field of ['hoten', 'email', 'matkhau']) {
    const missing = new User({ hoten: 'Test', email: 'test@example.com', matkhau: 'hashed' });
    missing.set(field, undefined);
    await assert.rejects(missing.validate(), error => Boolean(error.errors[field]));
  }
  console.log('User schema validation passed: four business fields, extra fields ignored, required fields checked.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
