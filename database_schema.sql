# MoKa — Full Database Architecture (Production Level)

This is the core structure that makes the app reliable, scalable, and ready for commercial use.

Because MoKa is a real-time job marketplace, the database must handle:

* customers
* workers
* jobs
* live matching
* payments
* ratings
* chat
* notifications
* admin controls
* fraud prevention

---

# MAIN DATABASE

## Primary DB:

# PostgreSQL

## Supporting DB:

# Redis (real-time cache + queues)

---

# CORE TABLES

---

# 1. Users Table

## Table:

`users`

### Stores:

Both customers and workers

### Fields:

```sql
id
full_name
email
phone_number
password_hash
role (customer / worker / admin)
profile_photo
status (active / suspended / pending)
created_at
updated_at
```

---

# 2. Worker Profiles Table

## Table:

`worker_profiles`

### Fields:

```sql
id
user_id (FK)
skill_category_id
years_of_experience
bio
current_latitude
current_longitude
availability_status (online/offline/busy)
verification_status
rating_average
total_jobs_completed
wallet_balance
created_at
updated_at
```

---

# 3. Skill Categories Table

## Table:

`skill_categories`

### Fields:

```sql
id
name
icon
description
created_at
```

Examples:

* plumbing
* electrician
* cleaning
* mechanic
* carpenter

---

# 4. Jobs Table

## Table:

`jobs`

### Fields:

```sql
id
customer_id (FK)
assigned_worker_id (FK nullable)
title
description
location_address
latitude
longitude
budget
urgency_level
status
preferred_time
job_photo
created_at
updated_at
```

### Status Values:

```text
pending
broadcasted
accepted
in_progress
completed
cancelled
disputed
```

---

# 5. Job Applications Table

## Table:

`job_applications`

### Fields:

```sql
id
job_id (FK)
worker_id (FK)
application_status
estimated_arrival_time
created_at
```

This handles multiple workers responding.

---

# 6. Payments Table

## Table:

`payments`

### Fields:

```sql
id
job_id (FK)
customer_id (FK)
worker_id (FK)
amount
platform_fee
payment_method
payment_status
transaction_reference
created_at
```

---

# 7. Ratings Table

## Table:

`ratings`

### Fields:

```sql
id
job_id (FK)
customer_id (FK)
worker_id (FK)
stars
review
created_at
```

---

# 8. Chat Messages Table

## Table:

`messages`

### Fields:

```sql
id
job_id (FK)
sender_id (FK)
receiver_id (FK)
message_type
message_content
is_read
created_at
```

---

# 9. Notifications Table

## Table:

`notifications`

### Fields:

```sql
id
user_id (FK)
title
message
notification_type
is_read
created_at
```

---

# 10. Worker Verification Table

## Table:

`worker_verifications`

### Fields:

```sql
id
worker_id (FK)
ghana_card_number
id_document_url
verification_status
reviewed_by_admin
reviewed_at
created_at
```

---

# 11. Wallet Table

## Table:

`wallets`

### Fields:

```sql
id
user_id (FK)
balance
last_updated
```

---

# 12. Wallet Transactions Table

## Table:

`wallet_transactions`

### Fields:

```sql
id
wallet_id (FK)
transaction_type
amount
reference
description
created_at
```

---

# 13. Support Tickets Table

## Table:

`support_tickets`

### Fields:

```sql
id
user_id (FK)
job_id (nullable FK)
subject
description
status
created_at
updated_at
```

---

# 14. Admin Logs Table

## Table:

`admin_logs`

### Fields:

```sql
id
admin_id (FK)
action
target_table
target_id
description
created_at
```

---

# REDIS USE CASES

Redis should handle:

## Real-Time

* nearby worker search
* active worker sessions
* live map tracking
* push notification queue
* temporary OTP storage
* online/offline states
* job broadcast queue

This keeps PostgreSQL fast.

---

# HIGH-VALUE RELATIONSHIPS

## Example

Customer → Posts → Job

Job → Broadcasts → Workers

Worker → Accepts → Job

Job → Generates → Payment

Payment → Updates → Wallet

Job → Ends → Rating

Admin → Monitors → Everything

This is the true system flow.

---

# INDUSTRY-GRADE ADDITIONS (Later)

Future upgrade tables:

* subscriptions
* premium workers
* business accounts
* insurance claims
* emergency jobs
* video consultation
* AI recommendations
* fraud scoring system

---

# VERY IMPORTANT

Do NOT skip:

## audit logs

## fraud prevention

## dispute management

## verification systems

These are what make startups survive.

---

# Next Step

Now we move to:

# Full Backend API Architecture (NestJS Production Blueprint)

This is where developers can start building immediately.
