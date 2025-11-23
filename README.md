# 🔒 Secure Installation Script - Dolibarr & GLPI

## 📋 Overview

This script automates the installation and secure configuration of two professional web applications:

- **Dolibarr** (v17.0.0) - Open source ERP/CRM
- **GLPI** (v10.0.15) - IT asset management and helpdesk system

The script sets up a complete infrastructure with self-signed SSL/TLS certificates, dedicated MariaDB databases, and secure Apache configuration.

## ✨ Key Features

### 🛡️ Security

- **Local Certificate Authority (CA)** - Creates an internal CA to issue certificates
- **SSL/TLS Certificates** - Modern protocols (TLS 1.2 and 1.3 only)
- **Strong Encryption** - Cipher suites: `TLS_AES_256_GCM_SHA384`, `TLS_AES_128_GCM_SHA256`, `TLS_CHACHA20_POLY1305_SHA256`
- **Apache Authentication** - Password protection for default page
- **Client Certificates** - PKCS12 certificate generation for mutual authentication
- **HTTPS Redirects** - Automatic HTTP to HTTPS redirection

### 🗄️ Database

- **MariaDB** with separate databases for each application
- **Dedicated Users** with minimal permissions (least privilege principle)
- **UTF8MB4 Encoding** for full multilingual support

### 🌐 Web Infrastructure

- **Apache 2.4** with SSL, Rewrite, and Headers modules
- **Separate VirtualHosts** for application isolation
- **PHP 7.x/8.x** with required extensions
- **Local DNS** via /etc/hosts for domain name resolution

## 📦 Prerequisites

### System

- **OS**: Debian 11/12 or Ubuntu 20.04/22.04
- **Privileges**: Root access (sudo)
- **RAM**: Minimum 2 GB recommended
- **Disk Space**: At least 5 GB available

### Files to Download BEFORE Execution

```bash
# Download Dolibarr 17.0.0
wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip

# Download GLPI 10.0.15
wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

## 🚀 Installation

### 1. Preparation

```bash
# Clone or download the script
cd /tmp
chmod +x script.sh

# Download archives (REQUIRED)
wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip
wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

### 2. Configuration (OPTIONAL)

Edit the script to modify default values:

```bash
# Domain names
DOLI_DOMAIN="dolibarr.nc.woze.lab"
GLPI_DOMAIN="glpi.nc.woze.lab"

# Database passwords
DB_ROOT_PASS="RootPass123!"
DOLI_DB_PASS="DoliPass123!"
GLPI_DB_PASS="GlpiPass123!"

# Apache authentication
APACHE_USER="admin"
APACHE_PASS="admin123"
```

### 3. Execution

```bash
sudo ./script.sh
```

⏱️ **Estimated Duration**: 5-10 minutes depending on network and CPU speed

## 📖 How It Works

The script executes in 10 sequential steps:

### Step 1/10: System Package Installation

- Update APT repositories
- Install Apache2, MariaDB, PHP and extensions
- Install OpenSSL and SSL tools
- Start and enable services

**Installed Packages**:

```
apache2, mariadb-server, php, php-mysql, php-xml, php-cli,
php-curl, php-gd, php-mbstring, php-zip, php-intl,
unzip, openssl, apache2-utils
```

### Step 2/10: MariaDB Configuration

- Start MariaDB service
- Set root password
- Secure installation

**SQL Commands Executed**:

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
FLUSH PRIVILEGES;
```

### Step 3/10: Dolibarr Database Creation

- Create database with UTF8MB4 encoding
- Create dedicated user with limited permissions
- Apply privileges

**Security Schema**:

```
dolibarr_db (database)
  └── dolibarr_user@localhost (GRANT ALL on dolibarr_db only)
```

### Step 4/10: GLPI Database Creation

- Same process as Dolibarr
- Complete data isolation

**Security Schema**:

```
glpi_db (database)
  └── glpi_user@localhost (GRANT ALL on glpi_db only)
```

### Step 5/10: Dolibarr Installation

- Extract ZIP archive to `/var/www/dolibarr`
- Configure permissions (owner: `www-data`)
- Create documents directory with write permissions

**Directory Structure Created**:

```
/var/www/dolibarr/
├── htdocs/          (web root)
├── documents/       (file storage)
└── [other Dolibarr folders]
```

### Step 6/10: GLPI Installation

- Extract TAR.GZ archive to `/var/www/glpi`
- Configure permissions
- Create `files/` and `config/` directories with write permissions

**Directory Structure Created**:

```
/var/www/glpi/
├── public/          (web root)
├── files/           (file storage)
├── config/          (configuration)
└── [other GLPI folders]
```

### Step 7/10: Certificate Authority (CA) Creation

#### 7.1 Root CA Generation

```bash
# RSA 4096 bits private key
openssl genrsa -out ca.key 4096

# Self-signed certificate valid 10 years
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt
```

**CA Characteristics**:

- Algorithm: RSA 4096 bits
- Hash: SHA-256
- Validity: 10 years
- Subject: `/C=FR/ST=IDF/L=Paris/O=MonEntreprise/CN=CA-Interne`

#### 7.2 Dolibarr Certificate Generation

```bash
# RSA 2048 bits private key
openssl genrsa -out dolibarr.nc.woze.lab.key 2048

# CSR (Certificate Signing Request)
openssl req -new -key dolibarr.nc.woze.lab.key -out dolibarr.nc.woze.lab.csr

# Signing by CA (validity 825 days)
openssl x509 -req -in dolibarr.nc.woze.lab.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out dolibarr.nc.woze.lab.crt -days 825
```

**Extensions Included**:

- `subjectAltName`: DNS.1 = dolibarr.nc.woze.lab

#### 7.3 GLPI Certificate Generation

- Same process as Dolibarr
- Distinct certificate for each domain

#### 7.4 Client Certificate Generation (PKCS12)

```bash
# Client key and CSR
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr

# Signing with clientAuth extensions
openssl x509 -req -CA ca.crt -CAkey ca.key -in client.csr \
  -out client.crt -days 120 -extfile client.cnf -extensions req_ext

# Export to PKCS12 format
openssl pkcs12 -export -in client.crt -inkey client.key \
  -out client.p12 -password pass:client123
```

**Client Certificate Characteristics**:

- Validity: 120 days
- Extensions: `clientAuth`, `digitalSignature`, `keyEncipherment`
- Format: PKCS12 (browser compatible)
- Password: `client123`

### Step 8/10: Apache VirtualHosts Configuration

#### 8.1 Dolibarr VirtualHost (HTTPS)

```apache
<VirtualHost *:443>
    ServerName dolibarr.nc.woze.lab
    DocumentRoot /var/www/dolibarr/htdocs

    # SSL/TLS Configuration
    SSLEngine on
    SSLCertificateFile /etc/ssl/myca/dolibarr.nc.woze.lab.crt
    SSLCertificateKeyFile /etc/ssl/myca/dolibarr.nc.woze.lab.key
    SSLCACertificateFile /etc/ssl/myca/ca.crt

    # Modern protocols only
    SSLProtocol -all +TLSv1.3 +TLSv1.2

    # Strong cipher suite
    SSLCipherSuite TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256
    SSLHonorCipherOrder on
</VirtualHost>
```

#### 8.2 Dolibarr VirtualHost (HTTP → HTTPS)

```apache
<VirtualHost *:80>
    ServerName dolibarr.nc.woze.lab
    Redirect permanent / https://dolibarr.nc.woze.lab/
</VirtualHost>
```

#### 8.3 Same Configuration for GLPI

- HTTPS VirtualHost on port 443
- HTTP → HTTPS redirect
- DocumentRoot: `/var/www/glpi/public`

**Apache Modules Enabled**:

- `ssl` - SSL/TLS support
- `rewrite` - URL rewriting
- `headers` - HTTP header manipulation

### Step 9/10: Apache Default Page Protection

```bash
# Create password file
htpasswd -bc /etc/apache2/.htpasswd admin admin123
```

**Default VirtualHost Configuration**:

```apache
<Directory /var/www/html>
    AuthType Basic
    AuthName "Restricted Access"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
```

**Purpose**: Protect Apache's default page to prevent information disclosure

### Step 10/10: Local DNS Configuration

```bash
# Add to /etc/hosts
echo "127.0.0.1    dolibarr.nc.woze.lab" >> /etc/hosts
echo "127.0.0.1    glpi.nc.woze.lab" >> /etc/hosts
```

**Effect**: Local domain name resolution without external DNS server

## 🔐 Access Information After Installation

### Apache Default Page

```
URL  : http://localhost
User : admin
Pass : admin123
```

### Dolibarr

```
URL          : https://dolibarr.nc.woze.lab
Database     : dolibarr_db
DB User      : dolibarr_user
DB Password  : DoliPass123!
```

**First Login**:

1. Import CA certificate in your browser
2. Access https://dolibarr.nc.woze.lab
3. Follow installation wizard
4. Use database information above

### GLPI

```
URL          : https://glpi.nc.woze.lab
Database     : glpi_db
DB User      : glpi_user
DB Password  : GlpiPass123!
```

**First Login**:

1. Import CA certificate in your browser
2. Access https://glpi.nc.woze.lab
3. Follow installation wizard
4. Use database information above

**GLPI Default Accounts**:

- **glpi/glpi** - Administrator account
- **tech/tech** - Technician account
- **normal/normal** - User account
- **post-only/postonly** - Post-only account

### SSL Certificates

```
CA Certificate   : /etc/ssl/myca/clients/ca-a-importer.crt
Client Certificate : /etc/ssl/myca/clients/client.p12
P12 Password     : client123
```

## 🌐 Import CA Certificate in Browsers

### Firefox

1. Settings → Privacy & Security → Certificates → View Certificates
2. "Authorities" tab → Import
3. Select `/etc/ssl/myca/clients/ca-a-importer.crt`
4. Check "Trust this CA to identify websites"

### Chrome/Chromium

```bash
# Linux
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "CA-Interne" -i /etc/ssl/myca/clients/ca-a-importer.crt

# Or via interface
# Settings → Privacy and security → Security → Manage certificates
# "Authorities" tab → Import
```

### Windows

1. Double-click `ca-a-importer.crt`
2. Install certificate → Local Machine
3. Place in "Trusted Root Certification Authorities"

### macOS

1. Double-click `ca-a-importer.crt`
2. Add to "login" keychain
3. Double-click certificate → Trust → Always Trust

## 🧪 Installation Verification

### Connectivity Tests

```bash
# Test Apache
curl -I http://localhost

# Test Dolibarr (SSL)
curl -k -I https://dolibarr.nc.woze.lab

# Test GLPI (SSL)
curl -k -I https://glpi.nc.woze.lab
```

### Service Verification

```bash
# Apache status
systemctl status apache2

# MariaDB status
systemctl status mariadb

# Listening ports
netstat -tlnp | grep -E ':(80|443|3306)'
```

**Expected Result**:

```
tcp6  0  0 :::80    :::*  LISTEN  [PID]/apache2
tcp6  0  0 :::443   :::*  LISTEN  [PID]/apache2
tcp   0  0 127.0.0.1:3306  0.0.0.0:*  LISTEN  [PID]/mariadbd
```

### SSL Certificate Tests

```bash
# Verify Dolibarr certificate
openssl s_client -connect dolibarr.nc.woze.lab:443 -CAfile /etc/ssl/myca/ca.crt

# Verify GLPI certificate
openssl s_client -connect glpi.nc.woze.lab:443 -CAfile /etc/ssl/myca/ca.crt
```

### Database Tests

```bash
# Dolibarr connection
mysql -u dolibarr_user -pDoliPass123! dolibarr_db -e "SHOW TABLES;"

# GLPI connection
mysql -u glpi_user -pGlpiPass123! glpi_db -e "SHOW TABLES;"
```

## 🔧 Troubleshooting

### Issue: Archives Not Found

**Symptom**:

```
ATTENTION: Archive /tmp/dolibarr.zip introuvable
ATTENTION: Archive /tmp/glpi.tgz introuvable
```

**Solution**:

```bash
# Download archives before rerunning the script
wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip
wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

### Issue: "Permission denied" Error

**Symptom**:

```
Error: This script must be run with sudo
```

**Solution**:

```bash
sudo ./script.sh
```

### Issue: Port 80/443 Already in Use

**Symptom**:

```
(98)Address already in use: AH00072: make_sock: could not bind to address [::]:80
```

**Solution**:

```bash
# Identify process using the port
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting service
sudo systemctl stop nginx  # example if nginx is running
```

### Issue: SSL Error in Browser

**Symptom**:

```
NET::ERR_CERT_AUTHORITY_INVALID
```

**Solution**:

1. Verify CA certificate is properly imported in browser
2. Restart browser after import
3. Clear browser SSL cache

**Chrome**:

```
chrome://net-internals/#sockets → Flush socket pools
chrome://net-internals/#ssl → Clear SSL cache
```

### Issue: MariaDB Connection Refused

**Symptom**:

```
ERROR 1045 (28000): Access denied for user 'dolibarr_user'@'localhost'
```

**Solution**:

```bash
# Check user and permissions
sudo mysql -u root -pRootPass123!

mysql> SELECT User, Host FROM mysql.user WHERE User LIKE '%dolibarr%';
mysql> SHOW GRANTS FOR 'dolibarr_user'@'localhost';

# Recreate user if necessary
mysql> DROP USER 'dolibarr_user'@'localhost';
mysql> CREATE USER 'dolibarr_user'@'localhost' IDENTIFIED BY 'DoliPass123!';
mysql> GRANT ALL PRIVILEGES ON dolibarr_db.* TO 'dolibarr_user'@'localhost';
mysql> FLUSH PRIVILEGES;
```

### Issue: Blank Page After Installation

**Symptom**: White page or 500 error on Dolibarr/GLPI

**Solution**:

```bash
# Check permissions
sudo chown -R www-data:www-data /var/www/dolibarr
sudo chown -R www-data:www-data /var/www/glpi

# Check Apache logs
sudo tail -f /var/log/apache2/error.log

# Check PHP logs
sudo tail -f /var/log/php*.log
```

### Issue: Missing PHP Modules

**Symptom**:

```
Required PHP extension 'gd' is not loaded
```

**Solution**:

```bash
# Check installed modules
php -m | grep -i gd

# Install missing modules
sudo apt install php-gd php-curl php-zip php-intl php-mbstring

# Restart Apache
sudo systemctl restart apache2
```

## 📁 Created File Structure

```
/var/www/
├── dolibarr/
│   ├── htdocs/              # Dolibarr web root
│   ├── documents/           # File storage
│   └── [other folders]
├── glpi/
│   ├── public/              # GLPI web root
│   ├── files/               # File storage
│   ├── config/              # Configuration
│   └── [other folders]
└── html/                    # Apache default page (protected)

/etc/ssl/myca/
├── ca.key                   # CA private key (PRIVATE - 600)
├── ca.crt                   # CA certificate
├── ca.srl                   # CA serial number
├── dolibarr.nc.woze.lab.key # Dolibarr private key (PRIVATE - 600)
├── dolibarr.nc.woze.lab.crt # Dolibarr certificate
├── dolibarr.nc.woze.lab.csr # Dolibarr CSR
├── dolibarr.nc.woze.lab.cnf # Dolibarr OpenSSL config
├── glpi.nc.woze.lab.key     # GLPI private key (PRIVATE - 600)
├── glpi.nc.woze.lab.crt     # GLPI certificate
├── glpi.nc.woze.lab.csr     # GLPI CSR
├── glpi.nc.woze.lab.cnf     # GLPI OpenSSL config
├── client.key               # Client private key (PRIVATE - 600)
├── client.crt               # Client certificate
├── client.csr               # Client CSR
├── client.cnf               # Client OpenSSL config
└── clients/
    ├── ca-a-importer.crt    # CA to distribute to users
    └── client.p12           # Client PKCS12 certificate

/etc/apache2/
├── .htpasswd                # Apache password file
└── sites-available/
    ├── 000-default.conf     # Default VirtualHost (protected)
    ├── dolibarr.conf        # Dolibarr VirtualHost
    └── glpi.conf            # GLPI VirtualHost
```

## 🔒 Security Considerations

### ⚠️ Development/Test Environment Only

**This script is designed for:**

- Development environments
- Test environments
- Demonstrations
- Training

**DO NOT use in production without modifications**:

1. **Self-signed Certificates**: Not recognized by public browsers
2. **Default Passwords**: Must be changed
3. **Basic Configuration**: Minimal security

### 🛡️ Production Recommendations

#### 1. SSL Certificates

```bash
# Use Let's Encrypt for valid certificates
apt install certbot python3-certbot-apache
certbot --apache -d dolibarr.example.com
```

#### 2. Passwords

```bash
# Generate strong passwords
openssl rand -base64 32
```

#### 3. Firewall

```bash
# Configure UFW
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

#### 4. Fail2Ban

```bash
# Brute-force protection
apt install fail2ban
systemctl enable fail2ban
```

#### 5. Updates

```bash
# Automate security updates
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

#### 6. Backups

```bash
# Database backup script
mysqldump -u root -p --all-databases > backup_$(date +%Y%m%d).sql

# File backup
tar czf backup_files_$(date +%Y%m%d).tar.gz /var/www/dolibarr/documents /var/www/glpi/files
```

#### 7. Monitoring

```bash
# Install monitoring
apt install monit
# Configure Apache, MariaDB, disk space monitoring
```

### 🔐 Security Hardening

#### Apache

```apache
# Hide Apache version
ServerTokens Prod
ServerSignature Off

# Security headers
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'"
```

#### MariaDB

```sql
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove test database
DROP DATABASE IF EXISTS test;

-- Restrict root access to localhost only
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

FLUSH PRIVILEGES;
```

#### PHP

```ini
; php.ini - Secure configuration
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php_errors.log
disable_functions = exec,passthru,shell_exec,system,proc_open,popen
allow_url_fopen = Off
allow_url_include = Off
session.cookie_httponly = 1
session.cookie_secure = 1
session.use_strict_mode = 1
```

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    USER                                 │
│              (Browser with CA imported)                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ HTTPS (TLS 1.2/1.3)
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  APACHE 2.4                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ :80 → :443   │  │ Dolibarr :443│  │  GLPI :443   │  │
│  │  (Redirect)  │  │ VirtualHost  │  │ VirtualHost  │  │
│  └──────────────┘  └──────┬───────┘  └──────┬───────┘  │
└────────────────────────────┼──────────────────┼─────────┘
                             │                  │
                    ┌────────▼────────┐ ┌───────▼────────┐
                    │   Dolibarr      │ │     GLPI       │
                    │  PHP App        │ │   PHP App      │
                    │  /var/www/      │ │  /var/www/     │
                    │   dolibarr/     │ │    glpi/       │
                    └────────┬────────┘ └───────┬────────┘
                             │                  │
                             │                  │
                    ┌────────▼──────────────────▼────────┐
                    │          MariaDB :3306             │
                    │  ┌──────────────┐ ┌─────────────┐  │
                    │  │ dolibarr_db  │ │  glpi_db    │  │
                    │  │ (dolibarr_   │ │  (glpi_     │  │
                    │  │    user)     │ │    user)    │  │
                    │  └──────────────┘ └─────────────┘  │
                    └────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              SSL/TLS INFRASTRUCTURE                     │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Internal CA (/etc/ssl/myca/)                    │   │
│  │  ├── ca.crt / ca.key (Root authority)            │   │
│  │  ├── dolibarr.nc.woze.lab.crt/.key               │   │
│  │  ├── glpi.nc.woze.lab.crt/.key                   │   │
│  │  └── client.p12 (Client certificate)             │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 📚 Resources and Documentation

### Official Documentation

**Dolibarr**:

- Official site: https://www.dolibarr.org/
- Documentation: https://wiki.dolibarr.org/
- GitHub: https://github.com/Dolibarr/dolibarr

**GLPI**:

- Official site: https://glpi-project.org/
- Documentation: https://glpi-install.readthedocs.io/
- GitHub: https://github.com/glpi-project/glpi

**Apache**:

- SSL/TLS Documentation: https://httpd.apache.org/docs/2.4/ssl/
- VirtualHost: https://httpd.apache.org/docs/2.4/vhosts/

**MariaDB**:

- Documentation: https://mariadb.com/kb/en/documentation/
- Security: https://mariadb.com/kb/en/securing-mariadb/

**OpenSSL**:

- Documentation: https://www.openssl.org/docs/
- Cookbook: https://www.feistyduck.com/library/openssl-cookbook/

### Recommended Tutorials

1. **Apache Security**: https://httpd.apache.org/docs/2.4/misc/security_tips.html
2. **MariaDB Hardening**: https://mariadb.com/kb/en/securing-mariadb/
3. **Let's Encrypt**: https://certbot.eff.org/

## 🤝 Support and Contribution

### Report an Issue

If you encounter a problem:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Check Apache and MariaDB logs
3. Document reproduction steps
4. Include complete error messages

### Possible Improvements

- [ ] Support for multiple Linux distributions
- [ ] Let's Encrypt certificate option
- [ ] Uninstallation script
- [ ] Pre-installation automatic backup
- [ ] Prerequisites validation before installation
- [ ] Silent mode (non-interactive)
- [ ] Dolibarr/GLPI update script
- [ ] Automatic Fail2Ban configuration
- [ ] Monitoring with Prometheus/Grafana

## 📝 Changelog

### Version 1.0 (Current)

- ✅ Automated Dolibarr 17.0.0 installation
- ✅ Automated GLPI 10.0.15 installation
- ✅ Internal CA creation with SSL/TLS certificates
- ✅ Apache configuration with secure VirtualHosts
- ✅ Dedicated MariaDB databases
- ✅ Apache default page protection
- ✅ PKCS12 client certificate generation
- ✅ Local DNS configuration via /etc/hosts
- ✅ TLS 1.2 and 1.3 only support

## 📄 License

This script is provided "as is", without warranty of any kind. Use at your own risk.

**Recommendation**: Test in a virtual environment before any deployment.

## ⚖️ Legal Notice

Installed software (Dolibarr, GLPI) have their own licenses:

- **Dolibarr**: GPL v3+
- **GLPI**: GPL v3+

Respect the terms of these licenses when using the software.

---

**Developed for**: Development and test environments
**Author**: Automated installation script
**Last updated**: 2024
