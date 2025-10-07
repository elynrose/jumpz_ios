# Firestore Security Rules for Jumpz App

This document explains the Firestore security rules implemented for the Jumpz fitness app.

## 🔒 Security Overview

The rules ensure that:
- Users can only access their own data
- All operations require authentication
- Data structure is validated
- Rate limiting prevents abuse
- Unauthorized access is blocked

## 📁 Data Structure

```
users/{userId}/
├── email: string
├── displayName: string
├── totalJumps: number
├── dailyGoal: number
├── goalStreak: number
├── createdAt: timestamp
├── lastActivity: timestamp
├── goalUpdatedAt: timestamp
├── lastStreakUpdate: timestamp
├── jumpSessions/{sessionId}/
│   ├── count: number
│   └── timestamp: timestamp
└── dailyProgress/{date}/
    ├── jumps: number
    ├── date: timestamp
    └── lastUpdated: timestamp
```

## 🛡️ Rule Categories

### 1. User Document Access
- **Read/Write**: Users can only access their own user document
- **Create**: Users can create their own document on first signup
- **Validation**: User data structure is validated on create/update

### 2. Jump Sessions
- **Private**: Each user's jump sessions are private
- **Rate Limiting**: Maximum 1 session per minute to prevent spam
- **Validation**: Session data structure is validated

### 3. Daily Progress
- **Private**: Daily progress is user-specific
- **Date Validation**: Progress date must match document ID
- **Structure Validation**: Progress data structure is validated

### 4. Leaderboard Access
- **Read-Only**: Users can read other users' data for leaderboard
- **Limited Fields**: Only displayName and totalJumps are accessible
- **Public Data**: Leaderboard data is considered public

## 🚀 Deployment

### Option 1: Using Firebase CLI
```bash
# Make sure you're logged in
firebase login

# Deploy rules
firebase deploy --only firestore:rules
```

### Option 2: Using the deployment script
```bash
# Make the script executable (already done)
chmod +x deploy-firestore-rules.sh

# Run the deployment script
./deploy-firestore-rules.sh
```

### Option 3: Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Firestore Database
4. Click on "Rules" tab
5. Copy and paste the rules from `firestore.rules`
6. Click "Publish"

## 🔧 Rule Files

- **`firestore.rules`** - Complete rules with validation and rate limiting
- **`firestore-simple.rules`** - Simplified rules for easier deployment
- **`deploy-firestore-rules.sh`** - Deployment script

## ⚠️ Important Notes

1. **Test First**: Always test rules in Firebase Console before deploying
2. **Backup**: Keep a backup of your current rules
3. **Gradual Rollout**: Consider testing with a small user group first
4. **Monitor**: Watch for any access denied errors after deployment

## 🧪 Testing Rules

### Test Cases to Verify:
1. ✅ User can read/write their own data
2. ✅ User cannot access other users' data
3. ✅ Unauthenticated requests are denied
4. ✅ Invalid data structures are rejected
5. ✅ Rate limiting works for jump sessions
6. ✅ Leaderboard data is readable by all users

### Firebase Console Testing:
1. Go to Firestore Database → Rules
2. Click "Rules playground"
3. Test different scenarios with the simulator

## 🔍 Rule Breakdown

### User Authentication
```javascript
request.auth != null && request.auth.uid == userId
```
- Ensures user is authenticated
- Verifies user can only access their own data

### Data Validation
```javascript
function isValidUserData() {
  return request.resource.data.keys().hasAll(['email', 'displayName', 'totalJumps']) &&
    request.resource.data.email is string &&
    request.resource.data.displayName is string &&
    request.resource.data.totalJumps is int &&
    request.resource.data.totalJumps >= 0;
}
```
- Validates required fields exist
- Ensures correct data types
- Prevents invalid data from being stored

### Rate Limiting
```javascript
request.time > resource.data.timestamp + duration.value(60, 's')
```
- Prevents spam by limiting session creation
- Ensures minimum 60 seconds between sessions

## 🚨 Security Best Practices

1. **Principle of Least Privilege**: Users only get access to what they need
2. **Data Validation**: All data is validated before storage
3. **Rate Limiting**: Prevents abuse and spam
4. **Authentication Required**: All operations require valid authentication
5. **Private by Default**: All data is private unless explicitly made public

## 📞 Support

If you encounter issues with the rules:
1. Check Firebase Console for error messages
2. Verify your Firebase project configuration
3. Test rules in the Rules playground
4. Check the Firebase documentation for rule syntax

## 🔄 Updates

To update rules:
1. Modify the `firestore.rules` file
2. Test in Firebase Console Rules playground
3. Deploy using one of the methods above
4. Monitor for any issues

Remember: **Always test rules before deploying to production!**

