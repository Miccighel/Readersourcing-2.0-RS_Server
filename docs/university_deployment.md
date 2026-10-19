# University deployment

The first network deployment is limited to university networks and the university VPN. Internet access is not
authorized. The intended domain is `readersourcing.org`; its DNS destination and final hostname will be agreed
with the DNS administrator. HTTPS termination, permitted network ranges and the SMTP relay still require confirmation.
This is a preparation record, not an instruction to publish DNS, open ports or replace the working private instance.

## Network and hostname

Readers must use an approved university network or connect to the university VPN. Confirm the actual source
networks and the permitted path to the service; do not infer allowed ranges from one SSH client address or allow
every private address range. A domain name does not change firewall rules or provide a route through the VPN.
An Internet facing entry point would require a separate decision and review.

A read only check on October 19 found the existing application listener on `127.0.0.1:33030`, with no TCP listeners
on ports 80 or 443. The checked Nginx, Apache, Caddy and Traefik host services were not active. This does not identify
or rule out a university proxy on another host. No ingress or firewall configuration was changed by that check.

A temporary university hostname can be used before `readersourcing.org` is ready, provided that it resolves and
routes from the permitted networks and is covered by a trusted HTTPS certificate. Agree that origin before changing
application settings or generating PDFs for other readers. Do not use a plain HTTP login or bypass certificate
validation while waiting for the final DNS arrangement.

Confirm whether the final origin is `https://readersourcing.org` or an agreed subdomain before generating PDFs for
real readers. The DNS administrator must choose the appropriate record for the actual ingress. A conventional
CNAME cannot coexist with the zone apex's SOA and NS records: the apex needs suitable A/AAAA records or the DNS
provider's supported alias mechanism. A subdomain can use a CNAME when appropriate. See
[RFC 2181, section 10.1](https://www.rfc-editor.org/rfc/rfc2181.html#section-10.1).

Verify the resulting route from the intended reader networks. A successful SSH tunnel to the current loopback
trial is not proof that the domain works over the VPN or the Internet.
Readers outside the university network must also connect to the VPN before following email confirmation, password
recovery or PDF rating links. A publicly distributed browser extension does not make its server reachable.

## HTTPS and mail

Ask who operates the reverse proxy, owns the certificate and manages its renewal. A VPN does not replace HTTPS
for credentials and application sessions. An approved university certificate or a valid publicly trusted certificate
can be used. [Let's Encrypt DNS validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge) can validate
a domain whose web service is not publicly reachable, when the required public DNS challenge can be managed.
Do not disable certificate checks or open the backend merely to obtain a certificate. No certificate or renewal
service has been configured by this preparation.

If HTTPS terminates on Homer, the application backend can remain on loopback. A university proxy on another host
cannot reach Homer's loopback listener: its backend route needs an explicitly approved interface and restriction
to that proxy. Do not expose the application backend to all interfaces or assume that Docker port publication is
restricted by a host firewall without verifying the effective
[Docker forwarding rules](https://docs.docker.com/engine/network/packet-filtering-firewalls/). PostgreSQL and Mailpit
must remain unavailable to network readers.

For mail, obtain the approved relay hostname, port, TLS requirements, authentication method and permitted sender
identity. Confirm whether network access is allowed from the application network. Provide passwords or certificates
only through the protected installation workflow, never the repository or a shared report. Mailpit currently captures
synthetic messages; its successful connection check is not delivery through a university SMTP relay. Validate
registration, confirmation and password recovery with a dedicated recipient after the real relay is configured.

The current private application network intentionally blocks external retrieval. A real deployment needs an approved
egress route for DNS, HTTPS publication downloads and SMTP. Keep `RS_PDF_ALLOW_PRIVATE_NETWORKS=false`: reaching a
server through the VPN is not permission for arbitrary PDF URLs to access university private addresses.

## Application definition

Prepare a separate reviewed deployment definition rather than editing the installed trial settings or weakening
its configuration and inventory guards. Retain the private trial and its verified backups. Use synthetic accounts
only for acceptance; choose the real instance's database, storage and privacy settings explicitly.

Set `PUBLIC_BASE_URL` to the agreed HTTPS origin, `FORCE_SSL=true` and `CORS_ALLOWED_ORIGINS` to the required trusted
origins. Set `ASSUME_SSL=true` only if every application request arrives through the approved HTTPS terminating proxy.
Keep the backend inaccessible to arbitrary clients that could supply forged forwarding headers. Follow the
[production requirements](production.md), including request size, timeouts, resource limits and privacy settings.

Keep the signing secret and final origin stable for the real service. Changing the origin does not rewrite rating
links already embedded in PDFs. The present synthetic PDFs refer to the loopback trial; do not distribute them as
domain based publication links. Configure RS_Rate for the agreed server and check its host permission, login,
upload, download and rating flow before releasing it. Chrome publication remains deferred.

## Information for the administrator

Before requesting activation, confirm:

1. the chosen HTTPS hostname and DNS target, using a temporary university name if necessary;
2. the permitted university and VPN source networks, ingress operator and restricted backend route;
3. certificate issuer, HTTPS proxy, renewal ownership and trusted forwarding policy;
4. SMTP relay, TLS, authentication and permitted sender;
5. allowed outbound DNS, publication HTTPS and SMTP access;
6. the reviewed image, unresolved security findings and any explicitly accepted residual risk;
7. a separate application definition, verified backup and agreed application maintenance step.

For the initial infrastructure discussion, ask the colleague for a usable university HTTPS hostname, whether an
existing university proxy and certificate are available, and the permitted university and VPN network ranges.
These decisions are needed even while the final `readersourcing.org` DNS arrangement remains pending. Once they
are confirmed, prepare the separate service definition and check access from both permitted and nonpermitted
networks before activation. Do not change the existing private trial simply to test network reachability.

No host update, host reboot, DNS change, firewall change, certificate issuance, mail configuration, automatic startup
or recurring backup is performed by this document. Activation remains pending these decisions and its own explicit
review and acceptance checks.
