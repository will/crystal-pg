set -e

AUTH_FILE=`psql -U postgres -c "SHOW hba_file" -At`
CONFIG_FILE=`psql -U postgres -c "SHOW config_file" -At`

# md5 authentication

sudo sed -i '1s/^/host	all	crystal_md5	127.0.0.1\/32	md5\n/' ${AUTH_FILE}
sudo sed -i '2s/^/host	all	crystal_md5	::1\/128	md5\n/' ${AUTH_FILE}

# ssl clientcert authentication

sudo sed -i '3s/^/hostssl all crystal_ssl 127.0.0.1\/32 cert clientcert=1\n/' ${AUTH_FILE}

mkdir ~/cert && cd ~/cert
openssl req -new -nodes -text -out ca.csr -keyout ca-key.pem -subj "/CN=certificate-authority"
openssl x509 -req -in ca.csr -text -extfile /etc/ssl/openssl.cnf -extensions v3_ca -signkey ca-key.pem -out ca-cert.pem
openssl req -new -nodes -text -out server.csr -keyout server-key.pem -subj "/CN=pg-server"
openssl x509 -req -in server.csr -text -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem
openssl req -new -nodes -text -out client.csr -keyout client-key.pem -subj "/CN=crystal_ssl"
openssl x509 -req -in client.csr -text -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem
chmod 600 *

sudo mkdir -p /etc/ssl/postgresql/
sudo cp ca-cert.pem server-cert.pem server-key.pem /etc/ssl/postgresql/
sudo chmod 700 /etc/ssl/postgresql
sudo chown -R postgres.postgres /etc/ssl/postgresql

sudo sed -i "s/^ssl_cert_file = .*/ssl_cert_file = '\/etc\/ssl\/postgresql\/server-cert.pem'/" ${CONFIG_FILE}
sudo sed -i "s/^ssl_key_file = .*/ssl_key_file = '\/etc\/ssl\/postgresql\/server-key.pem'/" ${CONFIG_FILE}
sudo sed -i -r "s/^#?ssl_ca_file = .*/ssl_ca_file = '\/etc\/ssl\/postgresql\/ca-cert.pem'/" ${CONFIG_FILE}

mkdir -p ~/.postgresql/
cp client-cert.pem client-key.pem ca-cert.pem ~/.postgresql/
cd ~/.postgresql/
mv ca-cert.pem root.crt
mv client-cert.pem crystal_ssl.crt
mv client-key.pem crystal_ssl.key
openssl verify -CAfile root.crt crystal_ssl.crt

# restart service

sudo service postgresql restart $TRAVIS_POSTGRESQL_VERSION
