# Intro

These are a couple of examples for making an ACI setup supporting SSL and custom domains, using the sidecar principle.  
The first example uses Nginx for reverse proxy and Certbot for handling the certificates.  
The second uses Caddy for reverse proxy and automatic handling (renewal) of certificates.  
As we are focussing on ACI and don't have a fixed IP address available DNS-01 challenge will be used to get the certificates from Letsencrypt. An overview of challenge types can be found [here](https://letsencrypt.org/docs/challenge-types/).    

Let's look at the (container) hosting options in Azure:

- **Option level 1**: VM vs container
1. Ubuntu VM provides a fixed IP, for which we can add an A record in our VPS, for certificates we could install Certbot on the VM itself.
2. Azure container:
    - **Option level 2**: Choosing between service to host the containers (Azure app service, Azure Container Instance, Azure container apps, Azure Kubernetes service), higher tiers have scalability, ease of setup etc. We default to ACI (most generic, cheapest). Full comparison [here](https://learn.microsoft.com/en-us/azure/container-apps/compare-options#container-option-comparisons)
    1. Azure container instance (ACI)
        - **Option level 3**: custom domain how?
        1. Via Azure resource config dashboard (ssl option) -> Not possible in case of ACI (where it is in Azure app service for example)
        2. ACI in virtual network, SSL is configured on the app gateway.
        3. Sidecar container
            - **Option level 4**: reverse proxying options
            1. Nginx (manually): Fetch certificate beforehand through manual dns challenge (easy option on Windows is through WSL for example), upload to Azure share and point to it in the nginx config. Renewal will also hage to be done manually.
            2. Nginx & Certbot (automatic option, more complex): cerbot (dns-cloudflare variant) fetches cert via dns challenge, places it in an Azure file share accessible by both containers, instead of exiting a wait loop is executed to renew the cert if needed. Nginx side will use an entrypoint script to wait until the certs are available (alt is to use a self-written openssl cert during startup), Nginx starts and will reload config via cron every day (in case of new certs by certbot).
            3. Nginx & letsencrypt: analogous to previous point.
            4. Caddy (auto, simple): build a custom image (for cloudflare dns api support, declare api token in caddyfile. Caddy starts up, fetches cert from letsencrypt and will auto refresh when needed.

As discussed earlier, ACI was chosen, being the cheaper and more generic container hosting option.  

The setup plan loosely consists of:  
1. Posessing / buying a domain.
2. Move domain management to Cloudflare (for the API permitting automated DNS challenge). Done by changing out namevservers in original VPS.
3. Making an Azure container context, registry and shares.
4. Local setup: testing (certificates fetched?) + image build and upload to ACR.
5. Azure deployment: They key is to declare a domain name for one of the containers in docker-compose.yml, this will make Azure create a fqdn for the container group. Enter this domain name as a CNAME record in the VPS configuration (Cloudflare).  
**Remark**: pay attention to resources, if deployment fails it is possible a higher tier is necessary (RAM and CPU can also be declared in the docker-compse.yml)

### Attention points
Azure file shares are used for transfer and persistance of certificate files between containers.  

phpmyadmin can be found in the configs,  it has no further use than be an example website to point to via reverse proxy.

### On YML limitation in case of ACI
Exposed ports must be the same on the in and outside, eg `-p 80:80` is good, `80:8080` won't work in Azure.  
Azure file shares mapped as volumes are only available as a root folder, sub folders can't be used directly, eg `caddydata:/data` -> OK, `caddydata/subfolder:/data` -> NOK

# Nginx & Certbot:
## Background:

In short we need to build custom images based on certbot and nginx locally, test certificate fetching, after which we upload to ACR. Two Azure file shares need to be prepared, one for certificates, the other for app configs (this volume can be the same for both apps/containers).

## Config files:
### Local

[Docker-compose.yml](nginx_certbot_local/Docker-compose.yml)  
The declared volumes are purely for testing but are functionally set up the same as the Azure yml further on.  
* Certbot specific volume: Has the config file with token that allows access to the Cloudflare API
* Nginx specific volume: Has the Nginx config file for reverse proxying, where the https segment points to the certificate files.
* Common: they have a common share for certificates, Certbot will place them, Nginx will read them.

[(nginx) Dockerfile](nginx_certbot_local/df_nginx/Dockerfile)  
The default nginx image will be adapted to restart on a daily basis (via cron) in case the certificate got renewed though the certbot container.  

[nginx-entrypoint.sh](nginx_certbot_local/df_nginx/nginx-entrypoint.sh)  
The default nginx startup command has been replaced with a loop that will first validate the existance of certificate files, only then will Nginx be allowed to start.  

[https_test.conf](nginx_certbot_local/nginx/https_test.conf)  
Reverse proxy config for http and https, the latter has declareations for the certificate files.  For testing, the HTML page is inline, in production http could be adapted to redirect to https.  

[cloudflare.ini](nginx_certbot_local/ini/cloudflare.ini)  
**Fill in API token from Cloudflare.**

[(certbot) Dockerfile](nginx_certbot_local/df_certbot/Dockerfile)  
Start from the certbot/dns-cloudflare but declare a custom entrypoint.sh.  

[certbot-entrypoint.sh](nginx_certbot_local/df_certbot/certbot-entrypoint.sh)  
Get the certificate from Letsencrypt using automatic DNS challenge with the help of the Cloudflare API. **Edit domain and email.**  
```bash
certbot certonly --dns-cloudflare --dns-cloudflare-credentials $ini_path/cloudflare.ini -d www.mydomain.com --test-cert --email mail@mail.com --non-interactive --agree-tos --dns-cloudflare-propagation-seconds 20
```
Moves the certificates to the volume. For this a function is declared that will read the source of the symlinks found under `etc/letsencrypt/live/www.mydomain.com`.  
Runs an infinite while loop that will do cerificate renewal if necessary, based on certificate file age, no unnecessazy calls are made.

### Azure

[Docker-compose.yml](nginx_certbot_az/Docker-compose.yml)  
Once the local image is pushed to ACR and the Azure file shares are present we can deploy with this docker-compose.  
* *phpmyadmin*: this container is an example.  
**Remark**: In one of the containers the domainname tag must be present.  
* *certbot* and *rproxy_certbot*: image tag refers to the ACR image.  

At the bottom the azure file shares are declared as volumes.  

Place `cloudflare.ini` as well as `https_test.conf` in the 'webcfgs' Azure file share. The latter needs to be adapted.

[https_prod.conf](nginx_certbot_local/nginx/https_prod.conf)  
In the server configs for both http as https:
```
location / {
        proxy_pass http://phpmyadmin:81;
    }
```
Optional, for redirecting http to https, replace the http config with:
```
server {
  listen 80;
  server_name mydomain.com www.mydomain.com;
  return 301 https://$host$request_uri;
}
```

## build / deploy:

```powershell
cd ./nginx_certbot_local
docker compose build
az login
az acr login --name myregistry.azurecr.io
docker tag localContainerName_rproxy_certbot myregistry.azurecr.io/rproxy_certbot
docker tag localContainerName_certbot myregistry.azurecr.io/certbot
docker compose push
cd ../nginx_certbot_az
docker login azure
docker context use myACIcontext
docker compose up
# validate -> az container [attach | logs | show] --resource-group myresourcegroup --name azcontainername
```

# Caddy:
## Background:

Like with previous containers we first need to build the image locally, test fetching of the certificate and upload the image to ACR. From which point Azure deployment is possible through a seperate docker-compose.

## Config files:
### Local

[Docker-compose.yml](caddy_local/Docker-compose.yml)  
* *nginx* container: purely for testing.  
* *caddy* container: Must have domainname tag and has two volumes, one for persisting caddy data, the other has the Caddyfile.  

[Dockerfile](caddy_local/Dockerfile)  
A custom Caddy image must be made to allow Cloudflare API support. [Source](github.com/caddy-dns/cloudflare)  

[Caddyfile](caddy_local/cfile/Caddyfile)  
Caddy config file, has proxying rules for custom domain. **Edit domain and Cloudflare token.**
```
..
www.mydomain.com {
	reverse_proxy phpmyadmin:81
	tls {
		dns cloudflare [token]
	}
}
```

### Azure:

[Docker-compose.yml](caddy_az/Docker-compose.yml)  
* *phpmyadmin* container: Example web app, default port needs to be changed as 80 and 443 are needed by Caddy.
* *caddy* container: Build is replaced by the image tag, which points to the previously pushed ACR image. Volumes are functionally the same as offline counterparts, just in Azure file shares.  

Just like with the ngix/certbot example two Azure shares are used and so need to be declared at the bottom.

Place local `Caddyfile` in 'caddyfile' Azure share.

### Cloudflare:

API token must have following permissions, otherwise the fetch through Caddy will fail  
* ZONE read
* DNS edit

Put security in CLoudflare at highest level, otherwise signed certificates are ignored.  
ssl/tls > encryption mode: full(strict)

## build / deploy:

```powershell
cd ./caddy_local
docker compose build
az login
az acr login --name myregistry.azurecr.io
docker tag localContainerName_caddy myregistry.azurecr.io/caddy
docker compose push
cd ../caddy_az
docker login azure
docker context use myACIcontext
docker compose up
# validate -> az container [attach | logs | show] --resource-group myresourcegroup --name azcontainername
```

# TODO

meer info cloudflare api (rechten), print screens?  
manueel ophalen via certbot cmd toevoegen? test arg toevoegen certbot cmd? dig cmd ter test txt record toevoegen?
