import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title", "currentAmount", "form", "sourceIdInput", "amountInput",
    "scopeSingle", "scopeOngoing", "scopeSingleLabel", "scopeOngoingLabel",
    "removeLinks"
  ]

  static monthNames = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  populate({ sourceId, sourceName, currentAmount, currency, singleId, ongoingId, triggerEl }) {
    const budget = this._budgetContext()
    const monthLabel = `${this.constructor.monthNames[budget.month]} ${budget.year}`

    this.titleTarget.textContent = `Adjust "${sourceName}" for ${monthLabel}`
    this.currentAmountTarget.textContent = `Current: ${this._formatAmount(currentAmount, currency)}`
    this.sourceIdInputTarget.value = sourceId
    this.amountInputTarget.value = currentAmount
    this.scopeSingleTarget.checked = true

    this.scopeSingleLabelTarget.textContent = `Just ${monthLabel}`
    this.scopeOngoingLabelTarget.textContent = `Starting ${monthLabel} onward`

    this.formTarget.action = `/budgets/${budget.id}/income_source_overrides`

    this.removeLinksTarget.innerHTML = ""
    if (singleId) this._addRemoveLink(`Remove ${monthLabel} override`, budget.id, singleId)
    if (ongoingId) this._addRemoveLink(`Remove ongoing override starting ${monthLabel}`, budget.id, ongoingId)

    this._triggerEl = triggerEl

    requestAnimationFrame(() => this.amountInputTarget.focus())
  }

  close() {
    this.element.close()
    if (this._triggerEl) this._triggerEl.focus()
  }

  _addRemoveLink(label, budgetId, overrideId) {
    const form = document.createElement("form")
    form.action = `/budgets/${budgetId}/income_source_overrides/${overrideId}`
    form.method = "post"
    const csrf = document.querySelector("meta[name=csrf-token]")?.content
    form.innerHTML = `
      <input type="hidden" name="_method" value="delete" />
      <input type="hidden" name="authenticity_token" value="${csrf || ""}" />
      <button type="submit" class="text-error-500 hover:text-error-300 text-sm"
              data-turbo-confirm="Revert to default amount?">
        ${label}
      </button>
    `
    this.removeLinksTarget.appendChild(form)
  }

  _budgetContext() {
    const el = document.querySelector("[data-budget-context]")
    return JSON.parse(el.dataset.budgetContext)
  }

  _formatAmount(amount, currency) {
    const symbol = currency === "USD" ? "$" : "₡"
    return `${symbol}${Number(amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }
}
