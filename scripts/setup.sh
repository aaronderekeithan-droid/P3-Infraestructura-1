#!/bin/bash
# Práctica 3 · Infraestructura 1 — Preparación de los servidores de la DMZ
# Autor: Aaron Hernández (2025-0800)
#
# Uso: sudo bash setup.sh caja | inventario | db
# Antes de ejecutar, cambiar CLAVE (la clave real NO se sube al repositorio).
set -e
[ "$EUID" -ne 0 ] && { echo "Usa sudo"; exit 1; }
ROL="$1"
CLAVE="CAMBIA_ESTA_CLAVE"
[ "$CLAVE" = "CAMBIA_ESTA_CLAVE" ] && { echo "Edita CLAVE primero"; exit 1; }
case "$ROL" in
  caja)       IP="10.8.27.2"; NOMBRE="Sistema de Caja" ;;
  inventario) IP="10.8.27.3"; NOMBRE="Sistema de Inventario" ;;
  db)         IP="10.8.27.4"; NOMBRE="DB Server" ;;
  *) echo "Rol invalido: caja | inventario | db"; exit 1 ;;
esac
GW="10.8.27.1"
IFACE=$(ip -o link show | awk -F': ' '$2!="lo"{print $2; exit}')
export DEBIAN_FRONTEND=noninteractive
 
apt-get update
if [ "$ROL" = "db" ]; then
  apt-get install -y mariadb-server openssh-server
  systemctl enable mariadb && systemctl restart mariadb
else
  apt-get install -y apache2 openssh-server
  echo "<h1>${NOMBRE}</h1><p>${IP}</p>" > /var/www/html/index.html
  systemctl enable apache2 && systemctl restart apache2
fi
 
id -u admin >/dev/null 2>&1 || useradd -m -s /bin/bash admin
echo "admin:${CLAVE}" | chpasswd
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/00-lab.conf
systemctl enable ssh && systemctl restart ssh
 
# El firewall solo permite archive.ubuntu.com y security.ubuntu.com
sed -i -E 's|https?://[a-z]{2}\.archive\.ubuntu\.com|http://archive.ubuntu.com|g' /etc/apt/sources.list
 
mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
mv /etc/netplan/50-cloud-init.yaml /root/50-cloud-init.yaml.bak 2>/dev/null || true
cat > /etc/netplan/01-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    ${IFACE}:
      addresses: [${IP}/28]
      routes: [{to: 0.0.0.0/0, via: ${GW}}]
      nameservers: {addresses: [8.8.8.8]}
EOF
chmod 600 /etc/netplan/01-lab.yaml
sync && shutdown -h now