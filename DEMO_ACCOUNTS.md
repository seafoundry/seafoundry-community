# Demo Account Credentials

## Pro Tier Demo Accounts (Empty for CSV Testing)

Each account has its own separate organization with no inventory data, perfect for CSV import testing.

**Password for all accounts:** `demo123`

| Email | Organization ID | Organization Name |
|-------|----------------|-------------------|
| pro1@provenance.app | demo_org_pro_1 | DEMO-PRO-1 |
| pro2@provenance.app | demo_org_pro_2 | DEMO-PRO-2 |
| pro3@provenance.app | demo_org_pro_3 | DEMO-PRO-3 |
| pro4@provenance.app | demo_org_pro_4 | DEMO-PRO-4 |
| pro5@provenance.app | demo_org_pro_5 | DEMO-PRO-5 |
| pro6@provenance.app | demo_org_pro_6 | DEMO-PRO-6 |
| pro7@provenance.app | demo_org_pro_7 | DEMO-PRO-7 |
| pro8@provenance.app | demo_org_pro_8 | DEMO-PRO-8 |
| pro9@provenance.app | demo_org_pro_9 | DEMO-PRO-9 |
| pro10@provenance.app | demo_org_pro_10 | DEMO-PRO-10 |

## Standard Tier Demo Accounts (With Sample Data)

| Tier | Email | Password | Organization |
|------|-------|----------|--------------|
| Community | community@provenance.app | demo123 | DEMO-COMMUNITY |
| Pro | pro@provenance.app | demo123 | DEMO-PRO |
| Scale | scale@provenance.app | demo123 | DEMO-SCALE |

## Genetics CSV Template

All pro accounts include access to the genetics CSV import with template download:

1. Navigate to **Genetics** workspace
2. Click **"Import CSV"** button
3. Click **"Download Template CSV"** to get empty template
4. Fill in genetics data
5. Upload and validate
6. Import when ready

**Template Columns:**
- provenanceId
- name
- speciesId
- organismKind
- genetTypeId
- clonalId
- aliases
- parentGameteIds
- donorGenotypeId
- archived
- archivedAt
- provenance.habitatType
- provenance.collectionDate
- provenance.notes

## Recreating Demo Accounts

To recreate all 10 pro demo accounts:
```bash
./scripts/seed-multi-pro-demos.sh
```

To recreate a single pro demo:
```bash
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
  node scripts/seed-demo.js --reset --org="demo_org_pro_1" \
  --user="pro1@provenance.app" --tier=pro \
  --name="DEMO-PRO-1" --domain="demo-pro-1" \
  --skip-inventory --skip-posts
```
