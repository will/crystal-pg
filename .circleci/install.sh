set -e

apt-get update
apt-get install gnupg curl lsb-release -y
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install $CIRCLE_JOB -y

