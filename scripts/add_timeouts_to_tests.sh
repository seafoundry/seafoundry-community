#!/bin/bash
# Script to add TestTimeoutHelper timeouts to test files
# Usage: ./scripts/add_timeouts_to_tests.sh

set -e

cd "$(dirname "$0")/.."

# Function to add import if missing
add_import_if_missing() {
  local file="$1"
  local import_line="$2"
  
  if ! grep -q "test_timeout_helper" "$file"; then
    # Find last import line and add after it
    if [ -f "$file" ]; then
      # Use sed to add import after last import line
      awk -v import="$import_line" '
        /^import / { 
          last_import = NR
          last_import_line = $0
        }
        END {
          if (last_import > 0) {
            print "# Added by timeout migration script"
            print last_import_line
            print import
          }
        }
      ' "$file" > /tmp/imports.txt || true
    fi
  fi
}

# Function to add timeout to test call
add_timeout_to_test() {
  local file="$1"
  local line_num="$2"
  
  # Check if timeout already exists in next 10 lines
  local has_timeout=false
  for ((i=line_num; i<line_num+10 && i<=$(wc -l < "$file"); i++)); do
    if sed -n "${i}p" "$file" | grep -q "timeout:"; then
      has_timeout=true
      break
    fi
    if sed -n "${i}p" "$file" | grep -qE "^\s*\}\);" || sed -n "${i}p" "$file" | grep -qE "^\s*\);"; then
      break
    fi
  done
  
  if [ "$has_timeout" = false ]; then
    # Find the closing }); or );
    local closing_line=$(sed -n "${line_num},\$p" "$file" | grep -nE "^\s*\}\), timeout:|^\s*\);$" | head -1 | cut -d: -f1)
    if [ -z "$closing_line" ]; then
      closing_line=$(sed -n "${line_num},\$p" "$file" | grep -nE "^\s*\}\);$" | head -1 | cut -d: -f1)
    fi
    
    if [ -n "$closing_line" ]; then
      local actual_line=$((line_num + closing_line - 1))
      # Replace }); with }, timeout: TestTimeoutHelper.defaultTimeout);
      sed -i.bak "${actual_line}s/});/, timeout: TestTimeoutHelper.defaultTimeout);/" "$file" || \
      sed -i.bak "${actual_line}s/);/, timeout: TestTimeoutHelper.defaultTimeout);/" "$file"
    fi
  fi
}

echo "Adding timeouts to test files..."
echo "This is a helper script - manual verification recommended"
echo ""
echo "For automated processing, use a Dart script with proper parsing."
echo "Manual approach: Search and replace patterns:"
echo "  }); -> }, timeout: TestTimeoutHelper.defaultTimeout);"
echo "  );  -> , timeout: TestTimeoutHelper.defaultTimeout);"
echo "  (when on test/testWidgets closing lines)"

