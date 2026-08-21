import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "TerminalModel.js" as Model

Panel {
  id: root

  moduleName: "terminal.shop"
  ipcTarget: "terminal.shop"
  manageIpc: false

  // Resolve the bundled helper from this QML file. Bar-widget instances are
  // injected with bar/moduleName/settings, but not the discovery manifest.
  // Keeping the path relative to the loaded plugin also avoids PATH lookup.
  readonly property string helperPath: {
    var path = String(Qt.resolvedUrl("bin/terminal-shop"))
    if (path.indexOf("file://") === 0) path = path.substring(7)
    try { return decodeURIComponent(path) } catch (e) { return path }
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int refreshIntervalSec: Math.max(60, Number(setting("refreshIntervalSec", 900)))

  property var accounts: []
  property string activeAccountId: ""
  property var snapshot: ({})
  property var products: []
  property var tokens: []
  property var apps: []
  property bool loading: false
  property string errorText: ""
  property string statusText: ""
  property string refreshedAt: ""
  property int tabIndex: 0
  property bool cursorActive: false

  property string selectedOrderId: ""
  property string selectedAddressId: ""
  property string selectedSubscriptionId: ""
  property string profileName: ""
  property string profileEmail: ""
  property string emailInput: ""
  property string addressName: ""
  property string addressStreet1: ""
  property string addressStreet2: ""
  property string addressCity: ""
  property string addressProvince: ""
  property string addressCountry: "US"
  property string addressZip: ""
  property string addressPhone: ""
  property string orderShippingName: ""
  property string orderShippingStreet1: ""
  property string orderShippingStreet2: ""
  property string orderShippingCity: ""
  property string orderShippingProvince: ""
  property string orderShippingCountry: "US"
  property string orderShippingZip: ""
  property string orderShippingPhone: ""
  property string appName: ""
  property string appRedirectUri: ""
  property string subscriptionQuantity: "1"
  property string subscriptionInterval: "1"
  property string subscriptionScheduleType: "weekly"
  property int subscriptionVariantIndex: 0
  property int subscriptionAddressIndex: 0
  property int subscriptionCardIndex: 0
  property string apiOperation: "product.list"
  property string apiParamsText: ""
  property string apiBodyText: "{}"
  property string apiOutput: ""
  property string apiCreateTokenOutput: ""
  property string requestOperation: ""
  property string confirmTitle: ""
  property string confirmMessage: ""
  property string confirmOperation: ""
  property var confirmParams: ({})
  property var confirmBody: ({})
  property var lastResult: ({})

  property string setupEnvironment: "dev"
  property string setupLabel: ""
  property string setupToken: ""
  property bool setupTokenVisible: false

  // One in-flight helper request plus one latest-wins pending request keeps
  // refresh clicks cheap without allowing stale stdout to overwrite newer UI.
  property string requestKind: ""
  property string requestInput: ""
  property var pendingJob: null
  property bool processFinished: true
  property bool responseHandled: true

  readonly property bool hasAccount: accounts.length > 0 && !!activeAccount
  readonly property bool setupMode: accounts.length === 0
  readonly property var activeAccount: findAccount(activeAccountId)
  readonly property var currentUser: Model.profileUser(snapshot)
  readonly property var cart: snapshot && snapshot.cart ? snapshot.cart : ({})
  readonly property var orders: Model.array(snapshot && snapshot.orders)
  readonly property var subscriptions: Model.array(snapshot && snapshot.subscriptions)
  readonly property var addresses: Model.array(snapshot && snapshot.addresses)
  readonly property var cards: Model.array(snapshot && snapshot.cards)
  readonly property var accountLabels: accountLabelList()
  readonly property var addressLabels: addressLabelList()
  readonly property var cardLabels: cardLabelList()
  readonly property var variantOptions: Model.variantOptions(products)
  readonly property var variantLabels: variantLabelList()
  readonly property var apiOperationNames: apiNameList()

  // Keep this list in sync with the helper's explicit registry. It powers the
  // advanced API tab without allowing arbitrary URLs or methods.
  readonly property var apiOperations: [
    { name: "product.list", method: "GET", auth: false },
    { name: "product.get", method: "GET", auth: false, params: "id" },
    { name: "profile.get", method: "GET", auth: true },
    { name: "profile.update", method: "PUT", auth: true },
    { name: "address.list", method: "GET", auth: true },
    { name: "address.get", method: "GET", auth: true, params: "id" },
    { name: "address.create", method: "POST", auth: true },
    { name: "address.update", method: "PATCH", auth: true, params: "id" },
    { name: "address.delete", method: "DELETE", auth: true, params: "id" },
    { name: "card.list", method: "GET", auth: true },
    { name: "card.get", method: "GET", auth: true, params: "id" },
    { name: "card.create", method: "POST", auth: true },
    { name: "card.collect", method: "POST", auth: true },
    { name: "card.delete", method: "DELETE", auth: true, params: "id" },
    { name: "cart.get", method: "GET", auth: true },
    { name: "cart.set_item", method: "PUT", auth: true },
    { name: "cart.set_address", method: "PUT", auth: true },
    { name: "cart.set_card", method: "PUT", auth: true },
    { name: "cart.convert", method: "POST", auth: true },
    { name: "cart.clear", method: "DELETE", auth: true },
    { name: "order.list", method: "GET", auth: true },
    { name: "order.get", method: "GET", auth: true, params: "id" },
    { name: "order.create", method: "POST", auth: true },
    { name: "order.cancel", method: "DELETE", auth: true, params: "id" },
    { name: "order.update_shipping", method: "PATCH", auth: true, params: "id" },
    { name: "subscription.list", method: "GET", auth: true },
    { name: "subscription.get", method: "GET", auth: true, params: "id" },
    { name: "subscription.update", method: "PUT", auth: true, params: "id" },
    { name: "subscription.create", method: "POST", auth: true },
    { name: "subscription.cancel", method: "DELETE", auth: true, params: "id" },
    { name: "token.list", method: "GET", auth: true },
    { name: "token.get", method: "GET", auth: true, params: "id" },
    { name: "token.create", method: "POST", auth: true },
    { name: "token.delete", method: "DELETE", auth: true, params: "id" },
    { name: "app.list", method: "GET", auth: true },
    { name: "app.get", method: "GET", auth: true, params: "id" },
    { name: "app.create", method: "POST", auth: true },
    { name: "app.delete", method: "DELETE", auth: true, params: "id" },
    { name: "account.link_email", method: "POST", auth: true },
    { name: "view.init", method: "GET", auth: true },
    { name: "email.subscribe", method: "POST", auth: false }
  ]

  function findAccount(id) {
    for (var i = 0; i < accounts.length; i++) {
      if (String(accounts[i].id || "") === String(id || "")) return accounts[i]
    }
    return accounts.length > 0 ? accounts[0] : null
  }

  function accountLabelList() {
    var result = []
    for (var i = 0; i < accounts.length; i++) result.push(Model.accountLabel(accounts[i]))
    return result
  }

  function addressLabelList() {
    var result = []
    for (var i = 0; i < addresses.length; i++) {
      var item = addresses[i] || ({})
      result.push(String(item.name || "Address") + " · " + String(item.city || "") + " " + String(item.country || ""))
    }
    return result
  }

  function cardLabelList() {
    var result = []
    for (var i = 0; i < cards.length; i++) {
      var item = cards[i] || ({})
      result.push(String(item.brand || "Card") + " •••• " + String(item.last4 || ""))
    }
    return result
  }

  function variantLabelList() {
    var result = []
    for (var i = 0; i < variantOptions.length; i++) result.push(variantOptions[i].name)
    return result
  }

  function apiNameList() {
    var result = []
    for (var i = 0; i < apiOperations.length; i++) result.push(apiOperations[i].method + " · " + apiOperations[i].name)
    return result
  }

  function apiSpec(name) {
    for (var i = 0; i < apiOperations.length; i++)
      if (apiOperations[i].name === name) return apiOperations[i]
    return null
  }

  function apiIndex(name) {
    for (var i = 0; i < apiOperations.length; i++)
      if (apiOperations[i].name === name) return i
    return 0
  }

  function replaceSettings(nextAccountId) {
    var next = ({})
    for (var key in settings) if (key !== "id") next[key] = settings[key]
    next.activeAccountId = nextAccountId
    root.settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(root.moduleName, next)
  }

  function selectAccount(index) {
    if (index < 0 || index >= accounts.length) return
    var nextId = String(accounts[index].id || "")
    if (!nextId || nextId === activeAccountId) return
    activeAccountId = nextId
    replaceSettings(nextId)
    snapshot = ({})
    statusText = "Loading " + Model.accountLabel(accounts[index]) + "…"
    refreshSnapshot()
  }

  function selectTab(index) {
    tabIndex = Math.max(0, Math.min(8, Number(index)))
    cursorActive = true
    if (tabIndex === 6 && hasAccount && tokens.length === 0 && apps.length === 0)
      refreshSecurity()
  }

  function refreshAll() {
    errorText = ""
    statusText = "Refreshing…"
    refreshAccounts()
  }

  function refreshAccounts() {
    runHelper("accounts", ["account-list"], ({}))
  }

  function refreshSnapshot() {
    if (!activeAccountId) return
    runHelper("snapshot", ["call", "view.init", "--account-id", activeAccountId], ({}))
  }

  function refreshProducts() {
    runHelper("products", ["call", "product.list", "--environment", setupEnvironment], ({}))
  }

  function refreshSecurity() {
    if (!activeAccountId) return
    runHelper("tokens", ["call", "token.list", "--account-id", activeAccountId], ({}))
  }

  function refreshAccountFields() {
    var user = currentUser || ({})
    profileName = String(user.name || "")
    profileEmail = String(user.email || "")
  }

  function fillAddressFields(address) {
    var value = address || ({})
    selectedAddressId = String(value.id || "")
    addressName = String(value.name || "")
    addressStreet1 = String(value.street1 || "")
    addressStreet2 = String(value.street2 || "")
    addressCity = String(value.city || "")
    addressProvince = String(value.province || "")
    addressCountry = String(value.country || "US")
    addressZip = String(value.zip || "")
    addressPhone = String(value.phone || "")
  }

  function fillOrderShipping(order) {
    var value = order && order.shipping ? order.shipping : ({})
    orderShippingName = String(value.name || "")
    orderShippingStreet1 = String(value.street1 || "")
    orderShippingStreet2 = String(value.street2 || "")
    orderShippingCity = String(value.city || "")
    orderShippingProvince = String(value.province || "")
    orderShippingCountry = String(value.country || "US")
    orderShippingZip = String(value.zip || "")
    orderShippingPhone = String(value.phone || "")
  }

  function findAddress(id) {
    for (var i = 0; i < addresses.length; i++)
      if (String(addresses[i].id || "") === String(id || "")) return addresses[i]
    return null
  }

  function findOrder(id) {
    for (var i = 0; i < orders.length; i++)
      if (String(orders[i].id || "") === String(id || "")) return orders[i]
    return null
  }

  function findSubscription(id) {
    for (var i = 0; i < subscriptions.length; i++)
      if (String(subscriptions[i].id || "") === String(id || "")) return subscriptions[i]
    return null
  }

  function selectOrder(id) {
    selectedOrderId = String(id || "")
    fillOrderShipping(findOrder(selectedOrderId))
    runOperation("operation", "order.get", { id: selectedOrderId }, ({}))
  }

  function selectSubscription(id) {
    selectedSubscriptionId = String(id || "")
    var value = findSubscription(selectedSubscriptionId)
    if (!value) return
    for (var i = 0; i < addresses.length; i++)
      if (String(addresses[i].id || "") === String(value.addressID || "")) subscriptionAddressIndex = i
    for (var j = 0; j < cards.length; j++)
      if (String(cards[j].id || "") === String(value.cardID || "")) subscriptionCardIndex = j
    var schedule = value.schedule || ({})
    subscriptionScheduleType = String(schedule.type || "weekly")
    subscriptionInterval = String(schedule.interval || "1")
    runOperation("operation", "subscription.get", { id: selectedSubscriptionId }, ({}))
  }

  function selectVariantForSubscription(id) {
    for (var i = 0; i < variantOptions.length; i++)
      if (String(variantOptions[i].id || "") === String(id || "")) subscriptionVariantIndex = i
    tabIndex = 4
  }

  function selectAddressForEdit(index) {
    if (index < 0 || index >= addresses.length) return
    fillAddressFields(addresses[index])
  }

  function addressIndex(id) {
    for (var i = 0; i < addresses.length; i++)
      if (String(addresses[i].id || "") === String(id || "")) return i
    return 0
  }

  function cardIndex(id) {
    for (var i = 0; i < cards.length; i++)
      if (String(cards[i].id || "") === String(id || "")) return i
    return 0
  }

  function parseKeyValueText(value) {
    var result = ({})
    var lines = String(value || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var separator = line.indexOf("=")
      if (separator <= 0) throw new Error("Parameters must use key=value, one per line.")
      result[line.slice(0, separator).trim()] = line.slice(separator + 1).trim()
    }
    return result
  }

  function parseJsonText(value) {
    var text = String(value || "{}").trim()
    if (!text) return ({})
    var result = JSON.parse(text)
    if (!result || typeof result !== "object" || Array.isArray(result))
      throw new Error("JSON body must be an object.")
    return result
  }

  function operationUsesProduction(operation) {
    var spec = apiSpec(operation)
    if (spec && spec.auth === false) return String(setupEnvironment) === "production"
    return activeAccount && String(activeAccount.environment || "") === "production"
  }

  function runOperation(kind, operation, params, body) {
    var spec = apiSpec(operation)
    if (!spec) {
      errorText = "That API operation is not available in this build."
      return
    }
    var args = ["call", operation]
    if (spec.auth) {
      if (!activeAccountId) {
        errorText = "Connect an account before using this operation."
        return
      }
      args.push("--account-id", activeAccountId)
    } else {
      args.push("--environment", setupEnvironment)
    }
    var values = params || ({})
    for (var key in values) args.push("--param", key + "=" + String(values[key]))
    runHelper(kind || "operation", args, body || ({}), operation)
  }

  function askConfirmation(title, message, operation, params, body) {
    confirmTitle = String(title || "Confirm action")
    confirmMessage = String(message || "This action changes your Terminal account.")
    confirmOperation = operation
    confirmParams = params || ({})
    confirmBody = body || ({})
  }

  function cancelConfirmation() {
    confirmTitle = ""
    confirmMessage = ""
    confirmOperation = ""
    confirmParams = ({})
    confirmBody = ({})
  }

  function approveConfirmation() {
    var operation = confirmOperation
    var params = confirmParams
    var body = confirmBody
    cancelConfirmation()
    if (operation === "local.account-remove")
      runHelper("operation", ["account-remove", "--account-id", String(params.accountId || "")], ({}), operation)
    else
      runOperation("operation", operation, params, body)
  }

  function runMutation(title, message, operation, params, body) {
    if (operationUsesProduction(operation)) {
      askConfirmation(title, message + "\n\nThis is a PRODUCTION account and may create a real charge.", operation, params, body)
    } else {
      askConfirmation(title, message, operation, params, body)
    }
  }

  function addVariant(variantId) {
    var quantity = Model.cartItemQuantity(cart, variantId) + 1
    runMutation("Add to cart", "Add this variant to the current cart?", "cart.set_item", ({ }), { productVariantID: variantId, quantity: quantity })
  }

  function setCartQuantity(variantId, quantity) {
    runMutation("Update cart", "Update this cart item quantity?", "cart.set_item", ({}), { productVariantID: variantId, quantity: Math.max(0, Number(quantity)) })
  }

  function setCartAddress(addressId) {
    if (!addressId) return
    runMutation("Set shipping address", "Use this address for the current cart?", "cart.set_address", ({}), { addressID: addressId })
  }

  function setCartCard(cardId) {
    if (!cardId) return
    runMutation("Set payment method", "Use this saved card for the current cart?", "cart.set_card", ({}), { cardID: cardId })
  }

  function checkout() {
    if (!cart || Model.cartItemCount(cart) === 0) {
      errorText = "Add at least one item before checking out."
      return
    }
    if (!cart.addressID || !cart.cardID) {
      errorText = "Choose a shipping address and payment method first."
      return
    }
    runMutation("Place order", "Place the current cart as an order?", "cart.convert", ({}), ({}))
  }

  function updateProfile() {
    runMutation("Update profile", "Save these profile changes?", "profile.update", ({}), { name: profileName, email: profileEmail })
  }

  function addressBody() {
    return {
      name: addressName,
      street1: addressStreet1,
      street2: addressStreet2,
      city: addressCity,
      province: addressProvince,
      country: addressCountry.toUpperCase(),
      zip: addressZip,
      phone: addressPhone
    }
  }

  function saveAddress() {
    var operation = selectedAddressId ? "address.update" : "address.create"
    var params = selectedAddressId ? { id: selectedAddressId } : ({})
    runMutation(selectedAddressId ? "Update address" : "Create address", "Save this shipping address?", operation, params, addressBody())
  }

  function deleteAddress() {
    if (!selectedAddressId) return
    runMutation("Delete address", "Delete this saved shipping address?", "address.delete", { id: selectedAddressId }, ({}))
  }

  function updateOrderShipping() {
    if (!selectedOrderId) return
    runMutation("Update order shipping", "Update the shipping address for this order?", "order.update_shipping", { id: selectedOrderId }, {
      shipping: {
        name: orderShippingName,
        street1: orderShippingStreet1,
        street2: orderShippingStreet2,
        city: orderShippingCity,
        province: orderShippingProvince,
        country: orderShippingCountry.toUpperCase(),
        zip: orderShippingZip,
        phone: orderShippingPhone
      }
    })
  }

  function cancelOrder() {
    var order = findOrder(selectedOrderId)
    if (!order || order.canCancel !== true) return
    runMutation("Cancel order", "Cancel order " + selectedOrderId + "?", "order.cancel", { id: selectedOrderId }, ({}))
  }

  function subscriptionBody() {
    var variant = variantOptions[subscriptionVariantIndex]
    var address = addresses[subscriptionAddressIndex]
    var card = cards[subscriptionCardIndex]
    return {
      productVariantID: variant ? variant.id : "",
      quantity: Math.max(1, Number(subscriptionQuantity || 1)),
      addressID: address ? String(address.id || "") : "",
      cardID: card ? String(card.id || "") : "",
      schedule: subscriptionScheduleType === "weekly"
        ? { type: "weekly", interval: Math.max(1, Number(subscriptionInterval || 1)) }
        : { type: "fixed" }
    }
  }

  function selectedCardId() {
    var card = cards[subscriptionCardIndex]
    return card ? String(card.id || "") : ""
  }

  function createSubscription() {
    var body = subscriptionBody()
    if (!body.productVariantID || !body.addressID || !body.cardID) {
      errorText = "Choose a product variant, address, and payment method first."
      return
    }
    runMutation("Create subscription", "Create this recurring subscription?", "subscription.create", ({}), body)
  }

  function updateSubscription() {
    if (!selectedSubscriptionId) return
    var body = {
      addressID: selectedAddressId,
      cardID: selectedCardId(),
      schedule: subscriptionScheduleType === "weekly"
        ? { type: "weekly", interval: Math.max(1, Number(subscriptionInterval || 1)) }
        : { type: "fixed" }
    }
    runMutation("Update subscription", "Save changes to this subscription?", "subscription.update", { id: selectedSubscriptionId }, body)
  }

  function cancelSubscription() {
    if (!selectedSubscriptionId) return
    runMutation("Cancel subscription", "Cancel this recurring subscription?", "subscription.cancel", { id: selectedSubscriptionId }, ({}))
  }

  function createToken() {
    runMutation("Create access token", "Create a new personal access token? It may be shown only once.", "token.create", ({}), ({}))
  }

  function deleteToken(id) {
    runMutation("Revoke access token", "Revoke this personal access token?", "token.delete", { id: id }, ({}))
  }

  function createApp() {
    runMutation("Create OAuth app", "Create this OAuth application?", "app.create", ({}), { name: appName, redirectURI: appRedirectUri })
  }

  function deleteApp(id) {
    runMutation("Delete OAuth app", "Delete this OAuth application?", "app.delete", { id: id }, ({}))
  }

  function collectCard() {
    runOperation("operation", "card.collect", ({}), ({}))
  }

  function deleteCard(id) {
    runMutation("Delete payment method", "Delete this saved payment method?", "card.delete", { id: id }, ({}))
  }

  function removeLocalAccount() {
    if (!activeAccountId) return
    askConfirmation("Remove local account", "Remove this account and its stored token from this computer?", "local.account-remove", { accountId: activeAccountId }, ({}))
  }

  function linkEmail() {
    if (!emailInput) return
    runMutation("Link email", "Link this email address to the account?", "account.link_email", ({}), { email: emailInput })
  }

  function subscribeEmail() {
    if (!emailInput) return
    askConfirmation("Subscribe email", "Subscribe this email address to Terminal updates?", "email.subscribe", ({}), { email: emailInput })
  }

  function loadAuthMetadata() {
    runHelper("metadata", ["auth-metadata", "--environment", activeAccount ? activeAccount.environment : setupEnvironment], ({}), "auth.metadata")
  }

  function executeApi() {
    var params
    var body
    try {
      params = parseKeyValueText(apiParamsText)
      body = parseJsonText(apiBodyText)
    } catch (e) {
      errorText = String(e.message || e)
      return
    }
    var spec = apiSpec(apiOperation)
    if (!spec) return
    if (spec.method !== "GET") {
      runMutation("Execute " + apiOperation, "Execute this mutating API operation?", apiOperation, params, body)
    } else {
      runOperation("operation", apiOperation, params, body)
    }
  }

  function openResultUrl() {
    var value = lastResult
    var url = typeof value === "string" ? value : (value && (value.url || value.href || value.link))
    if (url) Qt.openUrlExternally(String(url))
  }

  function addAccount() {
    var token = String(setupToken || "").trim()
    if (!token) {
      errorText = "Paste a personal access token first."
      return
    }
    errorText = ""
    statusText = "Verifying account…"
    runHelper("account-add", ["account-add"], {
      environment: setupEnvironment,
      label: String(setupLabel || "").trim(),
      token: token
    })
  }

  function runHelper(kind, args, payload, operation) {
    var job = { kind: kind, args: args, payload: payload || ({}), operation: operation || "" }
    if (!helperPath) {
      errorText = "The Terminal Shop helper is not available from this plugin."
      return
    }
    if (helper.running || !processFinished) {
      pendingJob = job
      return
    }
    startHelper(job)
  }

  function startHelper(job) {
    requestKind = job.kind
    requestOperation = job.operation || ""
    requestInput = JSON.stringify(job.payload || ({}))
    processFinished = false
    responseHandled = false
    loading = true
    errorText = ""
    helper.command = [helperPath].concat(job.args || [])
    helper.running = true
  }

  function maybeStartPending() {
    if (!processFinished || !responseHandled) return
    if (pendingJob) {
      var next = pendingJob
      pendingJob = null
      startHelper(next)
    } else {
      loading = false
      statusText = statusText === "Refreshing…" || statusText === "Loading…" ? "" : statusText
    }
  }

  function handleHelper(kind, raw) {
    var response = null
    try { response = JSON.parse(String(raw || "")) } catch (e) {
      errorText = "The helper returned invalid JSON."
      responseHandled = true
      maybeStartPending()
      return
    }

    if (!response || response.ok !== true) {
      var error = response && response.error ? response.error : ({})
      errorText = String(error.message || "Terminal API request failed.")
      statusText = response && response.status === 401 ? "Authentication required" : ""
      responseHandled = true
      maybeStartPending()
      return
    }

    var data = response.data
    refreshedAt = response.meta && response.meta.fetchedAt ? String(response.meta.fetchedAt) : ""
    errorText = ""

    if (kind === "accounts") {
      accounts = Model.array(data)
      var selected = findAccount(activeAccountId)
      if (selected) {
        var selectedId = String(selected.id || "")
        if (selectedId !== activeAccountId) {
          activeAccountId = selectedId
          replaceSettings(selectedId)
        }
        statusText = "Loading…"
        Qt.callLater(refreshSnapshot)
      } else {
        activeAccountId = ""
        statusText = ""
        Qt.callLater(refreshProducts)
      }
    } else if (kind === "snapshot") {
      snapshot = data && typeof data === "object" ? data : ({})
      products = Model.array(snapshot.products)
      refreshAccountFields()
      if (!selectedAddressId && addresses.length > 0) fillAddressFields(addresses[0])
      statusText = "Updated " + Model.shortDate(refreshedAt)
    } else if (kind === "products") {
      products = Model.array(data)
      statusText = products.length + " products"
    } else if (kind === "account-add") {
      setupToken = ""
      setupLabel = ""
      statusText = "Account connected"
      Qt.callLater(refreshAccounts)
    } else if (kind === "tokens") {
      tokens = Model.array(data)
      statusText = ""
      Qt.callLater(function() {
        if (activeAccountId) runHelper("apps", ["call", "app.list", "--account-id", activeAccountId], ({}))
      })
    } else if (kind === "apps") {
      apps = Model.array(data)
      statusText = ""
    } else if (kind === "operation") {
      lastResult = data
      apiOutput = Model.json(data)
      statusText = requestOperation + " completed"

      if (requestOperation === "local.account-remove") {
        activeAccountId = ""
        snapshot = ({})
        Qt.callLater(refreshAccounts)
      } else if (requestOperation === "auth.metadata") {
        apiOutput = Model.json(data)
      } else if (requestOperation === "view.init") {
        snapshot = data && typeof data === "object" ? data : ({})
        products = Model.array(snapshot.products)
        refreshAccountFields()
      } else if (requestOperation === "product.list") {
        products = Model.array(data)
      } else if (requestOperation === "token.list") {
        tokens = Model.array(data)
      } else if (requestOperation === "app.list") {
        apps = Model.array(data)
      } else if (requestOperation === "token.create") {
        apiCreateTokenOutput = Model.json(data)
        Qt.callLater(refreshSecurity)
      } else if (requestOperation.indexOf("token.") === 0 || requestOperation.indexOf("app.") === 0) {
        Qt.callLater(refreshSecurity)
      } else if (requestOperation !== "product.get" && requestOperation !== "address.get" && requestOperation !== "card.get" && requestOperation !== "order.get" && requestOperation !== "subscription.get") {
        Qt.callLater(refreshSnapshot)
      }
    }

    responseHandled = true
    maybeStartPending()
  }

  function moveCursor(dx, dy) {
    if (dx !== 0) selectTab(tabIndex + dx)
    if (dy !== 0 && panelFlick)
      panelFlick.contentY = Math.max(0, Math.min(panelFlick.contentHeight - panelFlick.height,
        panelFlick.contentY + dy * Style.space(54)))
  }

  function activateCurrent() {
    if (setupMode) return
    refreshAll()
  }

  function openTokenInstructions() {
    statusText = "Create a PAT with: ssh " + (setupEnvironment === "dev" ? "dev." : "") + "terminal.shop -t tokens"
  }

  function toggleSetupEnvironment() {
    setupEnvironment = setupEnvironment === "dev" ? "production" : "dev"
    if (setupMode) refreshProducts()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    tabIndex = 0
    cursorActive = false
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      refreshAll()
    })
  }

  Component.onCompleted: {
    activeAccountId = String(setting("activeAccountId", "") || "")
    refreshAccounts()
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    onTriggered: if (root.opened) root.refreshAll()
  }

  Process {
    id: helper
    stdinEnabled: true

    onStarted: {
      write(root.requestInput + "\n")
      root.requestInput = ""
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.handleHelper(root.requestKind, text)
        root.responseHandled = true
        root.maybeStartPending()
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") console.warn("terminal.shop helper failed")
    }

    onExited: {
      root.processFinished = true
      root.maybeStartPending()
    }
  }

  IpcHandler {
    target: "terminal.shop"
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { root.refreshAll(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        anchors.fill: parent

        Canvas {
          id: terminalMark
          anchors.fill: parent
          property color markColor: root.bar ? root.bar.barForeground : Color.foreground

          onMarkColorChanged: requestPaint()
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()

          onPaint: {
            var context = getContext("2d")
            context.clearRect(0, 0, width, height)
            var side = Math.min(width, height)
            var scale = side / 256.0
            var offsetX = (width - side) / 2.0
            var offsetY = (height - side) / 2.0
            context.fillStyle = markColor

            context.fillRect(offsetX + 131 * scale, offsetY + 48 * scale, 76 * scale, 161 * scale)
            context.beginPath()
            context.moveTo(offsetX + 48 * scale, offsetY + 104 * scale)
            context.lineTo(offsetX + 67 * scale, offsetY + 104 * scale)
            context.lineTo(offsetX + 67 * scale, offsetY + 86 * scale)
            context.lineTo(offsetX + 86 * scale, offsetY + 86 * scale)
            context.lineTo(offsetX + 86 * scale, offsetY + 104 * scale)
            context.lineTo(offsetX + 108 * scale, offsetY + 104 * scale)
            context.lineTo(offsetX + 108 * scale, offsetY + 117 * scale)
            context.lineTo(offsetX + 86 * scale, offsetY + 117 * scale)
            context.lineTo(offsetX + 86 * scale, offsetY + 157 * scale)
            context.bezierCurveTo(offsetX + 86 * scale, offsetY + 164 * scale, offsetX + 90 * scale, offsetY + 168 * scale, offsetX + 98 * scale, offsetY + 168 * scale)
            context.lineTo(offsetX + 108 * scale, offsetY + 168 * scale)
            context.lineTo(offsetX + 108 * scale, offsetY + 181 * scale)
            context.lineTo(offsetX + 97 * scale, offsetY + 181 * scale)
            context.bezierCurveTo(offsetX + 77 * scale, offsetY + 181 * scale, offsetX + 67 * scale, offsetY + 173 * scale, offsetX + 67 * scale, offsetY + 158 * scale)
            context.lineTo(offsetX + 67 * scale, offsetY + 117 * scale)
            context.lineTo(offsetX + 48 * scale, offsetY + 117 * scale)
            context.closePath()
            context.fill()
          }
        }
      }
    }
    active: root.hasAccount && root.errorText === ""
    tooltipText: root.hasAccount
      ? Model.accountLabel(root.activeAccount)
      : "Connect a terminal.shop account"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refreshAll()
      else if (buttonCode === Qt.RightButton) root.selectTab(4)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(700))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: labelInput.activeFocus || tokenInput.activeFocus

      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCurrent()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refreshAll() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(10)

            Column {
              width: parent.width - refreshButton.width - Style.space(10)
              spacing: Style.space(3)

              Text {
                width: parent.width
                text: "TERMINAL SHOP"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }

              Text {
                width: parent.width
                text: root.hasAccount ? Model.accountLabel(root.activeAccount) : "No account connected"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Rectangle {
              id: refreshButton
              width: Style.space(78)
              height: Style.spacing.controlHeight
              radius: Style.cornerRadius
              color: root.track
              border.width: 1
              border.color: root.accent

              Text {
                anchors.centerIn: parent
                text: root.loading ? "Loading" : "Refresh"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                onClicked: root.refreshAll()
              }
            }
          }

          Rectangle {
            visible: root.accounts.length > 0
            width: parent.width
            height: accountRow.implicitHeight + Style.space(16)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
            radius: Style.cornerRadius
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

            Row {
              id: accountRow
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: "ACCOUNT"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              ComboBox {
                id: accountCombo
                width: Math.max(160, parent.width - 90)
                model: root.accountLabels
                currentIndex: {
                  for (var i = 0; i < root.accounts.length; i++)
                    if (String(root.accounts[i].id || "") === root.activeAccountId) return i
                  return 0
                }
                onActivated: root.selectAccount(currentIndex)
              }
            }
          }

          Flow {
            id: tabs
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: ["Overview", "Shop", "Cart", "Orders", "Subscriptions", "Account", "Security", "Developer", "API"]

              Rectangle {
                required property string modelData
                required property int index
                width: (tabs.width - tabs.spacing * 4) / 5
                height: Style.spacing.controlHeight
                radius: Style.cornerRadius
                color: index === root.tabIndex ? root.track : "transparent"
                border.width: 1
                border.color: index === root.tabIndex ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                Text {
                  anchors.centerIn: parent
                  text: modelData
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.selectTab(index)
                }
              }
            }
          }

          Rectangle {
            visible: root.errorText !== ""
            width: parent.width
            implicitHeight: errorLabel.implicitHeight + Style.space(18)
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.12)
            radius: Style.cornerRadius
            border.width: 1
            border.color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.38)

            Text {
              id: errorLabel
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              text: root.errorText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Text {
            visible: root.statusText !== ""
            width: parent.width
            text: root.statusText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }

          Rectangle {
            visible: root.confirmOperation !== ""
            width: parent.width
            implicitHeight: confirmColumn.implicitHeight + Style.space(20)
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.10)
            radius: Style.cornerRadius
            border.width: 1
            border.color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.42)

            Column {
              id: confirmColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text { width: parent.width; text: root.confirmTitle; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
              Text { width: parent.width; text: root.confirmMessage; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

              Row {
                spacing: Style.space(8)
                Rectangle {
                  width: Style.space(84)
                  height: Style.spacing.controlHeight
                  radius: Style.cornerRadius
                  color: root.accent
                  Text { anchors.centerIn: parent; text: "Confirm"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                  MouseArea { anchors.fill: parent; onClicked: root.approveConfirmation() }
                }
                Rectangle {
                  width: Style.space(84)
                  height: Style.spacing.controlHeight
                  radius: Style.cornerRadius
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.20)
                  Text { anchors.centerIn: parent; text: "Cancel"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; onClicked: root.cancelConfirmation() }
                }
              }
            }
          }

          Column {
            id: setupColumn
            visible: root.setupMode
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: "CONNECT AN ACCOUNT"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              width: parent.width
              text: "Create a personal access token with the command below, then paste it here. The token is verified and stored in Secret Service."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Rectangle {
              width: parent.width
              height: Style.spacing.controlHeight
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
              radius: Style.cornerRadius
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

              Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(10)
                text: "ssh " + (root.setupEnvironment === "dev" ? "dev." : "") + "terminal.shop -t tokens"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              MouseArea { anchors.fill: parent; onClicked: root.openTokenInstructions() }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: Style.spacing.controlHeight
                radius: Style.cornerRadius
                color: root.setupEnvironment === "dev" ? root.track : "transparent"
                border.width: 1
                border.color: root.setupEnvironment === "dev" ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
                Text { anchors.centerIn: parent; text: "DEV SANDBOX"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; onClicked: { root.setupEnvironment = "dev"; root.refreshProducts() } }
              }

              Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: Style.spacing.controlHeight
                radius: Style.cornerRadius
                color: root.setupEnvironment === "production" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.16) : "transparent"
                border.width: 1
                border.color: root.setupEnvironment === "production" ? root.urgent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
                Text { anchors.centerIn: parent; text: "PRODUCTION"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; onClicked: { root.setupEnvironment = "production"; root.refreshProducts() } }
              }
            }

            Rectangle {
              width: parent.width
              height: Style.spacing.controlHeight
              color: "transparent"
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              radius: Style.cornerRadius

              TextInput {
                id: labelInput
                anchors.fill: parent
                anchors.margins: Style.space(9)
                text: root.setupLabel
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                onTextChanged: root.setupLabel = text
              }
              Text { visible: !labelInput.text; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: "Account label (optional)"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            }

            Rectangle {
              width: parent.width
              height: Style.spacing.controlHeight
              color: "transparent"
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              radius: Style.cornerRadius

              TextInput {
                id: tokenInput
                anchors.left: parent.left
                anchors.right: showToken.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(6)
                echoMode: root.setupTokenVisible ? TextInput.Normal : TextInput.Password
                text: root.setupToken
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                onTextChanged: root.setupToken = text
              }
              Text { visible: !tokenInput.text; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: "Personal access token"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
              Text {
                id: showToken
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Style.space(10)
                text: root.setupTokenVisible ? "hide" : "show"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                MouseArea { anchors.fill: parent; onClicked: root.setupTokenVisible = !root.setupTokenVisible }
              }
            }

            Rectangle {
              width: parent.width
              height: Style.spacing.controlHeight
              color: root.accent
              radius: Style.cornerRadius
              Text { anchors.centerIn: parent; text: "Connect account"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; onClicked: root.addAccount() }
            }
          }

          Column {
            id: dashboard
            // Retained as a compatibility fallback while the expanded
            // dashboard below hosts the full commerce and account workflow.
            visible: false
            width: parent.width
            spacing: Style.space(12)

            Column {
              visible: root.tabIndex === 0
              width: parent.width
              spacing: Style.space(10)

              Text { text: "OVERVIEW"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              Text {
                width: parent.width
                text: root.currentUser.name || root.currentUser.email || "Terminal user"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
              }
              Text {
                width: parent.width
                text: (root.currentUser.email || "") + "\n" + Model.environmentLabel(root.activeAccount ? root.activeAccount.environment : "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Rectangle {
                width: parent.width
                implicitHeight: summaryText.implicitHeight + Style.space(18)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                radius: Style.cornerRadius
                border.width: 1
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                Text {
                  id: summaryText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Cart: " + Model.cartItemCount(root.cart) + " item(s)\nAddresses: " + root.addresses.length + " · Cards: " + root.cards.length + "\nOrders: " + root.orders.length + " · Subscriptions: " + root.subscriptions.length
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  lineHeight: 1.25
                  wrapMode: Text.WordWrap
                }
              }

              Text { visible: root.orders.length === 0; text: "No orders returned yet."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Repeater {
                model: root.orders.slice(0, 3)
                Rectangle {
                  required property var modelData
                  width: parent.width
                  height: Style.space(42)
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
                  radius: Style.cornerRadius
                  Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: Model.orderTitle(modelData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                  Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(10); text: Model.shortDate(modelData.created); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                }
              }
            }

            Column {
              visible: root.tabIndex === 1
              width: parent.width
              spacing: Style.space(10)
              Text { text: "SHOP"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              Text { visible: root.products.length === 0; text: "No products returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Repeater {
                model: root.products
                Rectangle {
                  required property var modelData
                  width: parent.width
                  implicitHeight: productColumn.implicitHeight + Style.space(18)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                  radius: Style.cornerRadius
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  Column {
                    id: productColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(10)
                    spacing: Style.space(4)
                    Text { width: parent.width; text: modelData.name || "Product"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                    Text { width: parent.width; text: (modelData.description || "") + (Model.productPrice(modelData) ? " · from " + Model.productPrice(modelData) : ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
                  }
                }
              }
            }

            Column {
              visible: root.tabIndex === 2
              width: parent.width
              spacing: Style.space(10)
              Text { text: "ORDERS"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              Text { visible: root.orders.length === 0; text: "No orders returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Repeater {
                model: root.orders
                Rectangle {
                  required property var modelData
                  width: parent.width
                  height: Style.space(54)
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  radius: Style.cornerRadius
                  Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: Style.space(10); anchors.topMargin: Style.space(8); text: Model.orderTitle(modelData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                  Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: Style.space(10); anchors.bottomMargin: Style.space(8); text: "Created " + Model.shortDate(modelData.created); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(10); text: Model.money(modelData.amount && modelData.amount.subtotal); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
            }

            Column {
              visible: root.tabIndex === 3
              width: parent.width
              spacing: Style.space(10)
              Text { text: "SUBSCRIPTIONS"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              Text { visible: root.subscriptions.length === 0; text: "No subscriptions returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Repeater {
                model: root.subscriptions
                Rectangle {
                  required property var modelData
                  width: parent.width
                  height: Style.space(52)
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  radius: Style.cornerRadius
                  Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: Model.subscriptionTitle(modelData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                  Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(10); text: Model.money(modelData.price); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
            }

            Column {
              visible: root.tabIndex === 4
              width: parent.width
              spacing: Style.space(10)
              Text { text: "SECURITY"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              Text { width: parent.width; text: "Remote personal access tokens and OAuth apps are read through the same fixed API registry. Creation and deletion will use explicit confirmation in the next commerce/security slice."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              Rectangle {
                width: parent.width
                implicitHeight: securityText.implicitHeight + Style.space(18)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                radius: Style.cornerRadius
                border.width: 1
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                Text { id: securityText; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: "Personal tokens: " + root.tokens.length + "\nOAuth apps: " + root.apps.length; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
              }
            }
          }

          EnhancedDashboard {
            id: enhancedDashboard
            host: root
            visible: root.hasAccount
            width: parent.width
          }
        }
      }
    }
  }
}
