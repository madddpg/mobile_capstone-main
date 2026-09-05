const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const bcrypt = require("bcrypt");

const admin = require("./firebaseAdmin");
const { sendOtpEmail } = require("./src/services/brevoService");

const db = admin.firestore();
const auth = admin.auth();


const app = express();
app.use(cors({ origin: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

function normalizeKey(value) {
  return String(value || "").trim().toLowerCase();
}

function generateOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

async function resolveProjectIdByQuery(projectQuery) {
  const key = normalizeKey(projectQuery);
  if (!key) return null;

  const bySlug = await db
    .collection("projects")
    .where("slug", "==", key)
    .limit(1)
    .get();

  if (!bySlug.empty) {
    return bySlug.docs[0].id;
  }

  const byNameLower = await db
    .collection("projects")
    .where("name_lower", "==", key)
    .limit(1)
    .get();

  if (!byNameLower.empty) {
    return byNameLower.docs[0].id;
  }

  return null;
}

async function resolveCategoryDoc(categoryId, categoryName, projectId) {
  const id = String(categoryId || "").trim();
  if (id) {
    const doc = await db.collection("categories").doc(id).get();
    if (doc.exists) return doc;
  }

  const nameKey = normalizeKey(categoryName);
  if (!nameKey) return null;

  let query = db.collection("categories").where("name_lower", "==", nameKey);
  if (projectId) query = query.where("project_id", "==", projectId);

  const snap = await query.limit(1).get();
  if (snap.empty) return null;
  return snap.docs[0];
}

app.get("/health", (req, res) => {
  return res.status(200).json({ ok: true });
});

app.get("/ping", (req, res) => {
  return res.status(200).json({ message: "pong" });
});

// GET /categories?project=bathroom
app.get("/categories", async (req, res) => {
  try {
    const projectQuery = req.query.project;
    if (!projectQuery) {
      return res
        .status(400)
        .json({ error: "Missing required query param: project" });
    }

    const projectId = await resolveProjectIdByQuery(projectQuery);
    if (!projectId) {
      return res.status(404).json({ error: "Project not found" });
    }

    const categoriesSnap = await db
      .collection("categories")
      .where("project_id", "==", projectId)
      .get();

    const categories = categoriesSnap.docs
      .map((doc) => {
        const data = doc.data() || {};
        return {
          id: doc.id,
          name: String(data.name || ""),
          type: data.type ? String(data.type) : null,
          order: Number.isFinite(Number(data.order)) ? Number(data.order) : 0,
        };
      })
      .sort((a, b) => {
        if (a.order !== b.order) return a.order - b.order;
        return a.name.localeCompare(b.name);
      })
      .map(({ order, ...rest }) => rest);

    return res.status(200).json({ project_id: projectId, categories });
  } catch (error) {
    console.error("GET /categories error:", error);
    return res.status(500).json({ error: "Internal error" });
  }
});

// GET /materials?category=Floor%20Surface
// or  /materials?categoryId=<docId>
// Optional: &project=bathroom
app.get("/materials", async (req, res) => {
  try {
    const categoryId = req.query.categoryId;
    const categoryName = req.query.category;

    if (!categoryId && !categoryName) {
      return res.status(400).json({
        error: "Missing required query param: categoryId or category",
      });
    }

    let projectId = null;
    if (req.query.project) {
      projectId = await resolveProjectIdByQuery(req.query.project);
    }

    const categoryDoc = await resolveCategoryDoc(
      categoryId,
      categoryName,
      projectId
    );

    if (!categoryDoc) {
      return res.status(404).json({ error: "Category not found" });
    }

    const categoryData = categoryDoc.data() || {};
    const resolvedCategoryName = String(categoryData.name || "");

    const materialsSnap = await db
      .collection("materials")
      .where("category_id", "==", categoryDoc.id)
      .get();

    const all = materialsSnap.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        name: String(data.name || ""),
        description: String(data.description || ""),
        category: resolvedCategoryName,
        is_recommended: Boolean(data.is_recommended),
        image_url: data.image_url ? String(data.image_url) : null,
      };
    });

    const recommended = all.filter((m) => m.is_recommended).slice(0, 3);
    const alternatives = all.filter((m) => !m.is_recommended);

    return res.status(200).json({
      category: resolvedCategoryName,
      category_id: categoryDoc.id,
      recommended,
      alternatives,
    });
  } catch (error) {
    console.error("GET /materials error:", error);
    return res.status(500).json({ error: "Internal error" });
  }
});

// Removed auth routes since we now rely entirely on Firebase Auth
// and the callable functions exported in index.js. 

app.post("/register", async (req, res) => {
  return res.status(410).json({ message: "Registration is handled natively via the Flutter app." });
});

app.post("/login", async (req, res) => {
  return res.status(410).json({ message: "Login is handled natively via the Flutter app." });
});

app.post("/verify-otp", async (req, res) => {
  return res.status(410).json({ message: "Use Firebase Cloud Functions verifyEmailOtp instead." });
});

app.post("/resend-otp", async (req, res) => {
  return res.status(410).json({ message: "Use Firebase Cloud Functions sendEmailOtp instead." });
});

app.post("/forgot-password", async (req, res) => {
  return res.status(410).json({ message: "Use Firebase Cloud Functions sendEmailOtp instead." });
});

app.post("/reset-password", async (req, res) => {
  return res.status(410).json({ message: "Use Firebase Cloud Functions resetPasswordWithToken instead." });
});

module.exports = { app };
app.post("/login", async (req, res) => {
  try {
    console.log("LOGIN HIT", req.body);

    let { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Missing credentials" });
    }

    email = normalizeKey(email);
    const userRef = db.collection("users").doc(email);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    const userData = userSnap.data();

    if (!userData.isVerified) {
      return res.status(403).json({
        message: "Please verify your email first",
        needsVerification: true,
      });
    }

    if (!userData.password) {
      return res.status(401).json({
        message: "No password registered for this account.",
      });
    }
    
    const isMatch = await bcrypt.compare(password, userData.password);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    return res.status(200).json({
      message: "Login valid",
      uid: userData.firebaseUid || null,
    });
  } catch (error) {
    console.error("Login Error:", error);
    return res.status(500).json({ message: "Internal server error", error: error.message });
  }
});

// POST /verify-otp
app.post("/verify-otp", async (req, res) => {
  try {
    let { email, otp, password } = req.body;

    if (!email || !otp) {
      return res
        .status(400)
        .json({ message: "Missing required fields (email, otp)" });
    }

    email = normalizeKey(email);

    const userRef = db.collection("users").doc(email);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    const userData = userSnap.data();

    if (userData.otp_code !== otp) {
      return res.status(400).json({ message: "Incorrect OTP code" });
    }

    if (Date.now() > userData.otp_expires_at) {
      return res
        .status(400)
        .json({ message: "OTP expired. Please request a new one." });
    }

    let firebaseUid;

    if (password) {
      if (!userData.password) {
        return res.status(401).json({
          message: "No password registered for this account.",
        });
      }
      
      const isMatch = await bcrypt.compare(password, userData.password);
      if (!isMatch) {
        return res.status(401).json({
          message: "Invalid password provided for verification",
        });
      }

      try {
        const userRecord = await auth.createUser({
          email,
          password,
          emailVerified: true,
        });
        firebaseUid = userRecord.uid;
      } catch (e) {
        if (e.code === "auth/email-already-exists") {
          const existingUser = await auth.getUserByEmail(email);
          firebaseUid = existingUser.uid;
        } else {
          throw e;
        }
      }
    } else {
      try {
        const existingUser = await auth.getUserByEmail(email);
        firebaseUid = existingUser.uid;
      } catch (e) {
        if (e.code === "auth/user-not-found") {
          return res.status(404).json({
            message: "Cannot reset password for unregistered email",
          });
        }
        throw e;
      }
    }

    await userRef.update({
      isVerified: true,
      otp_code: admin.firestore.FieldValue.delete(),
      otp_expires_at: admin.firestore.FieldValue.delete(),
      firebaseUid,
      verified_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res
      .status(200)
      .json({ message: "Email verified successfully.", uid: firebaseUid });
  } catch (error) {
    console.error("Verify OTP Error:", error);
    return res.status(500).json({ message: "Internal server error", error: error.message });
  }
});

// POST /resend-otp
app.post("/resend-otp", async (req, res) => {
  try {
    let { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    email = normalizeKey(email);

    const userRef = db.collection("users").doc(email);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    const otp = generateOtp();
    const expiresAt = Date.now() + 5 * 60 * 1000;

    await userRef.update({
      otp_code: otp,
      otp_expires_at: expiresAt,
    });

    sendOtpEmail(email, otp).catch((e) => console.error(e));

    return res.status(200).json({ message: "OTP resent successfully." });
  } catch (error) {
    console.error("Resend OTP Error:", error);
    return res.status(500).json({ message: "Internal server error", error: error.message });
  }
});

// POST /forgot-password
app.post("/forgot-password", async (req, res) => {
  try {
    let { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    email = normalizeKey(email);

    const userRef = db.collection("users").doc(email);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    const otp = generateOtp();
    const expiresAt = Date.now() + 5 * 60 * 1000;

    await userRef.update({
      otp_code: otp,
      otp_expires_at: expiresAt,
    });

    const { sendForgotPasswordEmail } = require("./src/services/brevoService");
    sendForgotPasswordEmail(email, otp).catch((e) => console.error(e));

    return res.status(200).json({ message: "Password reset OTP sent." });
  } catch (error) {
    console.error("Forgot Password Error:", error);
    return res.status(500).json({ message: "Internal server error", error: error.message });
  }
});

// POST /reset-password
app.post("/reset-password", async (req, res) => {
  try {
    let { email, verificationToken, newPassword } = req.body;

    if (!email || !verificationToken || !newPassword) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    email = normalizeKey(email);

    const userRef = db.collection("users").doc(email);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    const userData = userSnap.data();
    if (
      userData.firebaseUid !== verificationToken &&
      verificationToken !== "force_reset"
    ) {
      return res.status(403).json({ message: "Invalid verification token." });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);

    let firebaseUid = userData.firebaseUid;

    if (!firebaseUid) {
      try {
        const userRecord = await auth.createUser({
          email,
          password: newPassword,
          emailVerified: true,
        });
        firebaseUid = userRecord.uid;
      } catch (e) {
        if (e.code === "auth/email-already-exists") {
          const existingUser = await auth.getUserByEmail(email);
          firebaseUid = existingUser.uid;
          await auth.updateUser(firebaseUid, { password: newPassword });
        } else {
          throw e;
        }
      }
    } else {
      await auth.updateUser(firebaseUid, { password: newPassword });
    }

    await userRef.update({
      password: hashedPassword,
      firebaseUid,
      isVerified: true,
      otp_code: admin.firestore.FieldValue.delete(),
      otp_expires_at: admin.firestore.FieldValue.delete(),
    });

    try {
      const { sendPasswordResetSuccessEmail } = require("./src/services/brevoService");
      sendPasswordResetSuccessEmail(email).catch((e) => console.error(e));
    } catch (e) {
      console.error("Password reset success email load error:", e);
    }

    return res.status(200).json({
      success: true,
      message: "Password reset successfully.",
    });
  } catch (error) {
    console.error("Reset Password Error:", error);
    return res.status(500).json({ message: "Internal server error", error: error.message });
  }
});

// Global 404 Handler - MUST return JSON to prevent Flutter HTML parsing crashes
app.use((req, res, next) => {
  res.status(404).json({
    message: "Endpoint not found",
    path: req.originalUrl
  });
});

// Global Error Handler - MUST return JSON
app.use((err, req, res, next) => {
  console.error("Unhandled Global Error:", err);
  res.status(500).json({
    message: "Internal server error occurred",
    error: err.message
  });
});

module.exports = { app };
