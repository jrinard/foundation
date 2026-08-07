import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["conversation", "compose", "messageLabel", "templatesSidebar"];

  static values = {
    url: String,
    interval: { type: Number, default: 5000 },
    initialInboundCount: { type: Number, default: 0 },
    initialLastInboundId: { type: Number, default: 0 },
    initialFollowUpMode: { type: Boolean, default: false }
  };

  connect() {
    this.lastInboundCount = this.initialInboundCountValue;
    this.lastInboundId = this.initialLastInboundIdValue || null;
    this.followUpMode = this.initialFollowUpModeValue;
    this.inFlight = false;
    this.handleVisibility = this.handleVisibility.bind(this);
    document.addEventListener("visibilitychange", this.handleVisibility);
    this.poll();
    this.startPolling();
  }

  disconnect() {
    this.stopPolling();
    document.removeEventListener("visibilitychange", this.handleVisibility);
  }

  handleVisibility() {
    if (document.hidden) {
      this.stopPolling();
    } else {
      this.poll();
      this.startPolling();
    }
  }

  startPolling() {
    this.stopPolling();
    this.timer = window.setInterval(() => this.poll(), this.intervalValue);
  }

  stopPolling() {
    if (this.timer) {
      window.clearInterval(this.timer);
      this.timer = null;
    }
  }

  async poll() {
    if (document.hidden || !this.urlValue || this.inFlight) return;

    this.inFlight = true;

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      });

      if (!response.ok) return;

      const data = await response.json();
      const inboundCount = Number(data.inbound_count ?? 0);
      const lastInboundId = data.last_inbound_id ? Number(data.last_inbound_id) : null;

      const newInbound =
        inboundCount > this.lastInboundCount ||
        (lastInboundId !== null &&
          this.lastInboundId !== null &&
          lastInboundId > this.lastInboundId);

      this.lastInboundCount = inboundCount;
      this.lastInboundId = lastInboundId;

      if (!newInbound) return;

      this.applyUpdates(data);
    } catch (_error) {
      // Ignore transient network errors; next poll will retry.
    } finally {
      this.inFlight = false;
    }
  }

  applyUpdates(data) {
    if (data.conversation_html && this.hasConversationTarget) {
      this.conversationTarget.innerHTML = data.conversation_html;
      this.element.dispatchEvent(
        new CustomEvent("outreach-enrollment-poll:conversation-updated", { bubbles: true })
      );
    }

    const activityEl = document.getElementById("outreach-enrollment-activity-feed");
    if (data.activity_html && activityEl) {
      activityEl.innerHTML = data.activity_html;
    }

    if (typeof data.follow_up_mode === "boolean") {
      this.applyFollowUpMode(data.follow_up_mode, data.templates_sidebar_html);
    }
  }

  applyFollowUpMode(followUpMode, templatesSidebarHtml) {
    if (followUpMode === this.followUpMode) return;

    this.followUpMode = followUpMode;
    this.element.classList.toggle("outreach-sms-step--follow-up", followUpMode);

    if (this.hasComposeTarget) {
      this.composeTarget.classList.toggle("outreach-sms-step-compose--follow-up", followUpMode);
    }

    if (this.hasMessageLabelTarget) {
      this.messageLabelTarget.textContent = followUpMode ? "Your reply" : "Message";
    }

    if (templatesSidebarHtml && this.hasTemplatesSidebarTarget) {
      this.templatesSidebarTarget.outerHTML = templatesSidebarHtml;
    }
  }
}
