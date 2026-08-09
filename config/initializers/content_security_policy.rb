Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.base_uri :self
  policy.connect_src :self
  policy.font_src :self,
    :data,
    "https://fonts.gstatic.com",
    "https://use.fontawesome.com"
  policy.form_action :self
  policy.frame_ancestors :none
  policy.img_src :self, :data, "https://img.shields.io"
  policy.object_src :none
  policy.script_src :self,
    "https://cdnjs.cloudflare.com",
    "https://cdn.datatables.net"

  # Several original views and the bundled visual assets use style attributes.
  # Keep them operational while limiting external styles to the declared hosts.
  policy.style_src :self,
    :unsafe_inline,
    "https://fonts.googleapis.com",
    "https://use.fontawesome.com",
    "https://cdn.datatables.net"
end
