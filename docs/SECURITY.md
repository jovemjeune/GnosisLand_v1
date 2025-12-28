# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| Mainnet | :white_check_mark: |
| Testnet | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please **DO NOT** open a public issue. Instead, please report it via one of the following methods:

1. **Email**: [security@gnosisland.io] (if available)
2. **GitHub Security Advisory**: Use GitHub's private vulnerability reporting feature
3. **Direct Contact**: Contact the project maintainers directly

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and work with you to resolve the issue before public disclosure.

## Security Best Practices

### For Developers

1. **Always use the latest dependencies**: Run `forge update` regularly
2. **Run security checks**: Use `forge audit` before deployment
3. **Review code changes**: All changes should be reviewed by at least one other developer
4. **Test thoroughly**: Run the full test suite before merging
5. **Use formal verification**: For critical functions, consider formal verification

### For Users

1. **Verify contract addresses**: Always verify contract addresses on block explorers
2. **Check audit reports**: Review security audit reports before interacting
3. **Start small**: Test with small amounts first
4. **Monitor transactions**: Keep track of your transactions
5. **Use hardware wallets**: For large amounts, use hardware wallets

## Dependency Security

This project uses the following security tools:

- **Forge Audit**: Checks for known vulnerabilities in dependencies
- **GitHub Actions**: Automated security scanning in CI/CD
- **Dependabot**: Automated dependency updates (for GitHub Actions)

### Running Security Checks

```bash
# Check for vulnerabilities
forge audit

# Run dependency check script
./script/check-dependencies.sh

# Check for outdated dependencies
forge update --check
```

## Known Security Considerations

### Smart Contract Risks

1. **Upgradeable Contracts**: All main contracts use UUPS upgradeable pattern. Only the owner can upgrade.
2. **Reentrancy**: Protected with `ReentrancyGuard` in critical functions.
3. **Access Control**: Uses OpenZeppelin's `Ownable` for access control.
4. **DeFi Integration**: Integrates with Aave and Morpho - inherits their security risks.

### External Dependencies

- **OpenZeppelin Contracts**: Battle-tested, audited library
- **Aave v3**: Audited DeFi protocol
- **Morpho Blue**: Audited DeFi protocol

## Security Audit Status

- [ ] Initial security audit (planned)
- [ ] Formal verification (planned)
- [ ] Bug bounty program (planned)

## Disclosure Policy

We follow a **coordinated disclosure** policy:

1. Reporter notifies us privately
2. We confirm and investigate (within 48 hours)
3. We develop and test a fix
4. We deploy the fix
5. We publicly disclose (with credit to reporter)

## Security Updates

Security updates will be:
- Tagged with `[SECURITY]` in commit messages
- Documented in CHANGELOG.md
- Announced via project channels

## Contact

For security concerns, please contact: [Add contact information]

---

**Last Updated**: 2025



