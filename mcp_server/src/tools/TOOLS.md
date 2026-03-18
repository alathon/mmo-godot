# MCP Tools Inventory

Complete list of tools to implement as typed MCP tools, derived from the Godot MCP Pro addon.
Each tool wraps one Godot MCP command with proper Zod schemas and formatted output.

Status legend: done, todo

---

## Script Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_read_script` | `read_script` | done |
| `godot_list_scripts` | `list_scripts` | done |
| `godot_create_script` | `create_script` | done |
| `godot_edit_script` | `edit_script` | done |
| `godot_attach_script` | `attach_script` | done |
| `godot_get_open_scripts` | `get_open_scripts` | done |
| `godot_validate_script` | `validate_script` | done |

## Scene Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_scene_tree` | `get_scene_tree` | done |
| `godot_get_scene_file_content` | `get_scene_file_content` | done |
| `godot_create_scene` | `create_scene` | done |
| `godot_open_scene` | `open_scene` | done |
| `godot_delete_scene` | `delete_scene` | done |
| `godot_add_scene_instance` | `add_scene_instance` | done |
| `godot_play_scene` | `play_scene` | done |
| `godot_stop_scene` | `stop_scene` | done |
| `godot_save_scene` | `save_scene` | done |
| `godot_get_scene_exports` | `get_scene_exports` | done |

## Node Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_add_node` | `add_node` | done |
| `godot_delete_node` | `delete_node` | done |
| `godot_duplicate_node` | `duplicate_node` | done |
| `godot_move_node` | `move_node` | done |
| `godot_update_property` | `update_property` | done |
| `godot_get_node_properties` | `get_node_properties` | done |
| `godot_add_resource` | `add_resource` | done |
| `godot_set_anchor_preset` | `set_anchor_preset` | done |
| `godot_rename_node` | `rename_node` | done |
| `godot_connect_signal` | `connect_signal` | done |
| `godot_disconnect_signal` | `disconnect_signal` | done |
| `godot_get_node_groups` | `get_node_groups` | done |
| `godot_set_node_groups` | `set_node_groups` | done |
| `godot_find_nodes_in_group` | `find_nodes_in_group` | done |

## Project Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_project_info` | `get_project_info` | done |
| `godot_get_filesystem_tree` | `get_filesystem_tree` | done |
| `godot_search_files` | `search_files` | done |
| `godot_search_in_files` | `search_in_files` | done |
| `godot_get_project_settings` | `get_project_settings` | done |
| `godot_set_project_setting` | `set_project_setting` | done |
| `godot_uid_to_project_path` | `uid_to_project_path` | done |
| `godot_project_path_to_uid` | `project_path_to_uid` | done |
| `godot_add_autoload` | `add_autoload` | done |
| `godot_remove_autoload` | `remove_autoload` | done |

## Editor Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_editor_errors` | `get_editor_errors` | done |
| `godot_get_output_log` | `get_output_log` | done |
| `godot_get_editor_screenshot` | `get_editor_screenshot` | done |
| `godot_get_game_screenshot` | `get_game_screenshot` | done |
| `godot_execute_editor_script` | `execute_editor_script` | done |
| `godot_clear_output` | `clear_output` | done |
| `godot_reload_plugin` | `reload_plugin` | done |
| `godot_reload_project` | `reload_project` | done |
| `godot_get_signals` | `get_signals` | done |
| `godot_compare_screenshots` | `compare_screenshots` | done |

## Resource Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_read_resource` | `read_resource` | done |
| `godot_edit_resource` | `edit_resource` | done |
| `godot_create_resource` | `create_resource` | done |
| `godot_get_resource_preview` | `get_resource_preview` | done |

## Input Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_simulate_key` | `simulate_key` | done |
| `godot_simulate_mouse_click` | `simulate_mouse_click` | done |
| `godot_simulate_mouse_move` | `simulate_mouse_move` | done |
| `godot_simulate_action` | `simulate_action` | done |
| `godot_simulate_sequence` | `simulate_sequence` | done |

## Runtime Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_game_scene_tree` | `get_game_scene_tree` | done |
| `godot_get_game_node_properties` | `get_game_node_properties` | done |
| `godot_set_game_node_property` | `set_game_node_property` | done |
| `godot_capture_frames` | `capture_frames` | done |
| `godot_record_frames` | `record_frames` | done |
| `godot_monitor_properties` | `monitor_properties` | done |
| `godot_execute_game_script` | `execute_game_script` | done |
| `godot_start_recording` | `start_recording` | done |
| `godot_stop_recording` | `stop_recording` | done |
| `godot_replay_recording` | `replay_recording` | done |
| `godot_find_nodes_by_script` | `find_nodes_by_script` | done |
| `godot_get_autoload` | `get_autoload` | done |
| `godot_batch_get_properties` | `batch_get_properties` | done |
| `godot_find_ui_elements` | `find_ui_elements` | done |
| `godot_click_button_by_text` | `click_button_by_text` | done |
| `godot_wait_for_node` | `wait_for_node` | done |
| `godot_find_nearby_nodes` | `find_nearby_nodes` | done |
| `godot_navigate_to` | `navigate_to` | done |
| `godot_move_to` | `move_to` | done |

## Animation Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_list_animations` | `list_animations` | done |
| `godot_create_animation` | `create_animation` | done |
| `godot_add_animation_track` | `add_animation_track` | done |
| `godot_set_animation_keyframe` | `set_animation_keyframe` | done |
| `godot_get_animation_info` | `get_animation_info` | done |
| `godot_remove_animation` | `remove_animation` | done |

## Animation Tree Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_create_animation_tree` | `create_animation_tree` | done |
| `godot_get_animation_tree_structure` | `get_animation_tree_structure` | done |
| `godot_add_state_machine_state` | `add_state_machine_state` | done |
| `godot_remove_state_machine_state` | `remove_state_machine_state` | done |
| `godot_add_state_machine_transition` | `add_state_machine_transition` | done |
| `godot_remove_state_machine_transition` | `remove_state_machine_transition` | done |
| `godot_set_blend_tree_node` | `set_blend_tree_node` | done |
| `godot_set_tree_parameter` | `set_tree_parameter` | done |

## TileMap Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_tilemap_set_cell` | `tilemap_set_cell` | done |
| `godot_tilemap_fill_rect` | `tilemap_fill_rect` | done |
| `godot_tilemap_get_cell` | `tilemap_get_cell` | done |
| `godot_tilemap_clear` | `tilemap_clear` | done |
| `godot_tilemap_get_info` | `tilemap_get_info` | done |
| `godot_tilemap_get_used_cells` | `tilemap_get_used_cells` | done |

## Theme Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_create_theme` | `create_theme` | done |
| `godot_set_theme_color` | `set_theme_color` | done |
| `godot_set_theme_constant` | `set_theme_constant` | done |
| `godot_set_theme_font_size` | `set_theme_font_size` | done |
| `godot_set_theme_stylebox` | `set_theme_stylebox` | done |
| `godot_get_theme_info` | `get_theme_info` | done |

## Physics Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_setup_collision` | `setup_collision` | done |
| `godot_set_physics_layers` | `set_physics_layers` | done |
| `godot_get_physics_layers` | `get_physics_layers` | done |
| `godot_add_raycast` | `add_raycast` | done |
| `godot_setup_physics_body` | `setup_physics_body` | done |
| `godot_get_collision_info` | `get_collision_info` | done |

## Shader Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_create_shader` | `create_shader` | done |
| `godot_read_shader` | `read_shader` | done |
| `godot_edit_shader` | `edit_shader` | done |
| `godot_assign_shader_material` | `assign_shader_material` | done |
| `godot_set_shader_param` | `set_shader_param` | done |
| `godot_get_shader_params` | `get_shader_params` | done |

## Audio Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_audio_bus_layout` | `get_audio_bus_layout` | done |
| `godot_add_audio_bus` | `add_audio_bus` | done |
| `godot_set_audio_bus` | `set_audio_bus` | done |
| `godot_add_audio_bus_effect` | `add_audio_bus_effect` | done |
| `godot_add_audio_player` | `add_audio_player` | done |
| `godot_get_audio_info` | `get_audio_info` | done |

## Navigation Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_setup_navigation_region` | `setup_navigation_region` | done |
| `godot_bake_navigation_mesh` | `bake_navigation_mesh` | done |
| `godot_setup_navigation_agent` | `setup_navigation_agent` | done |
| `godot_set_navigation_layers` | `set_navigation_layers` | done |
| `godot_get_navigation_info` | `get_navigation_info` | done |

## Particle Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_create_particles` | `create_particles` | done |
| `godot_set_particle_material` | `set_particle_material` | done |
| `godot_set_particle_color_gradient` | `set_particle_color_gradient` | done |
| `godot_apply_particle_preset` | `apply_particle_preset` | done |
| `godot_get_particle_info` | `get_particle_info` | done |

## Profiling Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_performance_monitors` | `get_performance_monitors` | done |
| `godot_get_editor_performance` | `get_editor_performance` | done |

## Batch/Analysis Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_find_nodes_by_type` | `find_nodes_by_type` | done |
| `godot_find_signal_connections` | `find_signal_connections` | done |
| `godot_batch_set_property` | `batch_set_property` | done |
| `godot_find_node_references` | `find_node_references` | done |
| `godot_get_scene_dependencies` | `get_scene_dependencies` | done |
| `godot_cross_scene_set_property` | `cross_scene_set_property` | done |

## Analysis Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_find_unused_resources` | `find_unused_resources` | done |
| `godot_analyze_signal_flow` | `analyze_signal_flow` | done |
| `godot_analyze_scene_complexity` | `analyze_scene_complexity` | done |
| `godot_find_script_references` | `find_script_references` | done |
| `godot_detect_circular_dependencies` | `detect_circular_dependencies` | done |
| `godot_get_project_statistics` | `get_project_statistics` | done |

## Export Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_list_export_presets` | `list_export_presets` | done |
| `godot_export_project` | `export_project` | done |
| `godot_get_export_info` | `get_export_info` | done |

## Input Map Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_get_input_actions` | `get_input_actions` | done |
| `godot_set_input_action` | `set_input_action` | done |

## Scene 3D Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_add_mesh_instance` | `add_mesh_instance` | done |
| `godot_setup_lighting` | `setup_lighting` | done |
| `godot_set_material_3d` | `set_material_3d` | done |
| `godot_setup_environment` | `setup_environment` | done |
| `godot_setup_camera_3d` | `setup_camera_3d` | done |
| `godot_add_gridmap` | `add_gridmap` | done |

## Test Commands
| Tool | Godot Command | Status |
|------|--------------|--------|
| `godot_run_test_scenario` | `run_test_scenario` | done |
| `godot_assert_node_state` | `assert_node_state` | done |
| `godot_assert_screen_text` | `assert_screen_text` | done |
| `godot_run_stress_test` | `run_stress_test` | done |
| `godot_get_test_report` | `get_test_report` | done |

---

**Total: 163 tools (163 done, 0 todo)**
