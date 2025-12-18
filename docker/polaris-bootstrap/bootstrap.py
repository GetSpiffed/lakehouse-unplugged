import os
import time
import json
import requests
from typing import Iterable

# ==============================
# Configuration from Environment
# ==============================
POLARIS_HOST = os.getenv("POLARIS_HOST", "polaris")
POLARIS_PORT = os.getenv("POLARIS_PORT", "8181")

POLARIS_MGMT = f"http://{POLARIS_HOST}:{POLARIS_PORT}/api/management/v1"
POLARIS_OAUTH_TOKEN_URL = os.getenv(
    "POLARIS_OAUTH2_TOKEN_URL",
    f"http://{POLARIS_HOST}:{POLARIS_PORT}/api/catalog/v1/oauth/tokens",
)

# Admin / OAuth bootstrap credentials
ADMIN_CLIENT_ID = os.getenv("POLARIS_OAUTH2_CLIENT_ID", "admin")
ADMIN_CLIENT_SECRET = os.getenv("POLARIS_OAUTH2_CLIENT_SECRET", "password")

# Catalog & principals
CATALOG_NAME = os.getenv("POLARIS_CATALOG_NAME", "polaris")

CLIENT_PRINCIPAL = os.getenv("POLARIS_CLIENT_PRINCIPAL", "lakehouse_client")
CLIENT_ROLE = f"{CLIENT_PRINCIPAL}_role"

ADMIN_PRINCIPAL = os.getenv("POLARIS_ADMIN_PRINCIPAL", "admin")

REQUEST_TIMEOUT = 10

# ==============================
# Helpers
# ==============================
def wait(msg: str) -> None:
    print(msg, flush=True)
    time.sleep(2)


def api_get(endpoint: str, headers: dict) -> requests.Response:
    return requests.get(
        f"{POLARIS_MGMT}/{endpoint}", headers=headers, timeout=REQUEST_TIMEOUT
    )


def api_post(endpoint: str, headers: dict, body: dict) -> requests.Response:
    return requests.post(
        f"{POLARIS_MGMT}/{endpoint}",
        headers=headers,
        json=body,
        timeout=REQUEST_TIMEOUT,
    )


def api_put(endpoint: str, headers: dict, body: dict) -> requests.Response:
    return requests.put(
        f"{POLARIS_MGMT}/{endpoint}",
        headers=headers,
        json=body,
        timeout=REQUEST_TIMEOUT,
    )


def ensure_status(
    response: requests.Response,
    *,
    action: str,
    ok_status: Iterable[int],
) -> requests.Response:
    if response.status_code in ok_status:
        return response

    raise RuntimeError(
        f"❌ {action} failed with {response.status_code}: {response.text}"
    )


# ==============================
# Authentication
# ==============================
def get_token() -> str:
    print("Using OAuth2 client credentials authentication...")

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
    }

    data = {
        "grant_type": "client_credentials",
        "client_id": ADMIN_CLIENT_ID,
        "client_secret": ADMIN_CLIENT_SECRET,
        "scope": "PRINCIPAL_ROLE:ALL",
    }

    for attempt in range(20):
        try:
            print(f"Authenticating with Polaris (attempt {attempt + 1})...")
            r = requests.post(
                POLARIS_OAUTH_TOKEN_URL,
                headers=headers,
                data=data,
                timeout=REQUEST_TIMEOUT,
            )

            if r.status_code == 200 and "access_token" in r.json():
                print("✓ Authenticated with Polaris")
                return r.json()["access_token"]

            print(f"Auth failed: {r.status_code} {r.text}")
        except Exception as e:  # noqa: BLE001
            print(f"Auth error: {e}")

        wait("Retrying authentication...")

    raise RuntimeError("❌ Could not authenticate to Polaris")


# ==============================
# Bootstrap steps
# ==============================
def ensure_admin_principal(token: str) -> None:
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    r = api_get(f"principals/{ADMIN_PRINCIPAL}", headers)
    if r.status_code == 200:
        print(f"✓ Admin principal '{ADMIN_PRINCIPAL}' already exists")
        return

    body = {
        "principal": {
            "name": ADMIN_PRINCIPAL,
            "properties": {"purpose": "admin"},
        },
        "credentialRotationRequired": False,
    }

    created = api_post("principals", headers, body)
    ensure_status(created, action="create admin principal", ok_status=(201,))
    print(f"✓ Created admin principal '{ADMIN_PRINCIPAL}'")


def ensure_catalog(token: str) -> None:
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    r = api_get(f"catalogs/{CATALOG_NAME}", headers)
    if r.status_code == 200:
        print(f"✓ Catalog '{CATALOG_NAME}' already exists")
        return

    body = {
        "catalog": {
            "name": CATALOG_NAME,
            "type": "ICEBERG_REST",
            "properties": {
                "uri": f"http://{POLARIS_HOST}:{POLARIS_PORT}/api/catalog/v1/{CATALOG_NAME}"
            },
        }
    }

    created = api_post("catalogs", headers, body)
    ensure_status(created, action="create catalog", ok_status=(201,))
    print(f"✓ Created catalog '{CATALOG_NAME}'")


def ensure_client_principal(token: str) -> dict:
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    r = api_get(f"principals/{CLIENT_PRINCIPAL}", headers)
    if r.status_code == 200:
        print(f"✓ Client principal '{CLIENT_PRINCIPAL}' exists, rotating credentials")
        rotation = api_post(f"principals/{CLIENT_PRINCIPAL}/rotate", headers, {})
        ensure_status(rotation, action="rotate client credentials", ok_status=(200,))
        return rotation.json()["credentials"]

    body = {
        "principal": {
            "name": CLIENT_PRINCIPAL,
            "properties": {"purpose": "lakehouse client"},
        },
        "credentialRotationRequired": False,
    }

    created = api_post("principals", headers, body)
    ensure_status(created, action="create client principal", ok_status=(201,))
    print(f"✓ Created client principal '{CLIENT_PRINCIPAL}'")
    return created.json()["credentials"]


def assign_roles(token: str) -> None:
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    def safe_post(endpoint: str, body: dict, description: str) -> None:
        response = api_post(endpoint, headers, body)
        ensure_status(
            response,
            action=description,
            ok_status=(200, 201, 204, 409),
        )

    def safe_put(endpoint: str, body: dict, description: str) -> None:
        response = api_put(endpoint, headers, body)
        ensure_status(
            response,
            action=description,
            ok_status=(200, 201, 204, 409),
        )

    # Principal role
    safe_post("principal-roles", {"principalRole": {"name": CLIENT_ROLE}}, "create principal role")
    safe_put(
        f"principals/{CLIENT_PRINCIPAL}/principal-roles",
        {"principalRole": {"name": CLIENT_ROLE}},
        "assign principal role",
    )

    # Catalog role
    catalog_role = f"{CATALOG_NAME}_role"
    safe_post(
        f"catalogs/{CATALOG_NAME}/catalog-roles",
        {"catalogRole": {"name": catalog_role}},
        "create catalog role",
    )

    safe_put(
        f"principal-roles/{CLIENT_ROLE}/catalog-roles/{CATALOG_NAME}",
        {"catalogRole": {"name": catalog_role}},
        "link catalog role",
    )

    safe_put(
        f"catalogs/{CATALOG_NAME}/catalog-roles/{catalog_role}/grants",
        {"grant": {"type": "catalog", "privilege": "CATALOG_MANAGE_CONTENT"}},
        "grant catalog access",
    )

    print(f"✓ Granted catalog access on '{CATALOG_NAME}'")


# ==============================
# MAIN
# ==============================
if __name__ == "__main__":
    print("🚀 Polaris bootstrap starting\n")

    token = get_token()

    ensure_admin_principal(token)
    ensure_catalog(token)
    assign_roles(token)
    creds = ensure_client_principal(token)

    print("\n🎉 Polaris bootstrap completed\n")
    print("Client credentials:")
    print("  POLARIS_CLIENT_ID:", creds["clientId"])
    print("  POLARIS_CLIENT_SECRET:", creds["clientSecret"])

    with open("/workspace/.env", "a", encoding="utf-8") as f:
        f.write(f"\nPOLARIS_CLIENT_ID={creds['clientId']}")
        f.write(f"\nPOLARIS_CLIENT_SECRET={creds['clientSecret']}")

    print("✓ Credentials written to .env")
