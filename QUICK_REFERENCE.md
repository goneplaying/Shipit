# 🚀 Supabase Quick Reference

Quick commands and code snippets for common tasks.

---

## 📋 Setup Commands (Do Once)

### Add Supabase Package
```
File → Add Package Dependencies
URL: https://github.com/supabase/supabase-swift
```

### Remove Firebase
```bash
# In Xcode:
Project → Target → Frameworks → Remove all Firebase*
Product → Clean Build Folder (⌘+⇧+K)
```

---

## 🔑 Essential Credentials

### Get From Supabase Dashboard:
```
Settings → API →
  - Project URL: https://xxx.supabase.co
  - anon public key: eyJhbG...
```

### Add To SupabaseConfig.swift:
```swift
static let supabaseURL = URL(string: "YOUR_URL")!
static let supabaseAnonKey = "YOUR_KEY"
```

---

## 📱 Common Code Snippets

### Send OTP
```swift
Task {
    try await SupabaseAuthService.shared.sendOTP(to: "+48790221569")
}
```

### Verify OTP
```swift
Task {
    try await SupabaseAuthService.shared.verifyOTP(
        phone: "+48790221569",
        token: "123456"
    )
}
```

### Sign Out
```swift
Task {
    try await SupabaseAuthService.shared.signOut()
}
```

### Check Auth Status
```swift
if SupabaseAuthService.shared.isAuthenticated {
    // User is logged in
}
```

### Get Current User
```swift
if let user = SupabaseAuthService.shared.user {
    print(user.id)
    print(user.email ?? "no email")
    print(user.phone ?? "no phone")
}
```

---

## 💾 Database Operations

### Save Profile
```swift
Task {
    try await ProfileData.shared.save()
}
```

### Load Profile
```swift
Task {
    try await ProfileData.shared.loadFromSupabase()
}
```

### Direct Query
```swift
struct User: Codable {
    let id: UUID
    let name: String
}

let users: [User] = try await SupabaseAuthService.shared.client.database
    .from("profiles")
    .select()
    .execute()
    .value
```

---

## 🗄️ Useful SQL Queries

### View All Profiles
```sql
SELECT * FROM profiles;
```

### Count Users
```sql
SELECT COUNT(*) FROM auth.users;
```

### Recent Signups
```sql
SELECT email, phone, created_at 
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 10;
```

### Delete Test User
```sql
DELETE FROM auth.users WHERE phone = '+48790221569';
```

### Check Table Structure
```sql
\d profiles
```

---

## 🐛 Quick Fixes

### "Module not found"
```bash
⌘+⇧+K (Clean)
Delete ~/Library/Developer/Xcode/DerivedData/Shipit*
⌘+B (Build)
```

### "No SMS received"
1. Check Twilio logs
2. Verify phone format: `+48790221569`
3. Check Supabase auth logs

### "Database error"
```sql
-- Re-create table
DROP TABLE IF EXISTS profiles CASCADE;
-- Then run CREATE TABLE script again
```

---

## 📊 Monitoring

### Check Auth Logs
```
Supabase Dashboard → Authentication → Logs
```

### Check Database
```
Supabase Dashboard → Database → Tables → profiles
```

### Check SMS Usage (Twilio)
```
Twilio Dashboard → Monitor → Logs → Messaging
```

---

## 🔧 Configuration Files

### SupabaseConfig.swift
```swift
struct SupabaseConfig {
    static let supabaseURL = URL(string: "YOUR_URL")!
    static let supabaseAnonKey = "YOUR_KEY"
}
```

### Info.plist Changes
Remove:
```xml
<key>CFBundleURLTypes</key>
<!-- Firebase URL schemes - DELETE -->
```

---

## 🧪 Testing

### Test Numbers (Add in Supabase Auth)
```
Supabase → Authentication → Phone → 
Phone numbers for testing:
  +48123456789 → 123456
```

### Console Logs to Watch For
```
✅ OTP sent successfully
✅ Phone verification successful  
👤 User ID: xxxxx
```

---

## 📞 Support

- **Supabase Discord**: https://discord.supabase.com
- **Supabase Docs**: https://supabase.com/docs
- **Twilio Support**: https://www.twilio.com/help

---

**Keep this file handy for quick reference!** 📌
