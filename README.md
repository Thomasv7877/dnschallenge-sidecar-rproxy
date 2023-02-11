# Intro

These are a couple of examples for making an ACI setup supporting SSL and custom domains, using the sidecar principle.  
The first example uses Nginx for reverse proxy and Certbot for handling the certificates.  
The second uses Caddy for reverse proxy and automatic handling (renewal) of certificates.  
As we are focussing on ACI and don't have a fixed IP address available DNS-01 challenge will be uses to get the certificates from Letsencrypt. An overview of challenge types can be found [here](https://letsencrypt.org/docs/challenge-types/).    

Let's look at the (container) hosting options in Azure:

setup = container groep / webapp in azure container instance (aci) uitvoeren met custom domain (ipv aci fqdn) en ssl support
- optie niv 1: vm vs container
1. ubuntu vm met fixed ip, a record voor dit ip in vps, certbot op vm zelf
2. azure container:
    - optie niv 2: keuze soort azure service om container te hosten -> (zie - azure container opties)
    1. Azure container instance (goedkoopst, meest generiek)
        - optie niv 3: ssl & custom domein hoe?
        1. via azure resource config dash (ssl) -> niet mogelijk voor ACI (wel va app service bv)
        2. ACI in virtueel netwerk, ssl ingesteld op app gateway die naar resource wijst
        3. sidecar container (= reverse proxy)
            - niv 4: reverse proxy opties
            1. nginx (manueel): dns challenge cert op voorhand opvragen (vb certbot in wsl) ne declarren in een nginx conf
            2. nginx & certbot (auto, complex): cerbot (dns-cloudflare variant) haalt cert op via dns challenge, plaatst het in door beide containers toegankelijke azure file share, ipv te exiten wordt wait loop uitgevoerd om cert evt te vernieuwen. nginx kant zal via entrypoint script gewacht worden tot certs beschikbaar zijn (alt is tijdens startup een zelfgeschreven openssl cert te gebruiken), nginx start en zal via cron elke dag config reloaden (voor geval nieuwe certs door certbot) -> (zie ./local_certbot)
            3. nginx & letsencrypt: analook aan 2
            4. caddy (auto, eenvoudig): custom image builden (voor cloudflare dns api suppor, api token in caddyfile declareren. caddy start op, haalt cert van letsencrypt op en zal auto verversen wanneer nodig

As discussed earlier, ACI has been chosen, being the cheaper and more generic container hosting option.  
The setup plan loosely consists of:  
domein kopen (transip is goedkoop)
domein verplaatsen naar cloudflare (voor dns challenge api, gratis): concreet nameservers wijzigen
azure container context en registry maken
lokale setup: testing + image build en push naar ACR -> (zie ./local_certbot & ## docker cmd gidsen)
azure deploy: (zie ## docker cmd gidsen) // opm! let op resources, evt hogere tier | meer resources in yml
	domainname bij 1 van de containers declareren om fqdn te krijgen voor aci groep, verkregen fqdn (check aci dash) ingeven als CNAME record in vps en ook gebruiken in rproxy config file
osticket spec: upgrade https://www.mydomain.com/csp/admin.php > filesystem plugin pad wijzigen

Azure file share for transfer and persistance of vertificate files between containers
PhpMyAdmin can be found in the configs, here it has no further use than be an example website to point to via reverse proxy.

On YML limitation in case of ACI:  
poorten moeten geexposed worden: vb -p 80:80, anders niet beschikbaar + in azure extra beperking dat in en uit poort zelfde moet zijn
azure file share moet apart gedeclareerd worden + wanneer gemapt aan service kan geen submap zijn van de file share, enkel root werkt

# Nginx & Certbot:
## Background:

Build the Caddy image that can connect to the Cloudflare API locally, test, then push to ACR.
Prepare two Azure file shares, one for Caddy data, one for the Caddyfile.


## Config files:
### Local

Docker-compose.yml  

(nginx) Dockerfile  
nginx-entrypoint.sh  

(certbot) Dockerfile  
certbot-entrypoint.sh

te editen files

### Azure

Docker-compose.yml  

## build / deploy:

alle cmd's

# Caddy:
## Background:

## Config files:
### Local

Docker-compose.yml   
Dockerfile 
CaddyFile

te editen files

### Azure:

Docker-compose.yml  

## build / deploy:

alle cmd's