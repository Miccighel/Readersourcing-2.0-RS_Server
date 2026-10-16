# University deployment

The intended domain is `readersourcing.org`. Its DNS destination, final hostname, access policy, HTTPS termination
and SMTP relay still require agreement with the university administrators. Homer is behind the university VPN.
This is a preparation record, not an instruction to publish DNS, open ports or replace the working private instance.

## Network and hostname

Agree whether readers must connect to the VPN or whether an approved public university proxy will provide access.
A domain name does not change firewall rules or provide a route through the VPN. For VPN access, confirm how the
name resolves and routes from a connected workstation. For Internet access, identify an approved ingress and its
restricted backend connection; do not expose Homer, Docker, PostgreSQL or Mailpit directly.

Confirm whether the final origin is `https://readersourcing.org` or an agreed subdomain before generating PDFs for
real readers. The DNS administrator must choose the appropriate record for the actual ingress. A conventional
CNAME cannot coexist with the zone apex's SOA and NS records: the apex needs suitable A/AAAA records or the DNS
provider's supported alias mechanism. A subdomain can use a CNAME when appropriate. See
[RFC 2181, section 10.1](https://www.rfc-editor.org/rfc/rfc2181.html#section-10.1).

Verify the resulting route from the intended reader networks. A successful SSH tunnel to the current loopback
trial is not proof that the domain works over the VPN or the Internet.
If access remains limited to the VPN, readers must also connect before following email confirmation, password
recovery or PDF rating links. A publicly distributed browser extension does not make its server reachable.

## HTTPS and mail

Ask who operates the reverse proxy, owns the certificate and manages its renewal. A VPN does not replace HTTPS
for credentials and application sessions. An approved university certificate or a valid publicly trusted certificate
can be used. [Let's Encrypt DNS validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge) can validate
a domain whose web service is not publicly reachable, when the required public DNS challenge can be managed.
Do not disable certificate checks or open the backend merely to obtain a certificate. No certificate or renewal
service has been configured by this preparation.

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

1. the final hostname and its DNS target;
2. VPN only or Internet access, the ingress operator and the permitted backend route;
3. certificate issuer, HTTPS proxy, renewal ownership and trusted forwarding policy;
4. SMTP relay, TLS, authentication and permitted sender;
5. allowed outbound DNS, publication HTTPS and SMTP access;
6. the reviewed image, unresolved security findings and any explicitly accepted residual risk;
7. a separate application definition, verified backup and agreed application maintenance step.

No host update, host reboot, DNS change, firewall change, certificate issuance, mail configuration, automatic startup
or recurring backup is performed by this document. Activation remains pending these decisions and its own explicit
review and acceptance checks.
