-- Install aggregate-only instrumentation after all modules exist. No saved data.
local _,ns=...
local P=ns.WardenPerformance
for _,spec in ipairs({
    {ns,'ChatFilter','chat processing'},{ns,'ScanExtraText','name discovery'},
    {ns.NameDisplays,'Scan','name labels'},{ns.Chronicle,'ObserveUnit','player observation'},
    {ns.ChronicleStore,'Observe','profile update'},{ns.ChronicleCapture,'Pump','capture pump'},
    {ns.ChronicleCapture,'Store','native snapshot'},{ns.ChronicleEvidence,'Pump','evidence pump'},
    {ns.ChronicleCombat,'Pump','combat aggregates'},
    {ns.AthenaCombatEvidence,'Pump','combat aura work'},{ns.AthenaCastCounts,'Pump','cast counts'},
    {ns.AetherCertificates,'AdoptIssued','Aether certificate adoption'},
    {ns.AetherCertificates,'UpgradePending','Aether proof upgrades'},
    {ns.AetherCertificates and ns.AetherCertificates.Enrollment,'Pump','Aether enrollment'},
    {ns.ChronicleRoute,'Sample','route sample'},{ns.ChronicleCodec,'Encode','route encode'},
    {ns.OlympusConnection,'Refresh','Olympus connection'},{ns.OlympusPanel,'Ensure','Olympus surface'},
    {ns.Spelling,'Analyze','spelling analysis'},{ns.Spelling,'Suggest','spelling suggestions'},
    {ns.ChronicleActivities,'Pump','activity index'},{ns.WardenDossier,'Pump','dossier work'},
    {ns.Workspace,'Queue','workspace refresh queue'},
}) do P.Wrap(spec[1],spec[2],spec[3]) end
