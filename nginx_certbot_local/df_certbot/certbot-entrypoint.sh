#!/bin/sh

cert_path=/etc/letsencrypt/live/www.mydomain.com
volume_path=/etc/certs
ini_path=/etc/cloudflare_api

function move_certs(){
    cp -f $(readlink -f $cert_path/fullchain.pem) $volume_path/fullchain.pem
    cp -f $(readlink -f $cert_path/privkey.pem) $volume_path/privkey.pem
}

cd $ini_path
certbot certonly --dns-cloudflare --dns-cloudflare-credentials $ini_path/cloudflare.ini -d www.mydomain.com --test-cert --email mail@mail.com --non-interactive --agree-tos --dns-cloudflare-propagation-seconds 20
#mkdir /etc/certs 
touch $volume_path/fullchain.pem
touch $volume_path/privkey.pem
move_certs
#while true; do sleep 1000; done # zal crontab nog kunnen uitvoeren? icm docker compuse up blijft cmd open..
trap exit TERM
while :
    do 
    pre_renew_time=$(stat -c %y $cert_path/fullchain.pem)
    certbot renew #--force-renewal
    post_renew_time=$(stat -c %y $cert_path/fullchain.pem)
    if [[ "$pre_renew_time" != "$post_renew_time" ]]; then
        move_certs
        #echo Forced renewal of certs handled
    fi
    sleep 12h & wait ${!}
    done
