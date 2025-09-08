# Subdomain Configuration

## Active Services

| Subdomain | Service | Description |
|-----------|---------|-------------|
| www.goplasmatic.io | Ghost CMS | Main website |
| webadmin.goplasmatic.io | Ghost Admin | CMS admin interface |
| reframeapi.goplasmatic.io | Reframe API | SWIFT message transformation |
| sandbox.goplasmatic.io | Sandbox | Testing environment |
| grafana.goplasmatic.io | Grafana | Monitoring dashboard |

## DNS Configuration

Add these A records in your DNS provider (GoDaddy):

```
A     @           YOUR_PUBLIC_IP     # Root domain
A     www         YOUR_PUBLIC_IP     # Main website (Ghost)
A     webadmin    YOUR_PUBLIC_IP     # Ghost admin
A     reframeapi  YOUR_PUBLIC_IP     # API service
A     sandbox     YOUR_PUBLIC_IP     # Sandbox
A     grafana     YOUR_PUBLIC_IP     # Monitoring
```

## SSL Certificates

SSL certificates are automatically configured via Let's Encrypt after DNS propagation.