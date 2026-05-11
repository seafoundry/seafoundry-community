#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { compile } = require('json-schema-to-typescript');

const SCHEMAS_DIR = path.join(__dirname, '..', 'schemas', 'models');
const OUTPUT_DIR = path.join(__dirname, '..', 'functions', 'src', 'models');

async function generateTypeScriptInterfaces() {
  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  // Get all schema files
  const schemaFiles = fs.readdirSync(SCHEMAS_DIR)
    .filter(file => file.endsWith('.schema.json'));

  console.log(`Found ${schemaFiles.length} schema files`);

  // Generate TypeScript interfaces for each schema
  for (const schemaFile of schemaFiles) {
    const schemaPath = path.join(SCHEMAS_DIR, schemaFile);
    const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    
    // Generate TypeScript interface
    const ts = await compile(schema, schema.title, {
      bannerComment: `/* tslint:disable */
/**
 * This file was automatically generated from JSON Schema.
 * DO NOT MODIFY IT BY HAND. Instead, modify the source JSON Schema file,
 * and run 'npm run generate-models' to regenerate this file.
 */`,
      style: {
        printWidth: 120,
        singleQuote: true,
      }
    });

    // Write TypeScript file
    const outputFileName = schemaFile.replace('.schema.json', '.ts');
    const outputPath = path.join(OUTPUT_DIR, outputFileName);
    fs.writeFileSync(outputPath, ts);
    
    console.log(`✅ Generated ${outputFileName}`);
  }

  // Generate index file
  const indexContent = schemaFiles
    .map(file => {
      const baseName = file.replace('.schema.json', '');
      const typeName = baseName.charAt(0).toUpperCase() + baseName.slice(1);
      return `export * from './${baseName}';`;
    })
    .join('\n') + '\n';

  fs.writeFileSync(path.join(OUTPUT_DIR, 'index.ts'), indexContent);
  console.log('✅ Generated index.ts');

  console.log('\n✨ TypeScript interfaces generated successfully!');
}

// Run the generator
generateTypeScriptInterfaces().catch(console.error);