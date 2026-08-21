# Terminal API contract

The helper is intentionally pinned to the documented Terminal API surface
instead of accepting arbitrary URLs. The current upstream contract is:

- API documentation: <https://www.terminal.shop/api>
- OpenAPI document: <https://api.terminal.shop/doc>
- Production: `https://api.terminal.shop`
- Dev sandbox: `https://api.dev.terminal.shop`

`lib/terminal_shop.py` contains the checked-in operation registry. It covers
the documented product, profile, address, card, cart, order, subscription,
token, app, account-link, view, and email operations. Read operations may retry
transient failures; mutations never retry automatically because the API does
not expose an idempotency contract for this client.
