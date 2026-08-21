import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))

from terminal_shop import (  # noqa: E402
    OPERATIONS,
    normalize_api_error,
    normalize_environment,
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


if __name__ == "__main__":
    unittest.main()
