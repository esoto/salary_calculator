import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["vacationToggle", "vacationFields", "holidayToggle", "holidayFields"]

  toggleVacation() {
    if (this.hasVacationFieldsTarget) {
      this.vacationFieldsTarget.hidden = !this.vacationToggleTarget.checked
    }
  }

  toggleHoliday() {
    if (this.hasHolidayFieldsTarget) {
      this.holidayFieldsTarget.hidden = !this.holidayToggleTarget.checked
    }
  }
}
