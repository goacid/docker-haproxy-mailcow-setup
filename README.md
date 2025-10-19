# Mailcow Setup Script

This repository contains an automated setup script for configuring a [Mailcow](https://mailcow.email/) installation with custom HAProxy integration and enhanced security settings.

## Overview

The `setup.sh` script automates the initial configuration of Mailcow Dockerized with the following features:

- Automatic cloning of the Mailcow repository
- Custom Docker Compose override configuration
- HAProxy integration for PROXY protocol support
- Enhanced TLS/SSL security settings for Dovecot and Postfix
- Custom volume path configuration
- Interactive prompts for all configuration steps

## Prerequisites

- Linux system with bash shell
- Docker and Docker Compose installed
- Git installed
- Root or sudo access for certain operations

## Quick Start

1. Clone or download this setup directory
2. Ensure the following files are present:
   - `setup.sh`
   - `docker-compose.override.yml`
   - `haproxy.cfg`
   - `extra.conf.dovecot`
   - `extra.conf.postfix`

3. Run the setup script:
   ```bash
   bash setup.sh
   ```

4. Follow the interactive prompts

## What the Script Does

### 1. Domain Name Configuration

The script prompts for your domain name (default: `example.net`) and uses it to automatically replace placeholders throughout all configuration files.

### 2. Mailcow Repository Setup

- Checks if `../mailcow-dockerized` directory exists
- If not found, clones the official Mailcow repository from GitHub
- Ensures you have the latest version of Mailcow

### 3. Docker Compose Override

Copies and customizes `docker-compose.override.yml`:
- Replaces `example.net` with your domain name
- Configures custom network settings
- Sets up HAProxy integration
- Backs up existing files before modification

### 4. Volume Directories
Because we chosse to keep volume in the same path of mailcowdockerized in docker-compose.override.yml, we need to create the directory structure. 

Creates the necessary Docker volume directories:
- `vmail` - Email storage
- `vmail-index` - Email indexes
- `mysql` - Database
- `redis` - Cache
- `rspamd` - Spam filter
- `postfix` - Mail transfer agent
- `dovecot` - IMAP/POP3 server
- `sogo-web` - Web interface
- And more...

Sets appropriate permissions for the volumes.

### 5. Custom Data Path

Modifies `generate_config.sh` to add a custom `MAILCOW_DATA_PATH` variable, allowing you to store Docker volumes in a custom location.

### 6. Mailcow Configuration Generation

Runs the Mailcow configuration generator with:
- `MAILCOW_HOSTNAME`: Your mail server hostname (default: `mail.$DOMAIN_NAME`)
- `MAILCOW_TZ`: Timezone (default: `Europe/Paris`)
- `SKIP_CLAMD`: Whether to skip ClamAV (default: `n`)

### 7. Dovecot Configuration (IMAP/POP3)

Deploys `extra.conf` for Dovecot with:
- **PROXY protocol support**: Configures trusted networks for HAProxy PROXY protocol
- **Enhanced TLS security**:
  - Minimum TLS version: TLSv1.2
  - Modern cipher suites (ECDHE, ChaCha20-Poly1305, AES-GCM)
  - Forward secrecy enabled  

See https://docs.mailcow.email/manual-guides/Dovecot/u_e-dovecot-harden_ciphers/

Automatically replaces the trusted networks placeholder with your configured value.

### 8. Postfix Configuration (SMTP)

Appends custom TLS configuration to Postfix's `extra.cf`:
- **High-security cipher list**: Modern ECDHE and ChaCha20-Poly1305 ciphers
- **Protocol restrictions**: Disables SSLv2, SSLv3, TLSv1, TLSv1.1
- **Cipher enforcement**: High security ciphers only for both incoming and outgoing SMTP
- **Cipher list preference**: Server-side cipher preference enabled  

See https://docs.mailcow.email/manual-guides/Postfix/u_e-postfix-harden_ciphers/

Checks for existing configuration to avoid duplicates.

### 9. HAProxy Configuration

Copies and customizes `haproxy.cfg`:
- Replaces `example.net` with your domain name
- Configures backends for Mailcow services
- Sets up PROXY protocol v2 for preserving client IPs
- Backs up existing configuration before modification

## Configuration Files

### `docker-compose.override.yml`
Extends the default Mailcow Docker Compose configuration with:
- Custom network settings
- HAProxy integration
- Additional service configurations

### `haproxy.cfg`
HAProxy configuration for:
- Frontend SSL/TLS termination
- Backend connections to Mailcow services (SMTP, IMAP, POP3, HTTP)
- PROXY protocol v2 support

### `extra.conf.dovecot`
Dovecot security enhancements:
- HAProxy trusted networks configuration
- TLS 1.2+ enforcement
- Modern cipher suite selection

### `extra.conf.postfix`
Postfix security enhancements:
- TLS protocol restrictions
- High-security cipher configuration
- Mandatory encryption settings

## Environment Variables

You can customize the script behavior using environment variables:

- `MAILCOW_HOSTNAME`: Mail server hostname (default: `mail.$DOMAIN_NAME`)
- `MAILCOW_TZ`: Timezone (default: `Europe/Paris`)
- `SKIP_CLAMD`: Skip ClamAV antivirus (default: `n`)
- `HAPROXY_TRUSTED_NETWORKS`: Trusted networks for PROXY protocol (default: `127.0.0.0/8 172.22.1.0/24 fd4d:6169:6c63:6f77::/64`)

Example:
```bash
MAILCOW_HOSTNAME=mail.mydomain.com MAILCOW_TZ=America/New_York bash setup.sh
```

## Interactive Prompts

The script prompts before each major action:
- Domain name entry
- Repository cloning
- File copying
- Volume creation
- Configuration generation
- Service configuration

All prompts default to "Yes" (press Enter to accept), or type `n` to skip.

## Security Features

### TLS/SSL Hardening
- Disables insecure protocols (SSLv2, SSLv3, TLS 1.0, TLS 1.1)
- Enforces TLS 1.2+ for all services
- Uses only modern, secure cipher suites
- Enables perfect forward secrecy

### PROXY Protocol Support
- Preserves real client IP addresses through HAProxy
- Configures trusted networks to prevent IP spoofing
- Supports both IPv4 and IPv6

## Troubleshooting

### "Directory not found" errors
Ensure you run the script from the `setup` directory, with `mailcow-dockerized` as a sibling directory, or let the script clone it automatically.

### Permission errors
Some operations require elevated privileges. Run with sudo if needed:
```bash
sudo bash setup.sh
```

### Configuration conflicts
If you've already configured Mailcow manually, the script will back up existing files with timestamps before making changes.

### Domain name not replaced
Ensure you enter the correct domain name at the first prompt. The script uses this value throughout all configuration files.

## Post-Setup Steps

After the script completes successfully:

1. Navigate to the Mailcow directory:
   ```bash
   cd ../mailcow-dockerized
   ```

2. Review the generated `mailcow.conf` file

3. Start the Mailcow services:
   ```bash
   docker compose up -d
   ```

4. Access the Mailcow web interface at `https://mail.yourdomain.com`

5. Complete the initial setup wizard

## File Backups

The script automatically backs up existing files before modification:
- `docker-compose.override.yml.backup.YYYYMMDD_HHMMSS`
- `generate_config.sh.backup`
- `extra.conf.backup.YYYYMMDD_HHMMSS`
- `extra.cf.backup.YYYYMMDD_HHMMSS`
- `haproxy.cfg.backup.YYYYMMDD_HHMMSS`

## Maintenance

To update configurations:
1. Modify the source files in the `setup` directory
2. Re-run the setup script
3. Restart affected services:
   ```bash
   cd ../mailcow-dockerized
   docker compose restart
   ```

## Security Considerations

- Review all configuration files before deployment
- Ensure `HAPROXY_TRUSTED_NETWORKS` matches your network topology
- Use strong passwords for Mailcow admin and database
- Keep Mailcow and Docker updated
- Monitor logs regularly for suspicious activity

## Support

For Mailcow-specific issues, refer to the official documentation:
- [Mailcow Documentation](https://docs.mailcow.email/)
- [Mailcow GitHub](https://github.com/mailcow/mailcow-dockerized)

For script-specific issues, review the generated configuration files and logs.

## License

This setup script is provided as-is for Mailcow deployment automation. Mailcow itself is licensed under AGPL-3.0.

---

**Last Updated**: October 2025
