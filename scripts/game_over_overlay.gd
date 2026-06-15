extends ColorRect

@onready var result_label: Label = $ResultLabel

func setup_result(player_won: bool, final_score: int, enemies_defeated: int) -> void:
	var result_text: String = "YOU WIN" if player_won else "GAME OVER"
	result_label.text = "%s\nScore: %d\nEnemies: %d" % [result_text, final_score, enemies_defeated]
