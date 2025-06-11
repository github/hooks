# Contributing

Thank you for your interest in contributing to the Hooks gem! This document outlines how to contribute to the project, including setting up your development environment, running tests, and releasing new versions.

## Getting Started

To get your development environment set up, you simply need to run the following command:

```bash
script/bootstrap
```

> Note: This command assumes you have a Ruby version manager like `rbenv` installed.

## Running Tests

After writing some code or making changes, you will need to run the following commands to ensure everything is working correctly:

1. Run unit tests:

    ```bash
    script/test
    ```

2. Run integration tests:

    ```bash
    script/integration
    ```

3. Run acceptance tests:

    ```bash
    script/acceptance
    ```

## Linting and Formatting

This project also requires that the linter must be run and pass before any code is committed. You can run the linter with the following command (with autocorrect enabled):

```bash
script/lint -A
```

## Releasing a new version

1. Update [`lib/hooks/version.rb`](lib/hooks/version.rb) with the next version number
2. Run `bundle install` to update gem version contained in the lockfile
3. Commit your changes and open a pull request
4. When the pull request is approved and merged into `main`, the [`.github/workflows/release.yml`](.github/workflows/release.yml) workflow will automatically run to release the new version to RubyGems and GitHub Packages 🎉.
