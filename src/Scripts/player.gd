extends KinematicBody2D

const GRAVITY := 600.0
const WALK_SPEED := 200.0
const JUMP_POWER := -300.0

var velocity := Vector2.ZERO
var can_jump := false
var hanging := false
var attached_rope_part_id : int = -INF
var attached_rope : Object = null
var rope_section_progress := 0.0
var attached_rope_rope_to_left := false
var last_pos := Vector2.ZERO

onready var visual = $Visual
onready var shape_hang = $Visual/ShapeHang
onready var shape_normal = $Visual/ShapeHang/ShapeNormal
onready var rope_attacher = $Visual/ShapeHang/RopeAttacher
onready var anim = $AnimationPlayer
onready var rope_detector = $RopeDetector
onready var ray_right = $FloorCheckR
onready var ray_left = $FloorCheckL

func _physics_process(delta):
	last_pos = position
	if !hanging:
		velocity.y += delta*GRAVITY
	
		if Input.is_action_pressed("ui_left"):
			anim.play("walk")
			visual.scale.x = -1
			velocity.x = -WALK_SPEED
		elif Input.is_action_pressed("ui_right"):
			anim.play("walk")
			visual.scale.x = 1
			velocity.x = WALK_SPEED
		else:
			anim.play("idle")
			velocity.x = 0
		
		if Input.is_action_just_pressed("ui_up") and can_jump:
			velocity.y = JUMP_POWER
			can_jump = false
		
		if !can_jump and is_on_floor():
			can_jump = true
		
		velocity = move_and_slide(velocity, Vector2.UP)
		
	else:
		velocity.y = 0
		can_jump = false
		var left = "ui_left" if attached_rope_rope_to_left else "ui_right"
		var right = "ui_left" if !attached_rope_rope_to_left else "ui_right"
		
		if Input.is_action_pressed(left):
			rope_section_progress -= 0.1
			visual.scale.x = -1 if attached_rope_rope_to_left else 1
			if rope_section_progress < 0:
				if attached_rope_part_id > 0:
					rope_section_progress = 1.0
					# warning-ignore:narrowing_conversion
					attached_rope_part_id = clamp( attached_rope_part_id-1, 0, attached_rope.rope_parts.size()-1 )
				else:
					rope_section_progress = 0.0
				
		elif Input.is_action_pressed(right):
			rope_section_progress += 0.1
			visual.scale.x = -1 if !attached_rope_rope_to_left else 1
			if rope_section_progress > 1:
				if attached_rope_part_id < attached_rope.rope_parts.size()-2:
					rope_section_progress = 0.0
					# warning-ignore:narrowing_conversion
					attached_rope_part_id = clamp( attached_rope_part_id+1, 0, attached_rope.rope_parts.size()-1 )
				else:
					rope_section_progress = 1.0
		
		global_position = get_player_pos_on_rope()
		
		if Input.is_action_pressed("ui_down") or floor_check():
			leave_rope()
		elif Input.is_action_just_pressed("ui_up"):
			leave_rope()
			velocity.y = JUMP_POWER
			can_jump = false


func leave_rope():
	set_hanging(false)
	attached_rope_part_id = -INF
	attached_rope.active_rope_id = attached_rope_part_id
	attached_rope = null


func floor_check():
	return ray_right.is_colliding() or ray_left.is_colliding()


func set_hanging(value):
	if hanging != value:
		hanging = value
		if hanging:
			shape_hang.self_modulate.a = 1
			shape_normal.hide()
			anim.play("hang")
			rope_attacher.show()
		else:
			shape_hang.self_modulate.a = 0
			shape_normal.show()
			rope_attacher.hide()
			anim.play("idle")
	


func get_player_pos_on_rope():
	attached_rope.active_rope_id = attached_rope_part_id
	var current_piece_pos = attached_rope.rope_parts[attached_rope_part_id].global_position
	var next_piece_id = clamp( attached_rope_part_id+1, 0, attached_rope.rope_parts.size()-1 )
	var next_piece_pos = attached_rope.rope_parts[next_piece_id].global_position
	var new_pos = lerp(current_piece_pos, next_piece_pos, rope_section_progress)
	
	new_pos -= rope_detector.position
	
	return new_pos


func _on_RopeDetector_body_entered(body:RopePiece):
	if !hanging and !Input.is_action_pressed("ui_down") and !Input.is_action_pressed("ui_up") and !is_on_floor():
		set_hanging(true)
		rope_section_progress = 0.0
		attached_rope_part_id = body.id
		attached_rope = body.parent
		body.apply_central_impulse(-(last_pos-position)*20)
		attached_rope_rope_to_left = attached_rope.rope_to_left
