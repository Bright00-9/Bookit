# BookIt

A microservices booking platform, built as a DevOps learning project:
Docker → CI/CD → Kubernetes → AWS.

## Architecture

```
Browser → frontend (Nginx, :5173)
              │
              ▼
        api-gateway (:8080)  ← only backend port exposed to your host
         │      │        │
         ▼      ▼        ▼
   auth-svc  availability-svc  booking-svc → RabbitMQ → notification-svc
         │           │              │
         └───────────┴──────────────┘
                      ▼
                  Postgres
```

- **frontend** — React SPA, talks only to api-gateway
- **api-gateway** — single entry point; issues httpOnly session cookie, rate limits, CORS
- **auth-service** — signup/login, JWT issuing
- **availability-service** — slot management, race-safe booking capacity
- **booking-service** — orchestrates bookings across services, publishes events
- **notification-service** — consumes booking events, sends notifications (logged to console for now)

## Running locally with Docker Compose

```bash
cp .env.example .env
# edit .env - at minimum change JWT_SECRET to a real random string

docker compose up --build
```

First run will:
1. Start Postgres and RabbitMQ, wait until both report healthy
2. Run the `migrate` job once, applying every service's SQL migrations
3. Build and start all 5 backend services
4. Build and start the frontend (served by Nginx)

Then visit **http://localhost:5173**.

Useful commands while it's running:
```bash
docker compose ps                       # see status of every container
docker compose logs -f booking-service  # tail logs for one service
docker compose logs -f notification-service  # watch notifications get consumed
docker compose down                     # stop everything
docker compose down -v                  # stop everything AND wipe the Postgres volume
```

RabbitMQ's management UI is at **http://localhost:15672** (guest/guest) — useful for watching messages flow through the `booking-events` queue in real time.

## Why one shared Postgres instance?

For local dev, all three services' tables live in one Postgres container for simplicity. In production, you'd typically give each service its own database (or at least its own schema with restricted credentials) — full database-per-service isolation. This project keeps one instance locally to keep Docker Compose approachable; production Terraform/RDS setup is a later phase of this project.
