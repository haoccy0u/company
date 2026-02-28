class_name AttributeBuff extends Resource

@export var buff_name: String
@export var operation := AttributeModifier.OperationType.ADD
@export var value := 0.0
@export var policy := DurationPolicy.Infinite

## duration_policy == HasDuration生效
## 单位：秒
@export var duration: float = 0.0
@export var merging := DurationMerging.Restart

enum DurationPolicy {
	Infinite,		## 持久地
	HasDuration,	## 有时效性地
	Period,			## 周期性地
}

enum DurationMerging {
	Restart,	## 重新开始计算时长
	Addtion,	## 新的时长叠加到现有时效上
	NoEffect,	## 对现有时效无任何影响
}

var attribute_modifier: AttributeModifier
var remaining_time: float
var is_pending_remove := false

var applied_attribute:
	get():
		return applied_attribute.get_ref() if is_instance_valid(applied_attribute) else null
		
func _init(_operation := AttributeModifier.OperationType.ADD, _value: float = 0.0, _name := ""):
	operation = _operation
	value = _value
	buff_name = _name
	_ensure_attribute_modifier()
	
func duplicate_buff() -> AttributeBuff:
	var duplicated_buff = duplicate(true)
	duplicated_buff.attribute_modifier = AttributeModifier.new(operation, value)
	duplicated_buff.operation = operation
	duplicated_buff.value = value
	duplicated_buff.policy = policy
	duplicated_buff.duration = duration
	duplicated_buff.remaining_time = duration
	duplicated_buff.is_pending_remove = false
	return duplicated_buff
	
## 由应用目标属性驱动
func run_process(delta: float):
	if has_duration() and not is_pending_remove:
		remaining_time = max(remaining_time - delta, 0.0)
		if is_zero_approx(remaining_time):
			is_pending_remove = true


static func add(_value: float = 0.0, _name := "") -> AttributeBuff:
	return AttributeBuff.new(AttributeModifier.OperationType.ADD, _value, _name)


static func sub(_value: float = 0.0, _name := "") -> AttributeBuff:
	return AttributeBuff.new(AttributeModifier.OperationType.SUB, _value, _name)


static func mult(_value: float = 0.0, _name := "") -> AttributeBuff:
	return AttributeBuff.new(AttributeModifier.OperationType.MULT, _value, _name)


static func div(_value: float = 0.0, _name := "") -> AttributeBuff:
	return AttributeBuff.new(AttributeModifier.OperationType.DIVIDE, _value, _name)


func operate(base_value: float) -> float:
	_ensure_attribute_modifier()
	return attribute_modifier.operate(base_value)


func has_duration() -> bool:
	return policy == DurationPolicy.HasDuration


func set_merging(_mergin: DurationMerging):
	merging = _mergin


func set_duration(_time: float) -> AttributeBuff:
	duration = _time
	remaining_time = duration
	if duration > 0.0:
		policy = DurationPolicy.HasDuration
	return self


func restart_duration():
	remaining_time = duration


func extend_duration(_time: float):
	remaining_time += _time


func _ensure_attribute_modifier() -> void:
	if not is_instance_valid(attribute_modifier):
		attribute_modifier = AttributeModifier.new(operation, value)
		return
	attribute_modifier.type = operation
	attribute_modifier.value = value
