#!/bin/bash
# Local setup script for mailcow-dockerized
#
# Usage:
#   ./local_setup.sh [MAILCOW_HOSTNAME] [MAILCOW_TZ] [SKIP_CLAMD]
#
# Examples:
#   ./local_setup.sh mail.example.net Europe/Paris n
#   MAILCOW_HOSTNAME=mail.example.net ./local_setup.sh
#

set -e  # Stop on error

MAILCOW_DIR="../mailcow-dockerized"
MAILCOW_REPO="https://github.com/mailcow/mailcow-dockerized.git"
OVERRIDE_SOURCE="./docker-compose.override.yml"
OVERRIDE_TARGET="$MAILCOW_DIR/docker-compose.override.yml"

# Ask for the domain name to use in HAProxy configuration
read -p "Enter the domain name for HAProxy configuration (default: example.net): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-example.net}

# Get parameters from arguments or environment variables
MAILCOW_HOSTNAME="${1:-${MAILCOW_HOSTNAME:-mail.$DOMAIN_NAME}}"
MAILCOW_TZ="${2:-${MAILCOW_TZ:-Europe/Paris}}"
SKIP_CLAMD="${3:-${SKIP_CLAMD:-n}}"
AUTO_GENERATE="${AUTO_GENERATE:-y}"

# HAProxy trusted networks for PROXY protocol
# Format: "network1 network2 network3" (space-separated)
HAPROXY_TRUSTED_NETWORKS="${HAPROXY_TRUSTED_NETWORKS:-127.0.0.0/8 172.22.1.0/24 fd4d:6169:6c63:6f77::/64}"

echo "=== Configuring mailcow-dockerized ==="
echo ""

# Check and clone mailcow-dockerized directory if necessary
if [ ! -d "$MAILCOW_DIR" ]; then
    echo "✗ Directory $MAILCOW_DIR not found"
    echo "📥 Cloning mailcow-dockerized repository..."
    
    # Go up one directory to clone
    PARENT_DIR=".."
    cd "$PARENT_DIR"
    
    if git clone "$MAILCOW_REPO" mailcow-dockerized; then
        echo "✓ Repository cloned successfully"
        cd - > /dev/null  # Return to setup directory
    else
        echo "✗ Error cloning repository"
        echo "⚠️  Script will continue but some steps may fail"
    fi
else
    echo "✓ Directory $MAILCOW_DIR found"
fi

echo ""
echo "=== Copying docker-compose.override.yml ==="

# Ask for confirmation
read -p "Do you want to copy/replace the docker-compose.override.yml file? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ File copy skipped"
else
    # Check if source file exists
    if [ ! -f "$OVERRIDE_SOURCE" ]; then
        echo "✗ Source file $OVERRIDE_SOURCE not found in setup directory"
        echo "⚠️  Skipping docker-compose.override.yml configuration"
    else
        # Backup existing file if it exists
        if [ -f "$OVERRIDE_TARGET" ]; then
            echo "  Backing up existing file..."
            mv "$OVERRIDE_TARGET" "$OVERRIDE_TARGET.backup.$(date +%Y%m%d_%H%M%S)"
        fi

        # Copy the file and replace example.net with DOMAIN_NAME
        echo "  Copying docker-compose.override.yml to $OVERRIDE_TARGET..."
        sed "s/example\.net/$DOMAIN_NAME/g" "$OVERRIDE_SOURCE" > "$OVERRIDE_TARGET"
        
        if [ $? -eq 0 ]; then
            echo "✓ File copied successfully: $OVERRIDE_TARGET"
            echo "✓ Domain name updated to $DOMAIN_NAME in docker-compose.override.yml"
        else
            echo "✗ Error copying file"
            echo "⚠️  Continuing despite error..."
        fi
    fi
fi

echo ""
echo "=== Creating volume directories ==="

read -p "Do you want to create the volume directories? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ Directory creation skipped"
else
    MAILCOW_VOLUME_PATH="$(realpath $MAILCOW_DIR)/volumes"
    echo "Volume path: $MAILCOW_VOLUME_PATH"

    mkdir -p "$MAILCOW_VOLUME_PATH"/{vmail,vmail-index,mysql,mysql-socket,redis,rspamd,postfix,postfix-tlspol,crypt,sogo-web,sogo-userdata-backup,clamd-db}

    echo "Setting permissions..."
    chown "$(id -u):$(id -g)" "$MAILCOW_VOLUME_PATH"

    echo "✓ Structure created:"
    ls -la "$MAILCOW_VOLUME_PATH"
fi

echo ""
echo "=== Modifying generate_config.sh ==="

# Define variables before prompt so they're always available
GENERATE_CONFIG="$MAILCOW_DIR/generate_config.sh"
MAILCOW_VOLUME_PATH="./volumes"

read -p "Do you want to modify generate_config.sh to add MAILCOW_VOLUME_PATH? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ generate_config.sh modification skipped"
else
    # Check if generate_config.sh exists
    if [ ! -f "$GENERATE_CONFIG" ]; then
        echo "✗ generate_config.sh not found in $MAILCOW_DIR"
    else
        # Create a backup
        cp "$GENERATE_CONFIG" "$GENERATE_CONFIG.backup"
        echo "✓ Backup created: generate_config.sh.backup"

        # Check if MAILCOW_VOLUME_PATH is already present
        if grep -q "^MAILCOW_VOLUME_PATH=" "$GENERATE_CONFIG"; then
            echo "⚠️  MAILCOW_VOLUME_PATH already present in generate_config.sh"
        else
            # Add MAILCOW_VOLUME_PATH right after MAILCOW_HOSTNAME=
            sed -i "/^MAILCOW_HOSTNAME=\${MAILCOW_HOSTNAME}/a\\
\\
# ------------------------------\\
# Custom data path for volumes\\
# ------------------------------\\
# Path where all Docker volumes will be stored\\
MAILCOW_VOLUME_PATH=$MAILCOW_VOLUME_PATH" "$GENERATE_CONFIG"
            
            echo "✓ MAILCOW_VOLUME_PATH added to generate_config.sh"
        fi
    fi
fi

echo ""
echo "=== Generating mailcow.conf ==="

# Configuration variables for generate_config.sh
echo "Configuration to use:"
echo "  MAILCOW_HOSTNAME: $MAILCOW_HOSTNAME"
echo "  MAILCOW_TZ: $MAILCOW_TZ"
echo "  SKIP_CLAMD: $SKIP_CLAMD"
echo ""

read -p "Do you want to run generate_config.sh to generate mailcow.conf? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ mailcow.conf generation skipped"
    CONF_GENERATED=false
else
    echo "Generating mailcow.conf..."
    
    # Export variables for generate_config.sh
    export MAILCOW_HOSTNAME
    export MAILCOW_TZ
    export SKIP_CLAMD
    
    # Run generate_config.sh in dev mode (no branch checkout)
    cd "$MAILCOW_DIR"
    if ./generate_config.sh --dev; then
        echo "✓ mailcow.conf generated successfully"
        CONF_GENERATED=true
    else
        echo "✗ Error generating mailcow.conf"
        echo "⚠️  Continuing despite error..."
        CONF_GENERATED=false
    fi
    cd - > /dev/null
fi

echo ""
echo "=== Dovecot Configuration (extra.conf) ==="

read -p "Do you want to copy Dovecot's extra.conf file? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ Dovecot extra.conf configuration skipped"
else
    DOVECOT_EXTRA_CONF="$MAILCOW_DIR/data/conf/dovecot/extra.conf"
    DOVECOT_EXTRA_SOURCE="./extra.conf.dovecot"

    # Create Dovecot configuration directory if necessary
    mkdir -p "$(dirname "$DOVECOT_EXTRA_CONF")"

    # Check if source file exists
    if [ ! -f "$DOVECOT_EXTRA_SOURCE" ]; then
        echo "✗ Source file extra.conf.dovecot not found in setup directory"
        echo "⚠️  Skipping Dovecot configuration"
    else
        # Backup existing file if present
        if [ -f "$DOVECOT_EXTRA_CONF" ]; then
            echo "  Backing up existing extra.conf..."
            mv "$DOVECOT_EXTRA_CONF" "$DOVECOT_EXTRA_CONF.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Copy the file and replace HAPROXY_TRUSTED_NETWORKS placeholder
        echo "  Copying extra.conf.dovecot to $DOVECOT_EXTRA_CONF..."
        sed "s|127.0.0.0/8 172.22.1.0/24 fd4d:6169:6c63:6f77::/64|$HAPROXY_TRUSTED_NETWORKS|g" "$DOVECOT_EXTRA_SOURCE" > "$DOVECOT_EXTRA_CONF"
        echo "✓ Dovecot extra.conf file copied successfully"
    fi

    echo "Dovecot configuration:"
    echo "  File: $DOVECOT_EXTRA_CONF"
    echo "  Trusted networks: $HAPROXY_TRUSTED_NETWORKS"
fi

echo ""
echo "=== Postfix Configuration (extra.cf) ==="

read -p "Do you want to append custom configuration to Postfix's extra.cf file? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ Postfix extra.cf configuration skipped"
else
    POSTFIX_EXTRA_CF="$MAILCOW_DIR/data/conf/postfix/extra.cf"
    POSTFIX_EXTRA_SOURCE="./extra.conf.postfix"
    
    # Create Postfix configuration directory if necessary
    mkdir -p "$(dirname "$POSTFIX_EXTRA_CF")"
    
    # Check if source file exists
    if [ ! -f "$POSTFIX_EXTRA_SOURCE" ]; then
        echo "✗ Source file extra.conf.postfix not found in setup directory"
        echo "⚠️  Skipping Postfix configuration"
    else
        # Check if extra.cf exists and if our custom config is already present
        if [ -f "$POSTFIX_EXTRA_CF" ] && grep -q "^tls_high_cipherlist" "$POSTFIX_EXTRA_CF"; then
            echo "⊙ Custom TLS configuration already present in extra.cf, keeping existing"
        else
            # Backup existing file if present
            if [ -f "$POSTFIX_EXTRA_CF" ]; then
                echo "  Backing up existing extra.cf..."
                cp "$POSTFIX_EXTRA_CF" "$POSTFIX_EXTRA_CF.backup.$(date +%Y%m%d_%H%M%S)"
                echo "  Appending custom configuration to extra.cf..."
                cat "$POSTFIX_EXTRA_SOURCE" >> "$POSTFIX_EXTRA_CF"
            else
                echo "  Creating extra.cf with custom configuration..."
                cp "$POSTFIX_EXTRA_SOURCE" "$POSTFIX_EXTRA_CF"
            fi
            echo "✓ Postfix extra.cf file updated successfully"
        fi
    fi
    
    echo "Postfix configuration:"
    echo "  File: $POSTFIX_EXTRA_CF"
fi
echo ""

echo ""
echo "=== PHP-FPM OPcache Configuration ==="

read -p "Do you want to copy the OPcache configuration file? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ OPcache configuration skipped"
else
    OPCACHE_CONF_DIR="$MAILCOW_DIR/data/conf/phpfpm/php-conf.d"
    OPCACHE_SOURCE="./opcache-recommended.ini"
    OPCACHE_TARGET="$OPCACHE_CONF_DIR/opcache-recommended.ini"
    
    # Create PHP-FPM configuration directory if necessary
    if [ ! -d "$OPCACHE_CONF_DIR" ]; then
        echo "  Creating PHP-FPM configuration directory..."
        mkdir -p "$OPCACHE_CONF_DIR"
        echo "✓ Directory created: $OPCACHE_CONF_DIR"
    else
        echo "✓ PHP-FPM configuration directory already exists"
    fi
    
    # Check if source file exists
    if [ ! -f "$OPCACHE_SOURCE" ]; then
        echo "✗ Source file opcache-recommended.ini not found in setup directory"
        echo "⚠️  Skipping OPcache configuration"
    else
        # Backup existing file if present
        if [ -f "$OPCACHE_TARGET" ]; then
            echo "  Backing up existing opcache-recommended.ini..."
            mv "$OPCACHE_TARGET" "$OPCACHE_TARGET.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        echo "  Copying opcache-recommended.ini to $OPCACHE_TARGET..."
        cp "$OPCACHE_SOURCE" "$OPCACHE_TARGET"
        
        if [ $? -eq 0 ]; then
            echo "✓ OPcache configuration file copied successfully"
        else
            echo "✗ Error copying OPcache configuration"
            echo "⚠️  Continuing despite error..."
        fi
    fi
    
    echo "OPcache configuration:"
    echo "  File: $OPCACHE_TARGET"
fi

echo ""
echo "=== Configuration HAProxy ==="


read -p "Do you want to copy the HAProxy configuration file? [Y/n] " -r response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "⊙ HAProxy configuration setup skipped"
else
    HAPROXY_CONF_DIR="$MAILCOW_DIR/data/conf/haproxy"
    HAPROXY_CFG_SOURCE="$(realpath ./haproxy.cfg)"
    HAPROXY_CFG_TARGET="$HAPROXY_CONF_DIR/haproxy.cfg"

    # Create the HAProxy configuration directory if it doesn't exist
    if [ ! -d "$HAPROXY_CONF_DIR" ]; then
        echo "  Creating HAProxy configuration directory..."
        mkdir -p "$HAPROXY_CONF_DIR"
        echo "✓ Directory created: $HAPROXY_CONF_DIR"
    else
        echo "✓ HAProxy configuration directory already exists"
    fi

    # Check if haproxy.cfg source file exists
    if [ ! -f "$HAPROXY_CFG_SOURCE" ]; then
        echo "✗ Source file haproxy.cfg not found in setup directory"
        echo "⚠️  Skipping haproxy.cfg configuration"
    else
        # Backup existing file if it exists
        if [ -f "$HAPROXY_CFG_TARGET" ]; then
            echo "  Backing up existing file..."
            mv "$HAPROXY_CFG_TARGET" "$HAPROXY_CFG_TARGET.backup.$(date +%Y%m%d_%H%M%S)"
        fi

        # Copy the file and replace example.net with DOMAIN_NAME
        echo "  Copying haproxy.cfg to $HAPROXY_CFG_TARGET..."
        sed "s/example\.net/$DOMAIN_NAME/g" "$HAPROXY_CFG_SOURCE" > "$HAPROXY_CFG_TARGET"

        if [ $? -eq 0 ]; then
            echo "✓ File copied successfully: $HAPROXY_CFG_TARGET"
            echo "✓ Domain name updated to $DOMAIN_NAME in haproxy.cfg"
        else
            echo "✗ Error copying file"
            echo "⚠️  Continuing despite error..."
        fi
    fi
fi

echo ""
echo "✅ Configuration completed!"
echo ""
if [ "$CONF_GENERATED" = true ]; then
    echo "Next step:"
    echo "  cd $MAILCOW_DIR && docker compose up -d"
else
    echo "Next steps:"
    echo "  1. cd $MAILCOW_DIR"
    echo "  2. Configure variables: export MAILCOW_HOSTNAME=mail.example.net MAILCOW_TZ=Europe/Paris"
    echo "  3. ./generate_config.sh --dev"
    echo "  4. docker compose up -d"
fi

