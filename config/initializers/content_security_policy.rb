# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    # upload.wikimedia.org : images des villes (Wikipedia API)
    # tile.openstreetmap.org : tuiles cartographiques (Leaflet / Mapbox)
    policy.img_src     :self, :https, :data,
                       "https://upload.wikimedia.org",
                       "https://*.tile.openstreetmap.org"
    policy.object_src  :none
    policy.script_src  :self, :https
    # Mapbox GL JS crée des event handlers inline (onclick, etc.) dans ses composants internes.
    # script-src-attr couvre uniquement les attributs on* — moins permissif qu'unsafe-inline global.
    policy.script_src_attr :unsafe_inline
    # unsafe_inline nécessaire pour Bootstrap et Stimulus qui injectent des styles inline
    policy.style_src   :self, :https, :unsafe_inline
    # connect_src :https couvre les requêtes SSE (/messages/stream) et events.mapbox.com
    policy.connect_src :self, :https
    # Mapbox GL JS crée des Web Workers depuis des blob: URLs — obligatoire pour la carte
    policy.worker_src  :self, "blob:"
    policy.frame_src   :none
  end

  # Le nonce est injecté automatiquement par Rails dans les balises <script>
  # générées par les helpers (importmap, etc.), ce qui permet d'autoriser
  # les scripts inline légitimes sans recourir à unsafe_inline.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
end
