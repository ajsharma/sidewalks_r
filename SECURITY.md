# Security Policy

## API Key Management

This project uses sensitive API keys for AI services (OpenAI, Anthropic). Never commit real API keys to version control.

### ✅ Safe Practices

**Use `.env.local` for local development:**
```bash
# .env.local (gitignored)
AI_OPENAI_API_KEY=sk-proj-your-real-key-here
AI_ANTHROPIC_API_KEY=sk-ant-your-real-key-here
```

**Use Rails credentials for production:**
```bash
EDITOR=vim bin/rails credentials:edit --environment production
```

**Use environment variables on hosting platforms:**
```bash
# Render.com, Heroku, etc.
AI_OPENAI_API_KEY=sk-proj-your-real-key-here
```

### ❌ Unsafe Practices

- ❌ Never commit `.env.local` to git
- ❌ Never hardcode keys in `config/ai.yml`
- ❌ Never share keys in pull requests or issues
- ❌ Never commit keys in code comments

## Secret Scanning

We use **gitleaks** to scan for leaked secrets in the codebase.

### Install Gitleaks

```bash
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz
tar -xzf gitleaks_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
```

### Scan Your Changes

```bash
# Scan all uncommitted changes
gitleaks detect --verbose --no-git

# Scan git history
gitleaks detect --verbose

# Run full development pipeline (includes gitleaks)
bin/go
```

### Pre-Commit Hook (Recommended)

Automatically scan for secrets before every commit:

```bash
# Install gitleaks pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run gitleaks before committing
if ! gitleaks protect --verbose --staged; then
  echo "❌ Gitleaks found secrets in staged files!"
  echo "Fix the issues above before committing."
  exit 1
fi
EOF

chmod +x .git/hooks/pre-commit
```

## What to Do If You Leak a Key

If you accidentally commit an API key:

1. **Immediately revoke the key** in the provider's dashboard:
   - OpenAI: https://platform.openai.com/api-keys
   - Anthropic: https://console.anthropic.com/

2. **Generate a new key** and update your local environment

3. **Remove the key from git history** using BFG Repo-Cleaner or `git filter-branch`:
   ```bash
   # Using BFG (recommended)
   brew install bfg
   bfg --replace-text secrets.txt
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

4. **Notify the team** if this is a shared repository

## Configuration Priority

Environment variables have the highest priority:

1. **ENV variables** (highest priority) - `.env.local`, shell environment
2. **Rails credentials** (encrypted) - `bin/rails credentials:edit`
3. **YAML config** (lowest priority) - `config/ai.yml`

## Reporting Security Issues

If you discover a security vulnerability, please email security@yourdomain.com instead of opening a public issue.

## Automated Security Checks

Our `bin/go` pipeline includes:

- ✅ **Gitleaks** - Secret scanning
- ✅ **Brakeman** - Rails security vulnerabilities
- ✅ **bundler-audit** - Ruby gem vulnerabilities
- ✅ **RuboCop** - Code security patterns

Run before every commit:
```bash
bin/go
```
