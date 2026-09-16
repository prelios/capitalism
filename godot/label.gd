extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Hello y'all")

var timer = 0
var click_counter = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timer += delta
	#print(delta)
	if timer > 1:
		print("Updating label with time")
		self.text = str(click_counter) + "   |   " + str(timer) + "s"


func _on_button_clicked() -> void:
	click_counter += 1
