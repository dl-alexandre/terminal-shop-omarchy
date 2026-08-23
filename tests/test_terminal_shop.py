import json
from io import BytesIO
from pathlib import Path
import sys
import unittest
from urllib.request import Request


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))

from terminal_shop import (  # noqa: E402
    OPERATIONS,
    normalize_api_error,
    normalize_environment,
    FixedOriginRedirectHandler,
    RedirectBlockedError,
    redact_sensitive_data,
    read_response_body,
    render_path,
)


class TerminalShopContractTests(unittest.TestCase):
    def test_documented_operation_count(self):
        self.assertEqual(len(OPERATIONS), 41)

    def test_all_resource_groups_are_present(self):
        expected_prefixes = {
            "product.",
            "profile.",
            "address.",
            "card.",
            "cart.",
            "order.",
            "subscription.",
            "token.",
            "app.",
            "account.",
            "view.",
            "email.",
        }
        self.assertEqual({name.split(".", 1)[0] + "." for name in OPERATIONS}, expected_prefixes)

    def test_path_parameters_are_url_encoded(self):
        self.assertEqual(render_path("/product/{id}", {"id": "var/one two"}), "/product/var%2Fone%20two")

    def test_missing_path_parameter_is_rejected(self):
        with self.assertRaises(Exception):
            render_path("/order/{id}", {})

    def test_environment_aliases(self):
        self.assertEqual(normalize_environment("prod"), "production")
        self.assertEqual(normalize_environment("sandbox"), "dev")

    def test_public_and_mutating_operations_have_expected_auth_and_retry_policy(self):
        self.assertFalse(OPERATIONS["product.list"]["auth"])
        self.assertTrue(OPERATIONS["product.list"]["retry"])
        self.assertTrue(OPERATIONS["order.list"]["auth"])
        self.assertFalse(OPERATIONS["cart.convert"]["retry"])

    def test_error_normalization_does_not_echo_unknown_payload(self):
        error = normalize_api_error(401, {"message": "nope", "token": "should-not-be-copied"})
        self.assertEqual(error["code"], "http_401")
        self.assertNotIn("token", json.dumps(error))

    def test_error_normalization_redacts_secret_like_messages_and_details(self):
        error = normalize_api_error(
            400,
            {"message": "token=super-secret-value", "details": {"secret": "hidden", "field": "email"}},
        )
        self.assertNotIn("super-secret-value", json.dumps(error))
        self.assertEqual(error["details"]["secret"], "[REDACTED]")

    def test_response_body_is_bounded(self):
        raw, error = read_response_body(BytesIO(b"{}"))
        self.assertEqual(raw, b"{}")
        self.assertIsNone(error)

        from terminal_shop import MAX_RESPONSE_BYTES

        raw, error = read_response_body(BytesIO(b"x" * (MAX_RESPONSE_BYTES + 1)))
        self.assertEqual(raw, b"")
        self.assertIn("exceeded", error or "")

    def test_sensitive_response_fields_are_redacted(self):
        value = redact_sensitive_data({"id": "tok_1", "token": "secret", "nested": [{"password": "pw"}]})
        self.assertEqual(value["id"], "tok_1")
        self.assertEqual(value["token"], "[REDACTED]")
        self.assertEqual(value["nested"][0]["password"], "[REDACTED]")

    def test_redirect_handler_rejects_cross_origin_and_scheme_changes(self):
        handler = FixedOriginRedirectHandler("https://api.terminal.shop")
        request = Request("https://api.terminal.shop/profile")
        with self.assertRaises(RedirectBlockedError):
            handler.redirect_request(request, None, 302, "Found", {}, "https://evil.example/profile")
        with self.assertRaises(RedirectBlockedError):
            handler.redirect_request(request, None, 302, "Found", {}, "http://api.terminal.shop/profile")

    def test_redirect_handler_allows_same_origin_https(self):
        handler = FixedOriginRedirectHandler("https://api.terminal.shop")
        request = Request("https://api.terminal.shop/profile")
        redirected = handler.redirect_request(
            request, None, 302, "Found", {"Content-Length": "0"}, "https://api.terminal.shop/v2/profile"
        )
        self.assertEqual(redirected.full_url, "https://api.terminal.shop/v2/profile")


if __name__ == "__main__":
    unittest.main()
