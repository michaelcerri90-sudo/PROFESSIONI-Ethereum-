// Raid Ethereum - classi, specializzazioni e buff di WoW: Forever.
// Fonti: Warcraft Tavern (27 spec), Conquest Capped e Timesaver (buff di raid, novembre 2026).
// DA VERIFICARE IN GIOCO: alcuni siti si contraddicono (raggio di Battle Shout, Greater Blessing).
// Per correggere un buff basta cambiare questo file.
window.RAID = (function () {
  const ICO = n => `https://wow.zamimg.com/images/wow/icons/medium/${n}.jpg`;

  const CLASSI = {
    DRUID:   { nome: "Druid",   colore: "#ff7c0a", icona: "classicon_druid" },
    HUNTER:  { nome: "Hunter",  colore: "#aad372", icona: "classicon_hunter" },
    MAGE:    { nome: "Mage",    colore: "#3fc7eb", icona: "classicon_mage" },
    PALADIN: { nome: "Paladin", colore: "#f48cba", icona: "classicon_paladin" },
    PRIEST:  { nome: "Priest",  colore: "#ffffff", icona: "classicon_priest" },
    ROGUE:   { nome: "Rogue",   colore: "#fff468", icona: "classicon_rogue" },
    SHAMAN:  { nome: "Shaman",  colore: "#0070dd", icona: "classicon_shaman" },
    WARLOCK: { nome: "Warlock", colore: "#8788ee", icona: "classicon_warlock" },
    WARRIOR: { nome: "Warrior", colore: "#c69b6d", icona: "classicon_warrior" },
  };

  // ruolo: T tank, H healer, M melee, R ranged. Le spec che fanno due ruoli sono divise in due voci.
  const SPEC = [
    ["DRUID", "balance", "Balance", "R", "spell_nature_starfall"],
    ["DRUID", "feral-tank", "Feral (tank)", "T", "ability_racial_bearform"],
    ["DRUID", "feral-dps", "Feral (DPS)", "M", "ability_druid_catform"],
    ["DRUID", "resto", "Restoration", "H", "spell_nature_healingtouch"],
    ["HUNTER", "bm", "Beast Mastery", "R", "ability_hunter_beasttaming"],
    ["HUNTER", "mm", "Marksmanship", "R", "ability_marksmanship"],
    ["HUNTER", "sv-melee", "Survival (melee)", "M", "ability_hunter_swiftstrike"],
    ["HUNTER", "sv-ranged", "Survival (ranged)", "R", "ability_hunter_swiftstrike"],
    ["MAGE", "arcane", "Arcane", "R", "spell_holy_magicalsentry"],
    ["MAGE", "fire", "Fire", "R", "spell_fire_firebolt02"],
    ["MAGE", "frost", "Frost", "R", "spell_frost_frostbolt02"],
    ["PALADIN", "holy", "Holy", "H", "spell_holy_holybolt"],
    ["PALADIN", "prot", "Protection", "T", "spell_holy_devotionaura"],
    ["PALADIN", "ret", "Retribution", "M", "spell_holy_auraoflight"],
    ["PRIEST", "disc", "Discipline", "H", "spell_holy_wordfortitude"],
    ["PRIEST", "holy", "Holy", "H", "spell_holy_holybolt"],
    ["PRIEST", "shadow", "Shadow", "R", "spell_shadow_shadowwordpain"],
    ["ROGUE", "assa", "Assassination", "M", "ability_rogue_eviscerate"],
    ["ROGUE", "combat", "Combat", "M", "ability_backstab"],
    ["ROGUE", "sub", "Subtlety", "M", "ability_stealth"],
    ["SHAMAN", "ele", "Elemental", "R", "spell_nature_lightning"],
    ["SHAMAN", "enh-dps", "Enhancement (DPS)", "M", "spell_nature_lightningshield"],
    ["SHAMAN", "enh-tank", "Enhancement (tank)", "T", "spell_nature_lightningshield"],
    ["SHAMAN", "resto", "Restoration", "H", "spell_nature_magicimmunity"],
    ["WARLOCK", "affli", "Affliction", "R", "spell_shadow_deathcoil"],
    ["WARLOCK", "demo", "Demonology", "R", "spell_shadow_metamorphosis"],
    ["WARLOCK", "destro", "Destruction", "R", "spell_shadow_rainoffire"],
    ["WARRIOR", "arms", "Arms", "M", "ability_warrior_savageblow"],
    ["WARRIOR", "fury", "Fury", "M", "ability_warrior_innerrage"],
    ["WARRIOR", "prot", "Protection", "T", "ability_warrior_defensivestance"],
  ].map(([classe, id, nome, ruolo, icona]) => ({ chiave: classe + ":" + id, classe, id, nome, ruolo, icona }));

  // tipo: raid = tutto il raid; gruppo = solo il gruppo di 5; debuff = sul boss; utile = utilita'.
  // da: chi lo porta. "CLASSE" = ogni spec della classe, "CLASSE:spec" = solo quella spec.
  const BUFF = [
    { id: "bs", nome: "Battle Shout", icona: "ability_warrior_battleshout", tipo: "raid", da: ["WARRIOR"] },
    { id: "gotw", nome: "Gift of the Wild", icona: "spell_nature_giftofthewild", tipo: "raid", da: ["DRUID"] },
    { id: "lotp", nome: "Leader of the Pack", icona: "spell_nature_unyeildingstamina", tipo: "raid", da: ["DRUID:feral-tank", "DRUID:feral-dps"], nota: "talento Feral" },
    { id: "moonkin", nome: "Moonkin Aura", icona: "spell_nature_moonglow", tipo: "raid", da: ["DRUID:balance"], nota: "talento Balance" },
    { id: "aotw", nome: "Aspect of the Wild", icona: "spell_nature_protectionformnature", tipo: "raid", da: ["HUNTER"] },
    { id: "trueshot", nome: "Trueshot Aura", icona: "ability_trueshot", tipo: "raid", da: ["HUNTER:mm"], nota: "talento Marksmanship" },
    { id: "ab", nome: "Arcane Brilliance", icona: "spell_holy_magicalsentry", tipo: "raid", da: ["MAGE"] },
    { id: "fort", nome: "Prayer of Fortitude", icona: "spell_holy_prayeroffortitude", tipo: "raid", da: ["PRIEST"] },
    { id: "spirit", nome: "Prayer of Spirit", icona: "spell_holy_prayerofspirit", tipo: "raid", da: ["PRIEST"] },
    { id: "shprot", nome: "Prayer of Shadow Protection", icona: "spell_holy_prayerofshadowprotection", tipo: "raid", da: ["PRIEST"] },
    { id: "soe", nome: "Strength of Earth Totem", icona: "spell_nature_earthbindtotem", tipo: "raid", da: ["SHAMAN"] },
    { id: "goa", nome: "Grace of Air Totem", icona: "spell_nature_invisibilitytotem", tipo: "raid", da: ["SHAMAN"] },
    { id: "wf", nome: "Windfury Totem", icona: "spell_nature_windfury", tipo: "raid", da: ["SHAMAN"] },
    { id: "ftt", nome: "Flametongue Totem", icona: "spell_nature_guardianward", tipo: "raid", da: ["SHAMAN"] },
    { id: "resaura", nome: "Auree di resistenza", icona: "spell_fire_sealoffire", tipo: "raid", da: ["PALADIN"] },
    // solo il gruppo
    { id: "might", nome: "Blessing of Might", icona: "spell_holy_fistofjustice", tipo: "gruppo", da: ["PALADIN"] },
    { id: "wisdom", nome: "Blessing of Wisdom", icona: "spell_holy_sealofwisdom", tipo: "gruppo", da: ["PALADIN"] },
    { id: "kings", nome: "Blessing of Kings", icona: "spell_magic_magearmor", tipo: "gruppo", da: ["PALADIN"] },
    { id: "devo", nome: "Devotion / Concentration Aura", icona: "spell_holy_devotionaura", tipo: "gruppo", da: ["PALADIN"] },
    { id: "manaspring", nome: "Mana Spring Totem", icona: "spell_nature_manaregentotem", tipo: "gruppo", da: ["SHAMAN"] },
    { id: "manatide", nome: "Mana Tide Totem", icona: "spell_frost_summonwaterelemental", tipo: "gruppo", da: ["SHAMAN:resto"], nota: "talento Restoration" },
    { id: "tremor", nome: "Tremor Totem", icona: "spell_nature_tremortotem", tipo: "gruppo", da: ["SHAMAN"] },
    { id: "ve", nome: "Vampiric Embrace", icona: "spell_shadow_unsummonbuilding", tipo: "gruppo", da: ["PRIEST:shadow"], nota: "talento Shadow" },
    { id: "bloodpact", nome: "Blood Pact", icona: "spell_shadow_bloodboil", tipo: "gruppo", da: ["WARLOCK"] },
    // debuff sul boss
    { id: "sunder", nome: "Sunder Armor", icona: "ability_warrior_sunder", tipo: "debuff", da: ["WARRIOR"] },
    { id: "expose", nome: "Expose Armor", icona: "ability_warrior_riposte", tipo: "debuff", da: ["ROGUE"] },
    { id: "ff", nome: "Faerie Fire", icona: "spell_nature_faeriefire", tipo: "debuff", da: ["DRUID"] },
    { id: "coe", nome: "Curse of the Elements", icona: "spell_shadow_chilltouch", tipo: "debuff", da: ["WARLOCK"] },
    { id: "cor", nome: "Curse of Recklessness", icona: "spell_shadow_unholystrength", tipo: "debuff", da: ["WARLOCK"] },
    { id: "hmark", nome: "Hunter's Mark", icona: "ability_hunter_snipershot", tipo: "debuff", da: ["HUNTER"] },
    { id: "judge", nome: "Judgement of Wisdom / Light", icona: "spell_holy_righteousnessaura", tipo: "debuff", da: ["PALADIN"] },
    { id: "demo", nome: "Demoralizing Shout / Roar", icona: "ability_warrior_warcry", tipo: "debuff", da: ["WARRIOR", "DRUID:feral-tank"] },
    { id: "tclap", nome: "Thunder Clap", icona: "spell_nature_thunderclap", tipo: "debuff", da: ["WARRIOR"] },
    // utilita'
    { id: "rebirth", nome: "Rebirth (rez in combattimento)", icona: "spell_nature_reincarnation", tipo: "utile", da: ["DRUID"] },
    { id: "innervate", nome: "Innervate", icona: "spell_nature_lightning", tipo: "utile", da: ["DRUID"] },
    { id: "soulstone", nome: "Soulstone", icona: "spell_shadow_soulgem", tipo: "utile", da: ["WARLOCK"] },
  ];

  const specPer = Object.fromEntries(SPEC.map(s => [s.chiave, s]));
  const buffDi = chiave => {
    const s = specPer[chiave];
    if (!s) return [];
    return BUFF.filter(b => b.da.includes(s.classe) || b.da.includes(chiave));
  };
  const RUOLI = { T: "Tank", H: "Healer", M: "DPS melee", R: "DPS ranged" };
  const TIPI = { raid: "Buff per tutto il raid", gruppo: "Buff per il gruppo", debuff: "Debuff sul boss", utile: "Utilita'" };
  const RAID = [
    { id: "barrow", nome: "Barrow Deeps", taglia: 10 },
    { id: "hyjal", nome: "Hyjal Summit", taglia: 20 },
    { id: "onyxia", nome: "Onyxia's Lair", taglia: 40 },
  ];
  return { ICO, CLASSI, SPEC, specPer, BUFF, buffDi, RUOLI, TIPI, RAID, RELAY: "https://professioniethereum.michael-cerri90.workers.dev" };
})();
