// ═══════════════════════════════════════════════════════════════════════
// EntityFormDrawer Template — Auto-generated from GRID_REGISTRY
// ERP OHADA · Produces a slide-in form for any SmartGrid entity
// ═══════════════════════════════════════════════════════════════════════
//
// Usage:
//   <EntityFormDrawer
//     config={GRID.employees}        ← grid config with columns
//     editRow={rowOrNull}            ← null = create, object = edit
//     onSave={(record, editRow) => ...}
//     onClose={() => setFormOpen(null)}
//   />
//
// The component reads config.columns.filter(c => c.editable) and generates
// the appropriate input for each column type:
//   text     → <input type="text">
//   currency → <input type="number"> with monospace font
//   number   → <input type="number">
//   percent  → <input type="number" step="0.001"> with ×100% suffix
//   date     → <input type="date"> defaults to today
//   boolean  → <input type="checkbox"> defaults to true
//   badge    → <select> from badgeMap, defaults to first key

import { useState, useEffect } from "react";
import { X, Save } from "lucide-react";

function EntityFormDrawer({ config, onSave, onClose, editRow }) {
  // Theme from context (useTheme hook in real app)
  const t = useTheme();

  // Extract editable columns
  const editableCols = config.columns.filter(c => c.editable);
  const isEdit = !!editRow;

  // Build default values per column type
  const buildDefault = () => {
    const obj = {};
    editableCols.forEach(c => {
      if (editRow) { obj[c.id] = editRow[c.id] ?? ""; return; }
      if (c.type === "boolean")  obj[c.id] = true;
      else if (c.type === "currency" || c.type === "number") obj[c.id] = "";
      else if (c.type === "percent") obj[c.id] = "";
      else if (c.type === "date") obj[c.id] = new Date().toISOString().slice(0, 10);
      else if (c.type === "badge" && c.badgeMap) obj[c.id] = Object.keys(c.badgeMap)[0];
      else obj[c.id] = "";
    });
    return obj;
  };

  const [form, setForm] = useState(buildDefault);
  const [shake, setShake] = useState(false);

  const set = (key, value) => setForm(prev => ({ ...prev, [key]: value }));

  const handleSave = () => {
    // Validate required fields (all non-boolean, non-percent fields)
    const required = editableCols.filter(c => c.type !== "boolean" && c.type !== "percent");
    const missing = required.filter(c => form[c.id] === "" || form[c.id] == null);
    if (missing.length > 0) {
      setShake(true);
      setTimeout(() => setShake(false), 500);
      return;
    }

    // Type coercion
    const record = { ...form };
    editableCols.forEach(c => {
      if (c.type === "currency" || c.type === "number") record[c.id] = Number(record[c.id]) || 0;
      if (c.type === "percent") record[c.id] = record[c.id] !== "" ? Number(record[c.id]) : null;
    });

    onSave(record, isEdit ? editRow : null);
  };

  const inputStyle = {
    width: "100%", padding: "8px 12px", borderRadius: 8,
    border: `1px solid ${t.inputBorder}`, background: t.inputBg,
    color: t.text, fontSize: "0.85rem", outline: "none", boxSizing: "border-box",
  };

  return (
    <div style={{ position: "fixed", inset: 0, zIndex: 1000, display: "flex", justifyContent: "flex-end" }}
         onClick={onClose}>
      {/* Backdrop */}
      <div style={{ position: "absolute", inset: 0, background: t.overlayBg }} />

      {/* Panel */}
      <div onClick={e => e.stopPropagation()}
           style={{
             position: "relative", width: 420, maxWidth: "90vw", height: "100%",
             background: t.panel, borderLeft: `1px solid ${t.border}`,
             display: "flex", flexDirection: "column",
             boxShadow: `-8px 0 30px ${t.shadow}`,
             animation: shake ? "shakeX 0.4s ease" : "slideIn 0.25s ease",
           }}>

        {/* Header */}
        <div style={{ padding: "16px 20px", borderBottom: `1px solid ${t.border}`,
                       display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: "1rem", color: t.text }}>
              {isEdit ? "Modifier" : "Nouveau"} {config.entityLabel || "Élément"}
            </div>
            <div style={{ fontSize: "0.75rem", color: t.textMuted, marginTop: 2 }}>
              {editableCols.length} champs
            </div>
          </div>
          <button onClick={onClose} style={{ padding: 6, borderRadius: 6, border: "none",
                                              background: "transparent", color: t.textMuted, cursor: "pointer" }}>
            <X size={18} />
          </button>
        </div>

        {/* Body — scrollable */}
        <div style={{ flex: 1, overflow: "auto", padding: "16px 20px" }}>
          {editableCols.map(col => (
            <div key={col.id} style={{ marginBottom: 14 }}>
              <label style={{ display: "block", fontSize: "0.78rem", fontWeight: 600, color: t.textMuted,
                              marginBottom: 5, textTransform: "uppercase", letterSpacing: "0.04em" }}>
                {col.label}
              </label>

              {/* Render input per column type */}
              {col.type === "boolean" ? (
                <label style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer" }}>
                  <input type="checkbox" checked={!!form[col.id]}
                         onChange={e => set(col.id, e.target.checked)}
                         style={{ width: 18, height: 18, accentColor: t.green }} />
                  {form[col.id] ? "Oui" : "Non"}
                </label>
              ) : col.type === "badge" && col.badgeMap ? (
                <select value={form[col.id] || ""} onChange={e => set(col.id, e.target.value)}
                        style={{ ...inputStyle, cursor: "pointer" }}>
                  {Object.entries(col.badgeMap).map(([k, v]) =>
                    <option key={k} value={k}>{v.label}</option>
                  )}
                </select>
              ) : col.type === "date" ? (
                <input type="date" value={form[col.id] || ""}
                       onChange={e => set(col.id, e.target.value)} style={inputStyle} />
              ) : col.type === "currency" || col.type === "number" ? (
                <input type="number" value={form[col.id]}
                       onChange={e => set(col.id, e.target.value)} placeholder="0"
                       style={{ ...inputStyle, fontFamily: "'JetBrains Mono',monospace" }} />
              ) : col.type === "percent" ? (
                <div style={{ position: "relative" }}>
                  <input type="number" step="0.001" value={form[col.id]}
                         onChange={e => set(col.id, e.target.value)} placeholder="0.00"
                         style={{ ...inputStyle, fontFamily: "'JetBrains Mono',monospace", paddingRight: 40 }} />
                  <span style={{ position: "absolute", right: 12, top: "50%", transform: "translateY(-50%)",
                                 color: t.textDim, fontSize: "0.8rem" }}>×100%</span>
                </div>
              ) : (
                <input type="text" value={form[col.id] || ""}
                       onChange={e => set(col.id, e.target.value)}
                       placeholder={col.label} style={inputStyle} />
              )}
            </div>
          ))}
        </div>

        {/* Footer */}
        <div style={{ padding: "14px 20px", borderTop: `1px solid ${t.border}`, display: "flex", gap: 10 }}>
          <button onClick={onClose}
                  style={{ flex: 1, padding: "10px 0", borderRadius: 8,
                           border: `1px solid ${t.border}`, background: "transparent",
                           color: t.textMuted, fontWeight: 600, fontSize: "0.85rem", cursor: "pointer" }}>
            Annuler
          </button>
          <button onClick={handleSave}
                  style={{ flex: 2, padding: "10px 0", borderRadius: 8, border: "none",
                           background: t.green, color: "#fff", fontWeight: 700, fontSize: "0.85rem",
                           cursor: "pointer", display: "flex", alignItems: "center",
                           justifyContent: "center", gap: 6 }}>
            <Save size={15} /> {isEdit ? "Enregistrer" : "Créer"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default EntityFormDrawer;
