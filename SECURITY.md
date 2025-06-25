# Security Policy

## 🔒 Security Overview

This NixOS NAS configuration includes several security features and follows security best practices. This document outlines security measures, reporting procedures, and supported versions.

## 🛡️ Security Features

### Network Security

- **Firewall**: Enabled with local network restrictions
- **Fail2ban**: Protection against brute force attacks
- **SSH Hardening**: Secure SSH configuration with limited authentication attempts
- **Port Restrictions**: Services restricted to local network ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)

### System Security

- **User Permissions**: Non-root user with sudo access
- **Automatic Updates**: System security updates enabled
- **Service Isolation**: Services run with minimal required permissions
- **Secure Defaults**: Security-first configuration choices

### File Sharing Security

- **Samba Authentication**: User-based authentication required
- **No Guest Access**: Guest access disabled for security
- **Local Network Only**: File sharing restricted to local networks
- **Secure Protocols**: Only SMB2+ protocols enabled

## 📊 Supported Versions

| Version | Supported          | NixOS Version |
| ------- | ------------------ | ------------- |
| main    | ✅ Active support  | 25.05         |
| v1.x    | ✅ Security fixes  | 25.05         |
| < v1.0  | ❌ End of life     | Various       |

## 🚨 Reporting Security Vulnerabilities

### What to Report

Please report security vulnerabilities if you discover:

- Authentication bypasses
- Unauthorized network access
- Information disclosure
- Remote code execution
- Privilege escalation
- Denial of service vulnerabilities

### How to Report

**🚫 DO NOT** create public GitHub issues for security vulnerabilities.

Instead, please:

1. **Email**: Send details to the maintainer privately
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fixes (if any)
3. **Wait**: Allow time for investigation and patching before public disclosure

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Security Fix**: Based on severity (see below)
- **Public Disclosure**: After fix is released and users have time to update

## ⚡ Severity Levels

### Critical (Fix within 24-48 hours)

- Remote code execution
- Authentication bypass
- Full system compromise

### High (Fix within 1 week)

- Privilege escalation
- Significant information disclosure
- Network security bypass

### Medium (Fix within 2 weeks)

- Limited information disclosure
- Denial of service
- Configuration vulnerabilities

### Low (Fix in next release)

- Minor security improvements
- Hardening opportunities
- Documentation issues

## 🔧 Security Configuration

### Initial Setup Security Checklist

After deploying, complete these security steps:

- [ ] Change default password: `sudo passwd jager`
- [ ] Set Samba password: `sudo smbpasswd -a jager`
- [ ] Add SSH public keys to `~/.ssh/authorized_keys`
- [ ] Disable SSH password authentication
- [ ] Verify firewall rules: `sudo iptables -L`
- [ ] Test fail2ban: `sudo fail2ban-client status`
- [ ] Mark passwords configured: `sudo touch /etc/nixos/.passwords-configured`

### Ongoing Security Maintenance

- **Regular Updates**: Keep system updated with `nix flake update && rebuild`
- **Monitor Logs**: Check system logs regularly with `journalctl`
- **Review Access**: Monitor SSH and Samba access logs
- **Backup Configurations**: Keep secure backups of configurations
- **Security Scanning**: Run periodic security scans

### Network Security Configuration

The configuration includes these network security measures:

```nix
# Example firewall rules (from modules/samba.nix)
networking.firewall = {
  extraCommands = ''
    # Restrict Samba to local networks only
    iptables -A nixos-fw -s 192.168.0.0/16 -p tcp --dport 445 -j ACCEPT
    iptables -A nixos-fw -s 10.0.0.0/8 -p tcp --dport 445 -j ACCEPT
    iptables -A nixos-fw -s 172.16.0.0/12 -p tcp --dport 445 -j ACCEPT
  '';
};
```

## 🛠️ Security Tools

### Included Security Tools

- **fail2ban**: Intrusion prevention
- **iptables**: Firewall management
- **systemd**: Service isolation
- **SSH**: Secure remote access

### Recommended Additional Tools

Consider adding these for enhanced security:

- **ClamAV**: Antivirus scanning
- **AIDE**: File integrity monitoring
- **Logwatch**: Log analysis
- **Nmap**: Network scanning (for auditing)

## 📋 Security Audit Checklist

### System Security

- [ ] All services run with minimal privileges
- [ ] Unnecessary services are disabled
- [ ] System packages are up to date
- [ ] User accounts follow principle of least privilege
- [ ] Sudo is properly configured

### Network Security

- [ ] Firewall is enabled and properly configured
- [ ] Services are bound to appropriate interfaces
- [ ] Unused network services are disabled
- [ ] Network access is restricted to trusted networks

### Data Security

- [ ] File permissions are correctly set
- [ ] Sensitive data is encrypted at rest (if applicable)
- [ ] Backup procedures are secure
- [ ] Access logs are monitored

## 🔗 Security Resources

### NixOS Security

- [NixOS Security](https://nixos.org/manual/nixos/stable/index.html#ch-security)
- [NixOS Hardening](https://nixos.wiki/wiki/Security)

### General Security

- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Controls](https://www.cisecurity.org/controls/)

## 📞 Contact

For security-related questions or concerns:

- **Security Issues**: Private email to maintainers
- **General Questions**: Open a GitHub discussion
- **Documentation**: Contribute via pull requests

Remember: When in doubt about security, err on the side of caution and reach out for guidance.
