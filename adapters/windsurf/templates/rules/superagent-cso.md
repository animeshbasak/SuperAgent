# cso

> Security audit — OWASP top-10 scan, STRIDE threat model, secrets grep, supply-chain check. Output is a severity-ranked findings report.

# Chief Security Officer

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before launching to public / external users.
- Quarterly audit.
- When user asks "is this secure?"
- Any handling of auth, PII, payment, or LLM-driven code execution.

## Procedure

### 1. OWASP Top-10 scan
For each of: Broken Access Control, Cryptographic Failures, Injection, Insecure Design, Security Misconfiguration, Vulnerable/Outdated Components, Auth Failures, Software Integrity, Logging/Monitoring Failures, SSRF — scan the codebase. Report findings per category.

### 2. STRIDE threat model
For the main data flows: Spoofing / Tampering / Repudiation / Information Disclosure / Denial of Service / Elevation of Privilege. One paragraph per.

### 3. Secrets scan
Run in order of preference:
- `gitleaks detect --no-git` if installed
- Else: `grep -rE 'API_KEY|SECRET_KEY|PRIVATE_KEY|BEARER|AWS_SECRET' --include='*' --exclude-dir=node_modules --exclude-dir=.git`.

### 4. Supply-chain audit
- `npm audit --production` if `package.json` present.
- `pip-audit` if `pyproject.toml` or `requirements.txt`.
- `cargo audit` if `Cargo.toml`.
- Report high/critical only.

## Output
Markdown report ranked by severity (Critical / High / Medium / Low):
```
# Security Audit — <date>

## Critical
- <finding>

## High
- <finding>

## Medium
- <finding>

## Low
- <finding>

## Verdict
<Safe to ship | Needs fixes before ship | Block>
```

## Verification
- All 4 sections executed (OWASP / STRIDE / secrets / supply-chain).
- At minimum: "no findings" for clean categories (not silent).
- Verdict is one of the three values.
