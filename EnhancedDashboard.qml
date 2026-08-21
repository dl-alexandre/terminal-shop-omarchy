import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "TerminalModel.js" as Model

// The expanded workflow surface is kept separate from Panel.qml so the bar
// widget remains responsible for transport, account state, and IPC only.
Column {
  id: root

  property var host
  width: parent ? parent.width : Style.space(520)
  spacing: Style.space(12)

  readonly property color foreground: host ? host.foreground : Color.foreground
  readonly property color dim: host ? host.dim : Color.foreground
  readonly property color accent: host ? host.accent : Color.accent
  readonly property color urgent: host ? host.urgent : Color.urgent
  readonly property color track: host ? host.track : Color.accent
  readonly property string fontFamily: host ? host.fontFamily : Style.font.family

  function surfaceColor() {
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  }

  function borderColor() {
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
  }

  function buttonColor() {
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  }

  // ------------------------------------------------------------------ overview
  Column {
    visible: host && host.tabIndex === 0
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "OVERVIEW"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { width: parent.width; text: host.currentUser.name || host.currentUser.email || "Terminal user"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading }
    Text { width: parent.width; text: (host.currentUser.email || "") + "\n" + Model.environmentLabel(host.activeAccount ? host.activeAccount.environment : ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

    Flow {
      width: parent.width
      spacing: Style.space(8)
      Repeater {
        model: [
          { label: "CART", value: Model.cartItemCount(host.cart) + " items" },
          { label: "ORDERS", value: host.orders.length + " total" },
          { label: "ADDRESSES", value: host.addresses.length + " saved" },
          { label: "PLANS", value: host.subscriptions.length + " active" }
        ]

        Rectangle {
          required property var modelData
          width: (parent.width - parent.spacing) / 2
          height: Style.space(64)
          color: root.surfaceColor()
          radius: Style.cornerRadius
          border.width: 1
          border.color: root.borderColor()

          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(10)
            spacing: Style.space(3)
            Text { text: modelData.label; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            Text { text: modelData.value; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)
      Repeater {
        model: ["Shop", "Cart", "Orders"]
        Rectangle {
          required property string modelData
          required property int index
          width: (parent.width - parent.spacing * 2) / 3
          height: Style.spacing.controlHeight
          radius: Style.cornerRadius
          color: root.buttonColor()
          border.width: 1
          border.color: root.borderColor()
          Text { anchors.centerIn: parent; text: modelData; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          MouseArea { anchors.fill: parent; onClicked: host.selectTab(index + 1) }
        }
      }
    }

    Text { visible: host.orders.length === 0; text: "No orders returned yet."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Repeater {
      model: host.orders.slice(0, 3)
      Rectangle {
        required property var modelData
        width: parent.width
        height: Style.space(44)
        color: "transparent"
        border.width: 1
        border.color: root.borderColor()
        radius: Style.cornerRadius
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: Model.orderTitle(modelData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(10); text: Model.shortDate(modelData.created); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        MouseArea { anchors.fill: parent; onClicked: { host.selectOrder(modelData.id); host.selectTab(3) } }
      }
    }
  }

  // ----------------------------------------------------------------------- shop
  Column {
    visible: host && host.tabIndex === 1
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "SHOP"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { width: parent.width; text: "Choose a variant to add it to your cart, or send it to the subscription builder."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
    Text { visible: host.products.length === 0; text: "No products returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }

    Repeater {
      model: host.products
      Rectangle {
        id: productCard
        required property var modelData
        property var productData: modelData
        width: parent.width
        implicitHeight: productBody.implicitHeight + Style.space(18)
        color: root.surfaceColor()
        radius: Style.cornerRadius
        border.width: 1
        border.color: root.borderColor()

        Column {
          id: productBody
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(10)
          spacing: Style.space(6)

          Text { width: parent.width; text: productCard.productData.name || "Product"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
          Text { width: parent.width; text: productCard.productData.description || ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }

          Repeater {
            model: Model.productVariants(productCard.productData)
            Rectangle {
              required property var modelData
              property var variantData: modelData
              width: parent.width
              height: Style.space(38)
              color: "transparent"
              border.width: 1
              border.color: root.borderColor()
              radius: Style.cornerRadius
              Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(8); text: Model.variantLabel(variantData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Style.space(6)
                width: Style.space(58)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.track
                Text { anchors.centerIn: parent; text: "+ Add"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; onClicked: host.addVariant(variantData.id) }
              }
              MouseArea { anchors.fill: parent; z: -1; onClicked: host.selectVariantForSubscription(variantData.id) }
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------------------------- cart
  Column {
    visible: host && host.tabIndex === 2
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "CART & CHECKOUT"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { visible: !host.cart || Model.cartItemCount(host.cart) === 0; text: "Your cart is empty. Add a product from Shop."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }

    Repeater {
      model: Model.array(host.cart && host.cart.items)
      Rectangle {
        required property var modelData
        property var itemData: modelData
        width: parent.width
        height: Style.space(54)
        color: "transparent"
        border.width: 1
        border.color: root.borderColor()
        radius: Style.cornerRadius
        Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: Style.space(10); anchors.topMargin: Style.space(7); text: Model.cartItemName(itemData, host.products); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: Style.space(10); anchors.bottomMargin: Style.space(7); text: Model.money(itemData.subtotal); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        Text { anchors.right: minus.left; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(6); text: String(itemData.quantity || 0); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        Rectangle { id: minus; anchors.right: plus.left; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(4); width: Style.space(24); height: Style.space(24); color: root.buttonColor(); radius: Style.cornerRadius; Text { anchors.centerIn: parent; text: "−"; color: root.foreground; font.pixelSize: Style.font.body }
MouseArea { anchors.fill: parent; onClicked: host.setCartQuantity(itemData.productVariantID, Number(itemData.quantity || 0) - 1) } }
        Rectangle { id: plus; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(8); width: Style.space(24); height: Style.space(24); color: root.buttonColor(); radius: Style.cornerRadius; Text { anchors.centerIn: parent; text: "+"; color: root.foreground; font.pixelSize: Style.font.body }
MouseArea { anchors.fill: parent; onClicked: host.setCartQuantity(itemData.productVariantID, Number(itemData.quantity || 0) + 1) } }
      }
    }

    Text { text: "Shipping address"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    ComboBox {
      width: parent.width
      model: host.addressLabels
      enabled: host.addresses.length > 0
      currentIndex: host.addressIndex(host.cart && host.cart.addressID)
      onActivated: if (currentIndex >= 0 && currentIndex < host.addresses.length) host.setCartAddress(host.addresses[currentIndex].id)
    }
    Text { visible: host.addresses.length === 0; text: "Add an address in Account before checkout."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }

    Text { text: "Payment method"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    ComboBox {
      width: parent.width
      model: host.cardLabels
      enabled: host.cards.length > 0
      currentIndex: host.cardIndex(host.cart && host.cart.cardID)
      onActivated: if (currentIndex >= 0 && currentIndex < host.cards.length) host.setCartCard(host.cards[currentIndex].id)
    }
    Text { visible: host.cards.length === 0; text: "Add a card securely in Account before checkout."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }

    Text { text: "Subtotal: " + Model.money(host.cart && host.cart.subtotal) + "    Total: " + Model.money(host.cart && host.cart.amount && host.cart.amount.total !== undefined ? host.cart.amount.total : (host.cart && host.cart.subtotal)); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
    Row {
      width: parent.width
      spacing: Style.space(8)
      Rectangle { width: Style.space(120); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.accent; Text { anchors.centerIn: parent; text: "Place order"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
MouseArea { anchors.fill: parent; onClicked: host.checkout() } }
      Rectangle { width: Style.space(110); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: "transparent"; border.width: 1; border.color: root.borderColor(); Text { anchors.centerIn: parent; text: "Clear cart"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.runMutation("Clear cart", "Remove every item from the current cart?", "cart.clear", ({}), ({})) } }
    }
  }

  // --------------------------------------------------------------------- orders
  Column {
    visible: host && host.tabIndex === 3
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "ORDERS"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { visible: host.orders.length === 0; text: "No orders returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Repeater {
      model: host.orders
      Rectangle {
        required property var modelData
        property var orderData: modelData
        width: parent.width
        height: Style.space(58)
        color: String(orderData.id || "") === host.selectedOrderId ? root.track : "transparent"
        border.width: 1
        border.color: root.borderColor()
        radius: Style.cornerRadius
        Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: Style.space(10); anchors.topMargin: Style.space(8); text: Model.orderTitle(orderData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: Style.space(10); anchors.bottomMargin: Style.space(8); text: Model.orderStatus(orderData) + " · " + Model.shortDate(orderData.created); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(10); text: Model.money(orderData.amount && (orderData.amount.total !== undefined ? orderData.amount.total : orderData.amount.subtotal)); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        MouseArea { anchors.fill: parent; onClicked: host.selectOrder(orderData.id) }
      }
    }

    Column {
      visible: host.selectedOrderId !== ""
      width: parent.width
      spacing: Style.space(8)
      property var selectedOrder: host.findOrder(host.selectedOrderId)
      Text { text: root.selectedOrder ? "ORDER " + root.selectedOrder.id : "Select an order"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
      Text { width: parent.width; text: root.selectedOrder ? ("Status: " + Model.orderStatus(root.selectedOrder) + "\nTracking: " + Model.trackingLabel(root.selectedOrder.tracking)) : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
      Row {
        width: parent.width
        spacing: Style.space(8)
        Rectangle { visible: root.selectedOrder !== null && root.selectedOrder !== undefined && root.selectedOrder.canCancel === true; width: Style.space(116); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.16); border.width: 1; border.color: root.urgent; Text { anchors.centerIn: parent; text: "Cancel order"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.cancelOrder() } }
      }
      Text { visible: root.selectedOrder !== null && root.selectedOrder !== undefined && root.selectedOrder.canUpdateShipping === true; text: "Update shipping"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
      Row { visible: root.selectedOrder !== null && root.selectedOrder !== undefined && root.selectedOrder.canUpdateShipping === true; width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Name"; text: host.orderShippingName; onTextChanged: host.orderShippingName = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Street address"; text: host.orderShippingStreet1; onTextChanged: host.orderShippingStreet1 = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
      Row { visible: root.selectedOrder !== null && root.selectedOrder !== undefined && root.selectedOrder.canUpdateShipping === true; width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "City"; text: host.orderShippingCity; onTextChanged: host.orderShippingCity = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "ZIP"; text: host.orderShippingZip; onTextChanged: host.orderShippingZip = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
      Rectangle { visible: root.selectedOrder !== null && root.selectedOrder !== undefined && root.selectedOrder.canUpdateShipping === true; width: Style.space(150); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); border.width: 1; border.color: root.borderColor(); Text { anchors.centerIn: parent; text: "Save shipping"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.updateOrderShipping() } }
    }
  }

  // --------------------------------------------------------------- subscriptions
  Column {
    visible: host && host.tabIndex === 4
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "SUBSCRIPTIONS"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { visible: host.subscriptions.length === 0; text: "No subscriptions returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Repeater {
      model: host.subscriptions
      Rectangle {
        required property var modelData
        property var subscriptionData: modelData
        width: parent.width
        height: Style.space(58)
        color: String(subscriptionData.id || "") === host.selectedSubscriptionId ? root.track : "transparent"
        border.width: 1
        border.color: root.borderColor()
        radius: Style.cornerRadius
        Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: Style.space(10); anchors.topMargin: Style.space(8); text: Model.subscriptionTitle(subscriptionData); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: Style.space(10); anchors.bottomMargin: Style.space(8); text: Model.scheduleLabel(subscriptionData.schedule) + (subscriptionData.next ? " · next " + String(subscriptionData.next).slice(0, 10) : ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(10); text: Model.money(subscriptionData.price); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        MouseArea { anchors.fill: parent; onClicked: host.selectSubscription(subscriptionData.id) }
      }
    }

    Text { text: "Create or update subscription"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
    ComboBox { width: parent.width; model: host.variantLabels; enabled: host.variantOptions.length > 0; currentIndex: host.subscriptionVariantIndex; onActivated: host.subscriptionVariantIndex = currentIndex }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Quantity"; text: host.subscriptionQuantity; onTextChanged: host.subscriptionQuantity = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Interval"; text: host.subscriptionInterval; onTextChanged: host.subscriptionInterval = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
    Row { width: parent.width; spacing: Style.space(6); ComboBox { width: (parent.width - parent.spacing) / 2; model: ["weekly", "fixed"]; currentIndex: host.subscriptionScheduleType === "fixed" ? 1 : 0; onActivated: host.subscriptionScheduleType = currentText }
ComboBox { width: (parent.width - parent.spacing) / 2; model: host.addressLabels; enabled: host.addresses.length > 0; currentIndex: host.subscriptionAddressIndex; onActivated: host.subscriptionAddressIndex = currentIndex } }
    ComboBox { width: parent.width; model: host.cardLabels; enabled: host.cards.length > 0; currentIndex: host.subscriptionCardIndex; onActivated: host.subscriptionCardIndex = currentIndex }
    Row { width: parent.width; spacing: Style.space(8); Rectangle { width: Style.space(150); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.accent; Text { anchors.centerIn: parent; text: host.selectedSubscriptionId ? "Save subscription" : "Create subscription"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
MouseArea { anchors.fill: parent; onClicked: host.selectedSubscriptionId ? host.updateSubscription() : host.createSubscription() } }
Rectangle { visible: host.selectedSubscriptionId !== ""; width: Style.space(128); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: "transparent"; border.width: 1; border.color: root.urgent; Text { anchors.centerIn: parent; text: "Cancel subscription"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.cancelSubscription() } } }
  }

  // ------------------------------------------------------------------- account
  Column {
    visible: host && host.tabIndex === 5
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "ACCOUNT"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { text: "Profile"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Name"; text: host.profileName; onTextChanged: host.profileName = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Email"; text: host.profileEmail; onTextChanged: host.profileEmail = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
    Rectangle { width: Style.space(120); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); border.width: 1; border.color: root.borderColor(); Text { anchors.centerIn: parent; text: "Save profile"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.updateProfile() } }

    Text { text: "Email access and updates"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: parent.width - Style.space(120); placeholderText: "Email address"; text: host.emailInput; onTextChanged: host.emailInput = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
Rectangle { width: Style.space(110); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); Text { anchors.centerIn: parent; text: "Link email"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.linkEmail() } } }
    Rectangle { width: Style.space(148); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); Text { anchors.centerIn: parent; text: "Subscribe updates"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.subscribeEmail() } }

    Text { text: "Shipping addresses"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
    Row { width: parent.width; spacing: Style.space(8); ComboBox { width: parent.width - Style.space(110); model: host.addressLabels; enabled: host.addresses.length > 0; currentIndex: host.addressIndex(host.selectedAddressId); onActivated: host.selectAddressForEdit(currentIndex) }
Rectangle { width: Style.space(100); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); Text { anchors.centerIn: parent; text: "New address"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.fillAddressFields({}) } } }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Name"; text: host.addressName; onTextChanged: host.addressName = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Street address"; text: host.addressStreet1; onTextChanged: host.addressStreet1 = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "City"; text: host.addressCity; onTextChanged: host.addressCity = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "ZIP"; text: host.addressZip; onTextChanged: host.addressZip = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Country"; text: host.addressCountry; onTextChanged: host.addressCountry = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Phone"; text: host.addressPhone; onTextChanged: host.addressPhone = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
    Row { width: parent.width; spacing: Style.space(8); Rectangle { width: Style.space(120); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.accent; Text { anchors.centerIn: parent; text: host.selectedAddressId ? "Save address" : "Create address"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
MouseArea { anchors.fill: parent; onClicked: host.saveAddress() } }
Rectangle { visible: host.selectedAddressId !== ""; width: Style.space(112); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: "transparent"; border.width: 1; border.color: root.urgent; Text { anchors.centerIn: parent; text: "Delete address"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.deleteAddress() } } }

    Text { text: "Payment methods"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
    Repeater { model: host.cards; Rectangle { required property var modelData; width: parent.width; height: Style.space(38); color: "transparent"; border.width: 1; border.color: root.borderColor(); radius: Style.cornerRadius; Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: String(modelData.brand || "Card") + " •••• " + String(modelData.last4 || ""); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
Text { anchors.right: deleteCardButton.left; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(8); text: Model.shortDate(modelData.expiration && modelData.expiration.year ? String(modelData.expiration.year) + "-" + String(modelData.expiration.month || "") : modelData.created); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
Rectangle { id: deleteCardButton; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(6); width: Style.space(26); height: Style.space(24); color: "transparent"; Text { anchors.centerIn: parent; text: "×"; color: root.urgent; font.pixelSize: Style.font.body }
MouseArea { anchors.fill: parent; onClicked: host.deleteCard(modelData.id) } } } }
    Row { width: parent.width; spacing: Style.space(8); Rectangle { width: Style.space(160); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); Text { anchors.centerIn: parent; text: "Add card securely"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.collectCard() } }
Rectangle { visible: host.requestOperation === "card.collect" && host.lastResult; width: Style.space(110); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.track; Text { anchors.centerIn: parent; text: "Open card page"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.openResultUrl() } } }

    Rectangle { width: Style.space(160); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: "transparent"; border.width: 1; border.color: root.urgent; Text { anchors.centerIn: parent; text: "Remove local account"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.removeLocalAccount() } }
  }

  // ------------------------------------------------------------------ security
  Column {
    visible: host && host.tabIndex === 6
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "SECURITY"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { width: parent.width; text: "Tokens are never placed in the bar configuration. New token responses may contain a secret, so copy them immediately and clear the result when done."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
    Rectangle { width: Style.space(138); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.accent; Text { anchors.centerIn: parent; text: "Create PAT"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
MouseArea { anchors.fill: parent; onClicked: host.createToken() } }
    Text { visible: host.apiCreateTokenOutput !== ""; width: parent.width; text: host.apiCreateTokenOutput; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; maximumLineCount: 8 }
    Repeater { model: host.tokens; Rectangle { required property var modelData; width: parent.width; height: Style.space(42); color: "transparent"; border.width: 1; border.color: root.borderColor(); radius: Style.cornerRadius; Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: Style.space(10); text: String(modelData.id || "Token") + " · " + String(modelData.token || "obfuscated"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(6); width: Style.space(26); height: Style.space(24); color: "transparent"; Text { anchors.centerIn: parent; text: "×"; color: root.urgent; font.pixelSize: Style.font.body }
MouseArea { anchors.fill: parent; onClicked: host.deleteToken(modelData.id) } } } }
    Text { visible: host.tokens.length === 0; text: "No personal access tokens returned."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
  }

  // ---------------------------------------------------------------- developer
  Column {
    visible: host && host.tabIndex === 7
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "DEVELOPER"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { width: parent.width; text: "Manage OAuth applications and inspect the fixed discovery metadata used by clients."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
    Row { width: parent.width; spacing: Style.space(6); TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "App name"; text: host.appName; onTextChanged: host.appName = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
TextField { width: (parent.width - parent.spacing) / 2; placeholderText: "Redirect URI"; text: host.appRedirectUri; onTextChanged: host.appRedirectUri = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
    Row { width: parent.width; spacing: Style.space(8); Rectangle { width: Style.space(118); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.accent; Text { anchors.centerIn: parent; text: "Create app"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
MouseArea { anchors.fill: parent; onClicked: host.createApp() } }
Rectangle { width: Style.space(130); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.buttonColor(); Text { anchors.centerIn: parent; text: "OAuth metadata"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.loadAuthMetadata() } } }
    Repeater { model: host.apps; Rectangle { required property var modelData; width: parent.width; height: Style.space(54); color: "transparent"; border.width: 1; border.color: root.borderColor(); radius: Style.cornerRadius; Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: Style.space(10); anchors.topMargin: Style.space(7); text: modelData.name || "OAuth app"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: Style.space(10); anchors.bottomMargin: Style.space(7); text: modelData.redirectURI || "No redirect URI"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: Style.space(6); width: Style.space(26); height: Style.space(24); color: "transparent"; Text { anchors.centerIn: parent; text: "×"; color: root.urgent; font.pixelSize: Style.font.body }
MouseArea { anchors.fill: parent; onClicked: host.deleteApp(modelData.id) } } } }
    Text { visible: host.apiOutput !== "" && host.requestOperation === "auth.metadata"; width: parent.width; text: host.apiOutput; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; maximumLineCount: 10 }
  }

  // ---------------------------------------------------------------- API explorer
  Column {
    visible: host && host.tabIndex === 8
    width: parent.width
    spacing: Style.space(10)

    Row {
      spacing: Style.space(8)
      Rectangle { width: Style.space(3); height: Style.space(18); radius: Style.space(2); color: root.accent; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "API EXPLORER"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
    Text { width: parent.width; text: "Every allowlisted Terminal API route is available here. Parameters use key=value, one per line; request bodies are JSON objects."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
    ComboBox { width: parent.width; model: host.apiOperationNames; currentIndex: host.apiIndex(host.apiOperation); onActivated: host.apiOperation = host.apiOperations[currentIndex].name }
    Text { text: "Parameters"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    TextArea { width: parent.width; height: Style.space(58); text: host.apiParamsText; onTextChanged: host.apiParamsText = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: TextEdit.NoWrap; placeholderText: "id=..." }
    Text { text: "JSON body"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    TextArea { width: parent.width; height: Style.space(100); text: host.apiBodyText; onTextChanged: host.apiBodyText = text; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap; placeholderText: "{}" }
    Rectangle { width: Style.space(120); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.accent; Text { anchors.centerIn: parent; text: "Execute"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
MouseArea { anchors.fill: parent; onClicked: host.executeApi() } }
    Text { visible: host.apiOutput !== ""; text: "Response"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    TextArea { visible: host.apiOutput !== ""; width: parent.width; height: Style.space(180); text: host.apiOutput; readOnly: true; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap }
    Rectangle { visible: host.apiOutput !== "" && (host.lastResult.url || host.lastResult.href || host.lastResult.link); width: Style.space(110); height: Style.spacing.controlHeight; radius: Style.cornerRadius; color: root.track; Text { anchors.centerIn: parent; text: "Open URL"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
MouseArea { anchors.fill: parent; onClicked: host.openResultUrl() } }
  }
}
