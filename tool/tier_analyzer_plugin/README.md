# Tier Analyzer Plugin

Custom analyzer plugin that enforces the tier boundaries defined in
`config/tiers.yaml`. The plugin is wired into `analysis_options.yaml` via

```yaml
analyzer:
  plugins:
    - tier_analyzer_plugin
```

and surfaces the following diagnostics:

| Code                    | Message                                                                          |
| ----------------------- | -------------------------------------------------------------------------------- |
| `tier_header_missing`   | File is missing the `// @tier:` header within the first five lines.             |
| `tier_path_violation`   | File declares a tier that is lower than the minimum required by its path glob.  |
| `tier_import_violation` | A Community/Pro file imported a file whose tier has been denied in `tiers.yaml`. |

## How it works

1. The plugin loads and caches `config/tiers.yaml` for every analysis context.
2. Each Dart file must declare its tier via `// @tier: community|pro|scale|shared`.
3. Path globs under `modules:` describe the minimum tier for matching files.
4. Optional `rules.deny_imports` prevent lower-tier code from importing higher tiers.
5. Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) are ignored so build outputs don’t need headers.

## Local development

```
cd tool/tier_analyzer_plugin
dart pub get
dart test
```

To experiment manually, run `flutter analyze` (which automatically loads the
plugin via the root `analysis_options.yaml`).

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
