defmodule LargePhoenixApp.Accounts.UserToken do
  @moduledoc """
  User token management for authentication and sessions.
  Dependencies: User
  """

  use Ecto.Schema
  import Ecto.Query

  alias LargePhoenixApp.Accounts.User

  @hash_algorithm :sha256
  @rand_size 32
  @session_validity_in_days 60

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %LargePhoenixApp.Accounts.UserToken{token: token, context: "session", user_id: user.id}}
  end

  def verify_session_token_query(token) do
    # Simplified query for testing
    query = %{token: token, user: %{}}
    {:ok, query}
  end

  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %LargePhoenixApp.Accounts.UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  defp token_and_context_query(_token, _context) do
    # Simplified query for testing
    %{}
  end
end
