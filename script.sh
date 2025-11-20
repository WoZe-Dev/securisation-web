
# télécharger avant le lancer du script les fichiers :

# wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip
# wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz


# Arrêt si erreur
set -e

################################################################################
# VARIABLES - A MODIFIER SELON VOS BESOINS
################################################################################

# Noms de domaine
DOLI_DOMAIN="dolibarr.nc.woze.lab"
GLPI_DOMAIN="glpi.nc.woze.lab"

# Mots de passe base de données
DB_ROOT_PASS="RootPass123!"
DOLI_DB_NAME="dolibarr_db"
DOLI_DB_USER="dolibarr_user"
DOLI_DB_PASS="DoliPass123!"
GLPI_DB_NAME="glpi_db"
GLPI_DB_USER="glpi_user"
GLPI_DB_PASS="GlpiPass123!"

# Authentification page Apache par défaut
APACHE_USER="admin"
APACHE_PASS="admin123"

# Chemins
WEB_DIR="/var/www"
CERT_DIR="/etc/ssl/myca"

################################################################################
# Vérification root
################################################################################

if [ "$EUID" -ne 0 ]; then
    echo "Erreur : Ce script doit être lancé avec sudo"
    exit 1
fi

echo "======================================================================"
echo "Installation Dolibarr et GLPI avec SSL"
echo "======================================================================"
echo ""

# Supprimer et recréer le dossier archives/partial
rm -rf /var/cache/apt/archives
mkdir -p /var/cache/apt/archives/partial

################################################################################
# ETAPE 1 : Installation des paquets nécessaires
################################################################################

echo "[1/10] Installation des paquets..."
apt update
apt install -y apache2 mariadb-server php php-mysql php-xml php-cli php-curl php-gd php-mbstring php-zip php-intl unzip openssl apache2-utils

# Démarrer Apache en premier
systemctl start apache2
systemctl enable apache2

# Attendre qu'Apache soit bien prêt
sleep 2

# Activation modules Apache avec chemin complet
/usr/sbin/a2enmod ssl rewrite headers

################################################################################
# ETAPE 2 : Configuration MariaDB
################################################################################

echo "[2/10] Configuration de MariaDB..."
systemctl start mariadb
systemctl enable mariadb

# Définir mot de passe root
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" 2>/dev/null || true
mysql -u root -p"${DB_ROOT_PASS}" -e "FLUSH PRIVILEGES;"

# Création base Dolibarr
echo "[3/10] Création base de données Dolibarr..."
mysql -u root -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DOLI_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DOLI_DB_USER}'@'localhost' IDENTIFIED BY '${DOLI_DB_PASS}';
GRANT ALL PRIVILEGES ON ${DOLI_DB_NAME}.* TO '${DOLI_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Création base GLPI
echo "[4/10] Création base de données GLPI..."
mysql -u root -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${GLPI_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${GLPI_DB_USER}'@'localhost' IDENTIFIED BY '${GLPI_DB_PASS}';
GRANT ALL PRIVILEGES ON ${GLPI_DB_NAME}.* TO '${GLPI_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

################################################################################
# ETAPE 3 : Installation Dolibarr
################################################################################

echo "[5/10] Installation de Dolibarr..."
mkdir -p ${WEB_DIR}/dolibarr

# Décompression archive
if [ -f /tmp/dolibarr.zip ]; then
    unzip -q /tmp/dolibarr.zip -d /tmp/
    DOLI_TEMP=$(find /tmp -maxdepth 1 -type d -name "dolibarr*" | head -n 1)
    cp -r ${DOLI_TEMP}/* ${WEB_DIR}/dolibarr/
    rm -rf ${DOLI_TEMP}
else
    echo "ATTENTION: Archive /tmp/dolibarr.zip introuvable"
fi

# Permissions
chown -R www-data:www-data ${WEB_DIR}/dolibarr
chmod -R 755 ${WEB_DIR}/dolibarr
mkdir -p ${WEB_DIR}/dolibarr/documents
chown -R www-data:www-data ${WEB_DIR}/dolibarr/documents

################################################################################
# ETAPE 4 : Installation GLPI
################################################################################

echo "[6/10] Installation de GLPI..."

# Décompression archive
if [ -f /tmp/glpi.tgz ]; then
    tar xzf /tmp/glpi.tgz -C /tmp/
    cp -r /tmp/glpi ${WEB_DIR}/
    rm -rf /tmp/glpi
else
    echo "ATTENTION: Archive /tmp/glpi.tgz introuvable"
fi

# Permissions
chown -R www-data:www-data ${WEB_DIR}/glpi
chmod -R 755 ${WEB_DIR}/glpi
mkdir -p ${WEB_DIR}/glpi/files ${WEB_DIR}/glpi/config
chown -R www-data:www-data ${WEB_DIR}/glpi/files ${WEB_DIR}/glpi/config

################################################################################
# ETAPE 5 : Création Autorité de Certification (CA)
################################################################################

echo "[7/10] Création du CA et des certificats..."
mkdir -p ${CERT_DIR}

# Génération clé et certificat CA
openssl genrsa -out ${CERT_DIR}/ca.key 4096
openssl req -x509 -new -nodes -key ${CERT_DIR}/ca.key -sha256 -days 3650 -out ${CERT_DIR}/ca.crt -subj "/C=FR/ST=IDF/L=Paris/O=MonEntreprise/CN=CA-Interne"

# Certificat pour Dolibarr
cat > ${CERT_DIR}/${DOLI_DOMAIN}.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = FR
ST = IDF
L = Paris
O = MonEntreprise
CN = ${DOLI_DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOLI_DOMAIN}
EOF

openssl genrsa -out ${CERT_DIR}/${DOLI_DOMAIN}.key 2048
openssl req -new -key ${CERT_DIR}/${DOLI_DOMAIN}.key -out ${CERT_DIR}/${DOLI_DOMAIN}.csr -config ${CERT_DIR}/${DOLI_DOMAIN}.cnf
openssl x509 -req -in ${CERT_DIR}/${DOLI_DOMAIN}.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/${DOLI_DOMAIN}.crt -days 825 -sha256 -extfile ${CERT_DIR}/${DOLI_DOMAIN}.cnf -extensions req_ext

# Certificat pour GLPI
cat > ${CERT_DIR}/${GLPI_DOMAIN}.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = FR
ST = IDF
L = Paris
O = MonEntreprise
CN = ${GLPI_DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${GLPI_DOMAIN}
EOF

openssl genrsa -out ${CERT_DIR}/${GLPI_DOMAIN}.key 2048
openssl req -new -key ${CERT_DIR}/${GLPI_DOMAIN}.key -out ${CERT_DIR}/${GLPI_DOMAIN}.csr -config ${CERT_DIR}/${GLPI_DOMAIN}.cnf
openssl x509 -req -in ${CERT_DIR}/${GLPI_DOMAIN}.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/${GLPI_DOMAIN}.crt -days 825 -sha256 -extfile ${CERT_DIR}/${GLPI_DOMAIN}.cnf -extensions req_ext

# Permissions
chmod 600 ${CERT_DIR}/*.key
chmod 644 ${CERT_DIR}/*.crt

# Copie CA pour les clients
mkdir -p ${CERT_DIR}/clients
cp ${CERT_DIR}/ca.crt ${CERT_DIR}/clients/ca-a-importer.crt

# Génération certificat client (cours 540)
openssl genrsa -out ${CERT_DIR}/client.key 2048
openssl req -new -key ${CERT_DIR}/client.key -out ${CERT_DIR}/client.csr \
    -subj "/C=FR/ST=IDF/L=Paris/O=MonEntreprise/CN=Client"
openssl x509 -req -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key \
    -in ${CERT_DIR}/client.csr -out ${CERT_DIR}/client.crt -days 120
openssl pkcs12 -export -in ${CERT_DIR}/client.crt -inkey ${CERT_DIR}/client.key \
    -out ${CERT_DIR}/clients/client.p12 -password pass:client123

################################################################################
# ETAPE 6 : Configuration Apache VirtualHosts
################################################################################

echo "[8/10] Configuration Apache avec SSL/TLS..."

# VirtualHost Dolibarr
cat > /etc/apache2/sites-available/dolibarr.conf <<EOF
<VirtualHost *:443>
    ServerName ${DOLI_DOMAIN}
    DocumentRoot ${WEB_DIR}/dolibarr/htdocs

    SSLEngine on
    SSLCertificateFile ${CERT_DIR}/${DOLI_DOMAIN}.crt
    SSLCertificateKeyFile ${CERT_DIR}/${DOLI_DOMAIN}.key
    SSLCACertificateFile ${CERT_DIR}/ca.crt
    SSLProtocol -all +TLSv1.3 +TLSv1.2

    <Directory ${WEB_DIR}/dolibarr/htdocs>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:80>
    ServerName ${DOLI_DOMAIN}
    Redirect permanent / https://${DOLI_DOMAIN}/
</VirtualHost>
EOF

# VirtualHost GLPI
cat > /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:443>
    ServerName ${GLPI_DOMAIN}
    DocumentRoot ${WEB_DIR}/glpi/public

    SSLEngine on
    SSLCertificateFile ${CERT_DIR}/${GLPI_DOMAIN}.crt
    SSLCertificateKeyFile ${CERT_DIR}/${GLPI_DOMAIN}.key
    SSLCACertificateFile ${CERT_DIR}/ca.crt
    SSLProtocol -all +TLSv1.3 +TLSv1.2

    <Directory ${WEB_DIR}/glpi>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:80>
    ServerName ${GLPI_DOMAIN}
    Redirect permanent / https://${GLPI_DOMAIN}/
</VirtualHost>
EOF

# Activation sites avec chemin complet
/usr/sbin/a2dissite default-ssl.conf 2>/dev/null || true
/usr/sbin/a2dissite 001-custom.conf 2>/dev/null || true
/usr/sbin/a2ensite 000-default.conf
/usr/sbin/a2ensite dolibarr.conf
/usr/sbin/a2ensite glpi.conf

################################################################################
# ETAPE 7 : Protection page par défaut Apache
################################################################################

echo "[9/10] Protection page par défaut Apache..."

# Création fichier de mots de passe
htpasswd -bc /etc/apache2/.htpasswd ${APACHE_USER} ${APACHE_PASS}

# Configuration VirtualHost par défaut
cat > /etc/apache2/sites-available/000-default.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AuthType Basic
        AuthName "Acces Restreint"
        AuthUserFile /etc/apache2/.htpasswd
        Require valid-user
    </Directory>
</VirtualHost>
EOF

################################################################################
# ETAPE 8 : Configuration /etc/hosts
################################################################################

echo "[10/10] Configuration DNS local..."

# Ajout dans /etc/hosts
sed -i "/${DOLI_DOMAIN}/d" /etc/hosts
sed -i "/${GLPI_DOMAIN}/d" /etc/hosts
echo "127.0.0.1    ${DOLI_DOMAIN}" >> /etc/hosts
echo "127.0.0.1    ${GLPI_DOMAIN}" >> /etc/hosts

################################################################################
# Finalisation
################################################################################

systemctl restart apache2

echo ""
echo "======================================================================"
echo "Installation terminée !"
echo "======================================================================"
echo ""
echo "Page Apache (protégée) : http://localhost"
echo "  User: ${APACHE_USER}"
echo "  Pass: ${APACHE_PASS}"
echo ""
echo "Dolibarr : https://${DOLI_DOMAIN}"
echo "  DB: ${DOLI_DB_NAME}"
echo "  User: ${DOLI_DB_USER}"
echo "  Pass: ${DOLI_DB_PASS}"
echo ""
echo "GLPI : https://${GLPI_DOMAIN}"
echo "  DB: ${GLPI_DB_NAME}"
echo "  User: ${GLPI_DB_USER}"
echo "  Pass: ${GLPI_DB_PASS}"
echo ""
echo "Certificat CA à importer : ${CERT_DIR}/clients/ca-a-importer.crt"
echo "Certificat client (PKCS12) : ${CERT_DIR}/clients/client.p12 (pass: client123)"
echo "======================================================================"
