import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["formContainer", "formTemplate"]

  close() {
    this.element.close()
  }

  resetForm() {
    if (this.hasFormContainerTarget && this.hasFormTemplateTarget) {
      this.formContainerTarget.innerHTML = this.formTemplateTarget.innerHTML
    }
  }
}
