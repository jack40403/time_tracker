// Shared utilities for screens.

function fmtTime(sec) {
  const h = Math.floor(sec/3600), m = Math.floor((sec%3600)/60), s = sec%60;
  if (h) return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
  return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
}
function fmtHMS(sec) {
  const h = Math.floor(sec/3600), m = Math.floor((sec%3600)/60);
  if (h) return `${h}h ${m}m`;
  return `${m}m`;
}

const SAMPLE_CATS = [
  { name:'閱讀', color:'#FF8FA3', mins: 47 },
  { name:'運動', color:'#6B8E4E', mins: 32 },
  { name:'學日文', color:'#7BB3E0', mins: 28 },
  { name:'寫程式', color:'#C5B7FF', mins: 33 },
];

// ── Generic chrome helpers shared by every screen ───────────────
function ThemedAppBar({ t, title, action }) {
  return (
    <div style={{
      padding:'12px 22px 4px', display:'flex', alignItems:'center', justifyContent:'space-between',
    }}>
      <span style={{
        fontFamily: t.fontDisplay, fontSize: 22, fontWeight: 700, letterSpacing: 1,
        color: t.appBarInk,
      }}>{title}</span>
      {action}
    </div>
  );
}

function ThemedCard({ t, children, style = {}, padding = 16 }) {
  return (
    <div style={{
      background: t.surface,
      borderRadius: t.radius,
      border: t.borderW ? `${t.borderW}px solid ${t.border}` : 'none',
      boxShadow: t.shadow !== 'transparent'
        ? `${Math.min(3,t.shadowOff[0])}px ${Math.min(3,t.shadowOff[1])}px 0 ${t.shadow}`
        : 'none',
      padding,
      ...style,
    }}>{children}</div>
  );
}

// segmented filter (日 週 月 年 自定)
function FilterTabs({ t, options, value, onChange }) {
  return (
    <div style={{
      display:'flex', gap:4, padding:4,
      background: t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.13)' : t.surfaceAlt,
      border: t.id==='cartoon'||t.id==='dark' ? '2px solid rgba(255,255,255,0.25)' : t.borderW ? `1.5px solid ${t.border}` : 'none',
      borderRadius: t.chipRadius>50 ? 999 : 14,
      fontFamily: t.fontBody,
    }}>
      {options.map(o => {
        const on = o.value === value;
        return (
          <button key={o.value} onClick={() => onChange(o.value)} style={{
            flex:1, padding:'7px 0', border:'none', cursor:'pointer',
            background: on ? (t.id==='cartoon' ? t.active : t.accent) : 'transparent',
            color: on ? (t.id==='cartoon'?t.ink:'#fff') : (t.id==='cartoon'||t.id==='dark' ? '#fff' : t.ink),
            fontSize:12, fontWeight: on?700:500, letterSpacing:0.5,
            borderRadius: t.chipRadius>50? 999 : 10,
          }}>{o.label}</button>
        );
      })}
    </div>
  );
}

window.fmtTime = fmtTime;
window.fmtHMS = fmtHMS;
window.SAMPLE_CATS = SAMPLE_CATS;
window.ThemedAppBar = ThemedAppBar;
window.ThemedCard = ThemedCard;
window.FilterTabs = FilterTabs;
