resource "auth0_attack_protection" "this" {
  count = var.manage_attack_protection ? 1 : 0

  brute_force_protection {
    enabled      = var.enable_brute_force_protection
    shields      = ["block", "user_notification"]
    mode         = "count_per_identifier_and_ip"
    max_attempts = var.brute_force_max_attempts
  }

  suspicious_ip_throttling {
    enabled = var.enable_suspicious_ip_throttling
    shields = ["admin_notification", "block"]

    pre_login {
      max_attempts = var.suspicious_ip_pre_login_max_attempts
      rate         = var.suspicious_ip_pre_login_rate
    }

    pre_user_registration {
      max_attempts = var.suspicious_ip_pre_registration_max_attempts
      rate         = var.suspicious_ip_pre_registration_rate
    }
  }

  breached_password_detection {
    enabled                      = var.enable_breached_password_detection
    shields                      = ["admin_notification", "block"]
    admin_notification_frequency = ["immediately"]
    method                       = "standard"
  }
}
