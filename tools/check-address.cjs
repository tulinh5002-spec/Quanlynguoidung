const User = require('../backend/models/User');
const good = new User({hoten:'Test', email:'test@example.com', matkhau:'hashed', diachi:'  12 Nguyen Trai  '});
if (good.validateSync()) throw good.validateSync();
if (good.diachi !== '12 Nguyen Trai') throw Error('address trim');
const bad = new User({hoten:'Test',email:'test@example.com',matkhau:'hashed',diachi:'a'.repeat(501)});
if (!bad.validateSync()?.errors.diachi) throw Error('address length');
console.log('Address schema validation passed');
