import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    sourceId: Number,
    sourceName: String,
    currentAmount: Number,
    currency: String,
    singleId: Number,
    ongoingId: Number
  }

  open(event) {
    event.preventDefault()
    const modal = document.getElementById("override-modal")
    if (!modal) return

    const ctrl = this.application.getControllerForElementAndIdentifier(modal, "override-modal")
    if (!ctrl) return

    ctrl.populate({
      sourceId: this.sourceIdValue,
      sourceName: this.sourceNameValue,
      currentAmount: this.currentAmountValue,
      currency: this.currencyValue,
      singleId: this.singleIdValue,
      ongoingId: this.ongoingIdValue,
      triggerEl: this.element
    })
    modal.showModal()
  }
}
