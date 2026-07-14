// We are currently letting them set the theme manually regardless of system settings
// This setup sets the class on the body tag

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["label"];

  connect() {
    console.log("=== Stimulus Theme Connect");
    this.applyStoredTheme();
    this.watchForSystemChanges();
  }

  applyStoredTheme() {
    const storedTheme = localStorage.getItem("foundation-theme");

    if (storedTheme) {
      this.setTheme(storedTheme);
    } else {
      const isDark = document.getElementById("app-theme-body")?.hasAttribute("data-dark");
      const labelText = isDark ? "Dark Mode" : "Light Mode";
      this.getLabelElements().forEach((labelEl) => {
        labelEl.textContent = labelText;
      });
    }
  }

  getLabelElements() {
    if (this.hasLabelTarget) {
      return this.labelTargets.length ? this.labelTargets : [this.labelTarget];
    }
    const legacy = document.getElementById("theme-label");
    return legacy ? [legacy] : [];
  }

  setTheme(theme) {
    const appElementBody = document.getElementById("app-theme-body");
    const isDark = theme === "dark";

    if (isDark) {
      appElementBody.setAttribute("data-dark", "true");
    } else {
      appElementBody.removeAttribute("data-dark");
    }

    const labelText = isDark ? "Dark Mode" : "Light Mode";
    this.getLabelElements().forEach((labelEl) => {
      labelEl.textContent = labelText;
    });

    console.log("=== Stimulus Theme:", theme);
    localStorage.setItem("foundation-theme", theme);
  }

  watchForSystemChanges() {
    window
      .matchMedia("(prefers-color-scheme: dark)")
      .addEventListener("change", (e) => {
        const newTheme = e.matches ? "dark" : "light";
        this.setTheme(newTheme);
      });
  }

  toggleTheme() {
    const currentTheme = localStorage.getItem("foundation-theme");
    const newTheme = currentTheme === "dark" ? "light" : "dark";
    localStorage.setItem("foundation-theme", newTheme);
    this.setTheme(newTheme);
  }
}
