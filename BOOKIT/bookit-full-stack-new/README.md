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

## Seeing the services actually talk to each other

The board comes pre-seeded with 4 sample sessions and one demo admin account, so there's something to interact with immediately:

```
Admin login:  admin@bookit.dev / admin12345
```

**To watch every service's part in a single request**, open a terminal and run:
```bash
docker compose logs -f --tail=0
```
This tails every container's logs together, each line tagged with its service name. Leave it running, then in the browser:

1. **Sign up** as a new (non-admin) user — watch `auth-service` log the account creation and `api-gateway` log the cookie being issued
2. **Reserve a seat** on one of the seeded sessions — watch, in order: `api-gateway` route the request, `booking-service` call `availability-service` to reserve the seat, `availability-service` log the seat count updating, `booking-service` log the booking being confirmed and the event being published, and `notification-service` log picking that event off the queue and "sending" a confirmation
3. **Cancel the booking** — watch the same chain run in reverse (release the seat, publish `booking.cancelled`, notification-service logs the cancellation)
4. **Log in as the seeded admin** and create a new session — watch `availability-service` log it going onto the board

RabbitMQ's management UI (**http://localhost:15672**, guest/guest) lets you watch messages land in the `booking-events` queue in real time as well, which is worth a look at least once — you'll see the queue depth go to 1 and back to 0 as booking-service publishes and notification-service consumes.

## Useful commands while it's running
```bash
docker compose ps                       # see status of every container
docker compose logs -f booking-service  # tail logs for one service
docker compose down                     # stop everything
docker compose down -v                  # stop everything AND wipe the Postgres volume
```

## Why one shared Postgres instance?

For local dev, all three services' tables live in one Postgres container for simplicity. In production, you'd typically give each service its own database (or at least its own schema with restricted credentials) — full database-per-service isolation. This project keeps one instance locally to keep Docker Compose approachable; production Terraform/RDS setup is a later phase of this project.
