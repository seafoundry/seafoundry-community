#!/bin/bash

# Create 10 empty pro demo organizations for CSV import testing
# Each account gets its own separate organization with unique ID

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for i in {1..10}; do
  echo "========================================="
  echo "Creating pro${i} demo account..."
  echo "========================================="
  
  GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
    node "${SCRIPT_DIR}/seed-demo.js" \
    --reset \
    --org="demo_org_pro_${i}" \
    --user="pro${i}@provenance.app" \
    --tier=pro \
    --name="DEMO-PRO-${i}" \
    --domain="demo-pro-${i}" \
    --skip-inventory \
    --skip-posts
    
  echo ""
  echo "✅ Created pro${i}@provenance.app (password: demo123, org: demo_org_pro_${i})"
  echo ""
done

echo "========================================="
echo "✅ All 10 pro demo accounts created!"
echo "========================================="
echo ""
echo "Login credentials:"
for i in {1..10}; do
  echo "  pro${i}@provenance.app / demo123 (org: demo_org_pro_${i}, name: DEMO-PRO-${i})"
done
