#!/bin/bash

URL="https://example.com/health.html" # TODO - isi dengan website
LOG="status.log"
LOOP=1000  # jumlah pengulangan, bisa diubah

for i in $(seq 1 $LOOP); do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    # Ambil baris yang mengandung [PRIMARY] atau [BACKUP]
    STATUS=$(curl -s "$URL" | grep -o 'PRIMARY\|BACKUP')
    # Kalau tidak ditemukan, beri keterangan UNKNOWN
    if [[ -z $STATUS ]]; then
        STATUS="[UNKNOWN]"
    fi
    echo "$TIMESTAMP | $STATUS"
    echo "$TIMESTAMP | $STATUS" >> $LOG
    sleep 0.5
done

echo "Selesai! Hasil di $LOG"
