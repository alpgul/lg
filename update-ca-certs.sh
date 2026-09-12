#!/bin/bash
# Description: Custom CA Certificate Overlay Fix for webOS
# Author: Updated for ISRG Root X1/X2 & 2024 Intermediate Certs (E5, E6, R10, R11)

export STARTUP_SCRIPTS_DIR=/var/lib/webosbrew/init.d
export CERT_FIX_SCRIPT=${STARTUP_SCRIPTS_DIR}/overlay-letsencrypt-ca-certs-fix
export CERT_FIX_DIR=/home/certfix-overlay

if [ ! -d "${STARTUP_SCRIPTS_DIR}" ] ; then
    echo "---------- FIX FAILED ----------"
    echo "Hata: Homebrew Channel init.d dizini bulunamadı (${STARTUP_SCRIPTS_DIR})."
    echo "Lütfen TV'nizin rootlandığından emin olun."
    exit 1
fi

echo "Eski konfigürasyon ve geçici dizinler temizleniyor..."
rm -rf ${CERT_FIX_DIR}
mkdir -p ${CERT_FIX_DIR}/etc_ssl/certs
mkdir -p ${CERT_FIX_DIR}/usr_share_ca-certificates
mkdir -p ${CERT_FIX_DIR}/work-etc_ssl
mkdir -p ${CERT_FIX_DIR}/work-usr_share_ca-certificates

echo "Süresi dolan DST Root CA X3 sertifikası pasife alınıyor..."
cat /etc/ca-certificates.conf | sed '/^mozilla\/DST_Root_CA_X3.crt$/ s/./!&/' > ${CERT_FIX_DIR}/fixed-ca-certificates.conf

echo "Güncel Let's Encrypt Root ve Intermediate sertifikaları indiriliyor..."
curl -kL https://letsencrypt.org/certs/isrgrootx1.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/isrgrootx1.crt
curl -kL https://letsencrypt.org/certs/isrg-root-x2.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/isrg-root-x2.crt
curl -kL https://letsencrypt.org/certs/isrg-root-x2-cross-signed.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/isrg-root-x2-cross.crt
curl -kL https://letsencrypt.org/certs/2024/e5.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-e5.crt
curl -kL https://letsencrypt.org/certs/2024/e6.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-e6.crt
curl -kL https://letsencrypt.org/certs/2024/r10.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-r10.crt
curl -kL https://letsencrypt.org/certs/2024/r11.pem -o ${CERT_FIX_DIR}/usr_share_ca-certificates/letsencrypt-r11.crt

# Konfigürasyon listesine sertifikaları yaz
for cert in isrgrootx1.crt isrg-root-x2.crt isrg-root-x2-cross.crt letsencrypt-e5.crt letsencrypt-e6.crt letsencrypt-r10.crt letsencrypt-r11.crt; do
    grep -qxF "$cert" ${CERT_FIX_DIR}/fixed-ca-certificates.conf || echo "$cert" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf
done

echo "Açılış (Startup) overlay script'i oluşturuluyor..."
cat << 'EOF' > ${CERT_FIX_SCRIPT}
#!/bin/bash
# Overlay custom CA certificates and reload trust store on boot

CERT_FIX_DIR=/home/certfix-overlay

mount --bind ${CERT_FIX_DIR}/fixed-ca-certificates.conf /etc/ca-certificates.conf
mount -t overlay overlay -o lowerdir=/etc/ssl,upperdir=${CERT_FIX_DIR}/etc_ssl,workdir=${CERT_FIX_DIR}/work-etc_ssl /etc/ssl
mount -t overlay overlay -o lowerdir=/usr/share/ca-certificates,upperdir=${CERT_FIX_DIR}/usr_share_ca-certificates,workdir=${CERT_FIX_DIR}/work-usr_share_ca-certificates /usr/share/ca-certificates

update-ca-certificates --fresh

if command -v c_rehash >/dev/null 2>&1; then
    c_rehash /etc/ssl/certs
elif command -v openssl >/dev/null 2>&1; then
    openssl rehash /etc/ssl/certs
fi
EOF

chmod +x ${CERT_FIX_SCRIPT}

echo "Değişiklikler anlık uygulanıyor..."
${CERT_FIX_SCRIPT}

echo "--------------------------------------------------"
echo "Kurulum ve Güncelleme Tamamlandı!"
echo "X1 ve X2 doğrulamasını test etmek için çalıştırın:"
echo "curl -v https://valid-isrgrootx1.letsencrypt.org"
echo "curl -v https://valid-isrgrootx2.letsencrypt.org"
echo "--------------------------------------------------"
