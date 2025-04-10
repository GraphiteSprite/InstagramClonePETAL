defmodule InstagramCloneWeb.ErrorHTML do
  use InstagramCloneWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates line below
  # and add pages to the error directory:
  #
  #   * lib/instagram_clone_web/controllers/error_html/404.html.heex
  #   * lib/instagram_clone_web/controllers/error_html/500.html.heex
  #
  # embed_templates "error_html/*"

  # The default is to render a generic error page.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end