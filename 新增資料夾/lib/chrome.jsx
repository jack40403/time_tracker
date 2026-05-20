// Status bar — matches each theme so the bezel feels native
function StatusBar({ t }) {
  const c = t.appBarInk === '#F4F2E7' || t.appBarInk === '#00F0FF' || t.appBarInk === 'rgba(255,255,255,0.92)'
    ? '#fff' : t.ink;
  return (
    <div style={{
      height: 36, display:'flex', alignItems:'center', justifyContent:'space-between',
      padding:'0 18px', fontSize:13, fontWeight:600, color:c,
      fontFamily:'system-ui, -apple-system, Roboto',
    }}>
      <span>9:30</span>
      <div style={{display:'flex', alignItems:'center', gap:6, opacity:0.9}}>
        <svg width="14" height="11" viewBox="0 0 14 11"><path d="M7 11L0 4a10 10 0 0114 0L7 11z" fill={c}/></svg>
        <svg width="14" height="11" viewBox="0 0 14 11"><path d="M13 10V0L0 10h13z" fill={c}/></svg>
        <svg width="22" height="11" viewBox="0 0 22 11"><rect x="0.5" y="0.5" width="19" height="10" rx="2" stroke={c} fill="none"/><rect x="2" y="2" width="14" height="7" rx="1" fill={c}/><rect x="20" y="3.5" width="1.5" height="4" rx="0.5" fill={c}/></svg>
      </div>
    </div>
  );
}

// Bottom nav — also matches theme
function BottomNav({ t, active=0 }) {
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
  const border = t.navBorder;
  const navStyle = {
    height: 64, background: t.navBg, color: t.navInk,
    borderTop: `${t.id==='retro' ? '4px' : '2px'} solid ${border}`,
    display:'grid', gridTemplateColumns:'repeat(5, 1fr)',
    fontFamily: t.fontBody,
  };
  return (
    <div style={navStyle}>
      {items.map((it, idx) => {
        const on = idx === active;
        return (
          <div key={idx} style={{display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:3, opacity: on?1:0.55}}>
            <div style={{ background: on && t.id==='cartoon' ? '#FFD60A' : on && t.id==='dark' ? 'rgba(255,209,102,0.18)' : 'transparent',
              padding: on && (t.id==='cartoon'||t.id==='dark') ? '3px 14px' : 0, borderRadius: 999,
              border: on && t.id==='cartoon' ? '2px solid #1A1A2E' : 'none'}}>
              <Icon k={it.i} filled={on} color={t.navInk}/>
            </div>
            <span style={{fontSize:10, fontWeight: on?700:500, letterSpacing: t.id==='retro'?1:0.3}}>{it.l}</span>
          </div>
        );
      })}
    </div>
  );
}

window.StatusBar = StatusBar;
window.BottomNav = BottomNav;
