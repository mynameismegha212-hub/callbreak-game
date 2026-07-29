extends Node2D

# ----------------------------------------------------
# 1. প্রয়োজনীয় ভেরিয়েবলসমূহ
# ----------------------------------------------------
var deck = []
var player1_hand = []
var player2_hand = []
var player3_hand = []
var player4_hand = []

var is_bidding = true
var can_play = false

var tween = null
var timer_bar = null
var turn_time_left = 6.0 
var is_player_turn_active = false
var tricks_played = 0 

var current_round = 1
var turn_order = ["YOU", "LEFT", "TOP", "RIGHT"]
var current_turn_index = 0
var trick_cards_played = 0
var current_trick = [] 
var table_card_nodes = [] 
var warning_label = null

var player1_card_buttons = []
var other_card_sprites = []

# মাল্টিপ্লেয়ার এবং বট ম্যানেজমেন্ট
const PORT = 10567
const MAX_PLAYERS = 4
var lobby_panel = null
var ip_input = null
var start_game_btn = null
var connected_players_label = null

# কোন পজিশনে কে খেলছে (bot নাকি নেটওয়ার্ক প্লেয়ারের ID)
var slot_status = {
	"YOU": "host",
	"LEFT": "bot",
	"TOP": "bot",
	"RIGHT": "bot"
}
var joined_peers = [] 

# স্কোরের হিসাব
var total_scores = {"YOU": 0.0, "LEFT": 0.0, "TOP": 0.0, "RIGHT": 0.0}
var scores = {
	"YOU": {"bid": 0, "won": 0},
	"LEFT": {"bid": 0, "won": 0},
	"TOP": {"bid": 0, "won": 0},
	"RIGHT": {"bid": 0, "won": 0}
}
var score_labels = {}
var score_panels = [] 
var bidding_panel = null

# ----------------------------------------------------
# 2. গেম শুরু এবং নেটওয়ার্ক সিগন্যাল
# ----------------------------------------------------
func _ready():
	randomize()
	
	get_tree().connect("network_peer_connected", self, "_on_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	get_tree().connect("connected_to_server", self, "_on_connected_to_server")
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	get_tree().connect("server_disconnected", self, "_on_server_disconnected")
	
	tween = Tween.new()
	add_child(tween)
	
	timer_bar = ColorRect.new()
	timer_bar.rect_position = Vector2(250, 465) 
	timer_bar.rect_size = Vector2(500, 5) 
	timer_bar.color = Color(1, 0, 0, 1) 
	timer_bar.visible = false
	add_child(timer_bar)

	show_lobby_ui()

# ----------------------------------------------------
# 3. লবি সিস্টেম (Lobby UI)
# ----------------------------------------------------
func show_lobby_ui():
	lobby_panel = ColorRect.new()
	lobby_panel.rect_min_size = Vector2(450, 320)
	lobby_panel.rect_position = Vector2(275, 140)
	lobby_panel.color = Color(0.05, 0.05, 0.1, 0.95)
	add_child(lobby_panel)
	
	var title = Label.new()
	title.text = "🎴 SPADES ONLINE MULTIPLAYER"
	title.rect_position = Vector2(85, 25)
	title.add_color_override("font_color", Color(1, 0.84, 0, 1))
	lobby_panel.add_child(title)
	
	var host_btn = Button.new()
	host_btn.text = "CREATE ROOM (HOST)"
	host_btn.rect_min_size = Vector2(250, 45)
	host_btn.rect_position = Vector2(100, 75)
	host_btn.connect("pressed", self, "_on_host_pressed")
	lobby_panel.add_child(host_btn)
	
	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.rect_min_size = Vector2(250, 35)
	ip_input.rect_position = Vector2(100, 135)
	lobby_panel.add_child(ip_input)
	
	var join_btn = Button.new()
	join_btn.text = "JOIN ROOM"
	join_btn.rect_min_size = Vector2(250, 45)
	join_btn.rect_position = Vector2(100, 185)
	join_btn.connect("pressed", self, "_on_join_pressed")
	lobby_panel.add_child(join_btn)
	
	connected_players_label = Label.new()
	connected_players_label.text = "Players in Lobby: 1/4"
	connected_players_label.rect_position = Vector2(140, 240)
	connected_players_label.visible = false
	lobby_panel.add_child(connected_players_label)
	
	start_game_btn = Button.new()
	start_game_btn.text = "START MATCH NOW"
	start_game_btn.rect_min_size = Vector2(250, 45)
	start_game_btn.rect_position = Vector2(100, 265)
	start_game_btn.add_color_override("font_color", Color(0, 1, 0, 1))
	start_game_btn.visible = false
	start_game_btn.connect("pressed", self, "_on_start_match_pressed")
	lobby_panel.add_child(start_game_btn)

# ----------------------------------------------------
# 4. নেটওয়ার্ক কানেকশন ও বট অ্যাসাইনমেন্ট
# ----------------------------------------------------
func _on_host_pressed():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(PORT, MAX_PLAYERS)
	get_tree().network_peer = peer
	
	connected_players_label.visible = true
	start_game_btn.visible = true
	print("Room Hosted! Waiting for players...")

func _on_join_pressed():
	var ip = ip_input.text
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, PORT)
	get_tree().network_peer = peer
	connected_players_label.text = "Connecting..."
	connected_players_label.visible = true

func _on_player_connected(id):
	if get_tree().is_network_server():
		joined_peers.append(id)
		if slot_status["LEFT"] == "bot": slot_status["LEFT"] = str(id)
		elif slot_status["TOP"] == "bot": slot_status["TOP"] = str(id)
		elif slot_status["RIGHT"] == "bot": slot_status["RIGHT"] = str(id)
		
		connected_players_label.text = "Players in Lobby: " + str(joined_peers.size() + 1) + "/4"
		rpc("update_lobby_count", joined_peers.size() + 1)

func _on_player_disconnected(id):
	print("Player disconnected: ", id)
	for key in slot_status.keys():
		if slot_status[key] == str(id):
			slot_status[key] = "bot"
			print(key, " is now replaced by a BOT.")
			
	if get_tree().is_network_server() and lobby_panel != null and is_instance_valid(lobby_panel):
		joined_peers.erase(id)
		connected_players_label.text = "Players in Lobby: " + str(joined_peers.size() + 1) + "/4"
		rpc("update_lobby_count", joined_peers.size() + 1)

func _on_connected_to_server():
	print("Connected to host!")

func _on_connection_failed():
	connected_players_label.text = "Connection Failed!"

func _on_server_disconnected():
	print("Server Closed!")
	get_tree().reload_current_scene()

remote func update_lobby_count(count):
	if connected_players_label and is_instance_valid(connected_players_label):
		connected_players_label.text = "Players in Lobby: " + str(count) + "/4\nWaiting for Host to start..."

# ----------------------------------------------------
# 5. গেম শুরু (Start Match & Sync)
# ----------------------------------------------------
func _on_start_match_pressed():
	var game_seed = randi()
	rpc("start_multiplayer_match", game_seed, slot_status)
	start_multiplayer_match(game_seed, slot_status)

remote func start_multiplayer_match(game_seed, host_slot_status):
	seed(game_seed) 
	slot_status = host_slot_status
	
	if lobby_panel and is_instance_valid(lobby_panel):
		lobby_panel.queue_free()
	
	start_new_match_round()

func start_new_match_round():
	for btn in player1_card_buttons:
		if is_instance_valid(btn): btn.queue_free()
	player1_card_buttons.clear()
	
	for spr in other_card_sprites:
		if is_instance_valid(spr): spr.queue_free()
	other_card_sprites.clear()
	
	current_trick.clear()
	tricks_played = 0
	is_bidding = true
	
	create_deck()
	deck.shuffle()
	deal_cards()
	
	player1_hand.sort_custom(self, "compare_cards")
	
	render_player1_cards()
	create_score_badges()
	show_bidding_panel()

# ----------------------------------------------------
# 6. কার্ড ডিলিং এবং লজিক
# ----------------------------------------------------
func create_deck():
	deck.clear()
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "j", "q", "k", "a"]
	var suits = ["c", "d", "h", "s"] 
	for suit in suits:
		for rank in ranks:
			deck.append(rank + suit + ".png")

func deal_cards():
	player1_hand.clear()
	player2_hand.clear()
	player3_hand.clear()
	player4_hand.clear()
	for i in range(13):
		player1_hand.append(deck.pop_front())
		player2_hand.append(deck.pop_front())
		player3_hand.append(deck.pop_front())
		player4_hand.append(deck.pop_front())

func get_card_suit(card_name: String) -> String:
	var clean = card_name.replace(".png", "")
	return clean.substr(clean.length() - 1, 1)

func get_card_rank_value(card_name: String) -> int:
	var clean = card_name.replace(".png", "")
	var rank_str = clean.substr(0, clean.length() - 1)
	if rank_str == "a": return 14
	elif rank_str == "k": return 13
	elif rank_str == "q": return 12
	elif rank_str == "j": return 11
	return int(rank_str)

func get_card_value(card_name: String) -> int:
	var rank_val = get_card_rank_value(card_name)
	var suit = get_card_suit(card_name)
	var suit_val = 0
	if suit == "s": suit_val = 400
	elif suit == "h": suit_val = 300
	elif suit == "d": suit_val = 200
	elif suit == "c": suit_val = 100
	return suit_val + rank_val

func compare_cards(a, b):
	return get_card_value(a) > get_card_value(b)

# ----------------------------------------------------
# 7. গেমপ্লে এবং টার্ন সিস্টেম
# ----------------------------------------------------
func play_next_turn():
	if trick_cards_played >= 4:
		yield(get_tree().create_timer(0.8), "timeout")
		evaluate_trick_winner()
		return
		
	var active_player = turn_order[current_turn_index]
	
	if active_player == "YOU":
		start_player_turn()
	else:
		if slot_status[active_player] == "bot":
			play_single_bot_turn(active_player)
		else:
			print("Waiting for network player: ", active_player)

func start_player_turn():
	can_play = true
	turn_time_left = 6.0 
	is_player_turn_active = true
	if timer_bar: timer_bar.visible = true

func _process(delta):
	if is_player_turn_active and not is_bidding:
		turn_time_left -= delta
		if timer_bar: timer_bar.rect_size.x = (turn_time_left / 6.0) * 500
		
		if turn_time_left <= 0:
			is_player_turn_active = false
			timer_bar.visible = false
			auto_play_card()

func auto_play_card():
	for btn in player1_card_buttons:
		if is_instance_valid(btn) and btn.is_connected("pressed", self, "_on_card_played"):
			_on_card_played(btn)
			return

func _on_card_played(btn: TextureButton):
	if is_bidding or not can_play: return
	var card_name = btn.get_meta("card_name")
	
	if current_trick.size() > 0:
		var lead_suit = get_card_suit(current_trick[0]["card"])
		if get_card_suit(card_name) != lead_suit:
			for c in player1_hand:
				if get_card_suit(c) == lead_suit:
					print("আপনার কাছে এই সেটের তাস আছে, সেটাই ফেলতে হবে!")
					return 

	can_play = false
	is_player_turn_active = false
	if timer_bar: timer_bar.visible = false

	player1_hand.erase(card_name)
	if is_instance_valid(btn): btn.queue_free()
	
	if get_tree().network_peer != null:
		rpc("play_remote_card", "YOU", card_name)
		
	register_played_card("YOU", card_name)
	render_player1_cards()

# ----------------------------------------------------
# 8. বটের চাল এবং কার্ড রেজিস্টার
# ----------------------------------------------------
func play_single_bot_turn(bot_name: String):
	if not get_tree().is_network_server() and get_tree().network_peer != null:
		return
		
	yield(get_tree().create_timer(0.8), "timeout")
	
	var hand = []
	if bot_name == "LEFT": hand = player2_hand
	elif bot_name == "TOP": hand = player3_hand
	elif bot_name == "RIGHT": hand = player4_hand
		
	if hand.size() > 0:
		var played_card = hand.pop_front()
		
		if get_tree().network_peer != null:
			rpc("play_remote_card", bot_name, played_card)
		
		register_played_card(bot_name, played_card)

remote func play_remote_card(player_name: String, card_name: String):
	if player_name != "YOU":
		register_played_card(player_name, card_name)

func register_played_card(player_name: String, card_name: String):
	current_trick.append({"player": player_name, "card": card_name})
	
	var start_pos = Vector2(460, 480)
	var target_pos = Vector2(460, 340)
	
	if player_name == "LEFT":
		start_pos = Vector2(180, 260)
		target_pos = Vector2(380, 280)
	elif player_name == "TOP":
		start_pos = Vector2(460, 210)
		target_pos = Vector2(460, 220)
	elif player_name == "RIGHT":
		start_pos = Vector2(740, 260)
		target_pos = Vector2(540, 280)
	elif player_name == "YOU":
		start_pos = Vector2(460, 480)
		target_pos = Vector2(460, 340)

	var card_sprite = Sprite.new()
	var tex = load("res://" + card_name)
	if tex: card_sprite.texture = tex
	card_sprite.scale = Vector2(0.11, 0.11)
	card_sprite.position = start_pos 
	add_child(card_sprite)
	table_card_nodes.append(card_sprite)
	
	tween.interpolate_property(card_sprite, "position", start_pos, target_pos, 0.35, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	
	if player_name == "LEFT" and player2_hand.has(card_name): player2_hand.erase(card_name)
	elif player_name == "TOP" and player3_hand.has(card_name): player3_hand.erase(card_name)
	elif player_name == "RIGHT" and player4_hand.has(card_name): player4_hand.erase(card_name)

	trick_cards_played += 1
	current_turn_index = (current_turn_index + 1) % 4
	play_next_turn()

# ----------------------------------------------------
# 9. বিজয়ী নির্ণয় ও স্কোরিং (স্লাইড অ্যানিমেশন সহ)
# ----------------------------------------------------
func evaluate_trick_winner():
	var lead_suit = get_card_suit(current_trick[0]["card"])
	var best_card = current_trick[0]["card"]
	var winner = current_trick[0]["player"]
	
	for i in range(1, current_trick.size()):
		var play = current_trick[i]
		var c_card = play["card"]
		var c_player = play["player"]
		
		var best_suit = get_card_suit(best_card)
		var c_suit = get_card_suit(c_card)
		var best_val = get_card_rank_value(best_card)
		var c_val = get_card_rank_value(c_card)
		
		if c_suit == "s" and best_suit != "s":
			best_card = c_card
			winner = c_player
		elif c_suit == "s" and best_suit == "s":
			if c_val > best_val:
				best_card = c_card
				winner = c_player
		elif c_suit != "s" and best_suit != "s":
			if c_suit == lead_suit and best_suit == lead_suit:
				if c_val > best_val:
					best_card = c_card
					winner = c_player
			elif c_suit == lead_suit and best_suit != lead_suit:
				best_card = c_card
				winner = c_player
				
	scores[winner]["won"] += 1
	update_score_badges()
	
	# উইনারের পজিশনে তাসগুলোর স্লাইড অ্যানিমেশন
	var winner_target_pos = Vector2(460, 430)
	if winner == "LEFT": winner_target_pos = Vector2(100, 260)
	elif winner == "TOP": winner_target_pos = Vector2(460, 90)
	elif winner == "RIGHT": winner_target_pos = Vector2(820, 260)
	elif winner == "YOU": winner_target_pos = Vector2(460, 430)
	
	for node in table_card_nodes:
		if is_instance_valid(node):
			tween.interpolate_property(node, "position", node.position, winner_target_pos, 0.4, Tween.TRANS_CUBIC, Tween.EASE_IN)
			tween.interpolate_property(node, "scale", node.scale, Vector2(0.01, 0.01), 0.4, Tween.TRANS_CUBIC, Tween.EASE_IN)
	tween.start()
	
	yield(get_tree().create_timer(0.45), "timeout")
	
	for node in table_card_nodes:
		if is_instance_valid(node): node.queue_free()
	table_card_nodes.clear()
	current_trick.clear()
	
	tricks_played += 1
	
	if tricks_played >= 13:
		current_round += 1
		start_new_match_round()
	else:
		current_turn_index = turn_order.find(winner)
		trick_cards_played = 0
		play_next_turn()

# ----------------------------------------------------
# 10. UI (রেন্ডার এবং বিড)
# ----------------------------------------------------
func render_player1_cards():
	for btn in player1_card_buttons:
		if is_instance_valid(btn): btn.queue_free()
	player1_card_buttons.clear()
	
	var start_x = 250
	for i in range(player1_hand.size()):
		var card_btn = TextureButton.new()
		var tex = load("res://" + player1_hand[i])
		if tex: card_btn.texture_normal = tex
		card_btn.rect_scale = Vector2(0.11, 0.11)
		card_btn.rect_position = Vector2(start_x + (i * 22), 490)
		card_btn.set_meta("card_name", player1_hand[i])
		card_btn.connect("pressed", self, "_on_card_played", [card_btn])
		add_child(card_btn)
		player1_card_buttons.append(card_btn)

func show_bidding_panel():
	bidding_panel = ColorRect.new()
	bidding_panel.rect_min_size = Vector2(400, 160)
	bidding_panel.rect_position = Vector2(310, 200)
	bidding_panel.color = Color(0.05, 0.05, 0.05, 0.9)
	add_child(bidding_panel)
	
	for i in range(1, 9):
		var btn = Button.new()
		btn.text = str(i)
		btn.rect_min_size = Vector2(65, 35)
		var col = (i - 1) % 4
		var row = (i - 1) / 4
		btn.rect_position = Vector2(35 + (col * 85), 55 + (row * 45))
		btn.connect("pressed", self, "_on_bid_selected", [i])
		bidding_panel.add_child(btn)

func _on_bid_selected(bid_val: int):
	rpc("sync_bid", "YOU", bid_val)
	sync_bid("YOU", bid_val)
	
	if get_tree().is_network_server():
		for p in ["LEFT", "TOP", "RIGHT"]:
			if slot_status[p] == "bot":
				var bot_bid = (randi() % 4) + 2
				rpc("sync_bid", p, bot_bid)
				sync_bid(p, bot_bid)
				
	bidding_panel.queue_free()
	is_bidding = false
	
	# সবচেয়ে বেশি যে বিড করেছে, তাকে প্রথম টার্ন দেওয়া
	var max_bid = -1
	var first_player = "YOU"
	for p in turn_order:
		if scores[p]["bid"] > max_bid:
			max_bid = scores[p]["bid"]
			first_player = p
			
	current_turn_index = turn_order.find(first_player)
	trick_cards_played = 0
	play_next_turn()

remote func sync_bid(player_name, bid_val):
	scores[player_name]["bid"] = bid_val
	update_score_badges()

func create_score_badges():
	for panel in score_panels:
		if is_instance_valid(panel): panel.queue_free()
	score_panels.clear()
	score_labels.clear()
	
	var positions = {
		"YOU": Vector2(460, 430),
		"LEFT": Vector2(100, 260),
		"TOP": Vector2(460, 90),
		"RIGHT": Vector2(820, 260)
	}
	
	for p in positions.keys():
		var panel = ColorRect.new()
		panel.rect_size = Vector2(100, 45)
		panel.rect_position = positions[p] - Vector2(50, 22)
		panel.color = Color(0, 0, 0, 0.75)
		add_child(panel)
		score_panels.append(panel)
		
		var label = Label.new()
		label.text = p + "\nBid: 0 | Won: 0"
		label.align = Label.ALIGN_CENTER
		label.valign = Label.VALIGN_CENTER
		label.rect_size = panel.rect_size
		panel.add_child(label)
		
		score_labels[p] = label
		
	update_score_badges()

func update_score_badges():
	for p_name in score_labels.keys():
		if score_labels.has(p_name) and is_instance_valid(score_labels[p_name]):
			var bid = scores[p_name]["bid"]
			var won = scores[p_name]["won"]
			score_labels[p_name].text = p_name + "\nBid: " + str(bid) + " | Won: " + str(won)
