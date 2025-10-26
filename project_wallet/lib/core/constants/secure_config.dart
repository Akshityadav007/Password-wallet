class SecureConfig {
  // Argon2id / pwhash params (tunable)
  static const int pwhashOutLen = 32;
  // Use interactive limits by default; you can bump to MODERATE for higher security.
  // The Sodium wrapper exposes constants; we'll use them in implementation.
}
