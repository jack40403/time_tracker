// HomeScreen — renders the Timer page against any theme.
// Mirrors home_page.dart layout: header / category list / timer card / action buttons.

function cardStyle(t) {
  const isGradient = typeof t.surface === 'string' && t.surface.startsWith('linear-');
  return {
    background: t.surface,
    borderRadius: t.radius,
    border: t.borderW ? `${t.borderW}px solid ${t.border}` : 'none',
    boxShadow: t.shadow !== 'transparent'
      ? `${t.shadowOff[0]}px ${t.shadowOff[1]}px 0 ${t.shadow}`
      : 'none',
    ...(isGradient ? {} : {}),
  };
}

function pillBtn(t, { active, bg }) {
  return {
    background: bg || (active ? t.active : t.chipBg),
    color: active ? t.chipInkSel : t.chipInk,
    border: t.borderW ? `${Math.max(2, t.borderW - 0.5)}px solid ${t.border}` : 'none',
    borderRadius: t.chipRadius,
    boxShadow: t.shadow !== 'transparent' && active
      ? `${Math.min(3, t.shadowOff[0])}px ${Math.min(3, t.shadowOff[1])}px 0 ${t.shadow}` : 'none',
  };
}

function fmt(sec) {
  const h = Math.floor(sec/3600), m = Math.floor((sec%3600)/60), s = sec%60;
  if (h) return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
  return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
}

const SAMPLE_CATEGORIES = [
  { name:'閱讀', color:'#FF8FA3' },
  { name:'運動', color:'#6B8E4E' },
  { name:'學日文', color:'#7BB3E0' },
  { name:'寫程式', color:'#C5B7FF' },
];

function HomeScreen({ t, running=true, elapsed=1547, dailyTotal=8423, selected='閱讀' }) {
  const cats = SAMPLE_CATEGORIES;

  // App header
  const Header = (
    <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', padding:'14px 22px 6px'}}>
      <span style={{
        fontFamily: t.fontDisplay, fontSize: 26, fontWeight: 600, letterSpacing: 1.2,
        color: t.appBarInk,
      }}>Me Time</span>
      <div style={{
        width:36, height:36, display:'grid', placeItems:'center',
        background: t.id==='cartoon' || t.id==='dark' ? 'rgba(255,255,255,0.18)' : t.surface,
        border: t.borderW ? `2px solid ${t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.35)' : t.border}` : 'none',
        borderRadius: 12, color: t.appBarInk,
      }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
          <path d="M21 12a9 9 0 11-3-6.7L21 8M21 3v5h-5"/>
        </svg>
      </div>
    </div>
  );

  // Section label
  const Label = (
    <div style={{
      padding:'8px 22px 6px', display:'flex', justifyContent:'space-between', alignItems:'center',
      fontFamily: t.fontBody, fontSize: 11, fontWeight: 700, letterSpacing: 1.5, color: t.mute,
    }}>
      <span>項目列表</span>
      <div style={{
        width:24, height:24, display:'grid', placeItems:'center',
        background: t.id==='retro'? '#0F380F' : t.action,
        border: t.borderW ? `${Math.max(1.5,t.borderW-1)}px solid ${t.border}` : 'none',
        borderRadius: t.chipRadius>50? 999 : 8, color: typeof t.action==='string'? t.actionInk : '#fff',
        boxShadow: t.shadow!=='transparent'? `1.5px 1.5px 0 ${t.shadow}` : 'none',
      }}>
        <svg width="12" height="12" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>
      </div>
    </div>
  );

  // Category chips
  const Chips = (
    <div style={{
      margin:'4px 22px 12px',
      padding: 8,
      background: t.id==='neon' ? 'rgba(255,255,255,0.04)' : t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.13)' : 'transparent',
      border: t.id==='cartoon'||t.id==='dark' ? '2px solid rgba(255,255,255,0.25)' : t.id==='neon' ? `1px solid ${t.border}` : 'none',
      borderRadius: t.radius - 6,
      display:'flex', flexDirection:'column', gap: 6,
    }}>
      {cats.map(c => {
        const on = c.name === selected;
        const activeBg = t.id==='y2k' || t.id==='pastel' ? t.active : c.color;
        return (
          <div key={c.name} style={{
            display:'flex', alignItems:'center', gap:10,
            padding:'10px 12px',
            background: on ? activeBg : t.chipBg,
            color: on ? t.chipInkSel : t.chipInk,
            border: t.borderW ? `${Math.max(1.5,t.borderW-1)}px solid ${t.id==='neon' ? (on?t.accent:t.border) : t.border}` : 'none',
            borderRadius: t.chipRadius,
            fontFamily: t.fontBody, fontSize: 14, fontWeight: 700,
            boxShadow: on && t.shadow!=='transparent' ? `2px 2px 0 ${t.shadow}` : 'none',
            transition:'all .15s',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" opacity="0.4"><circle cx="9" cy="6" r="1.6"/><circle cx="15" cy="6" r="1.6"/><circle cx="9" cy="12" r="1.6"/><circle cx="15" cy="12" r="1.6"/><circle cx="9" cy="18" r="1.6"/><circle cx="15" cy="18" r="1.6"/></svg>
            <span style={{flex:1}}>{c.name}</span>
            {on && (
              <span style={{
                fontSize:10, fontWeight:800, padding:'3px 8px',
                background: t.id==='retro' ? t.surfaceAlt : 'rgba(255,255,255,0.3)',
                color: t.id==='retro' ? t.ink : t.chipInkSel,
                borderRadius: t.chipRadius>50? 999 : 6,
                border: t.id==='retro' ? `1.5px solid ${t.border}` : '1px solid rgba(255,255,255,0.4)',
              }}>{Math.floor(elapsed/60)}m</span>
            )}
          </div>
        );
      })}
    </div>
  );

  // Timer card
  const timerFont = t.fontTimer;
  const haloOn = t.timerHaloOn && running;
  const TimerCard = (
    <div style={{margin:'8px 22px 4px', position:'relative'}}>
      {haloOn && (
        <div style={{
          position:'absolute', inset:-8, borderRadius: t.radius+8,
          background:`radial-gradient(closest-side, ${t.accentSoft}, transparent 70%)`,
          filter:'blur(8px)', pointerEvents:'none',
        }}/>
      )}
      <div style={{
        position:'relative',
        padding:'24px 20px 22px',
        textAlign:'center',
        ...cardStyle(t),
        ...(t.id==='neon' ? { backdropFilter:'blur(20px)', boxShadow:`0 0 0 1px ${t.border}, 0 0 24px ${t.accentSoft}` } : {}),
      }}>
        <div style={{
          fontFamily: t.fontDisplay, fontSize: 14, fontWeight: 700, letterSpacing: 1.5,
          color: t.id==='retro' ? t.ink : t.id==='neon' ? t.accent : (t.id==='cartoon'? '#FFB300' : t.accent),
          marginBottom: 6, textTransform: t.id==='minimal'||t.id==='pastel'||t.id==='paper' ? 'none' : 'uppercase',
        }}>{running ? t.running : t.timerLabel}</div>
        <div style={{
          fontFamily: timerFont, fontSize: 64, fontWeight: 700,
          color: t.accent, lineHeight: 1,
          textShadow: t.id==='cartoon' ? '3px 3px 0 rgba(0,0,0,0.13)' :
                      t.id==='neon' ? `0 0 12px ${t.accentSoft}, 0 0 24px ${t.accentSoft}` :
                      t.id==='y2k' ? '0 2px 0 rgba(26,31,77,0.2)' : 'none',
          letterSpacing: t.id==='retro' ? -2 : -1,
        }}>{fmt(elapsed)}</div>
        <div style={{
          marginTop: 16, display:'inline-flex', alignItems:'center', gap:8,
          padding:'8px 14px',
          background: t.surfaceAlt,
          border: t.id==='minimal'? 'none' : t.id==='neon'? '1px solid rgba(0,240,255,0.3)' : `1.5px solid ${t.id==='cartoon'?'rgba(26,26,46,0.12)':t.border}`,
          borderRadius: t.chipRadius>50? 999 : 14,
          fontFamily: t.fontBody, fontSize: 12, fontWeight: 700, color: t.ink,
        }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="13" r="8"/><path d="M9 2h6M12 9v4l3 2"/></svg>
          <span>今天已累積</span>
          <span style={{fontFamily: t.fontTimer, fontWeight:700}}>{fmt(dailyTotal)}</span>
        </div>
      </div>
    </div>
  );

  // Action buttons
  const actionBtn = (icon, bg, ink, size=46) => (
    <div style={{
      width:size, height:size, display:'grid', placeItems:'center',
      background: bg, color: ink,
      border: t.borderW ? `${Math.max(2,t.borderW-0.5)}px solid ${t.border}` : 'none',
      borderRadius: t.id==='retro'? 0 : 14,
      boxShadow: t.shadow!=='transparent' ? `${Math.min(3,t.shadowOff[0])}px ${Math.min(3,t.shadowOff[1])}px 0 ${t.shadow}` : 'none',
    }}>{icon}</div>
  );
  const Actions = (
    <div style={{display:'flex', justifyContent:'center', alignItems:'center', gap:30, padding:'18px 0 12px'}}>
      {actionBtn(
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"><path d="M3 12a9 9 0 109-9 9.7 9.7 0 00-6.6 2.6L3 8"/><path d="M3 3v5h5"/></svg>,
        t.id==='retro'? '#C6DE8C' : t.id==='neon'? 'rgba(255,255,255,0.04)' : '#E0E0E0',
        t.id==='neon'? t.ink : '#666'
      )}
      {/* Play button */}
      <div style={{
        position:'relative',
        width:84, height:84, borderRadius:'50%',
        background: t.action,
        display:'grid', placeItems:'center',
        color: t.actionInk,
        border: t.borderW ? `${t.borderW}px solid ${t.id==='neon'? t.accent : t.border}` : 'none',
        boxShadow:
          t.id==='neon' ? `0 0 0 2px ${t.accent}, 0 0 30px ${t.accentSoft}, inset 0 0 20px rgba(255,54,242,0.15)` :
          t.shadow!=='transparent' ? `${t.shadowOff[0]}px ${t.shadowOff[1]}px 0 ${t.shadow}` :
          '0 10px 24px rgba(0,0,0,0.15)',
      }}>
        {running ? (
          <svg width="34" height="34" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>
        ) : (
          <svg width="38" height="38" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
        )}
        {t.id==='y2k' && (
          <div style={{position:'absolute', top:6, left:14, right:14, height:14, borderRadius:99,
            background:'linear-gradient(180deg, rgba(255,255,255,0.85), rgba(255,255,255,0))'}}/>
        )}
      </div>
      {actionBtn(
        <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>,
        t.id==='retro'? '#306230' : '#FF5252', '#fff'
      )}
    </div>
  );

  return (
    <div style={{padding:'2px 0 4px', position:'relative', zIndex:1}}>
      {Header}
      {Label}
      {Chips}
      {TimerCard}
      {Actions}
    </div>
  );
}

window.HomeScreen = HomeScreen;
