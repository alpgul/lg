#!/bin/bash

# Explicitly remove the old expired X3 certificate from the trust store
# Download current LetsEncrypt certificates and use mount --bind method for webOS compatibility

export PURPOSE="Bind-mount custom CA certificates to bypass read-only filesystem limitations"

export STARTUP_SCRIPTS_DIR=/var/lib/webosbrew/init.d
export CERT_FIX_SCRIPT=${STARTUP_SCRIPTS_DIR}/overlay-letsencrypt-ca-certs-fix
export CERT_FIX_DIR=/home/certfix-overlay

if [ ! -d "${STARTUP_SCRIPTS_DIR}" ] ; then
cat << EOM
----------
FIX FAILED
----------
Error: Homebrew Channel init.d directory does not exist (${STARTUP_SCRIPTS_DIR})
Ensure you have rooted your TV via https://rootmy.tv/
EOM
exit 1
fi

# Önceki mount kilitlerini temizle
umount -l /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true
umount -l /etc/ca-certificates.conf 2>/dev/null || true

# Eski kalıntıları temizle
rm -f ${CERT_FIX_SCRIPT}
rm -rf ${CERT_FIX_DIR}

mkdir -p ${CERT_FIX_DIR}/etc_ssl/certs/
mkdir -p ${CERT_FIX_DIR}/usr_share_ca-certificates/

echo "Removing reference to expired LetsEncrypt root CA certificate..."
cat /etc/ca-certificates.conf | sed '/^mozilla\/DST_Root_CA_X3.crt$/ s/./!&/' > ${CERT_FIX_DIR}/fixed-ca-certificates.conf

echo "Downloading current LetsEncrypt CA Certificates (X1, X2, Cross-signed, E5, E6, R10, R11)..."
curl -kL https://letsencrypt.org/certs/isrgrootx1.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/isrgrootx1.crt
curl -kL https://letsencrypt.org/certs/isrg-root-x2.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/isrgrootx2.crt
curl -kL https://letsencrypt.org/certs/isrg-root-x2-cross-signed.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/isrg-root-x2-cross.crt
curl -kL https://letsencrypt.org/certs/2024/e5.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-e5.crt
curl -kL https://letsencrypt.org/certs/2024/e6.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-e6.crt
curl -kL https://letsencrypt.org/certs/2024/r10.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-r10.crt
curl -kL https://letsencrypt.org/certs/2024/r11.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-r11.crt

echo "isrgrootx1.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "isrgrootx2.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "isrg-root-x2-cross.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-e5.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-e6.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-r10.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
echo "letsencrypt-r11.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf

echo "Generating Bundle file for cURL and Browser..."
cp /etc/ssl/certs/ca-certificates.crt ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt 2>/dev/null || touch ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt
cat ${CERT_FIX_DIR}/usr_share_ca-certificates/*.crt >> ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt

echo "Generating OpenSSL Hash Symlinks..."
for certfile in ${CERT_FIX_DIR}/usr_share_ca-certificates/*.crt; do
    if command -v openssl >/dev/null 2>&1; then
        HASH=$(openssl x509 -hash -noout -in "$certfile" 2>/dev/null)
        HASH_OLD=$(openssl x509 -subject_hash_old -noout -in "$certfile" 2>/dev/null)
        [ -n "$HASH" ] && ln -sf "$certfile" "${CERT_FIX_DIR}/etc_ssl/certs/${HASH}.0"
        [ -n "$HASH_OLD" ] && ln -sf "$certfile" "${CERT_FIX_DIR}/etc_ssl/certs/${HASH_OLD}.0"
    fi
done

echo "Creating startup certificate bind-mount script..."

cat << 'EOF' > ${CERT_FIX_SCRIPT}
#!/bin/bash
# Bind-mount custom CA certificates configuration on boot
CERT_FIX_DIR=/home/certfix-overlay

mount --bind ${CERT_FIX_DIR}/fixed-ca-certificates.conf /etc/ca-certificates.conf
mount --bind ${CERT_FIX_DIR}/etc_ssl/certs /etc/ssl/certs
mount --bind ${CERT_FIX_DIR}/usr_share_ca-certificates /usr/share/ca-certificates

if [ -f "${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt" ]; then
    mount --bind ${CERT_FIX_DIR}/etc_ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
fi

update-ca-certificates --fresh 2>/dev/null || true
EOF

chmod a+x ${CERT_FIX_SCRIPT}

echo "Applying fixes immediately..."
${CERT_FIX_SCRIPT}

echo "Certificate fix configuration complete. Rebooting to apply fix..."
reboot
