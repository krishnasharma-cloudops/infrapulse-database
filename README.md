# InfraPulse — Database Setup Guide

This repository contains the PostgreSQL schema and initialization scripts for the InfraPulse Infrastructure Monitoring platform. It stores server inventory, CPU, memory and disk utilization, historical measurements and resource alerts.

There are two ways to deploy the database:

- **IaaS (Infrastructure as a Service):** Install and manage PostgreSQL on an Ubuntu virtual machine.
- **PaaS (Platform as a Service):** Use Azure Database for PostgreSQL — Flexible Server. Azure manages the database infrastructure and backups.

For the two-VM InfraPulse deployment (backend VM and dashboard VM), choose **Option 2**. You do not need to complete both options.

> This project uses PostgreSQL, not Microsoft SQL Server or Azure SQL Database. No Docker or container tooling is required.

## Repository structure

```text
infrapulse-database/
├── init/
│   └── 01-schema.sql
├── demo/
│   └── seed.sql
├── .gitignore
├── LICENSE
└── README.md
```

| File | Purpose |
|---|---|
| `init/01-schema.sql` | Creates the servers, metrics and alerts tables, constraints and indexes. |
| `demo/seed.sql` | Inserts three demonstration servers, historical measurements and an example disk alert. |
| `.gitignore` | Excludes local or sensitive files from Git. |
| `LICENSE` | Project license. |
| `README.md` | Database setup and deployment instructions. |

No additional PostgreSQL extension is required by the current schema.

## Deployment architecture

```text
Browser --> Frontend VM (Nginx, React)
                 |
                 | HTTP :8000 (private network)
                 v
            Backend VM (FastAPI)
                 |
                 | PostgreSQL :5432
                 v
            PostgreSQL (VM or Azure Flexible Server)
```

Deploy the database first, then `infrapulse-query-service`, and finally `infrapulse-dashboard`. The dashboard does not connect directly to PostgreSQL.

## Prerequisites

- An Azure subscription and access to the Azure Portal.
- A backend Ubuntu VM with outbound internet access to install packages and clone your repository.
- Your own GitHub repository URL; replace `YOUR_USERNAME` in the commands.
- An SSH key for VM access.
- Optional: [pgAdmin 4](https://www.pgadmin.org/download/) on your workstation.

All shell commands below use Bash on Ubuntu. SQL commands are explicitly marked. Replace example hostnames and IP addresses with your actual values. Never commit passwords or real `.env` files.

---

## Option 1: IaaS Setup (PostgreSQL on a Linux VM)

### Step 1: Create the database VM and configure network security

Create an Ubuntu Server 24.04 LTS VM in the Azure Portal. Use the same virtual network as the backend VM, with a separate database subnet if desired.

| Setting | Example |
|---|---|
| Resource group | `rg-infrapulse` |
| VM name | `vm-infrapulse-database` |
| Private IP | `10.0.3.4` |
| Backend private IP | `10.0.2.4` |
| Authentication | SSH public key |
| Public IP | Optional for restricted SSH access |

In VM > Networking > Network settings, add inbound NSG rules:

| Priority | Protocol | Destination port | Source | Action |
|---|---|---|---|---|
| 1000 | TCP | 22 | Your workstation public IP or authorized jump host | Allow |
| 1010 | TCP | 5432 | Backend private IP `10.0.2.4/32` | Allow |
| 4000 | Any | Any | Any | Deny |

Do not expose port 5432 to the entire internet. Restrict any additional access to trusted clients. If using a private VM, provide an explicit outbound internet path for package installation and Git access.

### Step 2: Connect and install PostgreSQL

From your workstation, if the database VM has a public IP:

```bash
ssh azureuser@YOUR_DATABASE_VM_PUBLIC_IP
```

For a private VM, use an authorized SSH jump host (with corresponding NSG rules):

```bash
ssh -J azureuser@YOUR_JUMP_HOST_PUBLIC_IP azureuser@10.0.3.4
```

On the database VM:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib git
sudo systemctl enable --now postgresql
sudo systemctl status postgresql --no-pager
pg_isready
```

`apt update` refreshes package information. `apt install` installs the server and Git. `systemctl` starts PostgreSQL and enables it on reboot. `pg_isready` checks whether the database accepts connections.

### Step 3: Configure PostgreSQL for private remote connections

Find the actual configuration paths:

```bash
sudo -u postgres psql -Atc 'SHOW config_file;'
sudo -u postgres psql -Atc 'SHOW hba_file;'
```

Ubuntu 24.04 normally installs PostgreSQL 16. Substitute the version/path reported by the previous commands if different.

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

Set the following line (use your database VM's actual private IP):

```ini
listen_addresses = 'localhost,10.0.3.4'
```

Edit the client authentication file:

```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

Add the following rule before any conflicting rule:

```text
hostssl infrapulse infrapulse 10.0.2.4/32 scram-sha-256
```

For this private lab, enable PostgreSQL TLS (`ssl = on` in `postgresql.conf`) and verify the configured server certificate and key exist and are readable by PostgreSQL. Ubuntu's packaged local certificate can be used for a lab with `sslmode=require`; for identity verification use a trusted certificate matching the database hostname and `verify-full`.

Save with Ctrl+O, Enter, Ctrl+X. Restart and verify:

```bash
sudo systemctl restart postgresql
sudo -u postgres psql -c 'SHOW ssl;'
sudo ss -ltnp | grep 5432
```

If UFW is enabled, also allow TCP 5432 only from the backend private IP:

```bash
sudo ufw status
sudo ufw allow from 10.0.2.4 to any port 5432 proto tcp
```

### Step 4: Create an application user and database

```bash
sudo -u postgres psql
```

Inside the PostgreSQL shell, run:

```sql
CREATE ROLE infrapulse LOGIN;
```

Set a strong password without placing it in shell history:

```text
\password infrapulse
```

Enter the password twice. Then run:

```sql
CREATE DATABASE infrapulse OWNER infrapulse;
```

Exit with `\q`. The application uses its own login instead of the database administrator.

### Step 5: Clone and initialize the repository

On the database VM:

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/infrapulse-database.git
cd infrapulse-database
ls -la
```

Run the schema as the application user so it owns the tables:

```bash
psql -h localhost -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -1 -f init/01-schema.sql
```

Enter the application password when prompted. `-f` executes a file; `-1` wraps the schema in a transaction; `ON_ERROR_STOP` stops on SQL errors.

Optionally insert the demonstration data:

```bash
psql -h localhost -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -f demo/seed.sql
```

Run the schema once on a new database. The seed script already contains its own transaction; repeating it adds more historical metrics.

### Step 6: Connect via pgAdmin 4 (IaaS, optional)

Use an SSH tunnel so PostgreSQL does not need a public inbound rule. From your workstation, while connected to a VM reachable by SSH:

```bash
ssh -N -L 15432:127.0.0.1:5432 azureuser@YOUR_DATABASE_VM_PUBLIC_IP
```

For a private database VM, add `-J azureuser@YOUR_JUMP_HOST_PUBLIC_IP` and use its private IP as the SSH destination. Keep this terminal open.

Open pgAdmin 4 > Servers > Register > Server.

| Field | Value |
|---|---|
| General > Name | InfraPulse-IaaS |
| Host name/address | `127.0.0.1` |
| Port | `15432` |
| Maintenance database | `infrapulse` |
| Username | `infrapulse` |
| Password | Application password |
| SSL mode | Require (lab TLS configuration) |

Click Save. Expand Databases > infrapulse > Schemas > public > Tables. If you already executed both scripts using `psql`, do not execute them again. Otherwise open Query Tool and run the contents of `init/01-schema.sql` first and `demo/seed.sql` second.

### Step 7: Test from the backend VM

On the backend VM, install the client and test private connectivity:

```bash
sudo apt update
sudo apt install -y postgresql-client
PGSSLMODE=require psql -h 10.0.3.4 -p 5432 -U infrapulse -d infrapulse
```

Run `\dt` and `\q`. Continue to the verification and backend configuration sections below.

---

## Option 2: PaaS Setup (Azure Database for PostgreSQL — Flexible Server)

This is the recommended option for InfraPulse when the backend and dashboard run on separate Azure VMs. You do not install PostgreSQL server software on either VM.

### Step 1: Provision the managed database

1. Sign in to the [Azure Portal](https://portal.azure.com/).
2. Search for **Azure Database for PostgreSQL flexible servers**.
3. Click **Create**.
4. Configure the Basics tab using the following example settings.

| Setting | Example value |
|---|---|
| Subscription | Your active subscription |
| Resource group | `rg-infrapulse` |
| Server name | `psql-infrapulse-unique` (choose a globally unique name) |
| Region | Central India, or the backend VM region |
| PostgreSQL version | 16 |
| Workload type | Development, if offered |
| Compute tier | Burstable |
| Compute size | B1ms or equivalent available size |
| Storage | 32 GiB or the available minimum |
| High availability | Disabled for a practice environment |
| Backup retention | 7 days |
| Authentication | PostgreSQL authentication |
| Admin username | `infraadmin` |
| Admin password | A strong unique password |

Availability and prices depend on region and subscription. Review the estimated cost before creating resources.

### Step 2: Configure networking

Choose **one** networking approach appropriate to your environment.

#### A. Public access with restricted firewall rules (simple pgAdmin setup)

In Networking, choose Public access (allowed IP addresses). Enable public access and add:

- Your workstation's current public IP, if using pgAdmin directly.
- The backend VM's actual outbound public IP (its public IP or NAT Gateway public IP, depending on routing).

For each rule, use the same start and end IP for a single trusted address. Do not enable access from all Azure services or all internet addresses. The frontend VM does not need a database firewall rule.

#### B. Private access (recommended for the private two-VM architecture)

Select Private access (VNet Integration). Use the backend VM's virtual network and a dedicated subnet delegated to `Microsoft.DBforPostgreSQL/flexibleServers`. Create/link the private DNS zone to the VNet. The backend VM must be able to resolve the database hostname and reach port 5432. Do not add a public firewall rule in this mode; use the backend VM or a private network connection for database administration.

Click Review + create, then Create. When deployment completes, open the resource and copy the fully qualified server hostname, for example:

```text
psql-infrapulse-unique.postgres.database.azure.com
```

### Step 3: Connect from the backend VM

SSH into the backend VM (use the authorized jump host if it has no public IP). Install the client tools:

```bash
sudo apt update
sudo apt install -y postgresql-client git ca-certificates
```

Set your actual hostname and TLS settings:

```bash
export DB_HOST=psql-infrapulse-unique.postgres.database.azure.com
export PGSSLMODE=verify-full
export PGSSLROOTCERT=/etc/ssl/certs/ca-certificates.crt
getent hosts "$DB_HOST"
```

The CA bundle must contain the trusted root certificates for Azure PostgreSQL. Follow Microsoft's TLS guidance if certificate verification fails; do not disable TLS.

```bash
psql -h "$DB_HOST" -p 5432 -U infraadmin -d postgres
```

Enter the Azure admin password. A `postgres=>` prompt indicates a successful login.

### Step 4: Create the database and application user

Inside `psql`:

```sql
CREATE ROLE infrapulse LOGIN;
```

```text
\password infrapulse
```

Enter the new application password twice. Grant the administrator membership in the newly created role if needed for assigning ownership (the application does not receive administrative privileges):

```sql
GRANT infrapulse TO infraadmin;
CREATE DATABASE infrapulse OWNER infrapulse;
```

If your admin username is different, substitute it in the GRANT command. Verify with `\l` and exit using `\q`.

### Step 5: Clone the repository and execute SQL files

On the backend VM:

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/infrapulse-database.git
cd infrapulse-database
ls -la
```

Initialize the empty database as the application user:

```bash
psql -h "$DB_HOST" -p 5432 -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -1 -f init/01-schema.sql
```

Insert optional demonstration data:

```bash
psql -h "$DB_HOST" -p 5432 -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -f demo/seed.sql
```

The first file creates the tables and indexes; the second populates them. Do not run the same schema twice on an initialized database.

### Step 6: Connect via pgAdmin 4 (PaaS, alternative)

If using public access and your workstation IP is allowed, launch pgAdmin 4. Right-click Servers > Register > Server.

| Field | Value |
|---|---|
| General > Name | InfraPulse-Azure-PaaS |
| Host name/address | Your server's `*.postgres.database.azure.com` hostname |
| Port | `5432` |
| Maintenance database | `postgres` (admin setup) or `infrapulse` (application login) |
| Username | `infraadmin` for setup; `infrapulse` for application operations |
| Password | Corresponding password |
| SSL mode | Verify-full with trusted root CA configured |

For a basic restricted lab, Require encrypts traffic but does not provide the same server identity verification as Verify-full. Prefer Verify-full. With private access, pgAdmin must run on a client with private connectivity and DNS resolution.

If you prefer pgAdmin rather than `psql` for initialization, create the role and database from an admin connection to `postgres` using the SQL in Step 4 (use the role dialog to set the password; `\password` is a psql-only command). Run CREATE DATABASE as its own statement outside a transaction. Then register/connect as `infrapulse` to the new database and open Query Tool. Open and execute `init/01-schema.sql`, then `demo/seed.sql`. Refresh the table list. Do not repeat initialization if Step 5 already succeeded.

---

## Verifying the setup (both options)

Connect to the `infrapulse` database as the application user using pgAdmin Query Tool or the appropriate `psql` command above.

### Check tables

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

Expected tables:

| Table | Purpose |
|---|---|
| alerts | Resource threshold alerts and recovery timestamps |
| metrics | CPU, memory and disk percentages over time |
| servers | Server hostnames and regions |

### Check demonstration data

```sql
SELECT * FROM servers ORDER BY id;
SELECT COUNT(*) FROM metrics;
SELECT * FROM alerts ORDER BY opened_at DESC;
```

After one successful seed on an empty database, expect three servers, 144 metric records and one open disk alert. Data changes as the collector runs.

### Test a sample insert safely

```sql
BEGIN;
INSERT INTO servers (hostname, region)
VALUES ('test-db-01', 'centralindia')
ON CONFLICT (hostname) DO NOTHING;

INSERT INTO metrics (server_id, cpu, memory, disk)
SELECT id, 35.5, 62.0, 48.0
FROM servers WHERE hostname = 'test-db-01';

SELECT s.hostname, m.cpu, m.memory, m.disk, m.collected_at
FROM metrics m JOIN servers s ON s.id = m.server_id
WHERE s.hostname = 'test-db-01'
ORDER BY m.collected_at DESC;
ROLLBACK;
```

The rollback removes the test changes. Alerts are generated by backend ingestion logic, not automatically by raw SQL inserts.

## Backend connection configuration

On the backend VM, clone `infrapulse-query-service` and follow its README. In the repository root:

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

For IaaS:

```dotenv
POSTGRES_HOST=10.0.3.4
POSTGRES_PORT=5432
POSTGRES_DB=infrapulse
POSTGRES_USER=infrapulse
POSTGRES_PASSWORD="YOUR_APPLICATION_PASSWORD"
PGSSLMODE=require
```

For Azure PaaS:

```dotenv
POSTGRES_HOST=psql-infrapulse-unique.postgres.database.azure.com
POSTGRES_PORT=5432
POSTGRES_DB=infrapulse
POSTGRES_USER=infrapulse
POSTGRES_PASSWORD="YOUR_APPLICATION_PASSWORD"
PGSSLMODE=verify-full
PGSSLROOTCERT=/etc/ssl/certs/ca-certificates.crt
```

Keep the other existing `.env.example` variables (`INGEST_TOKEN`, `ALERT_THRESHOLD`, `STALE_SECONDS`) and configure a strong ingestion token. Do not use the Azure administrator account for application access. The actual backend reads separate PostgreSQL environment variables and connects using psycopg; it does not require a `DATABASE_URL` variable. TLS variables are handled by libpq. For a production IaaS deployment, configure trusted certificates and use `verify-full` with a matching DNS hostname.

After the backend dependencies are installed and Uvicorn is running, verify:

```bash
curl http://localhost:8000/health/ready
curl http://localhost:8000/api/v1/servers
```

Expected readiness response: `{"status":"ready"}`. Then start the demo or real collector as described in the backend README and deploy the dashboard.

## Troubleshooting

| Error | What to check |
|---|---|
| Connection timeout | NSG, Azure firewall, routing and actual outbound IP. |
| Hostname cannot be resolved | Server name and private DNS zone linkage. |
| Password authentication failed | Correct application username and password. |
| SSL certificate verification failed | Trusted CA bundle and exact database hostname. |
| Permission denied | Database ownership and application role. |
| Relation already exists | Schema was previously executed; do not rerun blindly. |
| Relation does not exist | Correct database and successful schema execution. |
| Dashboard reports offline servers | Start the metrics collector; historical seed data alone does not keep servers online. |

## GitHub publishing and maintenance

If this repository is already cloned on your laptop, replace its README.md with this file and run:

```bash
git status
git add README.md
git commit -m "Add PostgreSQL IaaS and Azure PaaS deployment guide"
git push origin main
```

Review staged files before committing. Never publish real credentials, connection secrets, SSH private keys or database backups. Azure resources may incur costs even when VMs are stopped; remove unused practice resources after preserving any data you need.

## Official documentation

- [Create an Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-portal)
- [Azure PostgreSQL firewall rules](https://learn.microsoft.com/en-us/azure/postgresql/security/security-firewall-rules)
- [Private networking](https://learn.microsoft.com/azure/postgresql/network/concepts-networking-private)

## Verification note

The file names, table definitions, seed counts and backend configuration variables in this guide were reviewed against the InfraPulse source code. Live Azure provisioning and database integration have not been executed as part of this documentation update. Expected outputs are acceptance checks, not recorded deployment results.
