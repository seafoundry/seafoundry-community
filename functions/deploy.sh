#!/bin/bash

# Deploy Firebase Functions
echo "Building and deploying Firebase Functions..."

# Build the functions
npm run build

# Deploy to Firebase
firebase deploy --only functions

echo "Deployment complete!" 