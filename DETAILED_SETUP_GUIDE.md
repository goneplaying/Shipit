# 📋 Detailed Supabase Setup Guide - Step by Step

Follow these steps **exactly** to complete the Firebase → Supabase migration.

---

## 🎯 STEP 1: Create Supabase Account (5 minutes)

### 1.1 Sign Up
1. Open browser and go to: **https://supabase.com**
2. Click **"Start your project"** button (green button, top right)
3. Choose sign-up method:
   - **GitHub** (recommended - fastest)
   - Or email/password
4. Complete sign-up process
5. You'll be redirected to Supabase Dashboard

### 1.2 Create New Project
1. On Dashboard, click **"New Project"** button
2. Fill in the form:
   ```
   Name: Shipit
   Database Password: [Create a strong password - SAVE THIS!]
   Region: Europe (Frankfurt) or closest to you
   Pricing Plan: Free
   ```
3. Click **"Create new project"**
4. ⏱️ Wait 2-3 minutes while project is being set up
5. You'll see a loading screen - **don't close the browser!**

### 1.3 Save Your Credentials
1. When setup completes, you'll see the project dashboard
2. Click **Settings** (⚙️ icon in left sidebar, at bottom)
3. Click **API** in the settings menu
4. You'll see these important values:

   **Copy these NOW:**
   ```
   Project URL: https://xxxxxxxxxxxxx.supabase.co
   anon public key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS....
   ```

5. **SAVE THESE IN A TEXT FILE** - you'll need them in Step 3!

---

## 🔧 STEP 2: Add Supabase Package to Xcode (3 minutes)

### 2.1 Open Package Dependencies
1. Open your project in **Xcode**
2. Click on project name in left sidebar (at the very top - "Shipit")
3. Make sure you're on the **project** (not target)
4. Go to menu: **File** → **Add Package Dependencies...**
   - Or use shortcut: `⌘` + `⇧` + `I`

### 2.2 Add Supabase Package
1. In the search bar at top right, paste:
   ```
   https://github.com/supabase/supabase-swift
   ```
2. Press `Enter`
3. Wait for package to load (~10 seconds)
4. You'll see **supabase-swift** package appear
5. In "Dependency Rule", select: **"Up to Next Major Version"** (should show 2.0.0 or higher)
6. Click **"Add Package"** button at bottom right

### 2.3 Select Package Products
1. A new sheet appears: "Choose Package Products"
2. You'll see several options - **Select ONLY:**
   - ✅ **Supabase** (check this one!)
   - Leave others unchecked
3. Make sure it's adding to target: **Shipit**
4. Click **"Add Package"** button

### 2.4 Wait for Package to Download
1. Xcode will download and integrate the package
2. Watch bottom right of Xcode - you'll see progress
3. Wait until it says "Indexing..."
4. ⏱️ This takes 30-60 seconds
5. ✅ Done when you don't see any spinners

---

## 📝 STEP 3: Update Supabase Credentials (2 minutes)

### 3.1 Open SupabaseConfig.swift
1. In Xcode, press `⌘` + `⇧` + `O` (Open Quickly)
2. Type: `SupabaseConfig`
3. Press `Enter`
4. File opens

### 3.2 Replace Placeholder Values
1. Find these lines:
   ```swift
   static let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
   static let supabaseAnonKey = "YOUR_ANON_KEY"
   ```

2. Replace with YOUR values from Step 1.3:
   ```swift
   static let supabaseURL = URL(string: "https://abcdefgh.supabase.co")!
   static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```

3. **IMPORTANT:** Keep the quotes and URL structure exactly as shown!
4. Save file: `⌘` + `S`

### 3.3 Verify No Errors
1. Build project: `⌘` + `B`
2. Check for errors in Issue Navigator (left sidebar, triangle icon)
3. If you see errors about Supabase, wait a bit longer for indexing to complete
4. If errors persist, go back to Step 2

---

## 🗑️ STEP 4: Remove Firebase (5 minutes)

### 4.1 Remove Firebase Packages
1. In Xcode, click project name in left sidebar
2. Select **Shipit** target (under "TARGETS")
3. Go to **Frameworks, Libraries, and Embedded Content** section
4. Look for Firebase packages (scroll through the list):
   - FirebaseAuth
   - FirebaseCore
   - FirebaseFirestore
   - FirebaseMessaging
   - Any other Firebase* packages
5. For EACH Firebase package:
   - Click on it to select
   - Click the **"-"** (minus) button below the list
   - Confirm removal
6. Repeat until ALL Firebase packages are gone

### 4.2 Clean Build Folder
1. Go to menu: **Product** → **Clean Build Folder**
   - Or shortcut: `⌘` + `⇧` + `K`
2. Wait for "Clean Finished" message
3. This removes old Firebase build artifacts

### 4.3 Delete Firebase Config File (if exists)
1. In Project Navigator (left sidebar)
2. Look for file named: **GoogleService-Info.plist**
3. If you find it:
   - Right-click on it
   - Select **"Delete"**
   - Choose **"Move to Trash"**
4. If you don't see it, skip this step

### 4.4 Remove Firebase from Info.plist
1. Find **Info.plist** in Project Navigator
2. Right-click → **Open As** → **Source Code**
3. Look for these entries and DELETE THEM:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>app-1-664544110683-ios-...</string>
           </array>
       </dict>
   </array>
   ```
4. Save file: `⌘` + `S`

### 4.5 Rebuild Project
1. Build: `⌘` + `B`
2. You might see some warnings - **that's OK!**
3. Check for any **errors** - there should be NONE
4. If you see errors about missing Firebase, that's actually good - they'll be gone soon

---

## 💾 STEP 5: Create Database Tables in Supabase (3 minutes)

### 5.1 Open SQL Editor
1. Go back to **Supabase Dashboard** in your browser
2. Make sure you're in your **Shipit** project
3. Click **SQL Editor** in left sidebar (icon looks like `</>`)
4. Click **"+ New query"** button (top right)

### 5.2 Create Profiles Table
1. Copy this ENTIRE SQL script:

```sql
-- Create profiles table for user data
CREATE TABLE profiles (
  -- Primary key linked to auth.users
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Profile type
  selectedTab INT NOT NULL DEFAULT 0,
  userType INT NOT NULL DEFAULT 0,
  
  -- Personal information
  firstName TEXT NOT NULL DEFAULT '',
  lastName TEXT NOT NULL DEFAULT '',
  
  -- Company information
  companyName TEXT NOT NULL DEFAULT '',
  nip TEXT NOT NULL DEFAULT '',
  
  -- Address
  selectedCountry TEXT NOT NULL DEFAULT 'Poland',
  streetAndNumber TEXT NOT NULL DEFAULT '',
  apartmentUnit TEXT NOT NULL DEFAULT '',
  postalCode TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT '',
  regionState TEXT NOT NULL DEFAULT '',
  
  -- Contact
  phonePrefix TEXT NOT NULL DEFAULT '+48',
  phoneNumber TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  
  -- Timestamps
  createdAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create index on id for faster lookups
CREATE INDEX profiles_id_idx ON profiles(id);

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

-- Create a function to automatically update updatedAt
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updatedAt = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to call the function
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

2. Paste it into the SQL editor
3. Click **"Run"** button at bottom right (or press `⌘` + `Enter`)
4. Wait for execution (~2 seconds)
5. You should see: **"Success. No rows returned"**
6. ✅ Table created!

### 5.3 Verify Table Creation
1. Click **Database** in left sidebar (icon looks like a cylinder)
2. Click **Tables**
3. You should see: **profiles** table listed
4. Click on it to see structure
5. ✅ Verify all columns are there

---

## 📱 STEP 6: Enable Phone Authentication (10 minutes)

### 6.1 Enable Phone Provider in Supabase
1. In Supabase Dashboard, click **Authentication** in left sidebar
2. Click **Providers** tab (at top)
3. Scroll down to **Phone** section
4. Toggle **"Enable Phone provider"** to ON (switch turns green)
5. **Don't close this page yet!** - you'll need to configure SMS

### 6.2 Option A: Quick Test with Supabase SMS (Limited)

**For testing only - limited quota!**

1. In the Phone provider settings, select:
   ```
   SMS Provider: Supabase (default)
   ```
2. Click **"Save"**
3. ⚠️ **Limitation:** Only 3-4 SMS per hour
4. Good for initial testing, but **use Twilio for production** (Option B)

### 6.3 Option B: Production Setup with Twilio (Recommended)

**This is the proper way for production:**

#### 6.3.1 Create Twilio Account
1. Go to: **https://www.twilio.com/try-twilio**
2. Sign up (it's free to start!)
3. Verify your email
4. Complete phone verification
5. You'll get **$15 free credit** - enough for ~300 SMS!

#### 6.3.2 Get Twilio Credentials
1. After signup, you're on Twilio Dashboard
2. Find this section: **"Account Info"** (right side)
3. Copy these values:
   ```
   Account SID: ACxxxxxxxxxxxxxxxxxx
   Auth Token: [click "show" then copy]
   ```
4. **SAVE THESE!**

#### 6.3.3 Get a Twilio Phone Number
1. In Twilio Dashboard, left sidebar
2. Click **Phone Numbers** → **Manage** → **Buy a number**
3. Select country: **Poland** (or your country)
4. Capabilities needed:
   - ✅ SMS
   - ✅ MMS (optional)
   - Voice (not needed)
5. Click **Search**
6. Pick any number (they're all the same price)
7. Click **Buy** (~$1/month)
8. Confirm purchase
9. **Copy your new phone number:** `+48...`

#### 6.3.4 Configure Twilio in Supabase
1. Go back to **Supabase** → **Authentication** → **Providers** → **Phone**
2. In Phone provider settings:
   ```
   Enable Phone Signup: ON
   SMS Provider: Twilio
   ```
3. Fill in Twilio settings:
   ```
   Twilio Account SID: ACxxxxxxxxxx [from step 6.3.2]
   Twilio Auth Token: your-token [from step 6.3.2]
   Twilio Phone Number: +48xxxxxxxxx [from step 6.3.3]
   ```
4. Click **"Save"**
5. ✅ SMS configured!

### 6.4 Configure Phone Auth Settings
In the same Phone provider screen:

```
OTP Expiry: 60 seconds (default is fine)
OTP Length: 6 (default is fine)
SMS Template: (leave default or customize)
```

Click **"Save"** if you made changes

---

## 🧪 STEP 7: Test Your App! (5 minutes)

### 7.1 Clean and Build
1. In Xcode: **Product** → **Clean Build Folder** (`⌘` + `⇧` + `K`)
2. Wait for "Clean Finished"
3. **Product** → **Build** (`⌘` + `B`)
4. Wait for "Build Succeeded"
5. Check for NO errors (warnings are OK)

### 7.2 Run on Device/Simulator
1. Select your device or simulator from scheme selector
2. **Product** → **Run** (`⌘` + `R`)
3. Wait for app to launch

### 7.3 Test Phone Verification

**What you should see:**

1. **Phone Number Page**:
   - Title: "What's your number?"
   - Country selector with flags
   - Phone number input
   - "Get verification code" button
   
2. **Enter your phone number**:
   - Select country (e.g., Poland 🇵🇱)
   - Enter: `790221569` (your number)
   - Tap **"Get verification code"**

3. **Verification Code Page**:
   - Title: "Enter verification code"
   - Text: "We sent a code to +48 790221569"
   - 6-digit input field
   
4. **Check your phone for SMS**:
   - You should receive SMS within 5-30 seconds
   - Code format: `123456` (6 digits)
   
5. **Enter the code**:
   - Type the 6 digits you received
   - It auto-submits when you enter 6 digits
   - Or tap "Verify" button

6. **Success!**:
   - You should be logged in
   - Redirected to HomePage (Carrier or Shipper)
   - ✅ Authentication working!

### 7.4 Check Console Logs

In Xcode console, you should see:
```
✅ [DEBUG] Supabase will be used for authentication
📱 [DEBUG] Sending OTP to: +48790221569
✅ [DEBUG] OTP sent successfully
🔐 [DEBUG] Verifying OTP for: +48790221569
✅ [DEBUG] Phone verification successful
👤 [DEBUG] User ID: xxxxx-xxxxx-xxxxx
```

---

## 🐛 TROUBLESHOOTING

### Problem: "Module 'Supabase' not found"
**Solution:**
1. Close Xcode completely
2. Delete **DerivedData**:
   - Go to: `~/Library/Developer/Xcode/DerivedData/`
   - Delete the `Shipit-xxx` folder
3. Reopen project
4. Clean Build Folder: `⌘` + `⇧` + `K`
5. Build: `⌘` + `B`

### Problem: "No SMS received"
**Solutions:**
1. **Check Twilio Account:**
   - Go to Twilio Dashboard
   - Click **Monitor** → **Logs** → **Messaging**
   - Look for your recent SMS - did it fail?
   
2. **Common Issues:**
   - ❌ Wrong phone number format → Use: `+48790221569`
   - ❌ Twilio trial account → Verify your phone number in Twilio first
   - ❌ No credit → Add $20 to Twilio account
   - ❌ Country restrictions → Some countries blocked, try another number

3. **Check Supabase Logs:**
   - Supabase Dashboard → **Authentication** → **Logs**
   - Look for errors about SMS sending

### Problem: "Invalid credentials" or "JWT malformed"
**Solution:**
1. Double-check `SupabaseConfig.swift`:
   - URL is correct (https://xxx.supabase.co)
   - anon key is complete (very long string starting with `eyJ`)
   - No extra spaces or line breaks
2. Get fresh credentials from Supabase Dashboard → Settings → API

### Problem: "Database error" or "Profiles table doesn't exist"
**Solution:**
1. Go to Supabase → SQL Editor
2. Run this to check:
   ```sql
   SELECT * FROM profiles;
   ```
3. If error, re-run the CREATE TABLE script from Step 5.2
4. Make sure you're in the correct project

### Problem: Build errors about Firebase
**Solution:**
1. Make sure ALL Firebase packages are removed (Step 4.1)
2. Search project for any remaining Firebase imports:
   - Press `⌘` + `⇧` + `F`
   - Search: `import Firebase`
   - Remove any remaining imports
3. Clean Build Folder: `⌘` + `⇧` + `K`
4. Rebuild: `⌘` + `B`

---

## ✅ VERIFICATION CHECKLIST

Before considering migration complete, verify:

- [ ] Supabase project created
- [ ] Credentials added to `SupabaseConfig.swift`
- [ ] Supabase package added to Xcode
- [ ] All Firebase packages removed
- [ ] `GoogleService-Info.plist` deleted
- [ ] `profiles` table created in Supabase
- [ ] Phone authentication enabled
- [ ] Twilio configured (or Supabase SMS for testing)
- [ ] App builds without errors
- [ ] Can send OTP to phone
- [ ] Can receive SMS with code
- [ ] Can verify code and log in
- [ ] User ID appears in console logs
- [ ] Can see profile in Supabase Database → Tables → profiles

---

## 🎉 SUCCESS!

If you completed all steps and all checkboxes are checked:

**🎊 Congratulations! Your app is now using Supabase!**

### What's Different Now:

✅ **No more reCAPTCHA!** - Users get SMS directly  
✅ **Better SMS delivery** - Twilio is very reliable  
✅ **PostgreSQL database** - More powerful than Firestore  
✅ **Cleaner code** - Modern async/await API  
✅ **No vendor lock-in** - Supabase is open source  

### Next Steps:

1. **Test with multiple users**
2. **Configure SMS templates** in Supabase
3. **Set up email auth** (optional) in SupabaseAuthService
4. **Add password reset** flow
5. **Monitor usage** in Supabase Dashboard

---

## 📚 Additional Resources:

- **Supabase Docs**: https://supabase.com/docs
- **Swift Client**: https://github.com/supabase/supabase-swift
- **Phone Auth Guide**: https://supabase.com/docs/guides/auth/phone-login
- **Twilio Docs**: https://www.twilio.com/docs/sms
- **Get Help**: https://supabase.com/docs/guides/getting-started

---

**Need help? Check the troubleshooting section or create an issue!**
