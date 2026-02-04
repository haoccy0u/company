extends Node2D

@onready var attribute_component: AttributeComponent = %AttributeComponent


const max_hp_attribute_name = "maxhp"
const health_attribute_name = "hp"

var max_hp_attribute: Attribute
var health_attribute: Attribute

func _ready() -> void:
	max_hp_attribute = attribute_component.find_attribute(max_hp_attribute_name)
	health_attribute = attribute_component.find_attribute(health_attribute_name)
	print(max_hp_attribute.attribute_name)
	print_health_stats()
	
	health_attribute.add(20.0)
	print_health_stats()
	
	health_attribute.sub(30)
	print_health_stats()
	
func print_health_stats():
	print(health_attribute.get_value(), max_hp_attribute.get_value())
