extends Node

const TICK_INTERVAL := 1.0
const CARD_POPUP_INTERVAL := 10

const DEBUGFLAG := false

const RESOURCE_FOOD := "food"
const RESOURCE_TOOLS := "tools"
const RESOURCE_MONEY := "money"

const BUILDING_FARM := "farm"
const BUILDING_FACTORY := "factory"
const BUILDING_CITY := "city"
const BUILDING_BANK := "bank"

const FARM_FOOD_OUTPUT := 5
const FARM_TOOLS_INPUT := 0

const FACTORY_FOOD_INPUT := 3
const FACTORY_TOOLS_OUTPUT := 2

const CITY_FOOD_INPUT := 4
const CITY_TOOLS_INPUT := 3
const CITY_MONEY_OUTPUT := 1

const EFFICIENCY_LOSS_PER_TICK := 0.1
const EFFICIENCY_RECOVERY_PER_TICK := 0.05

const BANK_GOAL := 1000
const HIGHSCORE_PATH := "user://highscores.json"
const MAX_HIGHSCORES := 10
