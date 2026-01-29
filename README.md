## Zabbix Quickstart for AV Engineers (Ubuntu + PostgreSQL)

This project gives you a **ready-to-run Zabbix monitoring stack** for AV systems:

- Zabbix Server (brains)
- PostgreSQL database (stores history and configuration)
- Zabbix Web UI (web dashboard)
- Zabbix Agent (monitors the host running the stack – the “Zabbix server” host)
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
- One for the Zabbix agent (monitors this host).
- One for the AV-focused Zabbix proxy.

All of this is controlled by the `docker-compose.yml` file in this folder.

---

### Running modes (profiles)

You can bring up **everything** (server + web + DB + agent + proxy) or **only the proxy and agent** (for a remote site that reports to a central Zabbix server).

| Mode | Profile | What runs | When to use |
|------|---------|-----------|--------------|
| **Full stack** | `full` | postgres, zabbix-server, zabbix-web, zabbix-agent, zabbix-proxy | This host is the Zabbix server (pilot or central). |
| **Edge** | `edge` | zabbix-agent, zabbix-proxy only | This host is a remote site; proxy and agent report to a central server. |

- **Full stack** (default):
  ```bash
  docker compose --profile full up -d
  ```
- **Proxy + agent only** (edge):
  1. In `.env`, set `ZABBIX_SERVER_ADDRESS` to your central Zabbix server hostname or IP (and `ZABBIX_SERVER_PORT` if not 10051).
  2. Run:
  ```bash
  docker compose --profile edge up -d
  ```

---

### Edge profile: getting the agent (and proxy) working

Use this when this host is a **remote site** and only runs the agent + proxy; the central Zabbix server is elsewhere.

**1. On the edge host (the remote machine)**

- Clone or copy this repo to the host (e.g. `/opt/zabbix`).
- Edit `.env`:
  - **`ZABBIX_SERVER_ADDRESS`** = hostname or IP of your **central Zabbix server** (as reachable from this host). Example: `zabbix.central.example.com` or `10.0.1.50`.
  - **`ZABBIX_SERVER_PORT`** = central server trapper port (default `10051`).
  - **`ZABBIX_AGENT_HOSTNAME`** = name this host will have in the Zabbix UI (e.g. `Remote site 1` or the machine hostname).
  - **`ZABBIX_AGENT_ACTIVE_SERVER`** = who the agent connects to for active checks (config and sending results). **Set to `zabbix-proxy`** on the edge host so the agent gets its config from the local proxy. Otherwise the agent talks to the central server, gets "no active checks, host monitored by proxy", and active check configuration update fails.
  - **`ZABBIX_AGENT_PASSIVESERVERS`** = hosts allowed to connect to the agent for passive checks (must include the proxy). Easiest for edge: set to the Docker bridge subnet, e.g. `172.18.0.0/24` (check `docker network inspect` if your subnet differs). Alternatively use a comma-separated list: `central-server,zabbix-proxy`. (If unset, default is `zabbix-server,zabbix-proxy`, which is wrong for edge.)
  - **`ZABBIX_PROXY_HOSTNAME`** = name the proxy will have in the Zabbix UI (e.g. `av-proxy-remote1`).
- Start only the agent and proxy:
  ```bash
  cd /opt/zabbix
  docker compose --profile edge up -d
  ```
- The agent listens on the host on port **10050** (`ZABBIX_AGENT_PORT`). The central server (or proxy) must be able to reach this host on that port for passive checks.

**2. On the central Zabbix server (in the UI)**

- **Register the proxy** (if you use it for this host):
  - Go to **Administration** → **Proxies** → **Create proxy**.
  - **Proxy name**: same as `ZABBIX_PROXY_HOSTNAME` on the edge (e.g. `av-proxy-remote1`).
  - **Mode**: Active (proxy connects to server). Save.

- **Create the host for this edge machine**:
  - Go to **Data collection** → **Hosts** → **Create host**.
  - **Host name**: same as `ZABBIX_AGENT_HOSTNAME` on the edge (e.g. `Remote site 1`).
  - **Interfaces** → Add **Zabbix agent**:
    - **IP address / DNS**: `zabbix-agent` (Docker service name – the **proxy** will use this to reach the agent on the same host).
    - **Connect to**: **DNS**.
    - **Port**: `10050` (or whatever `ZABBIX_AGENT_PORT` is on the edge).
  - **Monitored by proxy**: **select the proxy** you created for this edge (required so the proxy, not the server, does passive checks; the proxy resolves `zabbix-agent` on the local Docker network).
  - Add to a group and assign a template (e.g. **Linux by Zabbix agent**). Save.

The agent uses **active** checks to push to the proxy/server. The **proxy** uses **passive** checks by connecting to `zabbix-agent:10050` on the Docker network (no firewall change needed on the edge host for agent traffic).

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
- **Agent host name**: `ZABBIX_AGENT_HOSTNAME`  
  - This is the host name you will use in the Zabbix UI for the machine running the stack.  
    Default: `Zabbix server`.
- **Proxy name**: `ZABBIX_PROXY_HOSTNAME`  
  - This is how the proxy will appear inside the Zabbix UI.  
    Example: `av-proxy-1`.

Save and close the file.

---

### 3. Start the monitoring stack

From `/opt/zabbix`:

```bash
mkdir -p ./data/postgres
docker compose --profile full up -d
```

This starts the **full stack** (postgres, server, web, agent, proxy). To start only proxy and agent (edge mode), set `ZABBIX_SERVER_ADDRESS` in `.env` and run `docker compose --profile edge up -d` (see [Running modes](#running-modes-profiles)).

This will:

- Create `./data/postgres/` (where the database files live).
- Download the necessary images (first time only).
- Start:
  - `postgres` (database)
  - `zabbix-server`
  - `zabbix-web`
  - `zabbix-agent` (monitors this host)
  - `zabbix-proxy`

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

### 5. Add the “Zabbix server” host (so the agent is monitored)

The stack includes a Zabbix agent that monitors the host running Docker. To see this host in Zabbix:

1. In the Zabbix UI, go to **Data collection** → **Hosts** → **Create host**.
2. **Host name**: use the same value as in `.env` → `ZABBIX_AGENT_HOSTNAME` (default: `Zabbix server`).
3. **Interfaces**: add an interface:
   - **Type**: Zabbix agent  
   - **IP address / DNS**: `zabbix-agent` (Docker service name; the server reaches the agent over the internal network.)  
   - **Connect to**: DNS  
   - **Port**: `10050`
4. Add the host to a group (e.g. **Linux servers**) and assign a template (e.g. **Linux by Zabbix agent active**).
5. Save.

The server will then collect metrics from the agent for this host (CPU, memory, disk, etc.).

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

### About the Zabbix server agent

The stack includes a **Zabbix agent** container that monitors the **same host** that runs the Zabbix server. It uses:

- **Image**: `zabbix/zabbix-agent:ubuntu-7.4-latest`
- **Server**: it reports to `zabbix-server` on the internal Docker network.
- **Host name in Zabbix**: set by `ZABBIX_AGENT_HOSTNAME` in `.env` (default: `Zabbix server`).

The agent runs with `privileged: true` and `pid: host` so it can collect real host metrics (processes, etc.), not just the container view. Port **10050** is published so the server can do passive checks; the agent also uses active checks to the server.

After you create a host in the UI with the same name as `ZABBIX_AGENT_HOSTNAME` and point its Zabbix agent interface at `zabbix-agent:10050`, the server will start monitoring this host.

---

### About the AV-focused proxy

The included proxy container:

- Uses the image `ghcr.io/hyperscaleav/zabbix-proxy-sqlite3:latest` (service name: `zabbix-proxy`).
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
  docker compose --profile full up -d
  ```

The database and configuration are preserved between restarts as long as `./data/postgres` is not deleted.

