#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "   CONFIGURACIÓN ALERTAS ZABBIX SOC   "
echo "======================================"

# ===============================
# INPUT INTERACTIVO
# ===============================

read -p "URL Zabbix [http://127.0.0.1:8080/api_jsonrpc.php]: " ZABBIX_URL_INPUT
ZABBIX_URL="${ZABBIX_URL_INPUT:-http://127.0.0.1:8080/api_jsonrpc.php}"

read -p "Usuario Zabbix [Admin]: " ZABBIX_USER_INPUT
ZABBIX_USER="${ZABBIX_USER_INPUT:-Admin}"

read -s -p "Password Zabbix: " ZABBIX_PASS
echo ""

read -p "Servidor SMTP [smtp.jasoc.cat]: " SMTP_SERVER_INPUT
SMTP_SERVER="${SMTP_SERVER_INPUT:-smtp.jasoc.cat}"

read -p "Puerto SMTP [587]: " SMTP_PORT_INPUT
SMTP_PORT="${SMTP_PORT_INPUT:-587}"

read -p "Email remitente [soc@jasoc.cat]: " SMTP_EMAIL_INPUT
SMTP_EMAIL="${SMTP_EMAIL_INPUT:-soc@jasoc.cat}"

read -s -p "Password SMTP: " SMTP_PASS
echo ""

SMTP_USER="$SMTP_EMAIL"
SMTP_HELO="jasoc.cat"

MEDIA_NAME="Mail-JaSoc"
ACTION_NAME="JASOC - Alertas SOC por correo"

export ZABBIX_URL ZABBIX_USER ZABBIX_PASS
export SMTP_SERVER SMTP_PORT SMTP_EMAIL SMTP_USER SMTP_PASS SMTP_HELO
export MEDIA_NAME ACTION_NAME

python3 <<'PY'
import json
import os
import urllib.request

def api(method, params=None, auth=True):
    global AUTH, REQ_ID

    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params or {},
        "id": REQ_ID
    }
    REQ_ID += 1

    if auth:
        payload["auth"] = AUTH

    req = urllib.request.Request(
        os.environ["ZABBIX_URL"],
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json-rpc"}
    )

    with urllib.request.urlopen(req) as r:
        res = json.loads(r.read().decode())

    if "error" in res:
        raise Exception(res["error"])

    return res["result"]

def first(x):
    return x[0] if x else None

REQ_ID = 1
AUTH = None

print("[*] Login...")
AUTH = api("user.login", {
    "username": os.environ["ZABBIX_USER"],
    "password": os.environ["ZABBIX_PASS"]
}, auth=False)

print("[*] Configurando Media Type...")

media = first(api("mediatype.get", {
    "filter": {"name": [os.environ["MEDIA_NAME"]]}
}))

params = {
    "name": os.environ["MEDIA_NAME"],
    "type": 0,
    "smtp_server": os.environ["SMTP_SERVER"],
    "smtp_port": os.environ["SMTP_PORT"],
    "smtp_helo": os.environ["SMTP_HELO"],
    "smtp_email": os.environ["SMTP_EMAIL"],
    "smtp_security": 1,
    "smtp_authentication": 1,
    "username": os.environ["SMTP_USER"],
    "passwd": os.environ["SMTP_PASS"],
    "content_type": 1,
    "status": 0
}

if media:
    params["mediatypeid"] = media["mediatypeid"]
    api("mediatype.update", params)
else:
    api("mediatype.create", params)

print("[*] Configurando acción global...")

groups = api("usergroup.get", {"filter": {"name": ["Zabbix administrators"]}})
usrgrpid = groups[0]["usrgrpid"]

if not api("action.get", {"filter": {"name": [os.environ["ACTION_NAME"]]}}):
    api("action.create", {
        "name": os.environ["ACTION_NAME"],
        "eventsource": 0,
        "filter": {
            "conditions": [{
                "conditiontype": 4,
                "operator": 5,
                "value": "2"
            }]
        },
        "operations": [{
            "operationtype": 0,
            "opmessage_grp": [{"usrgrpid": usrgrpid}]
        }]
    })

print("[*] Creando triggers básicos...")

hosts = api("host.get", {"output": ["hostid","host"]})

for h in hosts:
    host = h["host"]

    triggers = [
        ("CPU alta", f"min(/{host}/system.cpu.load[all,avg5],5m)>2"),
        ("RAM alta", f"min(/{host}/vm.memory.utilization,5m)>90"),
        ("Disco lleno", f"min(/{host}/vfs.fs.size[/,pused],5m)>85"),
        ("Host caído", f"max(/{host}/agent.ping,5m)=0")
    ]

    for desc, expr in triggers:
        if not api("trigger.get", {"filter":{"description":[desc]}}):
            api("trigger.create", {
                "description": f"JASOC - {desc}",
                "expression": expr,
                "priority": 3
            })

print("")
print("[V] ZABBIX CONFIGURADO")
PY
