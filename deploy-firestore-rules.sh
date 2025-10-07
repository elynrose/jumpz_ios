#!/bin/bash

# Deploy Firestore Security Rules
# Make sure you have Firebase CLI installed and are logged in

echo "🔥 Deploying Firestore Security Rules..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Please run:"
    echo "firebase login"
    exit 1
fi

# Deploy the rules
echo "📝 Deploying rules from firestore.rules..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Firestore rules deployed successfully!"
    echo ""
    echo "📋 Rules Summary:"
    echo "• Users can only access their own data"
    echo "• Jump sessions are private to each user"
    echo "• Daily progress is user-specific"
    echo "• All other access is denied"
    echo ""
    echo "🔒 Your Firestore database is now secure!"
else
    echo "❌ Failed to deploy rules. Please check your Firebase configuration."
    exit 1
fi

