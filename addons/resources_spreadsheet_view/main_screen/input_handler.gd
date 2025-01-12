@tool
extends Node

const EditorView = preload("res://addons/resources_spreadsheet_view/editor_view.gd")
const SelectionManager = preload("res://addons/resources_spreadsheet_view/main_screen/selection_manager.gd")

@onready var editor_view : EditorView = get_parent()
@onready var selection : SelectionManager = get_node("../SelectionManager")


func _on_cell_gui_input(event : InputEvent, cell : Control):
	if event is InputEventMouseButton:
		editor_view.grab_focus()
		if event.button_index != MOUSE_BUTTON_LEFT:
			if event.button_index == MOUSE_BUTTON_RIGHT && event.is_pressed():
				if !cell in selection.edited_cells:
					selection.deselect_all_cells()
					selection.select_cell(cell)

				selection.rightclick_cells()

			return

		if event.pressed:
			if Input.is_key_pressed(KEY_CTRL):
				if cell in selection.edited_cells:
					selection.deselect_cell(cell)

				else:
					selection.select_cell(cell)

			elif Input.is_key_pressed(KEY_SHIFT):
				selection.select_cells_to(cell)

			else:
				selection.deselect_all_cells()
				selection.select_cell(cell)


func _gui_input(event : InputEvent):
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			if event.button_index == MOUSE_BUTTON_RIGHT && event.is_pressed():
				editor_view.cells_context.emit(selection.edited_cells)

			return

		editor_view.grab_focus()
		if !event.pressed:
			selection.deselect_all_cells()


func _input(event : InputEvent):
	if !event is InputEventKey or !event.pressed:
		return
	
	if !editor_view.has_focus() or selection.edited_cells.size() == 0:
		return

	if event.keycode == KEY_CTRL or event.keycode == KEY_SHIFT:
		# Modifier keys do not get processed.
		return
	
	# Ctrl + Z (before, and instead of, committing the action!)
	if Input.is_key_pressed(KEY_CTRL):
		if event.keycode == KEY_Z:
			if Input.is_key_pressed(KEY_SHIFT):
				editor_view.editor_plugin.undo_redo.redo()
			# Ctrl + z (smol)
			else:
				editor_view.editor_plugin.undo_redo.undo()
			
			return

		# This shortcut is used by Godot as well.
		if event.keycode == KEY_Y:
			editor_view.editor_plugin.undo_redo.redo()
			return

	_key_specific_action(event)
	editor_view.grab_focus()
	editor_view.editor_interface.get_resource_filesystem().scan()


func _key_specific_action(event : InputEvent):
	var column = selection.get_cell_column(selection.edited_cells[0])
	var ctrl_pressed := Input.is_key_pressed(KEY_CTRL)

	# BETWEEN-CELL NAVIGATION
	if event.keycode == KEY_UP:
		_move_selection_on_grid(0, (-1 if !ctrl_pressed else -10))

	elif event.keycode == KEY_DOWN:
		_move_selection_on_grid(0, (1 if !ctrl_pressed else 10))

	elif Input.is_key_pressed(KEY_SHIFT) and event.keycode == KEY_TAB:
		_move_selection_on_grid((-1 if !ctrl_pressed else -10), 0)
	
	elif event.keycode == KEY_TAB:
		_move_selection_on_grid((1 if !ctrl_pressed else 10), 0)

	# Non-text and paths can't be edited.
	if editor_view.columns[column] == "resource_path":
		return
	
	if !selection.column_editors[column].is_text():
		return
	
	# CURSOR MOVEMENT
	if event.keycode == KEY_LEFT:
		TextEditingUtils.multi_move_left(
			selection.edited_cells_text, selection.edit_cursor_positions, ctrl_pressed
		)
	
	elif event.keycode == KEY_RIGHT:
		TextEditingUtils.multi_move_right(
			selection.edited_cells_text, selection.edit_cursor_positions, ctrl_pressed
		)
	
	elif event.keycode == KEY_HOME:
		for i in selection.edit_cursor_positions.size():
			selection.edit_cursor_positions[i] = 0

	elif event.keycode == KEY_END:
		for i in selection.edit_cursor_positions.size():
			selection.edit_cursor_positions[i] = selection.edited_cells_text[i].length()
	
	# Ctrl + C (so you can edit in a proper text editor instead of this wacky nonsense)
	elif ctrl_pressed and event.keycode == KEY_C:
		TextEditingUtils.multi_copy(selection.edited_cells_text)
		get_tree().set_input_as_handled()
			
	# The following actions do not work on non-editable cells.
	if !selection.column_editors[column].is_text() or editor_view.columns[column] == "resource_path":
		return
	
	# Ctrl + V
	elif ctrl_pressed and event.keycode == KEY_V:
		editor_view.set_edited_cells_values(TextEditingUtils.multi_paste(
			selection.edited_cells_text, selection.edit_cursor_positions
		))
		get_tree().set_input_as_handled()

	# ERASING
	elif event.keycode == KEY_BACKSPACE:
		editor_view.set_edited_cells_values(TextEditingUtils.multi_erase_left(
			selection.edited_cells_text, selection.edit_cursor_positions, ctrl_pressed
		))

	elif event.keycode == KEY_DELETE:
		editor_view.set_edited_cells_values(TextEditingUtils.multi_erase_right(
			selection.edited_cells_text, selection.edit_cursor_positions, ctrl_pressed
		))
		get_viewport().set_input_as_handled()

	# And finally, text typing.
	elif event.keycode == KEY_ENTER:
		editor_view.set_edited_cells_values(TextEditingUtils.multi_input(
			"\n", selection.edited_cells_text, selection.edit_cursor_positions
		))

	elif event.unicode != 0 and event.unicode != 127:
		editor_view.set_edited_cells_values(TextEditingUtils.multi_input(
			char(event.unicode), selection.edited_cells_text, selection.edit_cursor_positions
		))


func _move_selection_on_grid(move_h : int, move_v : int):
	var cell = selection.edited_cells[0]
	editor_view.grab_focus()
	selection.deselect_all_cells()
	selection.select_cell(
		editor_view.node_table_root.get_child(
			cell.get_index()
			+ move_h + move_v * editor_view.columns.size()
		)
	)
