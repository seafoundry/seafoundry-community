#!/bin/bash

# Script to replace hardcoded colors and spacing with theme system

echo "Replacing hardcoded colors and spacing with theme system..."

# Find all Dart files in widgets and screens directories
find lib/widgets lib/screens -name "*.dart" -type f | while read file; do
    echo "Processing: $file"
    
    # Add theme import if not present and if Colors. is used
    if grep -q "Colors\." "$file" && ! grep -q "import.*theme\.dart" "$file"; then
        # Find the last import line and add theme import after it
        sed -i '' '/^import.*\.dart.*;$/a\
import '\''package:seafoundry_app/theme/theme.dart'\'';
' "$file"
    fi
    
    # Replace common Colors with AppColors
    sed -i '' 's/Colors\.red/AppColors.error/g' "$file"
    sed -i '' 's/Colors\.green/AppColors.success/g' "$file"
    sed -i '' 's/Colors\.orange/AppColors.warning/g' "$file"
    sed -i '' 's/Colors\.blue/AppColors.primary/g' "$file"
    sed -i '' 's/Colors\.deepOrange/AppColors.mortalityEventColor/g' "$file"
    sed -i '' 's/Colors\.purple/AppColors.organizationColor/g' "$file"
    sed -i '' 's/Colors\.teal/AppColors.secondary/g' "$file"
    sed -i '' 's/Colors\.brown/AppColors.genetColor/g' "$file"
    sed -i '' 's/Colors\.grey/AppColors.textSecondary/g' "$file"
    sed -i '' 's/Colors\.gray/AppColors.textSecondary/g' "$file"
    sed -i '' 's/Colors\.white/AppColors.surface/g' "$file"
    sed -i '' 's/Colors\.black/AppColors.textPrimary/g' "$file"
    sed -i '' 's/Colors\.transparent/Colors.transparent/g' "$file"  # Keep transparent as is
    
    # Replace specific color variations
    sed -i '' 's/Colors\.red\.shade[0-9]*/AppColors.error/g' "$file"
    sed -i '' 's/Colors\.green\.shade[0-9]*/AppColors.success/g' "$file"
    sed -i '' 's/Colors\.orange\.shade[0-9]*/AppColors.warning/g' "$file"
    sed -i '' 's/Colors\.blue\.shade[0-9]*/AppColors.primary/g' "$file"
    sed -i '' 's/Colors\.deepOrange\.shade[0-9]*/AppColors.mortalityEventColor/g' "$file"
    sed -i '' 's/Colors\.purple\.shade[0-9]*/AppColors.organizationColor/g' "$file"
    sed -i '' 's/Colors\.teal\.shade[0-9]*/AppColors.secondary/g' "$file"
    sed -i '' 's/Colors\.brown\.shade[0-9]*/AppColors.genetColor/g' "$file"
    sed -i '' 's/Colors\.grey\.shade[0-9]*/AppColors.textSecondary/g' "$file"
    sed -i '' 's/Colors\.gray\.shade[0-9]*/AppColors.textSecondary/g' "$file"
    
    # Replace EdgeInsets with Spacing constants
    sed -i '' 's/EdgeInsets\.all(2)/EdgeInsets.all(Spacing.xxs)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(4)/EdgeInsets.all(Spacing.xs)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(8)/EdgeInsets.all(Spacing.sm)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(16)/EdgeInsets.all(Spacing.md)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(24)/EdgeInsets.all(Spacing.lg)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(32)/EdgeInsets.all(Spacing.xl)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(48)/EdgeInsets.all(Spacing.xxl)/g' "$file"
    sed -i '' 's/EdgeInsets\.all(64)/EdgeInsets.all(Spacing.xxxl)/g' "$file"
    
    # Replace EdgeInsets.symmetric
    sed -i '' 's/EdgeInsets\.symmetric(horizontal: 2\([^0-9]\)/EdgeInsets.symmetric(horizontal: Spacing.xxs\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(horizontal: 4\([^0-9]\)/EdgeInsets.symmetric(horizontal: Spacing.xs\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(horizontal: 8\([^0-9]\)/EdgeInsets.symmetric(horizontal: Spacing.sm\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(horizontal: 16\([^0-9]\)/EdgeInsets.symmetric(horizontal: Spacing.md\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(horizontal: 24\([^0-9]\)/EdgeInsets.symmetric(horizontal: Spacing.lg\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(horizontal: 32\([^0-9]\)/EdgeInsets.symmetric(horizontal: Spacing.xl\1/g' "$file"
    
    sed -i '' 's/EdgeInsets\.symmetric(vertical: 2\([^0-9]\)/EdgeInsets.symmetric(vertical: Spacing.xxs\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(vertical: 4\([^0-9]\)/EdgeInsets.symmetric(vertical: Spacing.xs\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(vertical: 8\([^0-9]\)/EdgeInsets.symmetric(vertical: Spacing.sm\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(vertical: 16\([^0-9]\)/EdgeInsets.symmetric(vertical: Spacing.md\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(vertical: 24\([^0-9]\)/EdgeInsets.symmetric(vertical: Spacing.lg\1/g' "$file"
    sed -i '' 's/EdgeInsets\.symmetric(vertical: 32\([^0-9]\)/EdgeInsets.symmetric(vertical: Spacing.xl\1/g' "$file"
    
    # Replace SizedBox dimensions
    sed -i '' 's/SizedBox(height: 2\([^0-9]\)/SizedBox(height: Spacing.xxs\1/g' "$file"
    sed -i '' 's/SizedBox(height: 4\([^0-9]\)/SizedBox(height: Spacing.xs\1/g' "$file"
    sed -i '' 's/SizedBox(height: 8\([^0-9]\)/SizedBox(height: Spacing.sm\1/g' "$file"
    sed -i '' 's/SizedBox(height: 16\([^0-9]\)/SizedBox(height: Spacing.md\1/g' "$file"
    sed -i '' 's/SizedBox(height: 24\([^0-9]\)/SizedBox(height: Spacing.lg\1/g' "$file"
    sed -i '' 's/SizedBox(height: 32\([^0-9]\)/SizedBox(height: Spacing.xl\1/g' "$file"
    sed -i '' 's/SizedBox(height: 48\([^0-9]\)/SizedBox(height: Spacing.xxl\1/g' "$file"
    sed -i '' 's/SizedBox(height: 64\([^0-9]\)/SizedBox(height: Spacing.xxxl\1/g' "$file"
    
    sed -i '' 's/SizedBox(width: 2\([^0-9]\)/SizedBox(width: Spacing.xxs\1/g' "$file"
    sed -i '' 's/SizedBox(width: 4\([^0-9]\)/SizedBox(width: Spacing.xs\1/g' "$file"
    sed -i '' 's/SizedBox(width: 8\([^0-9]\)/SizedBox(width: Spacing.sm\1/g' "$file"
    sed -i '' 's/SizedBox(width: 16\([^0-9]\)/SizedBox(width: Spacing.md\1/g' "$file"
    sed -i '' 's/SizedBox(width: 24\([^0-9]\)/SizedBox(width: Spacing.lg\1/g' "$file"
    sed -i '' 's/SizedBox(width: 32\([^0-9]\)/SizedBox(width: Spacing.xl\1/g' "$file"
    sed -i '' 's/SizedBox(width: 48\([^0-9]\)/SizedBox(width: Spacing.xxl\1/g' "$file"
    sed -i '' 's/SizedBox(width: 64\([^0-9]\)/SizedBox(width: Spacing.xxxl\1/g' "$file"
    
    # Replace BorderRadius.circular with Spacing constants  
    sed -i '' 's/BorderRadius\.circular(2\([^0-9]\)/BorderRadius.circular(Spacing.xxs\1/g' "$file"
    sed -i '' 's/BorderRadius\.circular(4\([^0-9]\)/BorderRadius.circular(Spacing.xs\1/g' "$file"
    sed -i '' 's/BorderRadius\.circular(8\([^0-9]\)/BorderRadius.circular(Spacing.sm\1/g' "$file"
    sed -i '' 's/BorderRadius\.circular(16\([^0-9]\)/BorderRadius.circular(Spacing.md\1/g' "$file"
    sed -i '' 's/BorderRadius\.circular(24\([^0-9]\)/BorderRadius.circular(Spacing.lg\1/g' "$file"
    sed -i '' 's/BorderRadius\.circular(32\([^0-9]\)/BorderRadius.circular(Spacing.xl\1/g' "$file"
    
done

echo "Theme replacement completed!"
echo "Next steps:"
echo "1. Run 'flutter analyze' to check for any issues"
echo "2. Fix any remaining compilation errors manually"
echo "3. Test the app to ensure everything works correctly"