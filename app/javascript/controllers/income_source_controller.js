import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amountField", "linkedUserField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const type = this.element.querySelector("[name*='income_type']")?.value

    if (type === "hourly") {
      this.amountFieldTarget.hidden = true
      this.linkedUserFieldTarget.hidden = false
    } else {
      this.amountFieldTarget.hidden = false
      this.linkedUserFieldTarget.hidden = true
    }
  }
}
