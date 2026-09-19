extends PanelContainer

class_name CompanyToken


@onready var _label: Label = $Label


func set_company_token(token: Dictionary) -> void:
	_label.text = "%s %s" % [token["company_emoji"], token["company_name"]]
	tooltip_text = "%s %s" % [token["company_emoji"], token["company_name"]]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
