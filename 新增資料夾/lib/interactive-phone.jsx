// InteractivePhone — a single phone that the user can tap-navigate through.
// Bottom nav switches pages; Settings page lets user pick a theme.

const { useState: useStateIP } = React;

function InteractivePhone() {
  const [themeId, setThemeId] = useStateIP('cartoon');
  const [tab, setTab] = useStateIP(0); // 0..4
  const t = window.THEMES_BY_ID[themeId];

  return (
    <div style={{
      width: PHONE_W, height: PHONE_H,
      borderRadius: 36, overflow:'hidden', position:'relative',
      background: '#0a0a0a', padding: 8, boxSizing:'border-box',
      boxShadow: '0 30px 60px rgba(0,0,0,0.18), 0 1px 2px rgba(0,0,0,0.2), inset 0 0 0 2px rgba(255,255,255,0.04)',
    }}>
      <div style={{
        width:'100%', height:'100%', borderRadius: 28, overflow:'hidden', position:'relative',
        background: t.bg, display:'flex', flexDirection:'column',
      }}>
        <ThemeBubbles t={t}/>

        <div style={{position:'relative', zIndex:2}}>
          <StatusBar t={t}/>
        </div>
        {/* notch */}
        <div style={{
          position:'absolute', left:'50%', top:8, transform:'translateX(-50%)',
          width:18, height:18, borderRadius:'50%', background:'#0a0a0a', zIndex:3,
        }}/>

        {/* content area — scrollable */}
        <div style={{flex:1, position:'relative', zIndex:1, overflow:'auto'}}>
          {tab === 0 && <HomeScreen t={t} running={true} elapsed={1547} dailyTotal={8423} selected="閱讀"/>}
          {tab === 1 && <StatisticsScreen t={t}/>}
          {tab === 2 && <GoalsScreen t={t}/>}
          {tab === 3 && <HistoryScreen t={t}/>}
          {tab === 4 && <SettingsScreen t={t} themeId={themeId} onPickTheme={setThemeId}/>}
        </div>

        {/* bottom nav (interactive) */}
        <div style={{position:'relative', zIndex:2}}>
          <InteractiveBottomNav t={t} active={tab} onChange={setTab}/>
        </div>
        <div style={{position:'absolute', bottom:6, left:'50%', transform:'translateX(-50%)',
          width:90, height:3, borderRadius:99,
          background: t.id==='neon' || t.id==='dark' ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.55)',
          zIndex:5,
        }}/>
      </div>
    </div>
  );
}

// Same as BottomNav but clickable
function InteractiveBottomNav({ t, active, onChange }) {
  const items = [
    { l:'計時', i:'timer' }, { l:'統計', i:'chart' }, { l:'目標', i:'flag' },
    { l:'歷史', i:'history' }, { l:'設定', i:'settings' },
  ];
  const Icon = ({k, filled, color}) => {
    const s = { width:22, height:22, fill:'none', stroke:color, strokeWidth:filled?0:2, strokeLinecap:'round', strokeLinejoin:'round' };
    const f = filled ? color : 'none';
    if (k==='timer') return <svg viewBox="0 0 24 24" {...s}><circle cx="12" cy="13" r="8" fill={f} stroke={color} strokeWidth="2"/><path d="M9 2h6M12 9v4l3 2" stroke={filled?'#fff':color}/></svg>;
    if (k==='chart') return <svg viewBox="0 0 24 24" {...s}><rect x="3" y="12" width="4" height="9" fill={f}/><rect x="10" y="7" width="4" height="14" fill={f}/><rect x="17" y="3" width="4" height="18" fill={f}/></svg>;
    if (k==='flag') return <svg viewBox="0 0 24 24" {...s}><path d="M5 21V4l11 3-3 4 3 4-11 1" fill={f}/></svg>;
    if (k==='history') return <svg viewBox="0 0 24 24" {...s}><path d="M3 12a9 9 0 109-9 9.7 9.7 0 00-6.6 2.6L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/></svg>;
    if (k==='settings') return <svg viewBox="0 0 24 24" {...s}><circle cx="12" cy="12" r="3" fill={f}/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></svg>;
  };
  return (
    <div style={{
      height: 64, background: t.navBg, color: t.navInk,
      borderTop: `${t.id==='retro' ? '4px' : '2px'} solid ${t.navBorder}`,
      display:'grid', gridTemplateColumns:'repeat(5, 1fr)',
      fontFamily: t.fontBody,
    }}>
      {items.map((it, idx) => {
        const on = idx === active;
        return (
          <button key={idx} onClick={() => onChange(idx)} style={{
            display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:3,
            opacity: on?1:0.55, background:'transparent', border:'none', cursor:'pointer',
            color:'inherit',
          }}>
            <div style={{
              background: on && t.id==='cartoon' ? '#FFD60A' : on && t.id==='dark' ? 'rgba(255,209,102,0.18)' : 'transparent',
              padding: on && (t.id==='cartoon'||t.id==='dark') ? '3px 14px' : 0, borderRadius: 999,
              border: on && t.id==='cartoon' ? '2px solid #1A1A2E' : 'none',
            }}>
              <Icon k={it.i} filled={on} color={t.navInk}/>
            </div>
            <span style={{fontSize:10, fontWeight: on?700:500, letterSpacing: t.id==='retro'?1:0.3}}>{it.l}</span>
          </button>
        );
      })}
    </div>
  );
}

window.InteractivePhone = InteractivePhone;
