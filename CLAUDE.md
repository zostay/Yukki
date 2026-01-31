# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Install author dependencies (Dist::Zilla plugins)
dzil authordeps --missing | cpanm --notest

# Install module dependencies
dzil listdeps --missing | cpanm --notest

# Run all tests with release checks
dzil test --release --verbose

# Run tests quickly (without dzil overhead)
prove -lv

# Run a single test
prove -lv t/app.t

# Build distribution tarball
dzil build
```

## Architecture Overview

Yukki is a git-backed wiki built on PSGI/Plack using Moo for object orientation.

### Core Classes

- **Yukki** (`lib/Yukki.pm`) - Base application class; loads config, provides model factory via `$app->model('Name')`
- **Yukki::Web** (`lib/Yukki/Web.pm`) - Web application extending Yukki; handles PSGI dispatch

### Request Flow

1. `Yukki::Web->dispatch($env)` receives PSGI env
2. Creates `Yukki::Web::Context` wrapping request/response/session
3. `Yukki::Web::Router` (Path::Router-based) matches URL to controller
4. Access control checked via `$app->check_access()`
5. Controller's `fire($ctx)` method processes request
6. View renders with Template::Pure
7. `$ctx->response->finalize()` returns PSGI response

### Models (`lib/Yukki/Model/`)

Git-backed data layer. Key models:
- **Repository** - Git repository operations
- **File** - Wiki page/file operations with git history
- **User** - User authentication (YAML files in `var/db/users/`)

### Controllers (`lib/Yukki/Web/Controller/`)

Role-based (`with 'Yukki::Web::Controller'`). Each implements `fire($ctx)`. Main controllers: Page, Attachment, Login, Admin::User, Admin::Repository.

### Views (`lib/Yukki/Web/View/`)

Template::Pure-based DOM templating. Views delegate content formatting to plugins.

### Plugin System (`lib/Yukki/Web/Plugin/`)

Plugins implement formatter roles:
- `Yukki::Web::Plugin::Role::Formatter` - MIME type handlers
- `Yukki::Web::Plugin::Role::FormatHelper` - `{{helper:...}}` syntax in wiki text

Configured in `yukki.conf` under `plugins:` array.

### Configuration

YAML config file (default `etc/yukki.conf`, override with `YUKKI_CONFIG` env var). Settings validated via Moo classes in `Yukki::Settings` and `Yukki::Web::Settings`.

### Type System

`Yukki::Types` defines custom types (AccessLevel, RepositoryName, LoginName, etc.) using Type::Tiny.

## Testing

Tests use Test2::V0. Test helpers in `t/lib/Yukki/Test.pm` provide:
- `yukki_setup()` - Creates temporary test wiki
- `yukki_git_init('repo')` - Initialize test repository
- `yukki_add_user(...)` - Add test user
