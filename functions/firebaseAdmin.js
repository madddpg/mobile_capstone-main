const admin = require("firebase-admin");

if (!admin.apps.length) {
  // Use Default Application Credentials in production
  admin.initializeApp();
}

module.exports = admin;