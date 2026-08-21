# Terminal Shop for Omarchy

The repository includes the official [Terminal GitHub organization avatar](https://avatars.githubusercontent.com/u/166243908?s=256&v=4) as `assets/terminal-shop-avatar.png`; the bar renders a monochrome mark derived from it to match Omarchy's icon system.

An Omarchy shell bar plugin for managing terminal.shop accounts, shopping, and
account data. It provides:

- secure personal-access-token onboarding with Secret Service storage;
- dev-sandbox and production account switching;
- product and variant browsing, cart editing, address/card selection, and a
  confirmation-gated checkout flow;
- order details, cancellation, and eligible shipping updates;
- subscription creation, schedule/card/address updates, and cancellation;
- profile, address, payment-method, and email management;
- personal access-token and OAuth application management;
- a fixed-operation API explorer for the complete documented API surface;
- keyboard navigation, a monochrome Terminal bar mark, and JSON response
  inspection.

The helper exposes the current documented Terminal API through an explicit
operation registry. Production mutations always show a confirmation step, and
the plugin never stores credentials in `shell.json` or accepts arbitrary URLs.

## Requirements

- Omarchy shell with Quickshell
- Python 3
- `secret-tool` with an unlocked Secret Service collection
- Network access to terminal.shop

## Install locally

From this directory:

```bash
omarchy plugin validate ./terminal-shop
```

For a local checkout, install it into Omarchy's user plugin directory:

```bash
install -d ~/.config/omarchy/plugins/terminal.shop
cp -a ./terminal-shop/. ~/.config/omarchy/plugins/terminal.shop/
omarchy-shell shell rescanPlugins
omarchy plugin enable terminal.shop --section right
```

To remove it safely:

```bash
omarchy plugin disable terminal.shop
omarchy plugin remove terminal.shop --yes
```

Once the plugin is published as a git repository, the normal installer is:

```bash
omarchy plugin add https://github.com/dl-alexandre/terminal-shop-omarchy.git --enable --yes
```

For development, point the Omarchy plugin directory at this folder or copy the
folder into `~/.config/omarchy/plugins/terminal.shop/`, then rescan:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable terminal.shop --section right
```

The helper's direct interface is also useful from a terminal:

```bash
~/.config/omarchy/plugins/terminal.shop/bin/terminal-shop call product.list --environment production
~/.config/omarchy/plugins/terminal.shop/bin/terminal-shop call order.list --account-id <account-id>
```

The API explorer and helper only allow operations from the checked-in registry;
they do not accept arbitrary hostnames or paths.

The plugin never writes a credential to `shell.json`. Account metadata is kept
under `$XDG_STATE_HOME/omarchy/terminal-shop/accounts.json` with mode 0600;
PATs are stored in Secret Service under the `terminal-shop` service name.

## API helper

The helper accepts one JSON request line on stdin and returns one JSON response
line. For example, after adding an account:

```bash
./bin/terminal-shop call view.init --account-id production-usr_example
```

The `call` command only accepts the fixed operation names in
`lib/terminal_shop.py`. It never accepts a caller-provided base URL. Read
operations retry transient failures; writes do not retry automatically.

Use the dev environment first. Production order, subscription, card, token,
and app mutations are confirmation-gated in the panel; the helper itself never
silently promotes a request to production.
