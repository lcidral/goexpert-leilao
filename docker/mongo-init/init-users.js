// This script runs automatically on MongoDB container initialization
// It creates the target database and a demo user document for testing.

// The compose sets MONGODB_DB via env file; however, init scripts run against the "test" db unless we switch.
// We will read env var if available via process.env (not available in mongo shell), so default to 'auctions'.
// In Mongo init context, 'db' points to 'test' by default, so we need to get the desired DB explicitly.

(function() {
  var dbName = 'auctions';
  try {
    // If a different name is desired, change here to match MONGODB_DB
    db = db.getSiblingDB(dbName);
  } catch (e) {
    // fallback silently
  }

  // Ensure collection exists and insert a known user id for tests
  db.createCollection('users');
  db.users.updateOne(
    { _id: '11111111-1111-1111-1111-111111111111' },
    { $set: { name: 'Demo User' } },
    { upsert: true }
  );
})();
