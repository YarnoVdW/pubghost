# pubghost

Detect ghosts in your Flutter/Dart project:
- **Unused dependencies** in `pubspec.yaml`
- **Unused classes/widgets** in your app `lib/`
- **Unused intl keys** from `.arb` files (ignores generated l10n)

Fast, lightweight CLI you can run locally or in CI.

## Features

- **-d**: (--deps) Scans `lib/` imports to find dependencies declared in `pubspec.yaml` but never imported.
- **-c**: (--widgets) Finds classes defined in your app and reports ones never referenced anywhere else.
- **-t**: (--intl) Parses `.arb` files and reports keys not used in code via common localization access like `S.of(context).keyName`, `AppLocalizations.current.keyName`, or `context.l10n.keyName`. Generated l10n sources are ignored.

## Installation

Add as a dev dependency:

```yaml
dev_dependencies:
  pubghost: ^1.0.7
```

Then get packages:

```bash
dart pub get
```

Optionally, activate globally:

```bash
dart pub global activate pubghost
```

## Usage

Run via Dart:

```bash
dart run pubghost --deps
dart run pubghost --widgets
dart run pubghost --intl
```

Or if globally activated:

```bash
pubghost --deps
pubghost --widgets
pubghost --intl
```

### Commands

- `--deps`: Check for unused dependencies declared in `pubspec.yaml`.
> See [Configuration and Conventions](#configuration-and-conventions) to ignore specific dependencies.
- `--widgets`: Check for unused classes/widgets under your project `lib/` directory.
- `--intl`: Check for `.arb` keys not referenced in your code. Generated l10n directories are excluded.

### Output

- Success:
  - `✅ All packages are used.`
  - `✅ All classes are used.`
  - `✅ All intl keys are used.`
- Findings:
  - `⚠️  Unused packages (N):`
  - `⚠️  Unused classes (N):`
  - `⚠️  Unused intl keys (N):`

## How it works

- **Unused dependencies**: Looks for `import 'package:<dep>/...'` in your `lib/` Dart files. Any dependency in `pubspec.yaml` without a matching import is reported.
- **Unused widgets**: Lists classes defined in `lib/`, then searches combined project code (excluding tests) for references such as usage, generics, inheritance, mixins, and constructor calls.
- **Unused intl**: Reads `.arb` files, collects keys, then scans your code (excluding tests and generated l10n folders) for `.keyName` occurrences next to a localization object. Keys seen only in generated sources are not counted as “used.”

## Configuration and Conventions

- Excludes scanning of:
  - `test/`
  - `.dart_tool/`, `build/`
  - `gen_l10n/`, `l10n/generated/`
- Only scans your project’s `lib/` code for usage.
- Assumes common Flutter gen-l10n usage patterns:
  - `S.of(context).myKey`
  - `AppLocalizations.of(context).myKey`
  - `AppLocalizations.current.myKey`
  - `context.l10n.myKey`
- Supports the exclusion of specific dependencies and classes by adding a `pubghost` section in `pubspec.yaml`:
> ```yaml
> pubghost:
>   ignore_dependencies:
>     - flutter_launcher_icons
>   ignore_classes:
>     - ExactClassName           # Exact class name match
>     - ".*Model$"               # Regex pattern: classes ending in "Model"
>     - "^MyPrefix.*"            # Regex pattern: classes starting with "MyPrefix"
> ```




## Limitations

- Heuristic-based scanning may produce false positives/negatives in advanced scenarios:
  - Dynamically constructed imports/usages
  - Reflection or code generation outside the excluded folders
  - Intl keys used through non-standard access patterns

## CI

Add a simple CI job to keep your project tidy:

```bash
dart run pubghost --deps
dart run pubghost --widgets
dart run pubghost --intl
```

---

Made with 💙 from Belgium.
[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/novadev.be)


## License

MIT
