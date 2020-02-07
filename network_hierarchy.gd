extends NetworkLogic
class_name NetworkHierarchy

const network_entity_manager_const = preload("res://addons/network_manager/network_entity_manager.gd")

var parent_id : int = network_entity_manager_const.NULL_NETWORK_INSTANCE_ID

func _reparent_entity_instance(p_instance : Node, p_parent : Node = null) -> void:
	print("Reparenting entity: " + p_instance.get_name())
	if !p_instance.is_inside_tree():
		ErrorManager.error("reparent_entity_instance: entity not inside tree!")
		
	var last_global_transform : Transform = Transform()
	if p_instance.simulation_logic_node:
		last_global_transform = p_instance.simulation_logic_node.get_global_transform()
		
	p_instance.get_parent().remove_child(p_instance)
	
	if p_parent:
		p_parent.add_child(p_instance)
		
	if p_instance.simulation_logic_node:
		p_instance.simulation_logic_node.set_global_transform(last_global_transform)

static func encode_parent_id(p_writer : network_writer_const, p_id : int) -> network_writer_const:
	p_writer.put_u32(p_id)
	
	return p_writer
	
static func decode_parent_id(p_reader : network_reader_const) -> int:
	return p_reader.get_u32()

static func write_entity_parent_id(p_writer : network_writer_const, p_entity : Node) -> network_writer_const:
	if p_entity.entity_parent:
		encode_parent_id(p_writer, p_entity.entity_parent.get_network_identity_node().network_instance_id)
	else:
		p_writer.put_u32(NetworkManager.network_entity_manager.NULL_NETWORK_INSTANCE_ID)
		
	return p_writer
	
static func read_entity_parent_id(p_reader : network_reader_const) -> int:
	return decode_parent_id(p_reader)

func on_serialize(p_writer : network_writer_const, p_initial_state : bool) -> network_writer_const:
	if p_initial_state:
		pass
		
	p_writer = write_entity_parent_id(p_writer, entity_node)
	
	return p_writer
	
func process_parenting():
	if entity_node:
		var entity_parent = entity_node.entity_parent
		var last_parent_id = network_entity_manager_const.NULL_NETWORK_INSTANCE_ID
		
		if entity_parent:
			last_parent_id = entity_node.network_identity_node.network_instance_id
		
		if parent_id != last_parent_id:
			if parent_id != network_entity_manager_const.NULL_NETWORK_INSTANCE_ID:
				if NetworkManager.network_entity_manager.network_instance_ids.has(parent_id):
					var network_identity : Node = NetworkManager.network_entity_manager.get_network_instance_identity(parent_id)
					if network_identity:
						var parent_instance : Node = network_identity.get_entity_node()
						entity_node.entity_parent = parent_instance
						entity_node.entity_parent_state = entity_node.ENTITY_PARENT_STATE_CHANGED
						_reparent_entity_instance(entity_node, parent_instance)
				else:
					entity_node.entity_parent = null
					entity_node.entity_parent_state = entity_node.ENTITY_PARENT_STATE_INVALID
					_reparent_entity_instance(entity_node, null)
			else:
				entity_node.entity_parent = null
				entity_node.entity_parent_state = entity_node.ENTITY_PARENT_STATE_CHANGED
				_reparent_entity_instance(entity_node, null)
	
func on_deserialize(p_reader : network_reader_const, p_initial_state : bool) -> network_reader_const:
	received_data = true
	
	parent_id = read_entity_parent_id(p_reader)
	
	process_parenting()
	
	return p_reader

func _ready():
	if Engine.is_editor_hint() == false:
		if received_data:
			call_deferred("process_parenting")
