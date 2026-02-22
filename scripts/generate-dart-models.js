#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const SCHEMAS_DIR = path.join(__dirname, '..', 'schemas', 'models');
const OUTPUT_DIR = path.join(__dirname, '..', 'lib', 'models', 'generated');

/**
 * Convert JSON Schema to Dart class
 */
function schemaToDart(schema, fileName) {
  const className = fileName.charAt(0).toUpperCase() + fileName.slice(1);
  
  let dartCode = `// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from ${fileName}.schema.json

import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part '${fileName}.g.dart';

@JsonSerializable()
class ${className} extends Equatable {
`;

  // Constructor parameters
  const required = schema.required || [];
  const properties = schema.properties || {};
  
  // Add fields
  Object.entries(properties).forEach(([key, prop]) => {
    const isRequired = required.includes(key);
    const dartType = jsonTypeToDart(prop.type, prop.format, prop.enum);
    const nullable = !isRequired ? '?' : '';
    
    if (prop.description) {
      dartCode += `  /// ${prop.description}\n`;
    }
    dartCode += `  final ${dartType}${nullable} ${key};\n`;
  });

  // Constructor
  dartCode += '\n  const ' + className + '({\n';
  Object.entries(properties).forEach(([key, prop]) => {
    const isRequired = required.includes(key);
    dartCode += `    ${isRequired ? 'required ' : ''}this.${key},\n`;
  });
  dartCode += '  });\n\n';

  // JSON serialization
  dartCode += `  factory ${className}.fromJson(Map<String, dynamic> json) => _$${className}FromJson(json);\n`;
  dartCode += `  Map<String, dynamic> toJson() => _$${className}ToJson(this);\n\n`;

  // Equatable props
  dartCode += '  @override\n';
  dartCode += '  List<Object?> get props => [' + Object.keys(properties).join(', ') + '];\n';
  
  dartCode += '}\n';

  return dartCode;
}

/**
 * Convert JSON Schema type to Dart type
 */
function jsonTypeToDart(type, format, enumValues) {
  if (enumValues) {
    return 'String'; // For now, treat enums as strings
  }
  
  switch (type) {
    case 'string':
      if (format === 'date-time') return 'DateTime';
      if (format === 'email') return 'String';
      if (format === 'uri') return 'String';
      return 'String';
    case 'number':
    case 'integer':
      return 'int';
    case 'boolean':
      return 'bool';
    case 'array':
      return 'List<dynamic>'; // Would need item type for proper typing
    case 'object':
      return 'Map<String, dynamic>';
    default:
      return 'dynamic';
  }
}

async function generateDartModels() {
  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  // Get all schema files
  const schemaFiles = fs.readdirSync(SCHEMAS_DIR)
    .filter(file => file.endsWith('.schema.json'));

  console.log(`Found ${schemaFiles.length} schema files`);

  // Generate Dart classes for each schema
  for (const schemaFile of schemaFiles) {
    const schemaPath = path.join(SCHEMAS_DIR, schemaFile);
    const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    const baseName = schemaFile.replace('.schema.json', '');
    
    // Generate Dart class
    const dartCode = schemaToDart(schema, baseName);
    
    // Write Dart file
    const outputPath = path.join(OUTPUT_DIR, `${baseName}.dart`);
    fs.writeFileSync(outputPath, dartCode);
    
    console.log(`✅ Generated ${baseName}.dart`);
  }

  // Generate barrel file
  const barrelContent = schemaFiles
    .map(file => {
      const baseName = file.replace('.schema.json', '');
      return `export '${baseName}.dart';`;
    })
    .join('\n') + '\n';

  fs.writeFileSync(path.join(OUTPUT_DIR, 'generated_models.dart'), barrelContent);
  console.log('✅ Generated generated_models.dart');

  console.log('\n✨ Dart models generated successfully!');
  console.log('Run "flutter pub run build_runner build" to generate serialization code');
}

// Run the generator
generateDartModels().catch(console.error);