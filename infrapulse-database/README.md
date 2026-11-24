# InfraPulse Database — Beginner Step-by-Step Guide (Hindi / Hinglish)

**Start here: Repository 1 of 3.** PostgreSQL ek database server hai; SQL usse baat karne ki language hai. Is repo ko Python ya npm se run nahi karna. PostgreSQL service start karke SQL files execute karni hain.

## Project ko samjhein (zero se)

InfraPulse ek server monitoring application hai. Database data rakhta hai, backend data padhta/likhta hai aur frontend browser mein data dikhata hai. Agent CPU (processor ka usage), RAM (memory ka usage) aur disk (storage ka usage) bhejta hai.

```text
Agent --> FastAPI --> PostgreSQL
Browser --> React/Vite --> FastAPI --> PostgreSQL
```

| Order | Repository | Port | Kaam |
|---|---|---|---|
| 1 | infrapulse-database | 5432 | Data store |
| 2 | infrapulse-query-service | 8000 | API |
| 3 | infrapulse-query-service (agent) | No listening port | Metrics send |
| 4 | infrapulse-dashboard | 5173 | Browser UI |

**Important:** Ye guide Ubuntu 24.04 / Ubuntu WSL ke Bash terminal ko main environment maanti hai. Windows native instructions bhi niche hain. WSL use kar rahe hain to database, Python aur Node sab WSL ke andar install karein; Windows aur WSL ke commands mix na karein. Internet initial software installation ke liye chahiye. `localhost` ka matlab apna computer hai. Port ek service ka numbered connection point hai. Command blocks mein sirf commands copy karein, output ya prompt nahi. Ek command successful hone ke baad agli command chalayein.

### Folder setup

Teeno ZIP files ek hi `InfraPulse` folder mein extract karein. Ubuntu/WSL mein is guide ka assumed path `~/InfraPulse` hai. `~` aapka home folder hai. Agar ZIP Downloads mein hain, unhe file manager se home ke InfraPulse folder mein extract kar sakte hain. WSL mein `explorer.exe .` se current Linux folder Windows Explorer mein khulta hai.

```bash
mkdir -p ~/InfraPulse
cd ~/InfraPulse
pwd
ls -a
```

`mkdir -p` folder banata hai (already ho to error nahi), `cd` folder badalta hai, `pwd` current path aur `ls -a` hidden files samet contents dikhata hai. Extract ke baad structure aisa ho:

```text
InfraPulse/
  infrapulse-database/
  infrapulse-query-service/
  infrapulse-dashboard/
```

Windows native mein `C:\Users\YOUR_NAME\InfraPulse` ke badle PowerShell mein `$HOME\InfraPulse` use karein. ZIP ko Extract All se isi folder mein extract karein. Double nested folders na banayein.

## 1. PostgreSQL install karein (Terminal 1)

Ubuntu/WSL:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-client
psql --version
sudo service postgresql start
sudo service postgresql status
pg_isready -h localhost -p 5432
```

`sudo` administrator permission deta hai; password type karte waqt characters nahi dikhte, normal hai. `apt update` package list update karta hai, `apt install` software install karta hai, `-y` confirmation accept karta hai. `psql` database client hai. `service ... start` database process start karta hai; `status` status dikhata hai (agar pager khule to `q`). `pg_isready` ka expected output `accepting connections` hai. WSL restart ke baad service dobara start karni pad sakti hai.

Windows native: https://www.postgresql.org/download/windows/ se PostgreSQL 14+ installer lein. Server aur command line tools install karein, postgres administrator password yaad rakhein, port 5432 rakhein. SQL Shell (psql) Start Menu se kholein. Server localhost, database postgres, port 5432, username postgres select karein; installer password enter karein. PowerShell mein psql not recognized ho to PostgreSQL installation ke `bin` folder ko PATH mein add karein aur naya terminal kholein. Services app se PostgreSQL service Running check karein.

## 2. Application user aur database banayein (sirf ek baar)

Ubuntu terminal:

```bash
sudo -u postgres psql
```

Ab `postgres=#` prompt SQL shell ka hai, Bash nahi. Ye do SQL commands alag alag execute karein (semicolon zaroori):

```sql
CREATE ROLE infrapulse LOGIN PASSWORD 'local-dev-password-change-me';
CREATE DATABASE infrapulse OWNER infrapulse;
```

Expected output `CREATE ROLE` aur `CREATE DATABASE`. Role application ka login hai; OWNER ka matlab is user ko database ka ownership milta hai. Ye password sirf local practice example hai. Agar change karte hain to backend ki `.env` mein same password rakhein. Windows SQL Shell mein bhi same SQL chalegi.

```sql
\du
\l
\q
```

`\du` roles, `\l` databases list karta hai, `\q` SQL shell se exit. Already exists error aaye to pehle existing user/database verify karein, delete na karein. Password reset zaroori ho to administrator SQL shell mein `ALTER ROLE infrapulse PASSWORD 'local-dev-password-change-me';` use karein.

## 3. Schema file execute karein

Ubuntu Bash:

```bash
cd ~/InfraPulse/infrapulse-database
ls -a
psql -h localhost -p 5432 -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -1 -f init/01-schema.sql
```

Windows PowerShell mein `cd "$HOME\InfraPulse\infrapulse-database"` use karein; baaki psql command same hai. Application password enter karein (postgres admin password nahi). Flags ka meaning: `-h` host, `-p` port, `-U` user, `-d` database, `-v ON_ERROR_STOP=1` error par stop, `-1` poori schema transaction, `-f` SQL file read. Expected `CREATE TABLE` aur `CREATE INDEX` messages. Schema **sirf ek baar** execute karein; relation already exists ka matlab pehle se table ho sakti hai.

## 4. Demo data insert karein

```bash
psql -h localhost -p 5432 -U infrapulse -d infrapulse -v ON_ERROR_STOP=1 -f demo/seed.sql
```

Seed file apni transaction khud chalati hai. Ismein 3 fake servers aur har server ke 48 historical samples hain. Fresh database par total 144 samples expected hain. Re-run se extra metrics insert ho sakte hain; repeated seed zaroori nahi. Demo server names real cloud resources nahi hain. Data 120 seconds se purana hone par server offline dikhega; live demo agent baad mein start karenge.

## 5. Verify karein ki data sach mein store hua

```bash
psql -h localhost -p 5432 -U infrapulse -d infrapulse
```

Ab SQL prompt `infrapulse=>` par:

```sql
\dt
SELECT id, hostname, region FROM servers ORDER BY id;
SELECT count(*) FROM metrics;
SELECT * FROM alerts;
SELECT hostname, cpu, memory, disk, collected_at FROM servers JOIN metrics ON servers.id = metrics.server_id ORDER BY collected_at DESC LIMIT 5;
\q
```

`\dt` tables list karta hai; `SELECT` data padhta hai; `count(*)` rows count karta hai; `JOIN` server ID se metrics jodta hai; `ORDER BY ... DESC` newest first; `LIMIT 5` sirf 5 results. Expected servers: demo-web-01, demo-api-01, demo-db-01. Disk alert demo-db-01 ke liye expected hai. Agar SQL output pager mein ho to `q` press karein.

## 6. Har file ka kaam

| File | Kaam |
|---|---|
| init/01-schema.sql | servers, metrics, alerts tables aur indexes banata hai |
| demo/seed.sql | Sample server data aur alert insert karta hai |
| .gitignore | Secrets aur local files Git se exclude karta hai |
| LICENSE | Code reuse ki license terms |
| README.md | Ye setup guide |

`servers.id` primary key unique identity hai. `metrics.server_id` aur `alerts.server_id` foreign keys hain jo server se link karti hain. CHECK constraints CPU/RAM/disk ko 0–100 tak restrict karte hain. Index latest metrics search fast karta hai; partial unique index ek resource ke liye ek hi active alert allow karta hai. `resolved_at` null hai to alert active hai.

## 7. Common errors

| Error | Kya karein |
|---|---|
| psql command not found | PostgreSQL client install/PATH check |
| Connection refused | service start karein, pg_isready run karein |
| Password authentication failed | Application role/password check karein |
| Database does not exist | Step 2 verify karein |
| No such file | pwd aur ls se current folder check karein |
| Relation already exists | Schema already initialized ho sakta hai; step 5 verify karein |

## 8. Backup (optional, advanced reset nahi)

```bash
pg_dump -h localhost -U infrapulse -d infrapulse -Fc -f infrapulse.dump
pg_restore -l infrapulse.dump
```

`pg_dump` backup banata hai, `-Fc` custom format, `pg_restore -l` backup contents dikhata hai. Restore ko safer empty database mein karein; existing database par `--clean` objects delete/replace karta hai, beginner setup mein use na karein. Backup GitHub par upload na karein.

## 9. Next repository

PostgreSQL running rakhein. Database terminal band kar sakte hain, service background mein chalti hai. Ab `~/InfraPulse/infrapulse-query-service/README.md` open karein. Backend tabhi start karein jab tables aur seed verification pass ho.

## GitHub par upload (application chalane ke liye optional)

Ubuntu par `sudo apt install -y git` se Git install karein. Windows par https://git-scm.com/downloads se Git install karein. `git --version` se verify karein. GitHub.com par New repository banayein, is repo ke exact naam se. README/license initialize na karein. Public karne se pehle secrets check karein.

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
git init -b main
git add .
git status --short
git commit -m "Initial InfraPulse project"
git remote add origin https://github.com/YOUR_USERNAME/infrapulse-database.git
git push -u origin main
```

In commands ko **isi repository ke root folder mein** chalayein. `YOUR_USERNAME` apna GitHub username aur `REPO_NAME` is repository ka naam rakhein. `git init` local repo banata hai, `add` files stage karta hai, `status` review karata hai, `commit` snapshot banata hai, `remote` GitHub URL jodta hai, `push` upload karta hai. HTTPS authentication ke liye Git Credential Manager/browser login ya GitHub token use karein, account password nahi. `.env`, database dumps, `.venv`, `node_modules` aur `dist` upload nahi karne hain; `.gitignore` inhe exclude karta hai. `git status` mein secret dikhe to commit se pehle hata dein. Existing remote ho to `git remote -v` check karein; dobara init/push blindly na karein.

## Verification note

Commands source configuration ke against review kiye gaye hain. Live database, dependency installation aur browser end-to-end test is packaging environment mein execute nahi hua. Neeche/uper diye expected results acceptance checks hain, actual test results nahi. Local lab credentials examples hain; public access se pehle authentication, HTTPS aur secure secrets configure karein.
