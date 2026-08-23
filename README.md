# listmonk Chatty

Deployment scaffold for running listmonk with a managed PostgreSQL database.

## Required environment variables

Set these in the deployment environment; never commit credentials:

- `LISTMONK_db__host`
- `LISTMONK_db__port` (normally `5432`)
- `LISTMONK_db__user`
- `LISTMONK_db__password`
- `LISTMONK_db__database`
- `LISTMONK_db__ssl_mode` (for managed Postgres, normally `require`)
- `LISTMONK_ADMIN_USER`
- `LISTMONK_ADMIN_PASSWORD`

The official listmonk image uses port `9000` and supports configuration through `LISTMONK_*` environment variables. The database schema installation is idempotent.

## Important

listmonk requires PostgreSQL for persistent data. The application container itself should not be treated as persistent storage.
