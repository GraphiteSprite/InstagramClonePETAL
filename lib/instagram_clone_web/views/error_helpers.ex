defmodule InstagramCloneWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML
  use Gettext, backend: InstagramCloneWeb.Gettext

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, class \\ [class: "invalid-feedback"]) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error),
        class: Keyword.get(class, :class),
        phx_feedback_for: input_id(form, field)
      )
    end)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(InstagramCloneWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(InstagramCloneWeb.Gettext, "errors", msg, opts)
    end
  end
end
