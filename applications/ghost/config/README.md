# Ghost CMS Configuration

This directory contains configuration files for Ghost CMS.

## Directory Structure

```
ghost/
├── config/          # Configuration files
│   └── README.md   # This file
└── data/           # Ghost content and data
    └── content/    # Themes, images, and uploads
```

## Environment Variables

Ghost is configured via environment variables in `docker/.env`:

- `GHOST_MYSQL_ROOT_PASSWORD` - MySQL root password
- `GHOST_MYSQL_DATABASE` - Ghost database name
- `GHOST_MYSQL_USER` - Ghost database user
- `GHOST_MYSQL_PASSWORD` - Ghost database password
- `MAIL_SERVICE` - Email service provider (e.g., Mailgun)
- `MAIL_USER` - Email service username
- `MAIL_PASS` - Email service password
- `MAIL_FROM` - From address for emails

## URLs

- Frontend: https://future.{your-domain}
- Admin: https://webadmin.{your-domain}

## First-Time Setup

1. Access https://webadmin.{your-domain}/ghost
2. Create your admin account
3. Configure site settings
4. Choose or upload a theme
5. Start creating content

## Data Persistence

All Ghost data is stored in the `data/content/` directory, which is mounted as a Docker volume. This includes:
- Uploaded images
- Themes
- Site configuration
- Content database

The MySQL database is stored in a separate Docker volume managed by docker-compose.