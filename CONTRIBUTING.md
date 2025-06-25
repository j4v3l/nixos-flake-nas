# Contributing to NixOS NAS Configuration

Thank you for your interest in contributing to this NixOS NAS configuration! This document provides guidelines and instructions for contributing.

## 🚀 Getting Started

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- Basic understanding of NixOS and Nix language
- Git for version control

### Development Setup

1. **Fork and clone the repository:**

   ```bash
   git clone https://github.com/your-username/nixos-flake-nas.git
   cd nixos-flake-nas
   ```

2. **Validate the configuration:**

   ```bash
   nix flake check
   ```

3. **Test building the configuration:**

   ```bash
   nix build .#nixosConfigurations.beelink-mini.config.system.build.toplevel --dry-run
   ```

## 📝 Making Changes

### Code Style

- Use 2-space indentation for Nix files
- Keep line length under 100 characters
- Use descriptive variable names
- Add comments for complex logic
- Follow existing naming conventions

### Module Structure

When creating or modifying modules:

```nix
{ config, lib, pkgs, ... }:

{
  # Use lib.mkEnableOption for optional features
  options.myservice.enable = lib.mkEnableOption "My Service";
  
  config = lib.mkIf config.myservice.enable {
    # Configuration goes here
  };
}
```

### Security Considerations

- Never commit secrets or passwords
- Use proper file permissions (e.g., 600 for sensitive files)
- Restrict network access to local networks where appropriate
- Follow the principle of least privilege
- Test firewall rules carefully

## 🧪 Testing

### Local Testing

1. **Validate flake syntax:**

   ```bash
   nix flake check --show-trace
   ```

2. **Test module imports:**

   ```bash
   nix-instantiate --eval --strict -E 'let pkgs = import <nixpkgs> {}; in (import ./modules/your-module.nix { config = {}; inherit pkgs; lib = pkgs.lib; })'
   ```

3. **Build configuration:**

   ```bash
   nix build .#nixosConfigurations.beelink-mini.config.system.build.toplevel --dry-run
   ```

### Hardware Testing

If you have access to compatible hardware:

1. Test deployment with the deploy script
2. Verify all services start correctly
3. Test network connectivity and file sharing
4. Check security configurations

## 📋 Submitting Changes

### Pull Request Process

1. **Create a feature branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes and commit:**

   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

3. **Push and create a pull request:**

   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Format

Use conventional commits format:

- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation changes
- `refactor:` code refactoring
- `test:` testing improvements
- `chore:` maintenance tasks

### Pull Request Requirements

Before submitting a PR, ensure:

- [ ] Code passes `nix flake check`
- [ ] Configuration builds successfully
- [ ] Documentation is updated if needed
- [ ] Security implications are considered
- [ ] Tests are included where applicable
- [ ] Commit messages follow conventional format

## 🎯 Areas for Contribution

### High Priority

- Additional NAS services (Nextcloud, Jellyfin, etc.)
- Hardware support for other mini PCs
- Backup and monitoring solutions
- Performance optimizations
- Security enhancements

### Documentation

- Setup guides for different hardware
- Troubleshooting documentation
- Architecture diagrams
- Video tutorials

### Testing

- Automated testing improvements
- Hardware compatibility testing
- Performance benchmarking
- Security auditing

## 🔒 Security

### Reporting Security Issues

Do not open public issues for security vulnerabilities. Instead:

1. Email security concerns to the maintainers
2. Provide detailed information about the vulnerability
3. Allow time for the issue to be addressed before public disclosure

### Security Guidelines

- Never commit credentials or secrets
- Use secure defaults in configurations
- Test security configurations thoroughly
- Follow NixOS security best practices
- Keep dependencies updated

## 📚 Resources

### NixOS Documentation

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS Options](https://search.nixos.org/options)
- [Nix Packages](https://search.nixos.org/packages)

### Community

- [NixOS Discourse](https://discourse.nixos.org/)
- [NixOS Reddit](https://www.reddit.com/r/NixOS/)
- [NixOS Matrix Chat](https://matrix.to/#/#nixos:nixos.org)

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project.

## 🙏 Questions?

If you have questions about contributing:

1. Check existing issues and documentation
2. Open a discussion issue
3. Reach out to maintainers

Thank you for contributing to make this NAS configuration better!
