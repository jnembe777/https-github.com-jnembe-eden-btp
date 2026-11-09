// ═══════════════════════════════════════════════════════════════════════
// GRID_REGISTRY Template — SmartGrid Column Configuration
// ERP OHADA · Gamme [JASPE|RUBIS|SAPHIR|ONYX]
// ═══════════════════════════════════════════════════════════════════════
//
// Each entity managed via SmartGrid needs one entry in the GRID object.
// The EntityFormDrawer auto-generates forms from columns marked editable:true.
//
// Column types:
//   text     → <input type="text">         (default)
//   currency → <input type="number">       (formatted with thousand separator + " F")
//   number   → <input type="number">       (formatted with thousand separator)
//   percent  → <input type="number">       (displayed as ×100%, stored as decimal 0.025)
//   date     → <input type="date">         (displayed DD/MM/YYYY)
//   boolean  → <input type="checkbox">     (displayed ✓/✗ icon)
//   badge    → <select> from badgeMap      (displayed as colored pill)
//
// Column properties:
//   id         : string  — field name in data object (required)
//   label      : string  — column header (required)
//   width      : number  — fixed width in px (optional, default 120)
//   flex       : number  — flex-grow (optional, use 1 for extensible columns)
//   align      : string  — "left" | "center" | "right" (optional, default "left")
//   type       : string  — see types above (optional, default "text")
//   sortable   : boolean — enable column sorting (optional)
//   filterable : boolean — enable column filter (optional)
//   groupable  : boolean — enable grouping by this column (optional)
//   editable   : boolean — include in EntityFormDrawer (optional)
//   badgeMap   : object  — { VALUE: { color: "#hex", label: "Display" } } (for badge type)
//   render     : func    — (value, row, theme) => JSX (custom renderer, optional)

const GRID = {
  // ── TEMPLATE ENTITY ──
  entity_name: {
    rowKey: "id",                    // Primary key field
    entityLabel: "Nom Entité",       // Label shown in form drawer title
    columns: [
      // Code / identifier column — usually first, monospace, gold color
      {
        id: "code",
        label: "Code",
        width: 80,
        sortable: true,
        editable: true,
        render: (v, row, t) => (
          <span style={{ fontFamily: "'JetBrains Mono',monospace", fontWeight: 600, color: t.gold }}>
            {v}
          </span>
        ),
      },
      // Label / name — flex column to fill space
      { id: "label", label: "Libellé", flex: 1, sortable: true, filterable: true, editable: true },
      // Badge / enum column
      {
        id: "status",
        label: "Statut",
        width: 90,
        sortable: true,
        groupable: true,
        editable: true,
        type: "badge",
        badgeMap: {
          ACTIVE:   { color: "#10B981", label: "Actif" },
          INACTIVE: { color: "#6B7280", label: "Inactif" },
          ARCHIVED: { color: "#F59E0B", label: "Archivé" },
        },
      },
      // Currency column — right-aligned, monospace
      { id: "amount", label: "Montant", width: 130, align: "right", type: "currency", editable: true },
      // Percent column
      { id: "rate", label: "Taux", width: 80, align: "right", type: "percent", editable: true },
      // Date column
      { id: "created_date", label: "Date création", width: 95, type: "date", editable: true },
      // Boolean column — centered checkmark
      { id: "is_active", label: "Actif", width: 55, align: "center", type: "boolean", editable: true },
    ],
  },
};

export default GRID;
