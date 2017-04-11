set -e

sudo cp .travis/pg_hba.conf $(psql -U postgres -c "SHOW hba_file" -At)

sudo service postgresql restart $TRAVIS_POSTGRESQL_VERSION
