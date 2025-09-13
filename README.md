UNDER DEVELOPMENT & EXPERIMENTAL - USE AT YOUR OWN RISK

# meld
Crystal Lang Package Manager — a modern, user-friendly package manager for Crystal projects.

## Features
- Simple commands for common package tasks (init, add, install, update, search, exec, binstubs).
- GitHub integration with common shard repo inference for quick adds.
- Development dependencies via --dev kept separate from runtime dependencies.
- Built-in shard search helper for quick discovery.
- Project initialization with a sensible shard.yml scaffold.
- Command execution passthrough within project context.

## Installation

### From Source
```bash
git clone https://github.com/cmittal790/meld.git
cd meld
shards install
crystal build src/meld.cr -o bin/meld
```

### Add to PATH
```bash
# Add the bin directory to your PATH (temporary for this shell):
export PATH=$PATH:/path/to/meld/bin
# Create a symlink into a directory already in PATH
# User-level (no sudo), common on Linux:
mkdir -p ~/.local/bin
ln -sf "$PWD/bin/meld" "$HOME/.local/bin/meld"

# Ensure ~/.local/bin is in PATH (persist for bash)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

# For zsh users
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# Verify
which meld && meld --version
```

## Usage

### Project Initialization
Start a new Crystal project with a properly configured shard.yml.

```bash
meld init
```

This creates a shard.yml file with:
- Project metadata template.
- Crystal version requirement.
- License and author fields.
- Main executable target.

### Adding Dependencies

Current syntax (no positional version; flags only):
- add <shard> [-v <version> | -b <branch> | -t <tag> | -c <commit>] [--dev].

Examples:
- Add latest (unpinned):
```bash
meld add kemal
```

- Add with version selector:
```bash
meld add kemal -v "~> 1.0.0"
```

- Add as development dependency:
```bash
meld add spec --dev
meld add ameba -v "~> 1.4.0" --dev
```

- Add from specific GitHub repository:
```bash
meld add my_shard -v "github:username/repository"
```

- Add from Git URL:
```bash
meld add my_shard -v "git:https://github.com/username/repo.git"
```

Notes:
- If no selector flag (-v/-b/-t/-c) is given, the dependency is added unpinned poiting to git repo head (no version/branch/tag/commit line).
- Only meld help <command> shows help; subcommands don’t treat “help” specially.

### Dependency Management

- Install all dependencies:
```bash
meld install
```

- Update all dependencies:
```bash
meld update
```

- Update a specific dependency:
```bash
meld update kemal
```

### Searching for Shards

- Search by keyword:
```bash
meld search "web framework"
meld search database
meld search testing
```

### Command Execution

- Run tests:
```bash
meld exec "crystal spec"
```

- Build project:
```bash
meld exec "crystal build src/my_project.cr"
```

- Run application:
```bash
meld exec "crystal run src/my_project.cr"
```

- Run code analysis:
```bash
meld exec "ameba"
```

### Binstubs

- Generate executable wrappers:
```bash
meld binstubs kemal
```

## Common Workflows

### Web Application Setup
```bash
# Initialize project
meld init

# Add web framework and dependencies
meld add kemal
meld add pg
meld add jwt

# Add development tools
meld add spec --dev
meld add ameba -v "~> 1.6.4" --dev
meld add webmock --dev

# Install everything
meld install
```

### Database Project Setup
```bash
# Initialize project
meld init

# Add ORM and database driver
meld add jennifer
meld add pg

# Add development dependencies
meld add spec --dev
meld install
```

### Testing Workflow
```bash
# Run tests
meld exec "crystal spec"

# Run static analysis
meld exec "ameba"

# Run specific test file
meld exec "crystal spec spec/models/user_spec.cr"
```

## Supported Shards

Built-in hints for popular Crystal shards:
- Web: kemal, lucky, amber, marten.
- Database: pg, mysql, sqlite3, redis.
- ORMs: jennifer, clear, granite.
- Dev tools: spec, ameba, webmock.
- Utilities: crest, jwt, colorize, hardware.

## Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| init | Initialize new project | meld init |
| add <shard> [-v <version> | -b <branch> | -t <tag> | -c <commit>] [--dev] | meld add kemal -v "~> 1.0.0" |
| search <query> | Search for shards | meld search "web framework" |
| install | Install dependencies | meld install |
| update [shard] | Update dependencies | meld update kemal |
| exec <command> | Execute command | meld exec "crystal spec" |
| binstubs <shard> | Generate binstubs | meld binstubs kemal |
| help [command] | Show help | meld help add |


## Development

### Prerequisites
- Crystal >= 1.17.1
- Shards package manager

### Setup
```bash
# Clone the repository
git clone https://github.com/cmittal790/meld.git
cd meld

# Install dependencies
shards install

# Build the project
crystal build src/meld.cr -o bin/meld

# Run tests
crystal spec
```

### Project Structure
```
src/
├── meld.cr          # Main entry point
├── meld/
│   ├── cli.cr       # Command-line interface
│   └── project.cr   # Project management logic
spec/                # Test files
shard.yml           # Project dependencies
```

### Running Tests
```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/meld/cli_spec.cr

# Run with coverage
crystal spec --coverage
```

## Contributing

1. Fork it (<https://github.com/cmittal790/meld/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Contribution Guidelines

- Write tests for new features
- Follow Crystal coding conventions
- Update documentation for new commands
- Add new shards to the local database when appropriate
- Ensure backwards compatibility

## License

This project is licensed under the AGPL-3 License. See LICENSE file for details.

## Contributors

- [Chetan Mittal](https://github.com/cmittal790) - creator and maintainer

## Roadmap

- [ ] Meld install script
- [ ] Global package install e.g. ```meld install -g morten```
- [ ] Remove packages (prunes from ```lib``` folder too) e.g. ```meld remove kemal```
- [ ] Meld self updater e.g. ```meld self update```
- [ ] Advanced search filters
- [ ] Configuration file support
- [ ] Package registry and integration
- [ ] Dependency resolution improvements

![meld example working screenshot](image.png)