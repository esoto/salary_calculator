import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["vacationToggle", "vacationFields", "vacationInput", "holidayToggle", "holidayFields", "holidayInput"]

  toggleVacation() {
    if (this.hasVacationFieldsTarget) {
      const isChecked = this.vacationToggleTarget.checked
      this.vacationFieldsTarget.hidden = !isChecked
      if (this.hasVacationInputTarget) {
        this.vacationInputTarget.disabled = !isChecked
      }
    }
  }

  toggleHoliday() {
    if (this.hasHolidayFieldsTarget) {
      const isChecked = this.holidayToggleTarget.checked
      this.holidayFieldsTarget.hidden = !isChecked
      if (this.hasHolidayInputTarget) {
        this.holidayInputTarget.disabled = !isChecked
      }
    }
  }
}
