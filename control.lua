local HelperFunctions = {}

local action_queue = {}

function add_queue_list(entity, action)

  local index = index_of_in_queue_list(entity)
  if index >= 0 then return end

  table.insert(action_queue, {entity = entity, action = action})
end

function remove_queue_list(entity)
  local index = index_of_in_queue_list(entity)
  if index >= 0 then
    table.remove(action_queue, index)
  end

end

function contains_queue_list(entity)
  return index_of_in_queue_list(entity) >= 0
end

function index_of_in_queue_list(entity)
  if not entity or not entity.valid then return -1 end

  for index, keyValue in pairs(action_queue) do
      if keyValue.entity and keyValue.entity.valid then
        if are_positions_equal(keyValue.entity.position, entity.position) then
          return index
        end
      end
  end

  return -1
end

function are_positions_equal(pos1, pos2)
  return pos1.x == pos2.x and pos1.y == pos2.y
end

function enqueue_action(entity, action)
  if contains_queue_list(entity) then return end

  add_queue_list(entity, action)

end

function dequeue_action_as_table(max_entries)

  if not action_queue then return {} end

  local listOfActions = {}

  for index, keyValue in pairs(action_queue) do

    local entity = keyValue.entity
    local action = keyValue.action

    if entity and entity.valid then
      table.insert(listOfActions, {entity = entity, action = action})

       max_entries = max_entries - 1

      if(max_entries <= 0) then
        break

      end
    end
  end

  return listOfActions
end

function get_distance(pos1, pos2)
  local dx = pos2.x - pos1.x
  local dy = pos2.y - pos1.y
  return math.sqrt(dx * dx + dy * dy)
end

function try_build_ghost(player, info)
  local inv = player.get_main_inventory()
  
  for _, ghost_entity in pairs(info.ghost_entities) do

    local skipDistanceCheck = player.character == nil
    -- if no character just ignore range check
    if(skipDistanceCheck or get_distance(player.position, ghost_entity.position) < info.ghost_search_range) then

      enqueue_action(ghost_entity, function()
        if ghost_entity.valid then

          local items = ghost_entity.ghost_prototype.items_to_place_this or {}

          for _,wanted_stack in pairs(items) do

            local stack = inv.find_item_stack(wanted_stack.name)
            if stack then
              if stack.count >= wanted_stack.count then
                local collide, entity, request_proxy = ghost_entity.revive{raise_revive=true, return_item_request_proxy=true}
                if entity then
                  if stack.health ~= nil and stack.health < 1 and entity.health ~= nil and entity.max_health ~= nil then
                    entity.health = stack.health * entity.max_health
                  end
                end

                if not ghost_entity.valid then -- entity is null if tile placed. So we check if ghost just got removed.
                  player.remove_item(wanted_stack)
                end
                return
              end
            end

          end

        end
      end)

    end

  end
end

function try_to_autodeconstruct(player, deconstructs)

    if deconstructs ~= nil then
        for _, entity in pairs(deconstructs) do
            if entity and entity.valid then
                if entity.to_be_deconstructed() then
                  
                  if entity.type == "deconstructible-tile-proxy" then
                    enqueue_action(entity, function() try_mine_tile_if_space(player, entity) end)
                  elseif (entity.prototype.mineable_properties and entity.prototype.mineable_properties.minable == true)  then
                    enqueue_action(entity, function() try_mine_entity_if_space(player, entity) end)
                  else
                    if entity.type == "cliff" then
                      enqueue_action(entity, function() try_remove_and_destruct_entity(player, entity) end)
                    end
                  end
              end
            end
        end
    end

end

function try_mine_tile_if_space(player, entity)

  -- maybe we canceled to to_be_deconstruct
  if not entity.to_be_deconstructed() then return false end

  local tileEntity = entity.surface.get_tile(entity.position.x, entity.position.y)
  if not HelperFunctions.can_insert(player, tileEntity) then return false end

  return player.mine_tile(tileEntity);
end

function try_mine_entity_if_space(player, entity)

  if not HelperFunctions.is_same_force_or_neutral(player, entity, true) then
    return false
  end

  -- maybe we canceled to to_be_deconstruct
  if not entity.to_be_deconstructed() then return false end
  if not HelperFunctions.can_insert(player, entity) then return false end

  return player.mine_entity(entity);
end

function try_remove_and_destruct_entity(player, entity)

    if(not entity.to_be_deconstructed()) then return false end

    local inv = player.get_main_inventory()
    local explosive_item = "cliff-explosives"

    if inv then
      if inv.get_item_count(explosive_item) > 0 then
          inv.remove({name = explosive_item, count = 1})

          entity.destroy({do_cliff_correction = true, raise_destroy = true})

          return true
      end
    end

    return false
end


function update_player(player)
    tick_autobuild(player)
    tick_action_queue(player)
end

function tick_action_queue(player)

  if not player.is_shortcut_toggled("toggle-player-auto-build") then
    return
  end

  if not action_queue then return end

  local listOfActions = dequeue_action_as_table(10)

  for index, keyValue in ipairs(listOfActions) do
    if keyValue and keyValue.entity and keyValue.entity.valid and keyValue.action then
      remove_queue_list(keyValue.entity)
      keyValue.action()
    end
  end

end

function tick_autobuild(player)
  if not player.is_shortcut_toggled("toggle-player-auto-build") then
    return
  end
  
  -- this means we are maybe in remote view. So no access to inventory for know.
  local inv = player.get_main_inventory()

  if not inv then
    return
  end

  -- local position = (player.character and player.position) or nil
  -- local radius = (player.character and (player.character.build_distance + 30)) or nil

  local position = player.position
  local radius = (player.character and (player.character.build_distance + 30)) or 50

  local info = storage.player_info[player.index]

  if not info then
    info = {
      character_position = position,
      ghost_search_range = radius,
      search_timer = 0,
      ghost_entities = {},
    }

    -- storage.player_info[player.index] = info
  end

  info.character_position = position
  info.ghost_search_range = radius

  info.search_timer = info.search_timer - 1

  if info.search_timer <= 0 then
    info.search_timer = 4

    local ghosts = player.surface.find_entities_filtered(
    {
      position = info.character_position,
      radius = info.ghost_search_range,
      force=player.force,
      type={"entity-ghost", "tile-ghost"},
      limit = 50
    })


    
    info.ghost_entities=ghosts

    local deconstructibles = player.surface.find_entities_filtered(
    {
      position = info.character_position,
      radius = info.ghost_search_range,
      force={player.force, "neutral"},
      to_be_deconstructed = true,
      limit = 30
    })

    try_build_ghost(player, info)
    try_to_autodeconstruct(player, deconstructibles)
  end
end


function toggle_auto_build(player_index)
  local player = game.players[player_index]
  local state = not player.is_shortcut_toggled("toggle-player-auto-build")
  player.set_shortcut_toggled("toggle-player-auto-build", state)
end

script.on_init(function()
  storage = storage or {}
  storage.player_info = storage.player_info or {}
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  storage.player_info[event.player_index] = nil
end)

script.on_event(defines.events.on_game_created_from_scenario , function(event)

  for index, _ in pairs(storage.player_info) do
      if storage.player_info[index] and storage.player_info[index].info then
        storage.player_info[index].info.deconstructs = {}
      end
  end

end)


script.on_event(defines.events.on_tick, function(event)
  for _,player in pairs(game.players) do
    if player.connected and ((game.tick + player.index) % 4) == 0 then
      update_player(player)
    end
  end
end)

script.on_event("toggle-player-auto-build", function(event)
  toggle_auto_build(event.player_index)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "toggle-player-auto-build" then
    toggle_auto_build(event.player_index)
  end
end)

-- script.on_event(defines.events.on_marked_for_deconstruction, function(event)
--   local player = game.get_player(event.player_index)
--   print("on_marked_for_deconstruction: ")
--   print(serpent.block(event))
-- end)

-- Table helper



-- functions, later move it to own script


function HelperFunctions.can_insert(player, entity)

  
  if entity.prototype and entity.prototype.mineable_properties and entity.prototype.mineable_properties.minable then
    if entity.prototype.mineable_properties.products then
      for _, product in pairs(entity.prototype.mineable_properties.products) do
        if product.type == "item" and (product.amount or product.amount_max)  then
          local count = math.floor(product.amount or product.amount_max)
          if count >= 1 then
            if not player.can_insert { name = product.name, count = count } then
              return false
            end
          end
        end
      end
    end
    return true
  end
  return false
  
end


function HelperFunctions.is_same_force_or_neutral(player, entity, check_also_neutral)

  check_also_neutral = check_also_neutral or false

  if not (player.force and entity.force) then
    return false
  end

  if check_also_neutral and entity.force.name == "neutral" then
    return true
  end

  return player.force.name == entity.force.name
end