ARG MONGODB_VERSION=5.0.3

FROM mongo:${MONGODB_VERSION} as builder
LABEL maintainer="Jens Frey <authsec@coffeecrew.org>" Version="2021-10-31"

ARG PWNED_DB_BASE_URL="https://downloads.pwnedpasswords.com/passwords"
ARG PWNED_DB_FILENAME="pwned-passwords-sha1-ordered-by-count-v7.7z"
ARG BATCH_SIZE="5000000"
# Make sure to set that outside of /data/db as that directory is set up as a
# VOLUME and therefore will discard all data after it has been declared.
# This was declared in the base image
ARG DB_PATH="/data/hibp"

# Map to env variables
ENV PWNED_DB_BASE_URL="${PWNED_DB_BASE_URL}"
ENV PWNED_DB_FILENAME="${PWNED_DB_FILENAME}"
ENV BATCH_SIZE="${BATCH_SIZE}"
ENV DB_PATH="${DB_PATH}"

WORKDIR /tmp

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends curl p7zip-full time parallel && \
    curl -Ok "${PWNED_DB_BASE_URL}/${PWNED_DB_FILENAME}" && \
    7za x -so ${PWNED_DB_FILENAME} | sed 's/:/,/g' > ${PWNED_DB_FILENAME%.7z}.txt && \
    NO_LINES_TOTAL=$(wc -l ${PWNED_DB_FILENAME%.7z}.txt | cut -d' ' -f1) && \
    NO_CPUS=$(lscpu | grep '^CPU(s):' | tr -s ' ' | cut -d' ' -f2) && \
    NO_LINES_PER_FILE=$((NO_LINES_TOTAL/NO_CPUS + 1)) && \
    split -l ${BATCH_SIZE} ${PWNED_DB_FILENAME%.7z}.txt pwds- && \
    rm -f ${PWNED_DB_FILENAME} ${PWNED_DB_FILENAME%.7z}.txt
    
FROM builder

WORKDIR /tmp
RUN mkdir -p "${DB_PATH}" && \
    ulimit -a && \
    mongod --fork --syslog --journalCommitInterval 500 --syncdelay 120 --dbpath "${DB_PATH}" && \
    ls pwds-* | time parallel -j+0 --eta "mongoimport --uri 'mongodb://localhost:27017/hibp' --bypassDocumentValidation --batchSize=${BATCH_SIZE} --mode delete --fields '_id.binary(base64),c.int32()' --columnsHaveTypes --db hibp --collection pwndpwds --type csv --file {}" && \
    mongod --shutdown --dbpath /data/hibp && \
    rm -f pwds-* && \
    apt-get purge -y curl p7zip-full && \
    apt-get autoremove -y && \
    apt-get clean && \
    find /var/lib/apt/lists -type f | xargs rm && \
    find /var/log -type f -exec rm {} \; && \
    rm -rf /usr/share/man/* && \
    rm -rf /usr/share/doc/* && \
    rm -f /var/log/alternatives.log /var/log/apt/* && \
    rm -f /var/cache/debconf/*-old

CMD ["sh", "-c", "mongod --journalCommitInterval 500 --syncdelay 120 --dbpath ${DB_PATH}"]