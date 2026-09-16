extends Player

class_name RandomPlayer


func _init(id):
	super(id)
	self.player_type = "Random"


func choose_target(players: Array[Player]):
	# Super method is random, so just pick that
	return super.choose_target(players)
