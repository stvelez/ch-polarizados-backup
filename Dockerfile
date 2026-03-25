FROM alpine:3.22 AS mysql-client

RUN apk add --no-cache mysql-client mariadb-connector-c gnupg

FROM n8nio/n8n:latest

USER root

# MySQL client binaries and libs
COPY --from=mysql-client /usr/bin/mysqldump /usr/bin/mysqldump
COPY --from=mysql-client /usr/lib/libssl.so.3 /usr/lib/libssl.so.3
COPY --from=mysql-client /usr/lib/libcrypto.so.3 /usr/lib/libcrypto.so.3
COPY --from=mysql-client /usr/lib/libz.so.1 /usr/lib/libz.so.1
COPY --from=mysql-client /usr/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
COPY --from=mysql-client /usr/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1
COPY --from=mysql-client /usr/lib/mariadb/plugin /usr/lib/mariadb/plugin

# GPG binaries and libs from Alpine stage
COPY --from=mysql-client /usr/bin/gpg /usr/bin/gpg
COPY --from=mysql-client /usr/bin/gpg2 /usr/bin/gpg2
COPY --from=mysql-client /usr/bin/gpgconf /usr/bin/gpgconf
COPY --from=mysql-client /usr/lib/libgcrypt.so.20 /usr/lib/libgcrypt.so.20
COPY --from=mysql-client /usr/lib/libgpg-error.so.0 /usr/lib/libgpg-error.so.0
COPY --from=mysql-client /usr/lib/libassuan.so.0 /usr/lib/libassuan.so.0

RUN chmod +x /usr/bin/mysqldump /usr/bin/gpg /usr/bin/gpg2

USER node
