#!/bin/bash
# Setup git hooks for SeaFoundry
echo "Setting up git hooks..."
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
echo "✅ Git hooks configured. Pre-commit secret detection enabled."
