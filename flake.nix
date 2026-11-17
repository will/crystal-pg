{
  description = "a postgres driver for crystal";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { nixpkgs, flake-utils, nix-filter, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        crystal = pkgs.crystal;

        pg_versions = builtins.map builtins.toString [ 18 17 16 15 14 ];
        default_pg = pkgs."postgresql_${builtins.head pg_versions}";

        certs = pkgs.stdenvNoCC.mkDerivation {
          name = "crystal-pg-test-certs";
          nativeBuildInputs = [ pkgs.openssl ];
          installPhase = ''
            mkdir $out

            cat > ca.ext <<'EOF'
            basicConstraints = critical, CA:TRUE
            keyUsage = critical, keyCertSign, cRLSign
            subjectKeyIdentifier = hash
            EOF

            cat > server.ext <<'EOF'
            basicConstraints = critical, CA:FALSE
            keyUsage = critical, digitalSignature, keyEncipherment
            extendedKeyUsage = serverAuth
            subjectAltName = IP:127.0.0.1
            EOF

            cat > client.ext <<'EOF'
            basicConstraints = critical, CA:FALSE
            keyUsage = critical, digitalSignature, keyEncipherment
            extendedKeyUsage = clientAuth
            EOF

            openssl req -new -nodes -text -out ca.csr -keyout ca-key.pem -subj "/CN=certificate-authority"
            openssl x509 -req -in ca.csr -text -signkey ca-key.pem -extfile ca.ext -days 3650 -out ca-cert.pem

            # An unrelated CA, used only as a bogus sslrootcert for the negative specs.
            openssl req -new -nodes -text -out other-ca.csr -keyout other-ca-key.pem -subj "/CN=other-certificate-authority"
            openssl x509 -req -in other-ca.csr -text -signkey other-ca-key.pem -extfile ca.ext -days 3650 -out other-ca-cert.pem

            openssl req -new -nodes -text -out server.csr -keyout server-key.pem -subj "/CN=pg-server"
            openssl x509 -req -in server.csr -text -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -extfile server.ext -days 3650 -out server-cert.pem

            openssl req -new -nodes -text -out client.csr -keyout client-key.pem -subj "/CN=crystal_ssl"
            openssl x509 -req -in client.csr -text -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -extfile client.ext -days 3650 -out client-cert.pem

            openssl verify -CAfile ca-cert.pem server-cert.pem
            openssl verify -CAfile ca-cert.pem client-cert.pem

            mv *.pem $out
          '';
          dontUnpack = true; # allows not giving a src
          dontPatch = true;
          dontConfigure = true;
          dontBuild = true;
          dontFixup = true;
        };

        tempdbSrc = pg: ''
          export PATH=${pg}/bin:"$PATH"

          tmpdir="$(mktemp -d)"

          export PGDATA="$tmpdir"
          export PGHOST="$tmpdir"
          export PGUSER=postgres
          export PGDATABASE=postgres
          while
            port=$(shuf -n 1 -i 49152-65535)
            ${pkgs.unixtools.netstat}/bin/netstat -atun | grep -q "$port"
          do
            continue
          done
          export PGPORT=$port
          export DATABASE_URL=postgres://127.0.0.1:$port/

          trap 'pg_ctl stop -m i; rm -rf "$tmpdir"' sigint sigterm exit

          PGTZ=UTC initdb --no-locale --encoding=UTF8 --no-sync -U "$PGUSER" --auth=trust > /dev/null

          #options="-F -c listen_addresses=\"\" -k $PGDATA"
          options="-F -c port=$port -k $PGDATA"

          cp ${certs}/*.pem "$tmpdir"
          chmod 600 "$tmpdir"/*.pem
          cert_opts="-c ssl=on -c ssl_cert_file='server-cert.pem' -c ssl_key_file='server-key.pem' -c ssl_ca_file='ca-cert.pem' "

          echo "
          local   all       postgres                     trust
          host    all       postgres       127.0.0.1/32  trust
          host    all       postgres       ::1/128       trust
          host    all       crystal_md5    127.0.0.1/32  md5
          hostssl all       crystal_ssl    127.0.0.1/32  cert
          host    all       crystal_clear  127.0.0.1/32  password
          host    all       crystal_scram  127.0.0.1/32  scram-sha-256
          " > $tmpdir/pg_hba.conf

          pg_ctl start -o "$options" -o "$cert_opts" #--log $tmpdir/pglogs.log

          export CRYSTAL_PG_CERT_DIR=${certs}
          "$@"
        '';

        specs = crystal.buildCrystalPackage {
          name = "specs";
          src = specSrc;
          buildPhase = ''
            echo 'require "./spec/**"' > specs.cr
          '';
          installPhase = "mkdir -p $out/bin && crystal build --error-on-warnings specs.cr -o $out/bin/specs";
          shardsFile = specSrc + "/shards.nix";
          preConfigure = "touch shard.lock";
          lockfile = null;
          doCheck = false;
          dontPatch = true;
          dontFixup = true;
          doInstallCheck = false;
          buildInputs = [ pkgs.gmp ];
        };

        filterSrc = files: (nix-filter.lib { root = ./.; include = [ "src" "spec" ] ++ files; });
        specSrc = filterSrc [ "shard.lock" "shards.nix" "shard.yml" ];
        check = pkgs.writeScriptBin "check" "nix build .#check --keep-going --print-build-logs";
        tempdb = pkgs.writeScriptBin "tempdb" (tempdbSrc default_pg);
      in
      rec {

        devShells.default = pkgs.mkShell {
          buildInputs = [ crystal pkgs.crystal2nix pkgs.shards pkgs.gmp check tempdb ]
            # ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.apple-sdk_15 ]
            ;
        };

        packages = {
          check = pkgs.linkFarmFromDrvs "crystal-pg-all-checks" (builtins.attrValues checks);
          inherit certs specs;
          };

        checks = {
          format = pkgs.stdenvNoCC.mkDerivation {
            name = "format";
            src = (filterSrc [ ]);
            installPhase = "mkdir $out && crystal tool format --check";
            nativeBuildInputs = [ crystal ];
            dontPatch = true;
            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;
          };
        } // pkgs.lib.genAttrs pg_versions (ver:
          pkgs.stdenvNoCC.mkDerivation {
            name = "specs-${ver}";
            nativeBuildInputs = [ specs (pkgs.writeScriptBin "tempdb" (tempdbSrc pkgs."postgresql_${ver}")) ];
            installPhase = "mkdir $out && tempdb specs";
            dontUnpack = true; # allows not giving a src
            doCheck = false;
            dontPatch = true;
            dontBuild = true;
            dontFixup = true;
          }
        );
      }

    );
}
