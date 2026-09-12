#!/bin/bash

# Explicitly remove the old expired X3 certificate from the trust store
# Download current LetsEncrypt certificates and X2 cross-signed/2024 intermediate certs
# Create a post-boot script to overlay this cert data over the readonly filesystem and reload CA cert config on boot

export PURPOSE="Overlay our custom CA certificate configuration (to replace outdated CA certs) and update trust store with X1, X2 and 2024 intermediates"

export STARTUP_SCRIPTS_DIR=/var/lib/webosbrew/init.d

export CERT_FIX_SCRIPT=${STARTUP_SCRIPTS_DIR}/overlay-letsencrypt-ca-certs-fix
export CERT_FIX_DIR=/home/certfix-overlay

if [ ! -d "${STARTUP_SCRIPTS_DIR}" ] ; then
cat << EOM
----------
FIX FAILED
----------

Error: Homebrew Channel init.d directory does not exist

       ${STARTUP_SCRIPTS_DIR}

Before running this script, ensure you have rooted your TV.

To root your TV, visit https://rootmy.tv/ in your TV's browser.

EOM
exit 1
fi

# Önceki mount kilitlerini kaldır (Eğer dosya sistemi kilitlendiyse)
umount -l /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true
umount -l /etc/ca-certificates.conf 2>/dev/null || true
umount -l /etc/ssl 2>/dev/null || true
umount -l /usr/share/ca-certificates 2>/dev/null || true

# Eski fix dosyasını zorla temizle ki script güncellenebilsin
rm -f ${CERT_FIX_SCRIPT}
rm -rf ${CERT_FIX_DIR}

mkdir -p ${CERT_FIX_DIR}/etc_ssl/certs/
mkdir -p ${CERT_FIX_DIR}/usr_share_ca-certificates/
mkdir -p ${CERT_FIX_DIR}/work-etc_ssl/
mkdir -p ${CERT_FIX_DIR}/work-usr_share_ca-certificates/

echo "Removing reference to expired LetsEncrypt root CA certificate..."

cat /etc/ca-certificates.conf | sed '/^mozilla\/DST_Root_CA_X3.crt$/ s/./!&/' > ${CERT_FIX_DIR}/fixed-ca-certificates.conf

echo "Downloading current LetsEncrypt CA Certificates (X1, X2, Cross-signed, E5, E6, R10, R11)..."
echo

curl -kL https://letsencrypt.org/certs/isrgrootx1.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/isrgrootx1.crt
curl -kL https://letsencrypt.org/certs/isrg-root-x2.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/isrg-root-x2.crt
curl -kL https://letsencrypt.org/certs/isrg-root-x2-cross-signed.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/isrg-root-x2-cross.crt
curl -kL https://letsencrypt.org/certs/2024/e5.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-e5.crt
curl -kL https://letsencrypt.org/certs/2024/e6.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-e6.crt
curl -kL https://letsencrypt.org/certs/2024/r10.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-r10.crt
curl -kL https://letsencrypt.org/certs/2024/r11.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-r11.crt

echo "isrgrootx1.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "isrg-root-x2.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "isrg-root-x2-cross.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-e5.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-e6.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-r10.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-r11.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf

echo "Generating Bundle file for cURL and Browser..."
cp /etc/ssl/certs/ca-certificates.crt ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt 2>/dev/null || touch ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt
cat ${CERT_FIX_DIR}/usr_share_ca-certificates/*.crt >> ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt

echo "Generating OpenSSL Hash Symlinks (X2 Fix)..."
for certfile in ${CERT_FIX_DIR}/usr_share_ca-certificates/*.crt; do
    if command -v openssl >/dev/null 2>&1; then
        HASH=$(openssl x509 -hash -noout -in "$certfile" 2>/dev/null)
        HASH_OLD=$(openssl x509 -subject_hash_old -noout -in "$certfile" 2>/dev/null)
        [ -n "$HASH" ] && ln -sf "$certfile" "${CERT_FIX_DIR}/etc_ssl/certs/${HASH}.0"
        [ -n "$HASH_OLD" ] && ln -sf "$certfile" "${CERT_FIX_DIR}/etc_ssl/certs/${HASH_OLD}.0"
    fi
done

echo
echo "Creating startup certificate overlay script..."

cat << 'EOF' > ${CERT_FIX_SCRIPT}
#!/bin/bash
# Overlay our custom CA certificate configuration and update trust store
CERT_FIX_DIR=/home/certfix-overlay

mount --bind ${CERT_FIX_DIR}/fixed-ca-certificates.conf /etc/ca-certificates.conf
mount -t overlay overlay -o lowerdir=/etc/ssl,upperdir=${CERT_FIX_DIR}/etc_ssl,workdir=${CERT_FIX_DIR}/work-etc_ssl /etc/ssl
mount -t overlay overlay -o lowerdir=/usr/share/ca-certificates,upperdir=${CERT_FIX_DIR}/usr_share_ca-certificates,workdir=${CERT_FIX_DIR}/work-usr_share_ca-certificates /usr/share/ca-certificates

if [ -f "${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt" ]; then
    mount --bind ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
fi

update-ca-certificates --fresh

if command -v c_rehash >/dev/null 2>&1; then
    c_rehash /etc/ssl/certs
elif command -v openssl >/dev/null 2>&1; then
    openssl rehash /etc/ssl/certs 2>/dev/null || true
fi
EOF

chmod a+x ${CERT_FIX_SCRIPT}

echo
echo "Applying fixes immediately..."
${CERT_FIX_SCRIPT}

echo
echo "LetsEncrypt certificate fix configuration complete. Rebooting to apply fix..."

reboot
