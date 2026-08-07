import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "body",
    "charCount",
    "conversationFeed",
    "sendButton",
    "sendHint",
    "pill",
    "customPill",
    "recipientPill",
    "recipientKey",
    "simulateRecipientKey",
    "phoneDisplay"
  ];

  static values = {
    textTemplates: Array,
    defaultTextTemplate: String,
    recipients: Array,
    selectedRecipientKey: String,
    allowSendWithoutPhone: Boolean,
    liveMessagingEnabled: Boolean,
    orgFromNumberConfigured: Boolean,
    fromNumberRequiredMessage: String,
    smsOptedOut: Boolean
  };

  connect() {
    this.selectedKey = this.defaultTextTemplateValue || "local_web_dev";
    this.syncSelectionFromBody();
    this.updateRecipientUI();
    this.refresh();
    this.scrollConversationToBottom();
    this.handleConversationUpdated = this.handleConversationUpdated.bind(this);
    this.element.addEventListener(
      "outreach-enrollment-poll:conversation-updated",
      this.handleConversationUpdated
    );
  }

  disconnect() {
    this.element.removeEventListener(
      "outreach-enrollment-poll:conversation-updated",
      this.handleConversationUpdated
    );
  }

  handleConversationUpdated() {
    this.scrollConversationToBottom();
  }

  scrollConversationToBottom() {
    if (!this.hasConversationFeedTarget) return;

    requestAnimationFrame(() => {
      const feed = this.conversationFeedTarget;
      feed.scrollTop = feed.scrollHeight;
    });
  }

  selectRecipient(event) {
    const key = event.currentTarget.dataset.recipientKey;
    if (!key) return;

    this.selectedRecipientKeyValue = key;
    this.updateRecipientUI();
    this.refresh();
  }

  updateRecipientUI() {
    const recipient = this.currentRecipient();
    if (!recipient) {
      this.setSendEnabled(this.canSend());
      return;
    }

    if (this.hasRecipientKeyTarget) {
      this.recipientKeyTarget.value = recipient.key;
    }

    this.simulateRecipientKeyTargets.forEach((input) => {
      input.value = recipient.key;
    });

    if (this.hasPhoneDisplayTarget) {
      this.phoneDisplayTarget.textContent = recipient.phone_display;
      this.phoneDisplayTarget.classList.toggle(
        "outreach-sms-step-warning",
        !recipient.phone_normalized
      );
      this.phoneDisplayTarget.classList.toggle(
        "outreach-sms-step-phone",
        !!recipient.phone_normalized
      );
    }

    this.recipientPillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.recipientKey === recipient.key);
    });

    this.setSendEnabled(this.canSend());
  }

  canSend() {
    return this.sendDisabledReason() === "";
  }

  sendDisabledReason() {
    if (this.allowSendWithoutPhoneValue) return "";

    if (this.smsOptedOutValue) return "Prospect opted out";
    if (!this.orgFromNumberConfiguredValue) {
      return this.fromNumberRequiredMessageValue || "Set this org from number in Settings before sending.";
    }
    if (!this.liveMessagingEnabledValue) {
      return "Messaging disabled — turn on Text Message Sending in Settings → Outreach → Text Messages";
    }

    const recipient = this.currentRecipient();
    if (!recipient?.phone_normalized) return "Phone is missing — add one on the prospect profile before sending.";

    return "";
  }

  setSendEnabled(canSend) {
    if (this.hasSendButtonTarget) {
      this.sendButtonTarget.disabled = !canSend;
    }

    if (this.hasSendHintTarget) {
      const reason = this.sendDisabledReason();
      this.sendHintTarget.hidden = canSend;
      if (!canSend && reason) {
        this.sendHintTarget.textContent = reason;
      }
    }
  }

  currentRecipient() {
    const key = this.hasSelectedRecipientKeyValue
      ? this.selectedRecipientKeyValue
      : this.recipientKeyTarget?.value;

    return (
      this.recipientsValue.find((entry) => entry.key === key) ||
      this.recipientsValue[0]
    );
  }

  selectTextTemplate(event) {
    const key = event.currentTarget.dataset.textTemplateKey;
    const textTemplate = this.textTemplatesValue.find((entry) => entry.key === key);
    if (!textTemplate) return;

    if (key === "calendar") {
      this.appendCalendlyLink(textTemplate.body);
    } else {
      this.bodyTarget.value = textTemplate.body;
    }

    this.selectedKey = key;
    this.updatePills();
    this.refresh();
  }

  appendCalendlyLink(link) {
    const current = this.bodyTarget.value.trimEnd();
    if (current.includes(link)) return;

    const separator = current.length === 0 ? "" : "\n\n";
    this.bodyTarget.value = `${current}${separator}${link}`;
  }

  handleInput() {
    this.syncSelectionFromBody();
    this.refresh();
  }

  syncSelectionFromBody() {
    const body = this.bodyTarget.value;
    const match = this.textTemplatesValue.find(
      (entry) => entry.key !== "calendar" && entry.body === body
    );

    if (match) {
      this.selectedKey = match.key;
    } else if (this.calendlyLinkAppended(body)) {
      this.selectedKey = "calendar";
    } else {
      this.selectedKey = "custom";
    }

    this.updatePills();
  }

  calendlyLinkAppended(body) {
    const calendar = this.textTemplatesValue.find((entry) => entry.key === "calendar");
    return calendar && body.includes(calendar.body);
  }

  updatePills() {
    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.textTemplateKey === this.selectedKey);
    });

    if (this.hasCustomPillTarget) {
      this.customPillTarget.classList.toggle("is-active", this.selectedKey === "custom");
    }
  }

  refresh() {
    const length = this.bodyTarget.value.length;
    const segments = length <= 160 ? 1 : Math.ceil(length / 153);

    this.charCountTarget.textContent = `${length} characters · ${segments} segment${segments === 1 ? "" : "s"}`;
  }
}
