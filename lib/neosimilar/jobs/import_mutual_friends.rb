module Job
  class ImportMutualFriends
    include Sidekiq::Worker
    sidekiq_options :retry => false

    def perform(uid, person_id)
      user = User.find_by_uid(uid)
      if user
        friend = User.find_by_uid(person_id)

        # Import mutual friends
        mutual_friends = user.client.get_connections("me", "mutualfriends/#{person_id}")

        commands = []

        # Make them friends
        mutual_friends.each do |mutual_friend|
          uid = mutual_friend["id"]

          node = User.find_by_uid(uid)
          unless node
            person = user.client.get_object(uid)
            node = User.create_from_facebook(person)
          end
          commands << [:execute_query, "START user=node({user_id}), friend=node({friend_id}) CREATE UNIQUE user-[:FRIENDS]->friend CREATE UNIQUE friend-[:FRIENDS]->user", {:user_id => node.neo_id, :friend_id => friend.neo_id}]
        end

        batch_result = $neo_server.batch *commands
      end
    end
  end
end