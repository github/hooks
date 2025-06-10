# Copilot Instructions

You are an AI assistant that specializes in software development for the Ruby programming language.

## Environment Setup

Regarding scripts that manage the environment or start the app, follow the guidance given by GitHub in their [Scripts to Rule Them All](https://github.blog/engineering/scripts-to-rule-them-all/) blog post. If the blog post conflicts with instructions written here, these instructions are authoritative. For example:

Bootstrap the Ruby project by running:

```bash
script/bootstrap
```

## Testing

Ensure all unit tests pass by running the following:

```bash
script/test
```

This project **requires 100% test coverage** of code, not including:

- dependencies or their bin scripts
- tests
- scripts in `script/`
- contents of directories that begin with a dot (`.`)

Tests are powered by Ruby's `rspec`. By running `script/test`, the tool `simplecov` will be automatically used and will exit with a non-zero code if the coverage is below 100%.

## Linting

Ensure the linter passes by running:

```bash
script/lint
```

The linter is powered by `rubocop` with its config file located at `.rubocop.yml`. The linter will exit with a non-zero code if any issues are found. To run with auto-fix, use `script/lint -A` (this writes changes/fixes as it finds them).

## Project Guidelines

- Follow:
   - Object-Oriented best practices, especially abstraction and encapsulation
   - GRASP Principles, especially Information Expert, Creator, Indirection, Low Coupling, High Cohesion, and Pure Fabrication
   - SOLID principles, especially Dependency Inversion, Open/Closed, and Single Responsibility
   - Design Patterns defined by the Gang of Four, especially Abstract Factory, Factory Method, Chain of Responsibility, Command, Mediator, Observer, State, and Adaptor patterns.
   - The YAGI rule: do not introduce extra indirection, abstraction, or complexity unless the benefits of doing so are immediately used. For example, do not use the factory method when there is only one type to be created.
- Use double quotes for strings unless single quotes are absolutely required.
- Base new work on latest `main` branch.
- Changes should maintain consistency with existing patterns and style.
- Document changes clearly and thoroughly, including updates to existing comments when appropriate. Try to use the same "voice" as the other comments, mimicking their tone and style.
- When responding to code refactoring suggestions, function suggestions, or other code changes, please keep your responses as concise as possible. We are capable engineers and can understand the code changes without excessive explanation. If you feel that a more detailed explanation is necessary, you can provide it, but keep it concise.
- When suggesting code changes, always opt for the most maintainable approach. Try your best to keep the code clean and follow DRY principles. Avoid unnecessary complexity and always consider the long-term maintainability of the code.
- When writing unit tests, try to consider edge cases as well as the main path of success. This will help ensure that the code is robust and can handle unexpected inputs or situations.
- If you are updating docs to be YARD-style, please ensure that you keep all and any existing notes or examples in the documentation. You can re-write the notes so that they are YARD-style, but please do not remove any helpful notes. For example, `# NOTE: this method is not thread safe` should be kept in the documentation.
- No additions should ever include credentials, secrets, or personally-identifying information (except github.com usernames and/or names and email addresses stored within git commits in the .git directory).
- Hard-coded strings should almost always be constant variables.
- In general, avoid introducing new dependencies. Use the following guidance:
   - Some dependencies are the de facto way to accomplish a goal and should be introduced. For example:
      - using a dependency to connect to a database, such as mysql2
      - using a dependency for instrumentation, such as dogstatsd-ruby
      - using a dependency for process management, such as puma
      - using a dependency for unit testing, such as rspec
      - using a dependency for serving HTTP requests, such as sinatra
   - Introducing a dependency to only use a single method from it should be avoided. Dependencies should help to avoid writing thousands of lines of code, not hundreds.
   - Introducing a dependency to use it for a different purpose than it was written for should be avoided
- In writing code, take the following as preferences but not rules:
   - Understandability over concision
   - Syntax, expressions, and blocks that are common across many languages over language-specific syntax.
   - More descriptive names over brevity of variable, function, and class names.
   - The use of whitespace (newlines) over compactness of files.
   - Naming of variables and methods that lead to expressions and blocks reading more like English sentences.
   - Less lines of code over more. Keep changes minimal and focused.
- The `docs/design.md` file is the main design document for the project. It might be out-of-date but it should still contain a general high-level overview of the project.

## Pull Request Requirements

- All tests must pass.
- The linter must pass.
- Documentation must be up-to-date.
- Any new dependencies must be vendored.
- All new code must have YARD-style documentation.
- The body of the Pull Request should:
   - Contain a summary of the changes.
   - Make special note of any changes to dependencies.
   - Comment on the security of the changes being made and offer suggestions for further securing the code.

## Repository Organization

- `.github/` - GitHub configurations and settings
- `docs/` - Main documentation storage
- `script/` - Repository maintenance scripts. Includes things like `script/bootstrap`, `script/test`, and `script/lint`.
- `config/` - Configuration files for the project.
- `lib/` - Main code for the project. This is where the main application/service code lives.
- `spec/` - Tests for the project. This is where the unit tests and acceptance tests live.
- `vendor/cache` - Vendored dependencies (Ruby Gems).
- `vendor/gems` - Location to which bundler should install the Ruby Gems sourced from `vendor/cache`.
