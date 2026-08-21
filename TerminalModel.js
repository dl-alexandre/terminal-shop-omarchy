.pragma library

function array(value) {
  return Array.isArray(value) ? value : []
}

function object(value) {
  return value && typeof value === "object" ? value : ({})
}

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : (fallback || 0)
}

function money(cents) {
  return "$" + (number(cents, 0) / 100).toFixed(2)
}

function accountLabel(account) {
  if (!account) return "No account"
  var label = String(account.label || account.name || account.email || account.id || "Account")
  var environment = String(account.environment || "").toLowerCase() === "dev" ? "DEV" : "PROD"
  return label + " · " + environment
}

function environmentLabel(environment) {
  return String(environment || "").toLowerCase() === "dev" ? "DEV SANDBOX" : "PRODUCTION"
}

function profileUser(data) {
  var root = object(data)
  if (root.user && root.user.user) return object(root.user.user)
  if (root.user) return object(root.user)
  if (root.profile && root.profile.user) return object(root.profile.user)
  return ({})
}

function productVariants(product) {
  return array(product && product.variants)
}

function variantLabel(variant) {
  if (!variant) return "Variant"
  var name = String(variant.name || variant.id || "Variant")
  return name + (variant.price !== undefined ? " · " + money(variant.price) : "")
}

function variantOptions(products) {
  var result = []
  var list = array(products)
  for (var i = 0; i < list.length; i++) {
    var product = list[i]
    var variants = productVariants(product)
    for (var j = 0; j < variants.length; j++) {
      var variant = object(variants[j])
      result.push({
        id: String(variant.id || ""),
        name: String(product.name || "Product") + " · " + variantLabel(variant),
        productName: String(product.name || "Product"),
        variantName: String(variant.name || variant.id || "Variant"),
        price: number(variant.price, 0)
      })
    }
  }
  return result
}

function productPrice(product) {
  var variants = productVariants(product)
  if (variants.length === 0) return ""
  return money(variants[0].price)
}

function cartItemCount(cart) {
  var count = 0
  var items = array(cart && cart.items)
  for (var i = 0; i < items.length; i++) count += Math.max(0, number(items[i].quantity, 0))
  return count
}

function cartItemQuantity(cart, variantId) {
  var items = array(cart && cart.items)
  var wanted = String(variantId || "")
  for (var i = 0; i < items.length; i++) {
    if (String(items[i].productVariantID || "") === wanted)
      return Math.max(0, number(items[i].quantity, 0))
  }
  return 0
}

function cartItemName(item, products) {
  var wanted = String(item && item.productVariantID || "")
  var variants = variantOptions(products)
  for (var i = 0; i < variants.length; i++)
    if (variants[i].id === wanted) return variants[i].name
  return wanted || "Cart item"
}

function orderTitle(order) {
  if (!order) return "Order"
  var id = String(order.id || "Order")
  var status = String(order.status || "unknown")
  return id + " · " + status
}

function subscriptionTitle(subscription) {
  if (!subscription) return "Subscription"
  var id = String(subscription.id || "Subscription")
  var next = String(subscription.next || "")
  return next ? id + " · next " + next.slice(0, 10) : id
}

function scheduleLabel(schedule) {
  var value = object(schedule)
  var type = String(value.type || "")
  if (type === "weekly") return "Every " + number(value.interval, 1) + " week(s)"
  if (type === "fixed") return "Fixed schedule"
  return type || "Schedule not set"
}

function orderStatus(order) {
  return String(order && order.status || "unknown").replace(/_/g, " ")
}

function trackingLabel(tracking) {
  var value = object(tracking)
  return String(value.url || value.number || value.carrier || "")
}

function json(value) {
  try { return JSON.stringify(value, null, 2) } catch (e) { return String(value || "") }
}

function shortDate(value) {
  var text = String(value || "")
  return text.length >= 10 ? text.slice(0, 10) : text
}
