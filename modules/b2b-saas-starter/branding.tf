resource "auth0_branding" "this" {
  count = local.create_branding ? 1 : 0

  logo_url = var.branding_logo_url

  dynamic "colors" {
    for_each = (var.branding_primary_color != null || var.branding_background_color != null) ? [1] : []
    content {
      # Variables are validated as hex-or-null, so a missing color is always null here,
      # not an empty string. The provider omits null attributes rather than sending "",
      # so this does not trigger the 400 / plan-drift seen with empty strings in organizations.tf.
      primary         = var.branding_primary_color
      page_background = var.branding_background_color
    }
  }
}
