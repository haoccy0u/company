class_name AttributeModifier extends Resource

enum OperationType{
	ADD,
	SUB,
	MULT,
	DIVIDE,
	SET,
}

var type: OperationType
var value: float

func _init(_type: OperationType = OperationType.ADD, _value: float = 0.0) -> void:
	type = _type
	value = _value

static func add(_value: float) -> AttributeModifier:
	return AttributeModifier.new(OperationType.ADD, _value)
	
static func subtract(_value: float) -> AttributeModifier:
	return AttributeModifier.new(OperationType.SUB, _value)

static func multiply(_value: float) -> AttributeModifier:
	return AttributeModifier.new(OperationType.MULT, _value)

static func divide(_value: float) -> AttributeModifier:
	return AttributeModifier.new(OperationType.DIVIDE, _value)

static func set_value(_value: float) -> AttributeModifier:
	return AttributeModifier.new(OperationType.SET, _value)
	
func operate(_base_value: float) -> float:
	match type:
		OperationType.ADD: return _base_value + value
		OperationType.SUB: return _base_value - value
		OperationType.MULT: return _base_value * value
		OperationType.DIVIDE: return 0.0 if is_zero_approx(value) else _base_value / value
		OperationType.SET: return value
	return value
