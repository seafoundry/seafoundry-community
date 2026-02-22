fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight (basic)

### ios beta_internal

```sh
[bundle exec] fastlane ios beta_internal
```

Deploy to internal testers only

### ios beta_external

```sh
[bundle exec] fastlane ios beta_external
```

Deploy to external beta groups

### ios build_flutter

```sh
[bundle exec] fastlane ios build_flutter
```

Build Flutter app for iOS

### ios deploy_testflight

```sh
[bundle exec] fastlane ios deploy_testflight
```

Full TestFlight deployment pipeline

### ios dev

```sh
[bundle exec] fastlane ios dev
```

Build app for development

### ios add_tester

```sh
[bundle exec] fastlane ios add_tester
```

Add tester to beta groups

### ios remove_tester

```sh
[bundle exec] fastlane ios remove_tester
```

Remove tester from TestFlight

### ios list_testers

```sh
[bundle exec] fastlane ios list_testers
```

List all testers

### ios import_testers

```sh
[bundle exec] fastlane ios import_testers
```

Import testers from CSV

### ios export_testers

```sh
[bundle exec] fastlane ios export_testers
```

Export testers to CSV

### ios distribute_build

```sh
[bundle exec] fastlane ios distribute_build
```

Distribute existing build to groups

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
