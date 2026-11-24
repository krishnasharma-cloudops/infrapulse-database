# InfraPulse Database — Complete Beginner Setup Guide

**Repository 1 of 3 | Start here**

PostgreSQL is the database server; SQL is the language used to communicate with it. This repository contains SQL scripts rather than a standalone Python or Node.js application. Start PostgreSQL and execute the scripts using its command-line client, `psql`.

## Project overview and execution order

InfraPulse is a three-tier infrastructure monitoring application. The collector sends CPU, memory (RAM), and disk usage measurements to the FastAPI backend. PostgreSQL stores those measurements and the React dashboard displays them.

```text
Collector --> FastAPI --> PostgreSQL
Browser --> React/Vite --> FastAPI --> PostgreSQL
```

| Order | Component | Port | Purpose |
|---|---|---|---|
| 1 | infrapulse-database | 5432 | Persistent data storage |
| 2 | infrapulse-query-service | 8000 | REST API |
| 3 | infrapulse-query-service agent | None | Sends measurements |
| 4 | infrapulse-dashboard | 5173 | Browser interface |

Use Ubuntu 24.04 or Ubuntu under WSL for the Bash commands in this guide. Native Windows alternatives are included where needed. Install all components in the same environment; do not mix native Windows and WSL installations. `localhost` refers to your own machine, and a port is a numbered network connection point. Run commands one at a time, checking the output before proceeding. Do not copy the terminal prompt or expected output.

## Prepare your project folder

```bash
mkdir -p ~/InfraPulse
cd ~/InfraPulse
pwd
ls -a
```

`mkdir -p` creates a directory if needed; `cd` changes directories; `pwd` prints the current location; `ls -a` lists files including hidden files. Extract the three source archives here, or clone your three populated GitHub repositories here. The final layout must be:

```text
InfraPulse/
  infrapulse-database/
  infrapulse-query-service/
  infrapulse-dashboard/
```

Avoid double-nested directories. On native Windows, use `$HOME\InfraPulse` in PowerShell and Extract All in File Explorer. In WSL, `explorer.exe .` opens the current Linux directory in Windows Explorer.

## 1. Install PostgreSQL (Terminal 1)

```bash
sudo apt update
sudo apt install -y postgresql postgresql-client
psql --version
sudo service postgresql start
sudo service postgresql status
pg_isready -h localhost -p 5432
```

`sudo` runs a command with administrator permissions. Password characters are hidden while typing. `apt update` refreshes package lists; `apt install` installs software; `-y` accepts confirmation. `psql` is the SQL client. `service` starts or checks PostgreSQL. If a status pager opens, press `q`. Expect `accepting connections` from `pg_isready`.

**Native Windows:** Install PostgreSQL 14 or later from https://www.postgresql.org/download/windows/. Include the server and command-line tools, remember the administrator password, and keep port 5432. Open SQL Shell (psql), select localhost, database postgres, port 5432, username postgres and enter the administrator password. If PowerShell cannot find psql, add the installation's `bin` directory to PATH and open a new terminal. Check the PostgreSQL service in the Windows Services application.

## 2. Create the application role and database (once only)

```bash
sudo -u postgres psql
```

The `postgres=#` prompt means you are inside the SQL shell, not Bash. Enter these SQL statements separately, including their semicolons:

```sql
CREATE ROLE infrapulse LOGIN PASSWORD 'local-dev-password-change-me';
CREATE DATABASE infrapulse OWNER infrapulse;
```

Expected messages: `CREATE ROLE` and `CREATE DATABASE`. The role is the application's login; `OWNER` grants ownership of the new database. Use the same password in the backend `.env` file. The example password is for local practice only. Windows SQL Shell accepts the same statements.

```sql
\du
\l
\q
```

These commands list roles, list databases and exit the SQL shell, respectively. If the role or database already exists, inspect it rather than deleting it. To reset the lab role password if necessary, run `ALTER ROLE infrapulse PASSWORD 'local-dev-password-change-me';` in the administrator SQL shell.

## 3. Execute the database schema

```bash
cd ~/InfraPulse/infrapulse-database
ls -a
psql -h localhost -p 5432 -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -1 -f init/01-schema.sql
```

Enter the application role password, not the postgres administrator password. On Windows PowerShell, use `cd "$HOME\InfraPulse\infrapulse-database"` first; the psql command is unchanged.

| Option | Meaning |
|---|---|
| -h | Database host |
| -p | Port |
| -U | Login role |
| -d | Database name |
| -v ON_ERROR_STOP=1 | Stop when an SQL error occurs |
| -1 | Execute the script in a single transaction |
| -f | Read the specified SQL file |

Expect CREATE TABLE and CREATE INDEX messages. Execute the schema only once for a new database.

## 4. Insert sample data

```bash
psql -h localhost -p 5432 -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -f demo/seed.sql
```

The seed script manages its own transaction and inserts three simulated servers, 48 historical measurements per server (144 measurements on a fresh database), and a disk alert. Re-running it can add duplicate historical measurements. These server names and region labels are simulated, not actual cloud resources. After 120 seconds without a new measurement, servers may appear offline; the demo collector will keep them updated later.

## 5. Verify the database

```bash
psql -h localhost -p 5432 -U infrapulse -d infrapulse
```

At the `infrapulse=>` SQL prompt, run:

```sql
\dt
SELECT id, hostname, region FROM servers ORDER BY id;
SELECT count(*) FROM metrics;
SELECT * FROM alerts;
SELECT hostname, cpu, memory, disk, collected_at FROM servers JOIN metrics ON servers.id = metrics.server_id ORDER BY collected_at DESC LIMIT 5;
\q
```

`\dt` lists tables; SELECT reads data; count(*) counts rows; JOIN connects server records to measurements; ORDER BY DESC sorts newest first; LIMIT restricts the result. Expect three tables, three demo servers (demo-web-01, demo-api-01, demo-db-01), 144 measurements on a fresh seed, and a disk alert for demo-db-01. Press `q` to leave a result pager if needed.

## 6. Repository structure and database design

```text
infrapulse-database/
├── init/01-schema.sql
├── demo/seed.sql
├── .gitignore
├── LICENSE
└── README.md
```

| File | Purpose |
|---|---|
| init/01-schema.sql | Creates tables, constraints and indexes |
| demo/seed.sql | Inserts demonstration servers, measurements and an alert |
| .gitignore | Excludes local files from Git |
| LICENSE | License terms |
| README.md | Setup and usage instructions |

| Table | Purpose | Key fields |
|---|---|---|
| servers | Server inventory | id, hostname, region, created_at |
| metrics | Historical measurements | server_id, collected_at, cpu, memory, disk |
| alerts | Resource threshold events | server_id, metric, value, opened_at, resolved_at |

Primary keys uniquely identify rows. Foreign keys connect metrics and alerts to the server record. CHECK constraints restrict utilization to 0–100. The server/time index accelerates recent measurement queries. A partial unique index permits only one unresolved alert per server and resource. A null resolved_at means the alert is active. Deleting a server also deletes its associated measurements and alerts through cascading foreign keys; avoid accidental deletes.

## 7. Troubleshooting

| Error | Action |
|---|---|
| psql command not found | Install the PostgreSQL client or check PATH |
| Connection refused | Start PostgreSQL and run pg_isready |
| Password authentication failed | Verify the application role and password |
| Database does not exist | Verify Step 2 |
| No such file | Check pwd and ls -a |
| Relation already exists | Schema may already be initialized; verify Step 5 |

## 8. Optional backup

```bash
pg_dump -h localhost -U infrapulse -d infrapulse -Fc -f infrapulse.dump
pg_restore -l infrapulse.dump
```

The first command creates a custom-format backup; the second lists its contents. Restore into a separate empty database when practicing. Do not use destructive restore options against a working database. Never publish backups to GitHub.

## 9. Next step

Leave PostgreSQL running in the background and open `infrapulse-query-service/README.md`. Do not start the backend until the database checks succeed. After restarting your computer, start the PostgreSQL service again; database creation and seeding do not need to be repeated.

## Publish this repository to GitHub using Git clone (optional)

These instructions are for publishing the supplied source code to your own GitHub account, not for running the application. Publish each repository separately.

1. Install Git (`sudo apt install -y git` on Ubuntu, or https://git-scm.com/downloads on Windows). Verify with `git --version`.
2. Open https://github.com/new and create an empty repository named `infrapulse-database`. Do not initialize it with a README, license or .gitignore. Choose public or private visibility as appropriate.
3. Configure your Git identity once, using your own name and email.

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

4. Clone into a separate publishing directory so that it does not conflict with your extracted source folder. Replace `YOUR_USERNAME` with your GitHub username.

```bash
mkdir -p ~/InfraPulse-publish
cd ~/InfraPulse-publish
git clone https://github.com/YOUR_USERNAME/infrapulse-database.git
cd infrapulse-database
```

An empty-repository warning is normal for a newly created repository. Copy the contents of the supplied source directory into this cloned directory, including hidden files such as `.gitignore` and `.env.example` where present. Do not replace the cloned `.git` directory. Do not copy actual secrets, database dumps, virtual environments, dependencies or build output.

5. Check the files and the destination repository before staging and committing.

```bash
git remote -v
git status
git add .
git status --short
```

`git clone` automatically configures the remote named `origin`; no `git init` or `git remote add` is necessary. `git add` stages files; `git status` lets you review them. Remove any staged secrets before committing.

```bash
git commit -m "Initial InfraPulse project"
git branch -M main
git push -u origin main
```

`git commit` records a snapshot, `git branch -M main` names the branch, and `git push` uploads the commit and sets the upstream branch. Authenticate using the browser/Git Credential Manager or a GitHub token, not your account password. Refresh the GitHub repository page and confirm the source files and README are present.

For an existing cloned repository, replace its README.md and run only:

```bash
git status
git add README.md
git commit -m "Improve English setup documentation"
git push
```

Never commit `.env`, real passwords, tokens, private SSH keys, database dumps, `.venv`, `node_modules` or `dist`. Review the staged file list even when `.gitignore` is present.

## Verification and security note

The instructions describe the supplied source configuration and expected acceptance results. They are not a claim that a live database, dependency installation or end-to-end browser deployment has been executed. The sample credentials are for a private local lab. Configure authentication, HTTPS and secure secrets before any public deployment. Read API endpoints do not currently require authentication.
