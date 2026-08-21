#!/usr/bin/env python3
"""Secure, dependency-free Terminal API adapter for the Omarchy plugin.

The QML process communicates with this helper using one JSON request line and
one JSON response line. Secrets are accepted only through stdin and are stored
in the user's Secret Service collection; they are never command-line args,
shell variables, plugin settings, or log output.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
import uuid


VERSION = "0.1.0"
MAX_RETRIES = 2
REQUEST_TIMEOUT_SECONDS = 20
RETRY_STATUS_CODES = {408, 429} | set(range(500, 600))

ENVIRONMENTS = {
    "production": {
        "api": "https://api.terminal.shop",
        "auth": "https://auth.terminal.shop",
    },
    "dev": {
        "api": "https://api.dev.terminal.shop",
        "auth": "https://auth.dev.terminal.shop",
    },
}

ENVIRONMENT_ALIASES = {"prod": "production", "production": "production", "dev": "dev", "sandbox": "dev"}


def _operation(method: str, path: str, *, auth: bool = True) -> dict[str, Any]:
    return {"method": method, "path": path, "auth": auth, "retry": method == "GET"}


# Keep this registry explicit and reviewable. It is also the coverage checklist
# for the documented Terminal API. The upstream page currently lists 37
# operations across these resources. The list mirrors the current v1.0.3
# OpenAPI document, including the account-link and order-management routes.
OPERATIONS: dict[str, dict[str, Any]] = {
    "product.list": _operation("GET", "/product", auth=False),
    "product.get": _operation("GET", "/product/{id}", auth=False),
    "profile.get": _operation("GET", "/profile"),
    "profile.update": _operation("PUT", "/profile"),
    "address.list": _operation("GET", "/address"),
    "address.get": _operation("GET", "/address/{id}"),
    "address.create": _operation("POST", "/address"),
    "address.update": _operation("PATCH", "/address/{id}"),
    "address.delete": _operation("DELETE", "/address/{id}"),
    "card.list": _operation("GET", "/card"),
    "card.get": _operation("GET", "/card/{id}"),
    "card.create": _operation("POST", "/card"),
    "card.collect": _operation("POST", "/card/collect"),
    "card.delete": _operation("DELETE", "/card/{id}"),
    "cart.get": _operation("GET", "/cart"),
    "cart.set_item": _operation("PUT", "/cart/item"),
    "cart.set_address": _operation("PUT", "/cart/address"),
    "cart.set_card": _operation("PUT", "/cart/card"),
    "cart.convert": _operation("POST", "/cart/convert"),
    "cart.clear": _operation("DELETE", "/cart"),
    "order.list": _operation("GET", "/order"),
    "order.get": _operation("GET", "/order/{id}"),
    "order.create": _operation("POST", "/order"),
    "order.cancel": _operation("DELETE", "/order/{id}"),
    "order.update_shipping": _operation("PATCH", "/order/{id}/shipping"),
    "subscription.list": _operation("GET", "/subscription"),
    "subscription.get": _operation("GET", "/subscription/{id}"),
    "subscription.update": _operation("PUT", "/subscription/{id}"),
    "subscription.create": _operation("POST", "/subscription"),
    "subscription.cancel": _operation("DELETE", "/subscription/{id}"),
    "token.list": _operation("GET", "/token"),
    "token.get": _operation("GET", "/token/{id}"),
    "token.create": _operation("POST", "/token"),
    "token.delete": _operation("DELETE", "/token/{id}"),
    "app.list": _operation("GET", "/app"),
    "app.get": _operation("GET", "/app/{id}"),
    "app.create": _operation("POST", "/app"),
    "app.delete": _operation("DELETE", "/app/{id}"),
    "account.link_email": _operation("POST", "/account/link-email"),
    "view.init": _operation("GET", "/view/init"),
    "email.subscribe": _operation("POST", "/email", auth=False),
}

ALIASES = {
    "products": "product.list",
    "profile": "profile.get",
    "snapshot": "view.init",
}


class HelperError(Exception):
    """An expected, user-actionable helper failure."""

    def __init__(self, code: str, message: str, *, details: Any = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def normalize_environment(value: Any) -> str:
    environment = str(value or "").strip().lower()
    try:
        return ENVIRONMENT_ALIASES[environment]
    except KeyError as exc:
        raise HelperError("invalid_environment", "Environment must be 'dev' or 'production'.") from exc


def validate_account_id(value: Any) -> str:
    account_id = str(value or "").strip()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", account_id):
        raise HelperError("invalid_account_id", "Account id contains unsupported characters.")
    return account_id


def safe_identifier(value: Any, fallback: str = "account") -> str:
    candidate = re.sub(r"[^A-Za-z0-9._-]+", "-", str(value or "").strip()).strip("-")
    candidate = candidate[:100]
    return candidate if candidate else fallback


def read_json_line() -> dict[str, Any]:
    raw = sys.stdin.readline()
    if not raw.strip():
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HelperError("invalid_json", "Request input was not valid JSON.") from exc
    if not isinstance(value, dict):
        raise HelperError("invalid_request", "Request input must be a JSON object.")
    return value


def write_response(value: dict[str, Any]) -> None:
    # One compact line keeps the QML StdioCollector and CLI behavior identical.
    sys.stdout.write(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def ok_response(operation: str, data: Any, *, status: int, environment: str, account_id: str = "") -> dict[str, Any]:
    return {
        "ok": True,
        "operation": operation,
        "status": status,
        "data": data,
        "meta": {
            "environment": environment,
            "accountId": account_id,
            "fetchedAt": now_iso(),
        },
    }


def error_response(
    operation: str,
    error: dict[str, Any],
    *,
    status: int = 0,
    environment: str = "",
    account_id: str = "",
) -> dict[str, Any]:
    return {
        "ok": False,
        "operation": operation,
        "status": status,
        "error": error,
        "meta": {
            "environment": environment,
            "accountId": account_id,
            "fetchedAt": now_iso(),
        },
    }


def helper_error_response(operation: str, error: HelperError) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "type": "client",
        "code": error.code,
        "message": error.message,
    }
    if error.details is not None:
        payload["details"] = error.details
    return error_response(operation, payload)


def unwrap_data(payload: Any) -> Any:
    if isinstance(payload, dict) and "data" in payload:
        return payload["data"]
    return payload


def normalize_api_error(status: int, payload: Any) -> dict[str, Any]:
    raw = payload if isinstance(payload, dict) else {}
    error_type = str(raw.get("type") or "http_error")
    code = str(raw.get("code") or f"http_{status}")
    message = str(raw.get("message") or f"Terminal API request failed with HTTP {status}.")
    normalized: dict[str, Any] = {"type": error_type, "code": code, "message": message}
    if raw.get("param") is not None:
        normalized["param"] = str(raw["param"])
    if raw.get("details") is not None:
        normalized["details"] = raw["details"]
    return normalized


def render_path(template: str, params: dict[str, str]) -> str:
    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in params or params[key] == "":
            raise HelperError("missing_path_parameter", f"Missing path parameter: {key}.")
        return quote(params[key], safe="")

    return re.sub(r"\{([A-Za-z0-9_]+)\}", replace, template)


def parse_params(values: list[str] | None) -> dict[str, str]:
    params: dict[str, str] = {}
    for value in values or []:
        if "=" not in value:
            raise HelperError("invalid_path_parameter", "Path parameters must use key=value syntax.")
        key, item = value.split("=", 1)
        key = key.strip()
        if not key:
            raise HelperError("invalid_path_parameter", "Path parameter name cannot be empty.")
        params[key] = item
    return params


class ApiClient:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")

    def request(
        self,
        method: str,
        path: str,
        *,
        token: str = "",
        body: Any = None,
        retryable: bool = False,
    ) -> tuple[int, Any, dict[str, str], str | None]:
        encoded_body = None
        headers = {
            "Accept": "application/json",
            "User-Agent": f"terminal-shop-omarchy/{VERSION}",
        }
        if body is not None and method != "GET":
            encoded_body = json.dumps(body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = f"Bearer {token}"

        for attempt in range(MAX_RETRIES + 1):
            request = Request(self.base_url + path, data=encoded_body, headers=headers, method=method)
            try:
                with urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                    raw = response.read()
                    payload, decode_error = decode_body(raw)
                    status = int(response.status)
                    if retryable and status in RETRY_STATUS_CODES and attempt < MAX_RETRIES:
                        time.sleep(0.25 * (2**attempt))
                        continue
                    return status, payload, dict(response.headers.items()), decode_error
            except HTTPError as exc:
                raw = exc.read()
                payload, decode_error = decode_body(raw)
                status = int(exc.code)
                if retryable and status in RETRY_STATUS_CODES and attempt < MAX_RETRIES:
                    time.sleep(0.25 * (2**attempt))
                    continue
                return status, payload, dict(exc.headers.items()) if exc.headers else {}, decode_error
            except (TimeoutError, URLError) as exc:
                if retryable and attempt < MAX_RETRIES:
                    time.sleep(0.25 * (2**attempt))
                    continue
                reason = getattr(exc, "reason", exc)
                return 0, None, {}, f"Network request failed: {reason}."

        return 0, None, {}, "Network request failed."


def decode_body(raw: bytes) -> tuple[Any, str | None]:
    if not raw:
        return {}, None
    try:
        return json.loads(raw.decode("utf-8")), None
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None, "Terminal API returned an invalid JSON response."


def response_error(status: int, message: str | None) -> dict[str, Any]:
    if status == 0:
        return {
            "type": "network",
            "code": "network_error",
            "message": message or "Network request failed.",
        }
    return {
        "type": "invalid_response",
        "code": "invalid_json",
        "message": message or "Terminal API returned an invalid JSON response.",
    }


def state_file() -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME") or "~/.local/state").expanduser()
    return state_home / "omarchy" / "terminal-shop" / "accounts.json"


def load_accounts() -> list[dict[str, Any]]:
    path = state_file()
    if not path.exists():
        return []
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HelperError("invalid_account_store", "The local account metadata file could not be read.") from exc
    accounts = value.get("accounts", []) if isinstance(value, dict) else []
    if not isinstance(accounts, list):
        raise HelperError("invalid_account_store", "The local account metadata file has an invalid shape.")
    return [item for item in accounts if isinstance(item, dict) and item.get("id")]


def save_accounts(accounts: list[dict[str, Any]]) -> None:
    path = state_file()
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        os.chmod(path.parent, 0o700)
    except OSError:
        pass
    payload = {"version": 1, "accounts": accounts}
    fd, temporary = tempfile.mkstemp(prefix="accounts.", suffix=".tmp", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def account_by_id(accounts: list[dict[str, Any]], account_id: str) -> dict[str, Any] | None:
    for account in accounts:
        if str(account.get("id")) == account_id:
            return account
    return None


def secret_attributes(account_id: str, environment: str) -> list[str]:
    return [
        "service",
        "terminal-shop",
        "account-id",
        account_id,
        "environment",
        environment,
        "credential",
        "access-token",
    ]


class SecretStore:
    def __init__(self) -> None:
        if shutil.which("secret-tool") is None:
            raise HelperError("secret_service_unavailable", "secret-tool is required to store Terminal credentials.")

    def lookup(self, account_id: str, environment: str) -> str:
        completed = subprocess.run(
            ["secret-tool", "lookup", *secret_attributes(account_id, environment)],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if completed.returncode == 1 and not completed.stdout.strip():
            raise HelperError("credential_missing", "No credential is stored for this account.")
        if completed.returncode != 0:
            raise HelperError("secret_service_error", "Secret Service could not read this credential.")
        token = completed.stdout.strip()
        if not token:
            raise HelperError("credential_missing", "No credential is stored for this account.")
        return token

    def store(self, account_id: str, environment: str, token: str, label: str) -> None:
        completed = subprocess.run(
            [
                "secret-tool",
                "store",
                "--label",
                f"Terminal Shop: {label}",
                *secret_attributes(account_id, environment),
            ],
            input=token + "\n",
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if completed.returncode != 0:
            raise HelperError("secret_service_error", "Secret Service could not store this credential.")

    def clear(self, account_id: str, environment: str) -> None:
        completed = subprocess.run(
            ["secret-tool", "clear", *secret_attributes(account_id, environment)],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if completed.returncode not in (0, 1):
            raise HelperError("secret_service_error", "Secret Service could not remove this credential.")


def run_account_list() -> dict[str, Any]:
    accounts = load_accounts()
    accounts.sort(key=lambda item: (str(item.get("label", "")).lower(), str(item.get("id", ""))))
    return {"ok": True, "operation": "account.list", "status": 200, "data": accounts, "meta": {"fetchedAt": now_iso()}}


def run_account_add(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    environment = normalize_environment(payload.get("environment") or args.environment)
    token = str(payload.get("token") or "").strip()
    if not token:
        raise HelperError("token_required", "Paste a personal access token to connect this account.")

    client = ApiClient(ENVIRONMENTS[environment]["api"])
    status, response, _, decode_error = client.request("GET", "/profile", token=token, retryable=True)
    if decode_error:
        return error_response("account.add", response_error(status, decode_error), status=status, environment=environment)
    if status < 200 or status >= 300:
        return error_response("account.add", normalize_api_error(status, response), status=status, environment=environment)

    profile = unwrap_data(response)
    user = profile.get("user") if isinstance(profile, dict) else {}
    if not isinstance(user, dict):
        user = profile if isinstance(profile, dict) else {}
    user_id = str(user.get("id") or "")
    requested_id = str(payload.get("accountId") or "").strip()
    identity_hint = user_id or str(user.get("email") or "") or uuid.uuid4().hex[:12]
    account_id = validate_account_id(requested_id) if requested_id else validate_account_id(
        safe_identifier(f"{environment}-{identity_hint}")
    )
    label = str(payload.get("label") or user.get("name") or user.get("email") or account_id).strip()
    accounts = load_accounts()
    account = {
        "id": account_id,
        "label": label[:120],
        "environment": environment,
        "userId": user_id,
        "name": user.get("name"),
        "email": user.get("email"),
        "createdAt": next((item.get("createdAt") for item in accounts if item.get("id") == account_id), now_iso()),
        "updatedAt": now_iso(),
    }

    store = SecretStore()
    store.store(account_id, environment, token, label)
    try:
        accounts = [item for item in accounts if item.get("id") != account_id]
        accounts.append(account)
        save_accounts(accounts)
    except Exception:
        store.clear(account_id, environment)
        raise

    return ok_response("account.add", {"account": account}, status=200, environment=environment, account_id=account_id)


def run_account_remove(account_id: str) -> dict[str, Any]:
    account_id = validate_account_id(account_id)
    accounts = load_accounts()
    account = account_by_id(accounts, account_id)
    if account is None:
        raise HelperError("account_not_found", "That local account does not exist.")
    environment = normalize_environment(account.get("environment"))
    SecretStore().clear(account_id, environment)
    save_accounts([item for item in accounts if item.get("id") != account_id])
    return ok_response("account.remove", {"accountId": account_id, "removed": True}, status=200, environment=environment, account_id=account_id)


def run_call(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    operation = ALIASES.get(args.operation, args.operation)
    if operation not in OPERATIONS:
        raise HelperError("unknown_operation", f"Unknown Terminal API operation: {args.operation}.")
    spec = OPERATIONS[operation]
    params = parse_params(args.param)
    path = render_path(spec["path"], params)
    accounts = load_accounts()
    account_id = str(args.account_id or "").strip()
    token = ""

    if spec["auth"]:
        if not account_id:
            raise HelperError("account_required", "This operation requires --account-id.")
        account_id = validate_account_id(account_id)
        account = account_by_id(accounts, account_id)
        if account is None:
            raise HelperError("account_not_found", "That local account does not exist.")
        environment = normalize_environment(account.get("environment"))
        token = SecretStore().lookup(account_id, environment)
    else:
        environment = normalize_environment(args.environment or "production")

    client = ApiClient(ENVIRONMENTS[environment]["api"])
    status, response, _, decode_error = client.request(
        spec["method"],
        path,
        token=token,
        body=payload if spec["method"] != "GET" and payload else None,
        retryable=bool(spec["retry"]),
    )
    if decode_error:
        return error_response(operation, response_error(status, decode_error), status=status, environment=environment, account_id=account_id)
    if status < 200 or status >= 300:
        return error_response(operation, normalize_api_error(status, response), status=status, environment=environment, account_id=account_id)
    return ok_response(operation, unwrap_data(response), status=status, environment=environment, account_id=account_id)


def run_auth_metadata(args: argparse.Namespace) -> dict[str, Any]:
    environment = normalize_environment(args.environment)
    client = ApiClient(ENVIRONMENTS[environment]["auth"])
    status, response, _, decode_error = client.request("GET", "/.well-known/oauth-authorization-server", retryable=True)
    if decode_error:
        return error_response("auth.metadata", response_error(status, decode_error), status=status, environment=environment)
    if status < 200 or status >= 300:
        return error_response("auth.metadata", normalize_api_error(status, response), status=status, environment=environment)
    return ok_response("auth.metadata", response, status=status, environment=environment)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="terminal-shop", description="Terminal API helper for the Omarchy shell plugin.")
    parser.add_argument("--version", action="version", version=VERSION)
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("account-list", help="List local account metadata without credentials.")

    add = commands.add_parser("account-add", help="Verify and store a PAT supplied on stdin as JSON.")
    add.add_argument("--environment", default="", help="Optional dev or production default.")

    remove = commands.add_parser("account-remove", help="Remove one local account and its credential.")
    remove.add_argument("--account-id", required=True)

    call = commands.add_parser("call", help="Call one allowlisted Terminal API operation.")
    call.add_argument("operation")
    call.add_argument("--account-id", default="")
    call.add_argument("--environment", default="")
    call.add_argument("--param", action="append", default=[], help="Path parameter as key=value; repeatable.")

    metadata = commands.add_parser("auth-metadata", help="Read fixed OAuth discovery metadata.")
    metadata.add_argument("--environment", default="production")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args: argparse.Namespace | None = None
    try:
        args = parser.parse_args(argv)
        if args.command == "account-list":
            response = run_account_list()
        elif args.command == "account-add":
            response = run_account_add(args, read_json_line())
        elif args.command == "account-remove":
            response = run_account_remove(args.account_id)
        elif args.command == "call":
            response = run_call(args, read_json_line())
        elif args.command == "auth-metadata":
            response = run_auth_metadata(args)
        else:
            raise HelperError("unknown_command", "Unknown helper command.")
        write_response(response)
        return 0 if response.get("ok") else 1
    except HelperError as error:
        write_response(helper_error_response(getattr(args, "command", "helper") if args else "helper", error))
        return 2
    except (OSError, subprocess.SubprocessError) as error:
        write_response(helper_error_response(getattr(args, "command", "helper") if args else "helper", HelperError("local_error", "Local credential or state operation failed.")))
        return 2


__all__ = [
    "ALIASES",
    "ENVIRONMENTS",
    "OPERATIONS",
    "ApiClient",
    "HelperError",
    "normalize_api_error",
    "normalize_environment",
    "render_path",
    "main",
]
