defmodule InstagramClone.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias InstagramClone.Accounts.Follows
  alias InstagramClone.Notifications.Notification

  @derive {Inspect, except: [:password]}
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :hashed_password, :string
    field :confirmed_at, :naive_datetime
    field :username, :string
    field :full_name, :string
    field :avatar_url, :string, default: "/images/default-avatar.png"
    field :bio, :string
    field :website, :string
    field :followers_count, :integer, default: 0
    field :following_count, :integer, default: 0
    field :posts_count, :integer, default: 0
    has_many :following, Follows, foreign_key: :follower_id
    has_many :followers, Follows, foreign_key: :followed_id
    has_many :posts, InstagramClone.Posts.Post
    has_many :likes, InstagramClone.Likes.Like
    has_many :comments, InstagramClone.Comments.Comment
    has_many :posts_bookmarks, InstagramClone.Posts.Bookmarks
    has_many :notifications, Notification
    has_many :actors, Notification, foreign_key: :actor_id

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :username, :full_name, :avatar_url, :bio, :website])
    |> validate_required([:username, :full_name])
    |> validate_length(:username, min: 5, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_.-]*$/,
      message: "Please use letters and numbers without space(only characters allowed _ . -)"
    )
    |> unique_constraint(:username)
    |> unsafe_validate_unique(:username, InstagramClone.Repo)
    |> validate_length(:full_name, min: 4, max: 255)
    |> validate_format(:full_name, ~r/^[a-zA-Z0-9 ]*$/, message: "Please use letters and numbers")
    |> validate_website_schemes()
    |> validate_website_authority()
    |> validate_email()
    |> validate_password(opts)
  end

  defp validate_website_schemes(changeset) do
    validate_change(changeset, :website, fn :website, website ->
      uri = URI.parse(website)
      if uri.scheme, do: check_uri_scheme(uri.scheme), else: [website: "Enter a valid website"]
    end)
  end

  defp validate_website_authority(changeset) do
    validate_change(changeset, :website, fn :website, website ->
      authority = URI.parse(website).authority

      if authority do
        if String.match?(authority, ~r/^[a-zA-Z0-9.-]*$/) do
          []
        else
          [website: "Enter a valid website"]
        end
      else
        []
      end
    end)
  end

  defp check_uri_scheme(scheme) when scheme == "http", do: []
  defp check_uri_scheme(scheme) when scheme == "https", do: []
  defp check_uri_scheme(_scheme), do: [website: "Enter a valid website"]

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, InstagramClone.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    register_user? = Keyword.get(opts, :register_user, true)

    if register_user? do
      changeset
      |> validate_required([:password])
      |> validate_length(:password, min: 6, max: 80)
      # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
      # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
      # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
      |> maybe_hash_password(opts)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%InstagramClone.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
