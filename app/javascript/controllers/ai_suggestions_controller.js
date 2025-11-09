import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "input",
    "submitButton",
    "buttonText",
    "spinner",
    "status",
    "errors",
    "errorMessage"
  ]

  connect() {
    console.log("AI Suggestions controller connected")
  }

  async submit(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const input = formData.get("input")

    if (!input || input.trim() === "") {
      this.showError("Please enter an activity description or URL")
      return
    }

    this.setLoading(true)
    this.hideError()

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: formData,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.getCSRFToken()
        }
      })

      const data = await response.json()

      if (response.ok) {
        this.handleSuccess(data)
      } else {
        this.showError(data.error || "An error occurred")
        this.setLoading(false)
      }
    } catch (error) {
      console.error("Error submitting suggestion:", error)
      this.showError("Network error. Please try again.")
      this.setLoading(false)
    }
  }

  handleSuccess(data) {
    // Clear the form
    this.inputTarget.value = ""

    // Show success status
    this.statusTarget.textContent = "AI is processing your request..."
    this.statusTarget.classList.add("text-blue-600", "font-medium")

    // Reset loading state after a delay
    setTimeout(() => {
      this.setLoading(false)
      this.statusTarget.textContent = ""
      this.statusTarget.classList.remove("text-blue-600", "font-medium")

      // Show a message that they should wait for the suggestion to appear
      this.statusTarget.textContent = "Suggestion will appear below when ready (usually 2-5 seconds)"
      this.statusTarget.classList.add("text-green-600")

      setTimeout(() => {
        this.statusTarget.textContent = ""
        this.statusTarget.classList.remove("text-green-600")
      }, 5000)
    }, 1000)
  }

  setLoading(isLoading) {
    if (isLoading) {
      this.submitButtonTarget.disabled = true
      this.spinnerTarget.classList.remove("hidden")
      this.buttonTextTarget.textContent = "Processing..."
      this.inputTarget.disabled = true
    } else {
      this.submitButtonTarget.disabled = false
      this.spinnerTarget.classList.add("hidden")
      this.buttonTextTarget.textContent = "Generate Suggestion"
      this.inputTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorsTarget.classList.remove("hidden")

    // Auto-hide after 10 seconds
    setTimeout(() => {
      this.hideError()
    }, 10000)
  }

  hideError() {
    this.errorsTarget.classList.add("hidden")
    this.errorMessageTarget.textContent = ""
  }

  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
