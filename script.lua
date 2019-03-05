--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
  --[[ print('onLoad!') --]]
  init()
  -- Setup...
  publicDeckURL="https://netrunnerdb.com/api/2.0/public/decklist/"
  privateDeckURL="https://netrunnerdb.com/api/2.0/private/deck/"
  cardURL="https://netrunnerdb.com/api/2.0/public/card/"

  privateDeck = false

  local tileGUID = '928c8e'
  tile = getObjectFromGUID(tileGUID)
  makeText()
  makeButton()
  makeCheckbox()
end

function spawnZone()
  -- Clean up scripting zone
  if pcZone
  then
    pcZone.destruct()
  end
  deckPos = LocalPos(self,{-3.71,1.5,0})
  local pcZonePos = LocalPos(self,{3.62, 2.6 , 0})
  zoneSpawn = {position = pcZonePos
       , scale = { 2.57, 5.1, 3.47 }
       , type = 'ScriptingTrigger'
       , rotation = self.getRotation() }
  pcZone = spawnObject(zoneSpawn)
  for i=1,1 do
       coroutine.yield(0)
   end

   local objectsInZone = pcZone.getObjects()
   for i,v in pairs(objectsInZone) do
     if v.tag == 'Deck' then
       playerCardDeck = v
     end
   end

   -- Get deck from NetrunnerDB
   local deckURL
   if privateDeck then deckURL = privateDeckURL
   else deckURL = publicDeckURL
   end

   WebRequest.get(deckURL .. deckID, self, 'deckReadCallback')

   return 1
end

function init()
  cardList = {}
  doneSlots = 0
  playerCardDeck = {}
  totalCards = 0
end

function buttonClicked()
  -- Reset
  init()
  -- Spawn scripting zone
  startLuaCoroutine(self, "spawnZone")
end

function checkboxClicked()
  buttons = tile.getButtons()
  for k,v in pairs(buttons) do
    if (v.label == "Приватная") then
      local button_parameters = {}
      button_parameters.label = "Публичная"
      button_parameters.index = v.index
      tile.editButton(button_parameters)
      privateDeck = false
    else
      if (v.label == "Публичная") then
        local button_parameters = {}
        button_parameters.label = "Приватная"
        button_parameters.index = v.index
        tile.editButton(button_parameters)
        privateDeck = true
      end
    end
  end
end


function deckReadCallback(req)
  -- Result check..
  if req.is_done and not req.is_error
  then
    if string.find(req.text, "<!DOCTYPE html>")
    then
      broadcastToAll("Приватная колода "..deckID.." не доступна", {0.5,0.5,0.5})
      return
    end
    JsonDeckRes = JSON.decode(req.text)
  else
    print (req.error)
    return
  end
  if (JsonDeckRes == nil)
  then
    broadcastToAll("Колода не найдена!", {0.5,0.5,0.5})
    return
  else
    print("Найдена колода: "..JsonDeckRes.data[1].name)
  end
  -- Count number of cards in decklist
  numSlots=0
  for cardid,number in
  pairs(JsonDeckRes.data[1].cards)
  do
    numSlots = numSlots + 1
  end

  -- Save card id, number in table and request card info from NetrunnerDB
  for cardID,number in pairs(JsonDeckRes.data[1].cards)
  do
    local row = {}
    row.cardName = ""
    row.cardCount = number
    cardList[cardID] = row
    WebRequest.get(cardURL .. cardID, self, 'cardReadCallback')
    totalCards = totalCards + number
  end
end

function cardReadCallback(req)
  -- Result check..
  if req.is_done and not req.is_error
  then
    -- Find unicode before using JSON.decode since it doesnt handle hex UTF-16
    local tmpText = string.gsub(req.text,"\\u(%d%d%d%d)", convertHexToDec)
    JsonCardRes = JSON.decode(tmpText)
  else
    print(req.error)
    return
  end


    cardList[JsonCardRes.data[1].code].cardName = JsonCardRes.data[1].title


  -- Update number of processed slots, if complete, start building the deck
  doneSlots = doneSlots + 1
  if (doneSlots == numSlots)
  then
    createDeck()
  end
end

function createDeck()
  -- Create clone of playerCardDeck to use for drawing cards
  local cloneParams = {}
  cloneParams.position = {0,0,50}
  tmpDeck = playerCardDeck.clone(cloneParams)

  for k,v in pairs(cardList) do
    searchForCard(v.cardName, v.cardCount)
  end

  tmpDeck.destruct()
end

function searchForCard(cardName, cardCount)
  allCards = tmpDeck.getObjects()
  for k,v in pairs(allCards) do
    if (v.nickname == cardName)
    then

        local takeParams = {position={10,0,20}, callback='cardTaken', callback_owner=self, index=v.index, smooth = false, params={cardName,cardCount,v.guid}}
        tmpDeck.takeObject(takeParams)
        print('Добавлено '.. cardCount .. ' ' .. cardName)
        return

    end
  end
  broadcastToAll("Карта не найдена: "..cardName, {0.5,0.5,0.5})
end

function cardTaken(card, params)
  if (card.getName() == params[1]) then
    for i=1,params[2]-1,1 do
      local cloneParams = {}
      cloneParams.position=deckPos
      card.clone(cloneParams)
    end
    card.setPosition(deckPos)
    if (JsonCardRes.data[1].side_code == "corp") then
        card.setScale({1.88,1.0,1.88})
    else
        card.setScale({1.94,1.0,1.94})
    end

  else
    print('Неизвестная карта: ' .. card.getName())
    tmpDeck.putObject(card)
  end
end

function makeText()
  -- Create textbox
  local input_parameters = {}
  input_parameters.input_function = "inputTyped"
  input_parameters.function_owner = self
  input_parameters.position = {0.023,0.2,-0.54}
  input_parameters.width = 1620
  input_parameters.scale = {0.1,0.1,0.1}
  input_parameters.height = 600
  input_parameters.font_size = 500
  input_parameters.tooltip = "Введите ID колоды с NetrunnerDB\nНапример для netrunnerdb.com/en/decklist/50862/one-of-us-will-be-famous ID будет 50862."
  input_parameters.alignment = 3 -- (1 = Automatic, 2 = Left, 3 = Center, 4 = Right, 5 = Justified) –Optional
  input_parameters.value=""
  tile.createInput(input_parameters)
end

function makeButton()
  -- Create Button
  local button_parameters = {}
  button_parameters.click_function = "buttonClicked"
  button_parameters.function_owner = self
  button_parameters.position = {0.07,0.1,-0.01}
  button_parameters.width = 300
  button_parameters.height = 10
  button_parameters.tooltip = "Нажмите для импорта колоды"
  tile.createButton(button_parameters)
end

function makeCheckbox()
  local checkbox_parameters = {}
  checkbox_parameters.click_function = "checkboxClicked"
  checkbox_parameters.function_owner = self
  checkbox_parameters.position = {-0.4,0.2,-0.54}
  checkbox_parameters.width = 1200
  checkbox_parameters.height = 300
  checkbox_parameters.tooltip = "Нажмите, чтобы переключаться между приватными и публичными колодами"
  checkbox_parameters.label = "Публичная"
  checkbox_parameters.font_size = 200
  checkbox_parameters.scale = {0.1,0.1,0.1}
  tile.createButton(checkbox_parameters)
end

-- Function to convert utf-16 hex to actual character since JSON.decode doesn't seem to handle utf-16 hex very well..
function convertHexToDec(a)
  return string.char(tonumber(a,16))
end
--------------
--------------
-- Start of Dzikakulka's positioning script


-- Return position "position" in "object"'s frame of reference
-- (most likely the only function you want to directly access)
function LocalPos(object, position)
    local rot = object.getRotation()
    local lPos = {position[1], position[2], position[3]}

    -- Z-X-Y extrinsic
    local zRot = RotMatrix('z', rot['z'])
    lPos = RotateVector(zRot, lPos)
    local xRot = RotMatrix('x', rot['x'])
    lPos = RotateVector(xRot, lPos)
    local yRot = RotMatrix('y', rot['y'])
    lPos = RotateVector(yRot, lPos)

    return Vect_Sum(lPos, object.getPosition())
end

-- Build rotation matrix
-- 1st table = 1st row, 2nd table = 2nd row etc
function RotMatrix(axis, angDeg)
    local ang = math.rad(angDeg)
    local cs = math.cos
    local sn = math.sin

    if axis == 'x' then
        return {
                    { 1,        0,             0 },
                    { 0,   cs(ang),   -1*sn(ang) },
                    { 0,   sn(ang),      cs(ang) }
               }
    elseif axis == 'y' then
        return {
                    {    cs(ang),   0,   sn(ang) },
                    {          0,   1,         0 },
                    { -1*sn(ang),   0,   cs(ang) }
               }
    elseif axis == 'z' then
        return {
                    { cs(ang),   -1*sn(ang),   0 },
                    { sn(ang),      cs(ang),   0 },
                    { 0,                  0,   1 }
               }
    end
end

-- Apply given rotation matrix on given vector
-- (multiply matrix and column vector)
function RotateVector(rotMat, vect)
    local out = {0, 0, 0}
    for i=1,3,1 do
        for j=1,3,1 do
            out[i] = out[i] + rotMat[i][j]*vect[j]
        end
    end
    return out
end

-- Sum of two vectors (of any size)
function Vect_Sum(vec1, vec2)
    local out = {}
    local k = 1
    while vec1[k] ~= nil and vec2[k] ~= nil do
        out[k] = vec1[k] + vec2[k]
        k = k+1
    end
    return out
end

-- End Dzikakulka's positioning script


function inputTyped(objectInputTyped, playerColorTyped, input_value, selected)
    deckID = input_value
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate ()
    --[[ print('onUpdate loop!') --]]
end
