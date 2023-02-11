#!/bin/sh
cert=/etc/certs/fullchain.pem

while [ ! -f  $cert ]; do
    echo "waiting on certbot to provide cert"
    sleep 10
done
cron
nginx -g "daemon off;" # default nginx entry cmd, moet ';' hebben want deel van .conf
