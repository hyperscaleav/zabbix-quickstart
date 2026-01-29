## Zabbix Quickstart for AV Engineers (Ubuntu + PostgreSQL)

This project gives you a **ready-to-run Zabbix monitoring stack** for AV systems:

- Zabbix Server (brains)
- PostgreSQL database (stores history and configuration)
- Zabbix Web UI (web dashboard)
- Zabbix Proxy (SQLite3, customized for AV monitoring)

You do **not** need to write code. You only need to run a few commands.

---

### Prerequisites on the server

You need a Linux server (for example Ubuntu Server) with:

- At least **2 vCPUs**
- At least **4 GB RAM** (more is better)
- At least **20 GB free disk** (for the database)
- Network access from your workstation to the server’s HTTP port (80)

And you need:

- Docker Engine
- Docker Compose v2 (usually available as the `docker compose` command)

To check:

```bash
docker --version
docker compose version
```

If these commands fail, ask your IT team to install Docker and Docker Compose.

---

### What is Docker (in simple terms)?

Docker lets you run applications in **containers**.  
You can think of each container as a small, pre-packaged app:

- One container for the database.
- One for the Zabbix server.
- One for the web interface.
- One for the AV-focused Zabbix proxy.

All of this is controlled by the `docker-compose.yml` file in this folder.

---

### 1. Install the Zabbix stack

Run these commands **on the server** (via SSH, for example):

```bash
sudo mkdir -p /opt/zabbix
sudo chown "$(id -u):$(id -g)" /opt/zabbix
cd /opt/zabbix

git clone https://github.com/hyperscaleav/zabbix-quickstart.git .
```

Now you have the project files in `/opt/zabbix`.

---

### 2. Configure basic settings (once)

Open the `.env` file in a text editor:

```bash
cd /opt/zabbix
nano .env
```

Check or change:

- **Database password**: `POSTGRES_PASSWORD`  
  - For lab use you can leave it as `zabbix`.  
  - For anything important, change it to a stronger password and remember it.
- **Web ports**: `ZABBIX_WEB_HTTP_PORT` and `ZABBIX_WEB_HTTPS_PORT`  
  - Default HTTP is `80` (standard). Change only if it conflicts with something else.
- **Timezone**: `PHP_TZ`  
  - Set it to your local timezone, for example `America/New_York`.
- **Proxy name**: `ZABBIX_PROXY_HOSTNAME`  
  - This is how the proxy will appear inside the Zabbix UI.  
    Example: `av-proxy-1`.

Save and close the file.

---

### 3. Start the monitoring stack

From `/opt/zabbix`:

```bash
./start.sh
```

This script will:

- Create `./data/postgres/` (where the database files live).
- Download the necessary images (first time only).
- Start:
  - `postgres` (database)
  - `zabbix-server`
  - `zabbix-web`
  - `zabbix-proxy-sqlite3`

You can see status with:

```bash
docker compose ps
```

---

### 4. Log into the Zabbix web interface

In a browser (from your workstation), open:

- `http://<your-server-ip>/`

Default Zabbix login:

- **User**: `Admin`
- **Password**: `zabbix`

You will be prompted to go through a short setup wizard the first time.  
Use the values from `.env` when it asks for database settings.

---

### Where is the data stored? (Persistence)

- The PostgreSQL database files are stored on disk at:

  ```bash
  /opt/zabbix/data/postgres
  ```

- Stopping the containers **does not** remove this data.

To **stop** the stack but keep all data:

```bash
cd /opt/zabbix
docker compose down
```

To **wipe everything** (fresh start):

```bash
cd /opt/zabbix
docker compose down
rm -rf ./data/postgres
```

The proxy’s own SQLite database is intentionally **ephemeral** (temporary).  
It keeps recent data and forwards it to the server; long-term history lives in PostgreSQL.

---

### About the AV-focused proxy

The included proxy container:

- Uses the image `ghcr.io/hyperscaleav/zabbix-proxy-sqlite3:latest`.
- Is a thin wrapper around the official Zabbix Proxy SQLite3 image.
- Adds extra tools and scripts useful for AV system monitoring.

By default it:

- Connects to the Zabbix server over the internal Docker network.
- Appears in the Zabbix UI as the name in `ZABBIX_PROXY_HOSTNAME` (from `.env`).

You can adjust proxy behaviour in `.env`:

- `ZBX_PROXYMODE` – active vs passive proxy.
- `ZBX_PROXYBUFFERMODE`, `ZBX_PROXYMEMORYBUFFERAGE`, `ZBX_PROXYMEMORYBUFFERSIZE` – how it buffers data when the link to the server is unstable.
- `ZBX_ENABLEREMOTECOMMANDS` – whether the server can run remote commands via the proxy.

---

### Stopping and restarting

- **Stop (keep data):**

  ```bash
  cd /opt/zabbix
  docker compose down
  ```

- **Start again:**

  ```bash
  cd /opt/zabbix
  ./start.sh
  ```

The database and configuration are preserved between restarts as long as `./data/postgres` is not deleted.

