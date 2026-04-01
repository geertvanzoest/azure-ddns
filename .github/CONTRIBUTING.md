# Contributing to azure-ddns

Thanks for your interest in contributing to azure-ddns!

## Reporting bugs

Open an [issue](https://github.com/geertvanzoest/azure-ddns/issues) with:

1. What you expected
2. What happened (including full output with `VERBOSE=1`)
3. Your environment (OS, bash version, curl version)

## Contributing code

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-improvement`)
3. Make sure tests pass: `bats test/`
4. Commit with a clear description
5. Open a Pull Request

## Code guidelines

- Bash 4.x compatible
- Use `shellcheck` if available
- Add tests for new functionality (bats-core)
- Keep it simple — this is a single-file script for a Pi

## Running tests

```bash
# Locally (Linux)
bats test/

# Via Docker (macOS)
docker run --rm -it -v "$(pwd)":/app -w /app debian:bookworm-slim bash
apt-get update && apt-get install -y curl jq bats && bats test/
```

## Security issues

Do **not** report security issues via a public issue. Instead, use a [private security advisory](https://github.com/geertvanzoest/azure-ddns/security/advisories).
