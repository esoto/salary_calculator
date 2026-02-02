import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

  edit() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.formTarget.querySelector("input[type='text']")?.focus()
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }
}
