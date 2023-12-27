-- Sample Basic Class Module
local mq             = require('mq')
local RGMercsLogger  = require("rgmercs.utils.rgmercs_logger")
local RGMercUtils    = require("rgmercs.utils.rgmercs_utils")
local shdClassConfig = require("rgmercs.class_configs.shd_class_config")

local Module         = { _version = '0.1a', name = "ShadowKnight", author = 'Derple' }
Module.__index       = Module
Module.Tanking       = false
Module.SpellLoadOut  = {}

local newCombatMode  = false

local function getConfigFileName()
    return mq.configDir ..
        '/rgmercs/PCConfigs/' .. Module.name .. "_" .. RGMercConfig.CurServer .. "_" .. RGMercConfig.CurLoadedChar .. '.lua'
end

function Module:SaveSettings(doBroadcast)
    mq.pickle(getConfigFileName(), self.settings)

    if doBroadcast then
        RGMercUtils.BroadcastUpdate(self.name, "SaveSettings")
    end
end

function Module:LoadSettings()
    RGMercsLogger.log_info("Basic Combat Module Loading Settings for: %s.", RGMercConfig.CurLoadedChar)
    local settings_pickle_path = getConfigFileName()

    local config, err = loadfile(settings_pickle_path)
    if err or not config then
        RGMercsLogger.log_error("\ay[Basic]: Unable to load global settings file(%s), creating a new one!",
            settings_pickle_path)
        self.settings = {}
        self:SaveSettings(true)
    else
        self.settings = config()
    end

    -- Setup Defaults
    self.settings.Mode = self.settings.Mode or 1
    self.settings.DoTorrent = self.settings.DoTorrent or true
    self.settings.DoDiretap = self.settings.DoDiretap or true
    self.settings.DoBandolier = self.settings.DoBandolier or false
    self.settings.DoBurn = self.settings.DoBurn or false
    self.settings.DoSnare = self.settings.DoSnare or true
    self.settings.AeTauntCnt = self.settings.AeTauntCnt or 2
    self.settings.HPStopDOT = self.settings.HPStopDOT or 30
    self.settings.TLP = self.settings.TLP or false

    newCombatMode = true
end

function Module.New()
        -- Only load this module for SKs
    if RGMercConfig.CurLoadedClass ~= "SHD" then return nil end

    RGMercsLogger.log_info("ShadowKnight Combat Module Loaded.")
    local newModule = setmetatable({ settings = {}, CombatState = "None" }, Module)

    newModule:LoadSettings()

    return newModule
end

function Module:setLoadOut(t)
    Module.SpellLoadOut = {}
    for _, s in ipairs(t) do
        local spell = s.name
        if not s.cond then
            RGMercsLogger.log_debug( "\atGem %d will load \am%s", s.gem, s.name)
        else
            RGMercsLogger.log_debug( "\atGem %d will load \am%s\at or \am%s", s.gem, s.name, s.other)
            if s.cond(self) then
                RGMercsLogger.log_debug( "\at   - Selected: \am%s", s.name)
            else
                spell = s.other
                RGMercsLogger.log_debug( "\at   - Selected: \am%s", s.other)
            end
        end

        local bestSpell = RGMercUtils.GetBestSpell(shdClassConfig.AbilitySets[spell])
        
        Module.SpellLoadOut[s.gem] = bestSpell
    end

    RGMercUtils.LoadSpellLoadOut(Module.SpellLoadOut)
end

function Module:setCombatMode(mode)
    RGMercsLogger.log_debug("\aySettings Combat Mode to: \am%s", mode)
    if mode == "Tank" then
        Module.Tanking = true
        if self.settings.TLP then
            self:setLoadOut(shdClassConfig.Rotations.TLP_Tank.Spells)
        else
            self:setLoadOut(shdClassConfig.Rotations.Tank.Spells)
        end
    elseif mode == "DPS" then
        Module.Tanking = false
        if self.settings.TLP then
            self:setLoadOut(shdClassConfig.Rotations.TLP_DPS.Spells)
        else
            self:setLoadOut(shdClassConfig.Rotations.DPS.Spells)
        end 
    end   
end

local function renderSetting(k, v)
    if type(v) == "table" then
        ImGui.Text(k)
        ImGui.Indent()
        for ki, kv in pairs(v) do
            renderSetting(ki, kv)
        end
        ImGui.Unindent()
    else
        ImGui.Text("%s => %s", k, v)
    end
end

function Module:Render()
    ImGui.Text("ShadowKnight Combat Modules")
    local pressed 

    if ImGui.CollapsingHeader("Current Settings") then
        for k, v in pairs(self.settings) do
            renderSetting(k, v)
        end
    end

    local pressed

    ImGui.Text("Mode: ")
    ImGui.SameLine()
    self.settings.Mode, pressed = ImGui.Combo("##_select_ai_mode", self.settings.Mode, shdClassConfig.Modes, #shdClassConfig.Modes)
    newCombatMode = newCombatMode or pressed

    self.settings.TLP, pressed = RGMercUtils.RenderOptionToggle("##_bool_tlp_mode", "TLP Mode", self.settings.TLP)
    newCombatMode = newCombatMode or pressed

    self.settings.DoTorrent, pressed = RGMercUtils.RenderOptionToggle("##_bool_do_torrent", "Use Torrents", self.settings.DoTorrent)
    newCombatMode = newCombatMode or pressed

    self.settings.DoDiretap, pressed = RGMercUtils.RenderOptionToggle("##_bool_do_diretap", "Use Diretap", self.settings.DoDiretap)
    newCombatMode = newCombatMode or pressed

    self.settings.DoBandolier, pressed = RGMercUtils.RenderOptionToggle("##_bool_do_bandolier", "Use Bandolier", self.settings.DoBandolier)
    if pressed then self:SaveSettings(true) end

    self.settings.DoBurn, pressed = RGMercUtils.RenderOptionToggle("##_bool_do_burn", "Burn", self.settings.DoBurn)
    if pressed then self:SaveSettings(true) end

    ImGui.Text("Spell Loadout")
    RGMercUtils.RenderLoadoutTable(Module.SpellLoadOut)

    ImGui.Text(string.format("Combat State: %s", self.CombatState))
end

function Module:GiveTime(combat_state)
    -- Main Module logic goes here.
    if newCombatMode then
        RGMercsLogger.log_debug("New Combat Mode Requested: %s", shdClassConfig.Modes[self.settings.Mode])
        self:setCombatMode(shdClassConfig.Modes[self.settings.Mode])
        self:SaveSettings(true)
        newCombatMode = false
    end

    self.CombatState = combat_state
end

function Module:Shutdown()
    RGMercsLogger.log_info("ShadowKnight Combat Module UnLoaded.")
end

return Module