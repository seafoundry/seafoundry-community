const admin = require("firebase-admin");
const fs = require("fs");
const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || "./firebase-service-account.json";
const creds = JSON.parse(fs.readFileSync(credPath, "utf8"));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(creds) });
}
admin.auth().getUserByEmail("dev@seafoundry.com")
  .then(user => {
    console.log("Found user:", user.uid);
    return admin.auth().deleteUser(user.uid);
  })
  .then(() => {
    console.log("Firebase Auth user deleted");
    process.exit(0);
  })
  .catch(err => {
    if (err.code === "auth/user-not-found") {
      console.log("User not found - already deleted");
      process.exit(0);
    }
    console.error("Error:", err.message);
    process.exit(1);
  });
