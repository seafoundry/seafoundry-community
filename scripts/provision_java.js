#!/usr/bin/env node

/**
 * Ensures a Java 17+ runtime is installed so the Firebase emulator can launch.
 * Runs automatically after `npm install` via the package.json `postinstall` hook.
 */

const { execSync, spawnSync } = require('child_process');
const os = require('os');

const MIN_VERSION = 17;

const shouldSkip =
    process.env.SEAFOUNDRY_SKIP_JAVA_PROVISION === '1' ||
    process.env.SEAFOUNDRY_SKIP_JAVA_PROVISION === 'true';

if (shouldSkip) {
    console.log('⚠️  Skipping Java provision (SEAFOUNDRY_SKIP_JAVA_PROVISION set).');
    process.exit(0);
}

function commandExists(cmd) {
    const whichCmd = process.platform === 'win32' ? 'where' : 'which';
    const result = spawnSync(whichCmd, [cmd], { stdio: 'ignore' });
    return result.status === 0;
}

function parseJavaMajor(versionString) {
    if (!versionString) {
        return null;
    }

    const parts = versionString.split('.');
    let major = parseInt(parts[0], 10);
    if (Number.isNaN(major)) {
        return null;
    }

    // Legacy Java versions report "1.x.y", so take the second part.
    if (major === 1 && parts.length > 1) {
        major = parseInt(parts[1], 10);
    }

    return Number.isNaN(major) ? null : major;
}

function getJavaVersion() {
    if (!commandExists('java')) {
        return null;
    }

    try {
        const output = execSync('java -version 2>&1', {
            encoding: 'utf-8',
            stdio: 'pipe',
            shell: true
        });
        const match = output.match(/version "(.*?)"/);
        if (!match) {
            return null;
        }
        const raw = match[1];
        return {
            raw,
            major: parseJavaMajor(raw)
        };
    } catch (error) {
        return null;
    }
}

function runCommand(command) {
    console.log(`$ ${command}`);
    execSync(command, { stdio: 'inherit', shell: true });
}

function installJava() {
    const platform = process.platform;

    if (platform === 'darwin') {
        if (!commandExists('brew')) {
            console.error(
                '❌ Homebrew is required to auto-install Temurin 17 on macOS.\n' +
                    'Install Homebrew from https://brew.sh/ or set SEAFOUNDRY_SKIP_JAVA_PROVISION=1 ' +
                    'after installing Java manually.'
            );
            process.exit(1);
        }

        runCommand('brew install --cask temurin@17');
        return;
    }

    if (platform === 'linux') {
        if (commandExists('apt-get')) {
            runCommand('sudo apt-get update');
            runCommand('sudo apt-get install -y openjdk-17-jdk');
            return;
        }

        if (commandExists('dnf')) {
            runCommand('sudo dnf install -y java-17-openjdk');
            return;
        }

        if (commandExists('yum')) {
            runCommand('sudo yum install -y java-17-openjdk');
            return;
        }

        console.error(
            '❌ Could not find a supported package manager (apt/dnf/yum) to install OpenJDK 17.\n' +
                'Install Java manually and re-run `npm install`.'
        );
        process.exit(1);
    }

    console.error(
        `❌ Automatic Java installation is not supported on ${os.platform()}.\n` +
            'Install Temurin/OpenJDK 17+, set JAVA_HOME if needed, and re-run `npm install`.'
    );
    process.exit(1);
}

function ensureJava() {
    console.log('🔍 Ensuring Java 17+ is installed for the Firebase emulator...');
    const current = getJavaVersion();
    if (current && current.major !== null && current.major >= MIN_VERSION) {
        console.log(`✅ Java ${current.raw} detected – nothing to do.`);
        return;
    }

    if (current) {
        console.log(
            `⚠️  Found Java ${current.raw}, but version ${MIN_VERSION}+ is required. Installing...`
        );
    } else {
        console.log('⚠️  Java runtime not detected. Installing Temurin/OpenJDK 17...');
    }

    installJava();

    const updated = getJavaVersion();
    if (!updated || updated.major === null || updated.major < MIN_VERSION) {
        console.error(
            '❌ Java installation did not succeed. Please install Temurin/OpenJDK 17 manually.'
        );
        process.exit(1);
    }

    console.log(`✅ Java ${updated.raw} installed and ready for firebase emulators:start.`);
}

ensureJava();
