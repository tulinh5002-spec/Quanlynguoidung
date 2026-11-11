const fs = require('node:fs');
const path = require('node:path');
const mongoose = require('mongoose');
const { EJSON } = require('bson');
require('dotenv').config({path:path.join(__dirname, '..', '.env'), quiet:true});
const fields = ['email','matkhau','hoten','hinhanh'];
const allowed = new Set(['_id', ...fields]);
async function main() {
  if (!process.env.MONGO_URI) throw Error('Missing MONGO_URI in backend/.env');
  await mongoose.connect(process.env.MONGO_URI, {serverSelectionTimeoutMS:15000});
  const db = mongoose.connection.db;
  const collection = db.collection('users');
  const before = await collection.find({}).toArray();
  for (const doc of before) {
    for (const key of fields) if (typeof doc[key] !== 'string') throw Error(`Aborted: document has missing/non-string ${key}`);
  }
  const stamp = new Date().toISOString().replace(/[:.]/g,'-');
  const backupDir = path.join(__dirname,'..','backups',stamp);
  fs.mkdirSync(backupDir,{recursive:true});
  fs.writeFileSync(path.join(backupDir,'users.before.mongo.json'), EJSON.stringify(before,null,2,{relaxed:false})+'\n');
  const info = await db.listCollections({name:'users'}).next();
  fs.writeFileSync(path.join(backupDir,'collection-options.before.json'), EJSON.stringify(info?.options ?? {},null,2)+'\n');
  const exportPath = path.join(__dirname,'..','NovaID_MongoDB_Database.json');
  if (fs.existsSync(exportPath)) fs.copyFileSync(exportPath,path.join(backupDir,'previous-export.json'));
  const extra = [...new Set(before.flatMap(doc=>Object.keys(doc).filter(key=>!allowed.has(key))))];
  if (extra.length) {
    const unset = Object.fromEntries(extra.map(key=>[key,'']));
    await collection.updateMany({}, {$unset:unset});
  }
  let validatorStatus = 'strict database validator';
  try { await db.command({
    collMod:'users',
    validator:{$jsonSchema:{bsonType:'object', required:['_id',...fields], additionalProperties:false,
      properties:{_id:{bsonType:'objectId'}, ...Object.fromEntries(fields.map(key=>[key,{bsonType:'string'}]))}}},
    validationLevel:'strict', validationAction:'error'
  }); } catch (error) {
    if (error.code !== 8000 || !error.message.includes('collMod')) throw error;
    validatorStatus = 'MongoDB account lacks collMod permission; application Mongoose schema restricts fields';
  }
  const after = await collection.find({}).sort({_id:1}).toArray();
  if (before.length !== after.length) throw Error('Record count changed during migration; inspect backup');
  const originals = new Map(before.map(doc=>[String(doc._id),doc]));
  for (const doc of after) {
    if (Object.keys(doc).some(key=>!allowed.has(key))) throw Error('Unexpected database field after migration');
    const original = originals.get(String(doc._id));
    for (const key of fields) if (original?.[key] !== doc[key]) throw Error(`Concurrent change detected: ${key}; inspect backup`);
  }
  fs.writeFileSync(exportPath, JSON.stringify(after.map(doc=>Object.fromEntries(fields.map(key=>[key,doc[key]]))),null,2)+'\n');
  fs.writeFileSync(path.join(__dirname,'..','NovaID_MongoDB_Database.mongo.json'), EJSON.stringify(after,null,2,{relaxed:false})+'\n');
  console.log(JSON.stringify({records:after.length,removedFields:extra,businessFields:fields,backupDirectory:backupDir,exportFile:exportPath,verifiedUnchanged:['record count','_id',...fields],validator:validatorStatus},null,2));
}
main().catch(error=>{console.error('Migration failed:',error.code || error.name, error.message.replace(/mongodb(?:\+srv)?:\/\/\S+/g,'[connection redacted]'));process.exitCode=1;}).finally(()=>mongoose.disconnect());
