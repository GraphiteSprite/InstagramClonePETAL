defmodule InstagramClone.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias InstagramClone.Repo
  alias InstagramClone.Accounts.{User, UserToken, UserNotifier}
  alias InstagramCloneWeb.UserAuth
  alias InstagramClone.Accounts.Follows
  alias InstagramClone.Notifications

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  def change_user(user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, register_user: false)
  end

  def update_user(user, attrs) do
    user
    |> User.registration_changeset(attrs, register_user: false)
    |> Repo.update()
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    user
    |> User.password_changeset(attrs)
    |> User.validate_current_password(password)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given username param.
  """
  def profile(param) do
    Repo.get_by!(User, username: param)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  def log_out_user(token) do
    user = get_user_by_session_token(token)
    # Delete all user tokens
    Repo.delete_all(UserToken.user_and_contexts_query(user, :all))

    # Broadcast to all liveviews to immediately disconnect the user
    InstagramCloneWeb.Endpoint.broadcast_from(
      self(),
      UserAuth.pubsub_topic(),
      "logout_user",
      %{
        user: user
      }
    )
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Creates a follow to the given followed user, and builds
  user association to be able to preload the user when associations are loaded,
  gets users to update counts, then performs 3 Repo operations,
  creates the follow, updates user followings count, and user followers count,
  we select the user in our updated followers count query, that gets returned
  """
  def create_follow(follower, followed, user) do
    follower = Ecto.build_assoc(follower, :following)
    follow = Ecto.build_assoc(followed, :followers, follower)
    update_following_count = from(u in User, where: u.id == ^user.id)
    update_followers_count = from(u in User, where: u.id == ^followed.id, select: u)

    notification =
      Notifications.build_following_notification(
        user: followed,
        actor: user
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:follow, follow)
    |> Ecto.Multi.insert(:notification, notification)
    |> Ecto.Multi.update_all(:update_following, update_following_count, inc: [following_count: 1])
    |> Ecto.Multi.update_all(:update_followers, update_followers_count, inc: [followers_count: 1])
    |> Repo.transaction()
    |> case do
      {:ok, %{update_followers: update_followers}} ->
        InstagramCloneWeb.Endpoint.broadcast_from(
          self(),
          UserAuth.pubsub_topic(),
          "notify_user",
          %{}
        )

        {1, user} = update_followers
        hd(user)
    end
  end

  @doc """
  Deletes following association with given user,
  then performs 3 Repo operations, to delete the association,
  update followings count, update and select followers count,
  updated followers count gets returned
  """
  def unfollow(follower_id, followed_id) do
    follow = following?(follower_id, followed_id)
    update_following_count = from(u in User, where: u.id == ^follower_id)
    update_followers_count = from(u in User, where: u.id == ^followed_id, select: u)

    notification =
      Notifications.get_following_notification(
        user_id: followed_id,
        actor_id: follower_id
      )

    Ecto.Multi.new()
    |> Ecto.Multi.delete(:follow, follow)
    |> Ecto.Multi.delete(:notification, notification)
    |> Ecto.Multi.update_all(:update_following, update_following_count,
      inc: [following_count: -1]
    )
    |> Ecto.Multi.update_all(:update_followers, update_followers_count,
      inc: [followers_count: -1]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{update_followers: update_followers}} ->
        InstagramCloneWeb.Endpoint.broadcast_from(
          self(),
          UserAuth.pubsub_topic(),
          "unnotify_user",
          %{}
        )

        {1, user} = update_followers
        hd(user)
    end
  end

  @doc """
  Returns nil if not found
  """
  def following?(follower_id, followed_id) do
    Repo.get_by(Follows, follower_id: follower_id, followed_id: followed_id)
  end

  @doc """
  Returns all user's followings
  """
  def list_following(user) do
    user = user |> Repo.preload(:following)
    user.following |> Repo.preload(:followed)
  end

  @doc """
  Returns all user's followers
  """
  def list_followers(user) do
    user = user |> Repo.preload(:followers)
    user.followers |> Repo.preload(:follower)
  end

  def random_5(user) do
    following_list = get_following_list(user)

    User
    |> where([u], u.id not in ^following_list)
    |> where([u], u.id != ^user.id)
    |> order_by(desc: fragment("Random()"))
    |> limit(5)
    |> Repo.all()
  end

  @doc """
  Returns the list of following user ids

  ## Examples

      iex> get_following_list(user)
      [3, 2, 1]
  """
  def get_following_list(user) do
    Follows
    |> select([f], f.followed_id)
    |> where(follower_id: ^user.id)
    |> Repo.all()
  end

  def search_users(q) do
    User
    |> where([u], ilike(u.username, ^"%#{q}%"))
    |> or_where([u], ilike(u.full_name, ^"%#{q}%"))
    |> select([u], map(u, [:avatar_url, :username, :full_name]))
    |> Repo.all()
  end
end
