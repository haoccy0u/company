class_name Attribute extends Resource

signal attribute_changed(attribute: Attribute)
signal buff_added(attribute:Attribute, buff:AttributeBuff)
signal buff_removed(attribute:Attribute, buff:AttributeBuff)

## 属性名称
@export var attribute_name: String

## 属性的默认数值(不变)
@export var base_value := 0.0: set = setter_base_value

## 自定义公式计算后
var computed_value := 0.0: set = setter_computed_value

## 初始化
var is_initialized_base_value = false

var modifiers: Array[AttributeModifier] = []

## 对当前属性有影响的buff集合
var buffs: Array[AttributeBuff] = []

## 寻找当前属性的属性集
var attribute_set:  ## (WeakRef)
	get():
		return attribute_set.get_ref()

#region Setter
func setter_base_value(value):
	if not is_initialized_base_value:
		is_initialized_base_value = true
		base_value = value
		computed_value = value

func setter_computed_value(value):
	computed_value = value
	attribute_changed.emit(self)
#endregion

#region public
func notify_attribute_change():
	attribute_changed.emit(self)

func update_computed_value():
	computed_value = _compute_value(computed_value)

## AttributeSet
func run_process(delta: float):
	var pending_remove_buffs: Array[AttributeBuff] = []
	
	## 删除
	for _buff in buffs:
		_buff.run_process(delta)
		if _buff.is_pending_remove:
			pending_remove_buffs.append(_buff)
	
	##确认
	for _buff in pending_remove_buffs:
		remove_buff(_buff)
		
func get_base_value():
	return base_value

func get_value():
	var attribute_value = computed_value
	for _buff in buffs:
		if _buff.policy != AttributeBuff.DurationPolicy.Period:
			attribute_value = _buff.operate(attribute_value)
	attribute_value = post_attribute_value_changed(attribute_value)
	return attribute_value

func set_value(_value: float):
	var operated_value = AttributeModifier.set_value(_value).operate(computed_value)
	computed_value = _compute_value(operated_value)


func add(_value: float):
	var operated_value = AttributeModifier.add(_value).operate(computed_value)
	computed_value = _compute_value(operated_value)


func sub(_value: float):
	var operated_value = AttributeModifier.subtract(_value).operate(computed_value)
	computed_value = _compute_value(operated_value)


func mult(_value: float):
	var operated_value = AttributeModifier.multiply(_value).operate(computed_value)
	computed_value = _compute_value(operated_value)


func div(_value: float):
	var operated_value = AttributeModifier.divide(_value).operate(computed_value)
	computed_value = _compute_value(operated_value)
	
func get_buff_size() -> int:
	return buffs.size()

func apply_buff_operation(_buff: AttributeBuff):
	if is_instance_valid(_buff):
		computed_value = post_attribute_value_changed(_buff.operate(computed_value))

func add_buff(_buff: AttributeBuff) -> AttributeBuff:
	if not is_instance_valid(_buff):
		return null
	
	var should_append_buff = true
	var pending_add_buff = _buff

	## 有命名的Buff时，处理重复Buff的duration逻辑
	if not _buff.buff_name.is_empty():
		var existing_buff = find_buff(_buff.buff_name)
		if is_instance_valid(existing_buff):
			match existing_buff.merging:
				AttributeBuff.DurationMerging.Restart: existing_buff.restart_duration()
				AttributeBuff.DurationMerging.Addtion: existing_buff.extend_duration(existing_buff.duration)
			pending_add_buff = existing_buff
			should_append_buff = false
	
	if should_append_buff:
		var duplicated_buff = _buff.duplicate_buff()
		duplicated_buff.applied_attribute = weakref(self)
		buffs.append(duplicated_buff)
		pending_add_buff = duplicated_buff
	
	buff_added.emit(self, pending_add_buff)
	attribute_changed.emit(self)
	return pending_add_buff
	
func remove_buff(_buff: AttributeBuff):
	if not is_instance_valid(_buff):
		return
	
	buffs.erase(_buff)
	buff_removed.emit(self, _buff)
	attribute_changed.emit(self)

func find_buff(buff_name: String) -> AttributeBuff:
	for _buff in buffs:
		if _buff.buff_name == buff_name:
			return _buff
	return null
#endregion


#region 子类继承
## 此处自定义计算公式	
func custom_compute(operated_value: float, _compute_params: Array[Attribute]) -> float:
	return operated_value

## 此处为属性依赖项列表
func derived_from() -> Array[String]:
	return []

## 完成计算后调用，用于数值后处理比如钳制
func post_attribute_value_changed(_value: float) -> float:
	return _value
#endregion


#region private
func _compute_value(_operated_value:float) -> float:
	var derived_attributes: Array[Attribute] = []
	var derived_attribute_names = derived_from()
	for _name in derived_attribute_names:
		var _attribute = attribute_set.find_attribute(_name)
		derived_attributes.append(_attribute)
	return custom_compute(_operated_value, derived_attributes)
#endregion
