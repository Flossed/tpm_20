const mongoose = require('mongoose');
const TPMKey = require('../models/TPMKey');

mongoose.connect('mongodb://192.168.129.197:27017/tpm20')
  .then(async () => {
    console.log('Connected to database');
    const keys = await TPMKey.find({status: {$ne: 'deleted'}}).lean();
    console.log('Found keys:', keys.length);
    
    keys.forEach(key => {
      console.log('\n--- Key:', key.name, '---');
      console.log('ID:', key._id);
      console.log('TPM Handle:', key.tmpHandle || key.tpmHandle);
      console.log('inTPM:', key.inTPM);
      console.log('Provider:', key.provider);
      console.log('Status:', key.status);
      if (key.metadata && key.metadata instanceof Map) {
        console.log('Metadata entries:');
        for (let [keyName, value] of key.metadata) {
          console.log('  ' + keyName + ':', value);
        }
      } else if (key.metadata) {
        console.log('Metadata (object):', key.metadata);
      }
    });
    
    mongoose.disconnect();
  })
  .catch(console.error);