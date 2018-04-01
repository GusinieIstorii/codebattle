defmodule Codebattle.CodeCheck.Ruby.IntegrationTest do
  use Codebattle.IntegrationCase

  alias CodebattleWeb.GameChannel
  alias Codebattle.GameProcess.{Server, Player}

  setup do
    timeout = Application.fetch_env!(:codebattle, :code_check_timeout)

    user1 = insert(:user)
    user2 = insert(:user)

    task = insert(:task)
    setup_lang(:ruby)

    socket1 = socket("user_id", %{user_id: user1.id, current_user: user1})
    socket2 = socket("user_id", %{user_id: user2.id, current_user: user2})

    {:ok,
     %{
       user1: user1,
       user2: user2,
       task: task,
       socket1: socket1,
       socket2: socket2,
       timeout: timeout
     }}
  end

  test "bad code, game playing", %{
    user1: user1,
    user2: user2,
    task: task,
    socket1: socket1,
    socket2: socket2,
    timeout: timeout
  } do
    # setup
    state = :playing

    data = %{
      players: [%Player{id: user1.id, user: user1}, %Player{id: user2.id, user: user2}],
      task: task
    }

    game = setup_game(state, data)
    game_topic = "game:" <> to_string(game.id)

    {:ok, _response, socket1} = subscribe_and_join(socket1, GameChannel, game_topic)
    {:ok, _response, _socket2} = subscribe_and_join(socket2, GameChannel, game_topic)
    :lib.flush_receive()

    ref = push(socket1, "check_result", %{editor_text: "sdf", lang: "ruby"})
    :timer.sleep(timeout)

    assert_reply(ref, :ok, %{output: output})

    expected_result = %{"status" => "error", "result" => "undefined local variable or method `sdf' for main:Object"}

    assert expected_result == Poison.decode!(output)

    fsm = Server.fsm(game.id)

    assert fsm.state == :playing
  end

  test "good code, player won", %{
    user1: user1,
    user2: user2,
    task: task,
    socket1: socket1,
    socket2: socket2,
    timeout: timeout
  } do
    # setup
    state = :playing

    data = %{
      players: [%Player{id: user1.id, user: user1}, %Player{id: user2.id, user: user2}],
      task: task
    }

    game = setup_game(state, data)
    game_topic = "game:" <> to_string(game.id)

    {:ok, _response, socket1} = subscribe_and_join(socket1, GameChannel, game_topic)
    {:ok, _response, _socket2} = subscribe_and_join(socket2, GameChannel, game_topic)
    :lib.flush_receive()

    push(socket1, "editor:text", %{editor_text: "test"})

    push(socket1, "check_result", %{
      editor_text: "def solution(x,y); x + y; end",
      lang: "ruby"
    })

    :timer.sleep(timeout)

    fsm = Server.fsm(game.id)
    assert fsm.state == :game_over
  end
end
