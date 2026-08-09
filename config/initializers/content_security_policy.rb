Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.base_uri :self
  policy.connect_src :self
  policy.font_src :self, :data
  policy.form_action :self
  policy.frame_ancestors :none
  policy.img_src :self, :data, "https://img.shields.io"
  policy.object_src :none
  policy.script_src :self

  # Several original views and the bundled visual assets use style attributes.
  # Keep them operational while serving the remaining styles locally.
  policy.style_src :self,
    :unsafe_inline
end
