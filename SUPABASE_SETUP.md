# 🚀 Supabase Migration Complete!

Firebase has been successfully removed and replaced with Supabase.

## ✅ What Was Done:

### Files Created:
1. **SupabaseConfig.swift** - Supabase credentials configuration
2. **SupabaseAuthService.swift** - Authentication service using Supabase
3. **SUPABASE_SETUP.md** - This setup guide

### Files Updated:
1. **PhoneNumberPage.swift** - Now uses Supabase for OTP
2. **VerificationCodePage.swift** - Now uses Supabase for verification
3. **ProfileData.swift** - Now uses Supabase PostgreSQL instead of Firestore
4. **ShipitApp.swift** - Removed Firebase, uses Supabase

### Files Removed/Backed Up:
1. **PhoneAuthUIDelegate.swift** - Deleted (was for Firebase reCAPTCHA)
2. **AuthService.swift** - Backed up as `AuthService.swift.firebase_backup`

---

## 📋 Setup Steps:

### 1. Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign up / Log in
3. Click **"New Project"**
4. Fill in:
   - Name: `Shipit`
   - Database Password: (choose a strong password)
   - Region: (choose closest to your users)
5. Click **"Create new project"**
6. Wait for setup to complete (~2 minutes)

### 2. Get Your Credentials

1. In your Supabase project, go to **Settings** → **API**
2. Copy these values:
   - **Project URL** (e.g., `https://xxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)

### 3. Update SupabaseConfig.swift

Open `Shipit/Shipit/SupabaseConfig.swift` and replace:

```swift
static let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
static let supabaseAnonKey = "YOUR_ANON_KEY"
```

With your actual values from step 2.

### 4. Add Supabase Swift Package

1. Open Xcode
2. Go to **File** → **Add Package Dependencies**
3. Enter: `https://github.com/supabase/supabase-swift`
4. Click **Add Package**
5. Select **Supabase** (the main package)
6. Click **Add Package**

### 5. Remove Firebase Dependencies

1. In Xcode, select your project
2. Go to your target → **Frameworks, Libraries, and Embedded Content**
3. Remove all Firebase packages:
   - FirebaseAuth
   - FirebaseCore
   - FirebaseFirestore
   - FirebaseMessaging
4. Also check **Build Phases** → **Link Binary** and remove any Firebase references

### 6. Delete Firebase Configuration File

Delete the following file from your project:
- `GoogleService-Info.plist` (if it exists)

### 7. Create Database Tables in Supabase

In your Supabase project, go to **SQL Editor** and run this SQL:

```sql
-- Create profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selectedTab INT DEFAULT 0,
  firstName TEXT DEFAULT '',
  lastName TEXT DEFAULT '',
  companyName TEXT DEFAULT '',
  nip TEXT DEFAULT '',
  selectedCountry TEXT DEFAULT 'Poland',
  streetAndNumber TEXT DEFAULT '',
  apartmentUnit TEXT DEFAULT '',
  postalCode TEXT DEFAULT '',
  city TEXT DEFAULT '',
  regionState TEXT DEFAULT '',
  phonePrefix TEXT DEFAULT '+48',
  phoneNumber TEXT DEFAULT '',
  email TEXT DEFAULT '',
  userType INT DEFAULT 0,
  updatedAt TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  createdAt TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own profile
CREATE POLICY "Users can read own profile" 
  ON profiles FOR SELECT 
  USING (auth.uid() = id);

-- Policy: Users can insert their own profile
CREATE POLICY "Users can insert own profile" 
  ON profiles FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile" 
  ON profiles FOR UPDATE 
  USING (auth.uid() = id);
```

### 8. Enable Phone Authentication in Supabase

1. In Supabase, go to **Authentication** → **Providers**
2. Enable **Phone** provider
3. Configure your SMS provider:
   - **Twilio** (recommended)
   - **MessageBird**
   - **Vonage**
   - Or use Supabase's built-in provider (limited)

**For Twilio:**
1. Sign up at [twilio.com](https://www.twilio.com)
2. Get your **Account SID** and **Auth Token**
3. Buy a phone number
4. In Supabase → Authentication → Providers → Phone:
   - Select **Twilio**
   - Enter Account SID and Auth Token
   - Enter your Twilio phone number
   - Save

### 9. Configure Phone Auth Settings (Optional)

In Supabase → Authentication → Phone:
- OTP Expiry: 60 seconds (default)
- OTP Length: 6 digits (default)

### 10. Test Your App!

1. Clean build folder: `⌘ + Shift + K`
2. Build and run: `⌘ + R`
3. Enter a phone number
4. You should receive an OTP via SMS
5. Enter the code and verify
6. You're logged in! ✅

---

## 🎯 Benefits of Supabase:

### ✅ No reCAPTCHA!
- Clean user experience
- No image verification needed
- Works perfectly in development and production

### ✅ Better SMS Delivery
- Reliable SMS delivery via Twilio/MessageBird
- No Firebase quota limits
- Better international coverage

### ✅ PostgreSQL Database
- Powerful relational database
- SQL queries
- Real-time subscriptions
- Better data modeling

### ✅ Open Source
- Self-hostable
- No vendor lock-in
- Active community

### ✅ Modern API
- Clean Swift async/await API
- Type-safe
- Better error handling

---

## 📱 Phone Auth Flow:

1. User enters phone number → `sendOTP()`
2. OTP sent via SMS (Twilio/etc)
3. User enters 6-digit code → `verifyOTP()`
4. User authenticated! → Session created
5. Profile data synced with PostgreSQL

---

## 🐛 Troubleshooting:

### SMS Not Received?
- Check Twilio account balance
- Verify phone number format (+48790221569)
- Check Twilio logs for errors
- Try a different phone number

### Build Errors?
- Make sure Firebase packages are completely removed
- Clean build folder (⌘ + Shift + K)
- Delete derived data
- Restart Xcode

### Database Errors?
- Check if tables are created in SQL Editor
- Verify Row Level Security policies
- Check user is authenticated

---

## 📚 Documentation:

- [Supabase Docs](https://supabase.com/docs)
- [Supabase Swift Client](https://github.com/supabase/supabase-swift)
- [Phone Auth Guide](https://supabase.com/docs/guides/auth/phone-login)

---

## 🎉 Next Steps:

1. Configure your Supabase project
2. Add the Swift package
3. Update credentials
4. Create database tables
5. Enable phone auth
6. Test!

**Welcome to Supabase!** 🚀
