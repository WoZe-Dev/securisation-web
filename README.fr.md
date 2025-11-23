# 🔒 Script d'Installation Sécurisée - Dolibarr & GLPI

## 📋 Vue d'ensemble

Ce script automatise l'installation et la configuration sécurisée de deux applications web professionnelles :
- **Dolibarr** (v17.0.0) - ERP/CRM open source
- **GLPI** (v10.0.15) - Système de gestion d'incidents et d'inventaire IT

Le script met en place une infrastructure complète avec certificats SSL/TLS auto-signés, bases de données MariaDB dédiées, et configuration Apache sécurisée.

## ✨ Fonctionnalités principales

### 🛡️ Sécurité
- **Autorité de Certification (CA) locale** - Création d'une CA interne pour émettre des certificats
- **Certificats SSL/TLS** - Protocoles modernes (TLS 1.2 et 1.3 uniquement)
- **Chiffrement fort** - Suite de chiffrement : `TLS_AES_256_GCM_SHA384`, `TLS_AES_128_GCM_SHA256`, `TLS_CHACHA20_POLY1305_SHA256`
- **Authentification Apache** - Protection par mot de passe de la page par défaut
- **Certificats client** - Génération de certificats PKCS12 pour authentification mutuelle
- **Redirections HTTPS** - Redirection automatique de HTTP vers HTTPS

### 🗄️ Base de données
- **MariaDB** avec bases de données séparées pour chaque application
- **Utilisateurs dédiés** avec permissions minimales (principe du moindre privilège)
- **Encodage UTF8MB4** pour support multilingue complet

### 🌐 Infrastructure Web
- **Apache 2.4** avec modules SSL, Rewrite, et Headers
- **VirtualHosts séparés** pour isolation des applications
- **PHP 7.x/8.x** avec extensions requises
- **DNS local** via /etc/hosts pour résolution des noms de domaine

## 📦 Prérequis

### Système
- **OS** : Debian 11/12 ou Ubuntu 20.04/22.04
- **Privilèges** : Accès root (sudo)
- **RAM** : Minimum 2 Go recommandé
- **Espace disque** : Au moins 5 Go disponibles

### Fichiers à télécharger AVANT l'exécution

```bash
# Télécharger Dolibarr 17.0.0
wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip

# Télécharger GLPI 10.0.15
wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

## 🚀 Installation

### 1. Préparation

```bash
# Cloner ou télécharger le script
cd /tmp
chmod +x script.sh

# Télécharger les archives (OBLIGATOIRE)
wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip
wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

### 2. Configuration (OPTIONNEL)

Éditer le script pour modifier les valeurs par défaut :

```bash
# Noms de domaine
DOLI_DOMAIN="dolibarr.nc.woze.lab"
GLPI_DOMAIN="glpi.nc.woze.lab"

# Mots de passe base de données
DB_ROOT_PASS="RootPass123!"
DOLI_DB_PASS="DoliPass123!"
GLPI_DB_PASS="GlpiPass123!"

# Authentification Apache
APACHE_USER="admin"
APACHE_PASS="admin123"
```

### 3. Exécution

```bash
sudo ./script.sh
```

⏱️ **Durée estimée** : 5-10 minutes selon la vitesse réseau et CPU

## 📖 Détails du fonctionnement

Le script s'exécute en 10 étapes séquentielles :

### Étape 1/10 : Installation des paquets système
- Mise à jour des dépôts APT
- Installation d'Apache2, MariaDB, PHP et extensions
- Installation d'OpenSSL et outils SSL
- Démarrage et activation des services

**Paquets installés** :
```
apache2, mariadb-server, php, php-mysql, php-xml, php-cli,
php-curl, php-gd, php-mbstring, php-zip, php-intl,
unzip, openssl, apache2-utils
```

### Étape 2/10 : Configuration MariaDB
- Démarrage du service MariaDB
- Définition du mot de passe root
- Sécurisation de l'installation

**Commandes SQL exécutées** :
```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
FLUSH PRIVILEGES;
```

### Étape 3/10 : Création base Dolibarr
- Création de la base de données avec encodage UTF8MB4
- Création d'un utilisateur dédié avec permissions limitées
- Application des privilèges

**Schéma de sécurité** :
```
dolibarr_db (database)
  └── dolibarr_user@localhost (GRANT ALL sur dolibarr_db uniquement)
```

### Étape 4/10 : Création base GLPI
- Même processus que pour Dolibarr
- Isolation complète des données

**Schéma de sécurité** :
```
glpi_db (database)
  └── glpi_user@localhost (GRANT ALL sur glpi_db uniquement)
```

### Étape 5/10 : Installation Dolibarr
- Décompression de l'archive ZIP dans `/var/www/dolibarr`
- Configuration des permissions (propriétaire : `www-data`)
- Création du répertoire documents avec permissions d'écriture

**Arborescence créée** :
```
/var/www/dolibarr/
├── htdocs/          (racine web)
├── documents/       (stockage fichiers)
└── [autres dossiers Dolibarr]
```

### Étape 6/10 : Installation GLPI
- Décompression de l'archive TAR.GZ dans `/var/www/glpi`
- Configuration des permissions
- Création des répertoires `files/` et `config/` avec permissions d'écriture

**Arborescence créée** :
```
/var/www/glpi/
├── public/          (racine web)
├── files/           (stockage fichiers)
├── config/          (configuration)
└── [autres dossiers GLPI]
```

### Étape 7/10 : Création de l'Autorité de Certification (CA)

#### 7.1 Génération de la CA racine
```bash
# Clé privée RSA 4096 bits
openssl genrsa -out ca.key 4096

# Certificat auto-signé valide 10 ans
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt
```

**Caractéristiques CA** :
- Algorithme : RSA 4096 bits
- Hash : SHA-256
- Validité : 10 ans
- Sujet : `/C=FR/ST=IDF/L=Paris/O=MonEntreprise/CN=CA-Interne`

#### 7.2 Génération certificat Dolibarr
```bash
# Clé privée RSA 2048 bits
openssl genrsa -out dolibarr.nc.woze.lab.key 2048

# CSR (Certificate Signing Request)
openssl req -new -key dolibarr.nc.woze.lab.key -out dolibarr.nc.woze.lab.csr

# Signature par la CA (validité 825 jours)
openssl x509 -req -in dolibarr.nc.woze.lab.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out dolibarr.nc.woze.lab.crt -days 825
```

**Extensions incluses** :
- `subjectAltName` : DNS.1 = dolibarr.nc.woze.lab

#### 7.3 Génération certificat GLPI
- Processus identique à Dolibarr
- Certificat distinct pour chaque domaine

#### 7.4 Génération certificat client (PKCS12)
```bash
# Clé et CSR client
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr

# Signature avec extensions clientAuth
openssl x509 -req -CA ca.crt -CAkey ca.key -in client.csr \
  -out client.crt -days 120 -extfile client.cnf -extensions req_ext

# Export au format PKCS12
openssl pkcs12 -export -in client.crt -inkey client.key \
  -out client.p12 -password pass:client123
```

**Caractéristiques certificat client** :
- Validité : 120 jours
- Extensions : `clientAuth`, `digitalSignature`, `keyEncipherment`
- Format : PKCS12 (compatible navigateurs)
- Mot de passe : `client123`

### Étape 8/10 : Configuration Apache VirtualHosts

#### 8.1 VirtualHost Dolibarr (HTTPS)
```apache
<VirtualHost *:443>
    ServerName dolibarr.nc.woze.lab
    DocumentRoot /var/www/dolibarr/htdocs

    # Configuration SSL/TLS
    SSLEngine on
    SSLCertificateFile /etc/ssl/myca/dolibarr.nc.woze.lab.crt
    SSLCertificateKeyFile /etc/ssl/myca/dolibarr.nc.woze.lab.key
    SSLCACertificateFile /etc/ssl/myca/ca.crt

    # Protocoles modernes uniquement
    SSLProtocol -all +TLSv1.3 +TLSv1.2

    # Suite de chiffrement forte
    SSLCipherSuite TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256
    SSLHonorCipherOrder on
</VirtualHost>
```

#### 8.2 VirtualHost Dolibarr (HTTP → HTTPS)
```apache
<VirtualHost *:80>
    ServerName dolibarr.nc.woze.lab
    Redirect permanent / https://dolibarr.nc.woze.lab/
</VirtualHost>
```

#### 8.3 Configuration identique pour GLPI
- VirtualHost HTTPS sur port 443
- Redirection HTTP → HTTPS
- DocumentRoot : `/var/www/glpi/public`

**Modules Apache activés** :
- `ssl` - Support SSL/TLS
- `rewrite` - Réécriture d'URL
- `headers` - Manipulation des en-têtes HTTP

### Étape 9/10 : Protection page par défaut Apache

```bash
# Création fichier de mots de passe
htpasswd -bc /etc/apache2/.htpasswd admin admin123
```

**Configuration VirtualHost par défaut** :
```apache
<Directory /var/www/html>
    AuthType Basic
    AuthName "Acces Restreint"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
```

**Objectif** : Protéger la page par défaut d'Apache pour éviter l'exposition d'informations

### Étape 10/10 : Configuration DNS local

```bash
# Ajout dans /etc/hosts
echo "127.0.0.1    dolibarr.nc.woze.lab" >> /etc/hosts
echo "127.0.0.1    glpi.nc.woze.lab" >> /etc/hosts
```

**Effet** : Résolution locale des noms de domaine sans serveur DNS externe

## 🔐 Informations d'accès après installation

### Page Apache par défaut
```
URL  : http://localhost
User : admin
Pass : admin123
```

### Dolibarr
```
URL          : https://dolibarr.nc.woze.lab
Base de données : dolibarr_db
Utilisateur DB  : dolibarr_user
Mot de passe DB : DoliPass123!
```

**Première connexion** :
1. Importer le certificat CA dans votre navigateur
2. Accéder à https://dolibarr.nc.woze.lab
3. Suivre l'assistant d'installation
4. Utiliser les informations de base de données ci-dessus

### GLPI
```
URL          : https://glpi.nc.woze.lab
Base de données : glpi_db
Utilisateur DB  : glpi_user
Mot de passe DB : GlpiPass123!
```

**Première connexion** :
1. Importer le certificat CA dans votre navigateur
2. Accéder à https://glpi.nc.woze.lab
3. Suivre l'assistant d'installation
4. Utiliser les informations de base de données ci-dessus

**Comptes par défaut GLPI** :
- **glpi/glpi** - Compte administrateur
- **tech/tech** - Compte technicien
- **normal/normal** - Compte utilisateur
- **post-only/postonly** - Compte post-only

### Certificats SSL
```
Certificat CA   : /etc/ssl/myca/clients/ca-a-importer.crt
Certificat client : /etc/ssl/myca/clients/client.p12
Mot de passe P12 : client123
```

## 🌐 Import du certificat CA dans les navigateurs

### Firefox
1. Paramètres → Vie privée et sécurité → Certificats → Afficher les certificats
2. Onglet "Autorités" → Importer
3. Sélectionner `/etc/ssl/myca/clients/ca-a-importer.crt`
4. Cocher "Confirmer cette AC pour identifier des sites web"

### Chrome/Chromium
```bash
# Linux
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "CA-Interne" -i /etc/ssl/myca/clients/ca-a-importer.crt

# Ou via l'interface
# Paramètres → Confidentialité et sécurité → Sécurité → Gérer les certificats
# Onglet "Autorités" → Importer
```

### Windows
1. Double-cliquer sur `ca-a-importer.crt`
2. Installer le certificat → Ordinateur local
3. Placer dans "Autorités de certification racines de confiance"

### macOS
1. Double-cliquer sur `ca-a-importer.crt`
2. Ajouter au trousseau "Connexion"
3. Double-cliquer sur le certificat → Faire confiance → Toujours approuver

## 🧪 Vérification de l'installation

### Test de connectivité

```bash
# Test Apache
curl -I http://localhost

# Test Dolibarr (SSL)
curl -k -I https://dolibarr.nc.woze.lab

# Test GLPI (SSL)
curl -k -I https://glpi.nc.woze.lab
```

### Vérification des services

```bash
# Statut Apache
systemctl status apache2

# Statut MariaDB
systemctl status mariadb

# Ports en écoute
netstat -tlnp | grep -E ':(80|443|3306)'
```

**Résultat attendu** :
```
tcp6  0  0 :::80    :::*  LISTEN  [PID]/apache2
tcp6  0  0 :::443   :::*  LISTEN  [PID]/apache2
tcp   0  0 127.0.0.1:3306  0.0.0.0:*  LISTEN  [PID]/mariadbd
```

### Test des certificats SSL

```bash
# Vérifier le certificat Dolibarr
openssl s_client -connect dolibarr.nc.woze.lab:443 -CAfile /etc/ssl/myca/ca.crt

# Vérifier le certificat GLPI
openssl s_client -connect glpi.nc.woze.lab:443 -CAfile /etc/ssl/myca/ca.crt
```

### Test des bases de données

```bash
# Connexion Dolibarr
mysql -u dolibarr_user -pDoliPass123! dolibarr_db -e "SHOW TABLES;"

# Connexion GLPI
mysql -u glpi_user -pGlpiPass123! glpi_db -e "SHOW TABLES;"
```

## 🔧 Dépannage

### Problème : Archives non trouvées

**Symptôme** :
```
ATTENTION: Archive /tmp/dolibarr.zip introuvable
ATTENTION: Archive /tmp/glpi.tgz introuvable
```

**Solution** :
```bash
# Télécharger les archives avant de relancer le script
wget -O /tmp/dolibarr.zip https://github.com/Dolibarr/dolibarr/archive/refs/tags/17.0.0.zip
wget -O /tmp/glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

### Problème : Erreur "Permission denied"

**Symptôme** :
```
Erreur : Ce script doit être lancé avec sudo
```

**Solution** :
```bash
sudo ./script.sh
```

### Problème : Port 80/443 déjà utilisé

**Symptôme** :
```
(98)Address already in use: AH00072: make_sock: could not bind to address [::]:80
```

**Solution** :
```bash
# Identifier le processus utilisant le port
sudo lsof -i :80
sudo lsof -i :443

# Arrêter le service conflictuel
sudo systemctl stop nginx  # exemple si nginx est actif
```

### Problème : Erreur SSL dans le navigateur

**Symptôme** :
```
NET::ERR_CERT_AUTHORITY_INVALID
```

**Solution** :
1. Vérifier que le certificat CA est bien importé dans le navigateur
2. Redémarrer le navigateur après import
3. Vider le cache SSL du navigateur

**Chrome** :
```
chrome://net-internals/#sockets → Flush socket pools
chrome://net-internals/#ssl → Clear SSL cache
```

### Problème : Connexion refusée à MariaDB

**Symptôme** :
```
ERROR 1045 (28000): Access denied for user 'dolibarr_user'@'localhost'
```

**Solution** :
```bash
# Vérifier l'utilisateur et les permissions
sudo mysql -u root -pRootPass123!

mysql> SELECT User, Host FROM mysql.user WHERE User LIKE '%dolibarr%';
mysql> SHOW GRANTS FOR 'dolibarr_user'@'localhost';

# Recréer l'utilisateur si nécessaire
mysql> DROP USER 'dolibarr_user'@'localhost';
mysql> CREATE USER 'dolibarr_user'@'localhost' IDENTIFIED BY 'DoliPass123!';
mysql> GRANT ALL PRIVILEGES ON dolibarr_db.* TO 'dolibarr_user'@'localhost';
mysql> FLUSH PRIVILEGES;
```

### Problème : Page blanche après installation

**Symptôme** : Page blanche ou erreur 500 sur Dolibarr/GLPI

**Solution** :
```bash
# Vérifier les permissions
sudo chown -R www-data:www-data /var/www/dolibarr
sudo chown -R www-data:www-data /var/www/glpi

# Vérifier les logs Apache
sudo tail -f /var/log/apache2/error.log

# Vérifier les logs PHP
sudo tail -f /var/log/php*.log
```

### Problème : Modules PHP manquants

**Symptôme** :
```
Required PHP extension 'gd' is not loaded
```

**Solution** :
```bash
# Vérifier les modules installés
php -m | grep -i gd

# Installer les modules manquants
sudo apt install php-gd php-curl php-zip php-intl php-mbstring

# Redémarrer Apache
sudo systemctl restart apache2
```

## 📁 Arborescence des fichiers créés

```
/var/www/
├── dolibarr/
│   ├── htdocs/              # Racine web Dolibarr
│   ├── documents/           # Stockage fichiers
│   └── [autres dossiers]
├── glpi/
│   ├── public/              # Racine web GLPI
│   ├── files/               # Stockage fichiers
│   ├── config/              # Configuration
│   └── [autres dossiers]
└── html/                    # Page par défaut Apache (protégée)

/etc/ssl/myca/
├── ca.key                   # Clé privée CA (PRIVÉE - 600)
├── ca.crt                   # Certificat CA
├── ca.srl                   # Numéro de série CA
├── dolibarr.nc.woze.lab.key # Clé privée Dolibarr (PRIVÉE - 600)
├── dolibarr.nc.woze.lab.crt # Certificat Dolibarr
├── dolibarr.nc.woze.lab.csr # CSR Dolibarr
├── dolibarr.nc.woze.lab.cnf # Config OpenSSL Dolibarr
├── glpi.nc.woze.lab.key     # Clé privée GLPI (PRIVÉE - 600)
├── glpi.nc.woze.lab.crt     # Certificat GLPI
├── glpi.nc.woze.lab.csr     # CSR GLPI
├── glpi.nc.woze.lab.cnf     # Config OpenSSL GLPI
├── client.key               # Clé privée client (PRIVÉE - 600)
├── client.crt               # Certificat client
├── client.csr               # CSR client
├── client.cnf               # Config OpenSSL client
└── clients/
    ├── ca-a-importer.crt    # CA à distribuer aux utilisateurs
    └── client.p12           # Certificat client PKCS12

/etc/apache2/
├── .htpasswd                # Fichier de mots de passe Apache
└── sites-available/
    ├── 000-default.conf     # VirtualHost par défaut (protégé)
    ├── dolibarr.conf        # VirtualHost Dolibarr
    └── glpi.conf            # VirtualHost GLPI
```

## 🔒 Considérations de sécurité

### ⚠️ Environnement de développement/test uniquement

**Ce script est conçu pour :**
- Environnements de développement
- Environnements de test
- Démonstrations
- Formation

**NE PAS utiliser en production sans modifications** :

1. **Certificats auto-signés** : Non reconnus par les navigateurs publics
2. **Mots de passe par défaut** : Doivent être changés
3. **Configuration basique** : Sécurité minimale

### 🛡️ Recommandations pour la production

#### 1. Certificats SSL
```bash
# Utiliser Let's Encrypt pour des certificats valides
apt install certbot python3-certbot-apache
certbot --apache -d dolibarr.example.com
```

#### 2. Mots de passe
```bash
# Générer des mots de passe forts
openssl rand -base64 32
```

#### 3. Pare-feu
```bash
# Configurer UFW
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

#### 4. Fail2Ban
```bash
# Protection contre brute-force
apt install fail2ban
systemctl enable fail2ban
```

#### 5. Mises à jour
```bash
# Automatiser les mises à jour de sécurité
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

#### 6. Sauvegarde
```bash
# Script de sauvegarde bases de données
mysqldump -u root -p --all-databases > backup_$(date +%Y%m%d).sql

# Sauvegarde fichiers
tar czf backup_files_$(date +%Y%m%d).tar.gz /var/www/dolibarr/documents /var/www/glpi/files
```

#### 7. Monitoring
```bash
# Installer monitoring
apt install monit
# Configurer surveillance Apache, MariaDB, espace disque
```

### 🔐 Durcissement de la sécurité

#### Apache
```apache
# Masquer la version d'Apache
ServerTokens Prod
ServerSignature Off

# Headers de sécurité
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'"
```

#### MariaDB
```sql
-- Supprimer les utilisateurs anonymes
DELETE FROM mysql.user WHERE User='';

-- Supprimer la base de données test
DROP DATABASE IF EXISTS test;

-- Restreindre l'accès root au localhost uniquement
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

FLUSH PRIVILEGES;
```

#### PHP
```ini
; php.ini - Configuration sécurisée
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

## 📊 Architecture du système

```
┌─────────────────────────────────────────────────────────┐
│                    UTILISATEUR                          │
│              (Navigateur avec CA importé)               │
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
│              INFRASTRUCTURE SSL/TLS                     │
│  ┌──────────────────────────────────────────────────┐   │
│  │  CA Interne (/etc/ssl/myca/)                     │   │
│  │  ├── ca.crt / ca.key (Autorité racine)           │   │
│  │  ├── dolibarr.nc.woze.lab.crt/.key               │   │
│  │  ├── glpi.nc.woze.lab.crt/.key                   │   │
│  │  └── client.p12 (Certificat client)              │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 📚 Ressources et documentation

### Documentation officielle

**Dolibarr** :
- Site officiel : https://www.dolibarr.org/
- Documentation : https://wiki.dolibarr.org/
- GitHub : https://github.com/Dolibarr/dolibarr

**GLPI** :
- Site officiel : https://glpi-project.org/
- Documentation : https://glpi-install.readthedocs.io/
- GitHub : https://github.com/glpi-project/glpi

**Apache** :
- Documentation SSL/TLS : https://httpd.apache.org/docs/2.4/ssl/
- VirtualHost : https://httpd.apache.org/docs/2.4/vhosts/

**MariaDB** :
- Documentation : https://mariadb.com/kb/en/documentation/
- Sécurité : https://mariadb.com/kb/en/securing-mariadb/

**OpenSSL** :
- Documentation : https://www.openssl.org/docs/
- Cookbook : https://www.feistyduck.com/library/openssl-cookbook/

### Tutoriels recommandés

1. **Sécurisation Apache** : https://httpd.apache.org/docs/2.4/misc/security_tips.html
2. **Durcissement MariaDB** : https://mariadb.com/kb/en/securing-mariadb/
3. **Let's Encrypt** : https://certbot.eff.org/

## 🤝 Support et contribution

### Signaler un problème

Si vous rencontrez un problème :

1. Vérifier la section [Dépannage](#-dépannage)
2. Consulter les logs Apache et MariaDB
3. Documenter les étapes de reproduction
4. Inclure les messages d'erreur complets

### Améliorations possibles

- [ ] Support de plusieurs distributions Linux
- [ ] Option de certificats Let's Encrypt
- [ ] Script de désinstallation
- [ ] Sauvegarde automatique pré-installation
- [ ] Validation des prérequis avant installation
- [ ] Mode silencieux (non-interactif)
- [ ] Script de mise à jour Dolibarr/GLPI
- [ ] Configuration Fail2Ban automatique
- [ ] Monitoring avec Prometheus/Grafana

## 📝 Changelog

### Version 1.0 (Actuelle)
- ✅ Installation automatisée Dolibarr 17.0.0
- ✅ Installation automatisée GLPI 10.0.15
- ✅ Création CA interne avec certificats SSL/TLS
- ✅ Configuration Apache avec VirtualHosts sécurisés
- ✅ Bases de données MariaDB dédiées
- ✅ Protection page par défaut Apache
- ✅ Génération certificats client PKCS12
- ✅ Configuration DNS local via /etc/hosts
- ✅ Support TLS 1.2 et 1.3 uniquement

## 📄 Licence

Ce script est fourni "tel quel", sans garantie d'aucune sorte. Utilisation à vos risques et périls.

**Recommandation** : Tester dans un environnement virtuel avant tout déploiement.

## ⚖️ Avertissement juridique

Les logiciels installés (Dolibarr, GLPI) ont leurs propres licences :
- **Dolibarr** : GPL v3+
- **GLPI** : GPL v3+

Respecter les termes de ces licences lors de l'utilisation.

---

**Développé pour** : Environnements de développement et test
**Auteur** : Script d'installation automatisée
**Dernière mise à jour** : 2024

