# Subdomain Configuration

This document outlines the subdomain structure for the multi-application infrastructure.

## Current Subdomains

| Subdomain | Service | Status | Description |
|-----------|---------|--------|-------------|
| www.goplasmatic.io | React Website | Active | Current main website (temporary) |
| goplasmatic.io | Redirect | Active | Redirects to www |
| grafana.goplasmatic.io | Grafana | Active | Monitoring dashboard |
| webadmin.goplasmatic.io | Ghost Admin | Ready | CMS admin interface |
| future.goplasmatic.io | Ghost Frontend | Ready | Future main website (Ghost) |

## DNS Configuration Required

Add the following DNS records to your domain registrar:

```
# A Records (replace with your actual public IP)
A     @          YOUR_PUBLIC_IP     # For root domain
A     www        YOUR_PUBLIC_IP     # For main website
A     grafana    YOUR_PUBLIC_IP     # For monitoring
A     webadmin   YOUR_PUBLIC_IP     # For Ghost CMS admin
A     future     YOUR_PUBLIC_IP     # For Ghost frontend preview

# Alternative: CNAME records if using a different setup
CNAME www        @
CNAME grafana    @
CNAME webadmin   @
CNAME future     @
```

## SSL Certificate Setup

After DNS propagation (usually 5-30 minutes), run SSL setup for each subdomain:

```bash
# Main website (includes root domain redirect)
./scripts/setup-ssl.sh main www.yourdomain.com your-email@domain.com YOUR_PUBLIC_IP

# Grafana monitoring
./scripts/setup-ssl.sh grafana grafana.yourdomain.com your-email@domain.com YOUR_PUBLIC_IP

# Ghost CMS Admin
./scripts/setup-ssl.sh webadmin webadmin.yourdomain.com your-email@domain.com YOUR_PUBLIC_IP

# Ghost CMS Frontend
./scripts/setup-ssl.sh future future.yourdomain.com your-email@domain.com YOUR_PUBLIC_IP

```

## Nginx Configuration

Each subdomain has its own Nginx configuration file:

- `website.conf` - Current main website (www.goplasmatic.io)
- `grafana.conf` - Monitoring dashboard
- `ghost-admin.conf` - Ghost CMS admin interface (enabled)
- `future.conf` - Ghost frontend preview (enabled)

## Adding New Services

To add a new service on a subdomain:

1. Create DNS A record pointing to your server IP
2. Create/enable Nginx configuration in `docker/nginx/sites-enabled/`
3. Add/uncomment the service in `docker-compose.yml`
4. Run SSL setup script for the new subdomain
5. Deploy with `docker compose up -d`

## Service URLs After Deployment

- **Current Website**: https://www.{your-domain} (React app - temporary)
- **Monitoring**: https://grafana.{your-domain}
- **Ghost Admin**: https://webadmin.{your-domain}/ghost
- **Ghost Preview**: https://future.{your-domain} (future main site)

## Notes

- Root domain redirects to www subdomain
- All HTTP traffic is redirected to HTTPS
- Each subdomain can have its own SSL certificate
- Rate limiting is applied to all subdomains
- Ghost CMS is configured with separate admin URL for security
- When ready to switch to Ghost CMS as main site:
  1. Update Ghost's `url` to https://www.{your-domain}
  2. Move React app to a different subdomain or retire it
  3. Update Nginx configurations accordingly