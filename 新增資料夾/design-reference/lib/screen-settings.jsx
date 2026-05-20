// SettingsScreen — sections + the theme picker (highlight)

function SectionLabel({ t, children, color }) {
  return (
    <div style={{
      fontFamily: t.fontDisplay, fontSize: 12, fontWeight: 700, letterSpacing: 1,
      color: color || (t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.85)' : t.ink),
      padding:'18px 8px 8px',
    }}>{children}</div>
  );
}

function Row({ t, icon, label, sub, trailing, divider = true, last = false }) {
  return (
    <div style={{
      display:'flex', alignItems:'center', gap:12, padding:'12px 14px',
      borderBottom: divider && !last ? `1px solid ${t.id==='neon'?'rgba(255,255,255,0.08)':'rgba(0,0,0,0.07)'}` : 'none',
      fontFamily: t.fontBody,
    }}>
      {icon && (
        <div style={{
          width:32, height:32, display:'grid', placeItems:'center',
          background: typeof icon === 'object' && icon.bg ? icon.bg : t.surfaceAlt,
          borderRadius: 8, color: icon.color || t.accent,
          border: t.id==='retro' ? `1.5px solid ${t.border}` : 'none',
        }}>{icon.svg || icon}</div>
      )}
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:13, fontWeight:700, color:t.ink}}>{label}</div>
        {sub && <div style={{fontSize:11, color:t.mute, marginTop:2}}>{sub}</div>}
      </div>
      {trailing}
    </div>
  );
}

// ── theme picker grid ──────────────────────────────────────────
function ThemeSwatch({ theme, active, onPick, currentTheme }) {
  const t = currentTheme;
  return (
    <button onClick={() => onPick(theme.id)} style={{
      flex:'0 0 auto', width:88,
      display:'flex', flexDirection:'column', alignItems:'center', gap:6,
      padding:6, background:'transparent', border:'none', cursor:'pointer',
    }}>
      <div style={{
        width:72, height:88, borderRadius: theme.radius>20 ? 14 : Math.max(6, theme.radius*0.5),
        background: theme.bg, overflow:'hidden', position:'relative',
        border: active ? `3px solid ${t.accent}` : `${t.borderW||1.5}px solid ${active?t.accent:t.border}`,
        boxShadow: active && t.shadow!=='transparent' ? `0 0 0 2px ${t.accent}40, 2px 2px 0 ${t.shadow}` : 'none',
      }}>
        {/* tiny mock: surface card + accent dot */}
        <div style={{
          position:'absolute', left:8, right:8, top:14, height:34,
          background: theme.surface, borderRadius: Math.max(2, theme.radius*0.4),
          border: theme.borderW ? `${Math.max(1, theme.borderW*0.5)}px solid ${theme.border}` : 'none',
        }}/>
        <div style={{
          position:'absolute', left:'50%', bottom:14, transform:'translateX(-50%)',
          width:18, height:18, borderRadius:'50%', background: theme.action,
          border: theme.borderW ? `${Math.max(1, theme.borderW*0.5)}px solid ${theme.border}` : 'none',
        }}/>
        {active && (
          <div style={{
            position:'absolute', top:4, right:4, width:18, height:18, borderRadius:'50%',
            background: t.accent, color:'#fff', display:'grid', placeItems:'center',
          }}>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round"><path d="M5 12l5 5L20 7"/></svg>
          </div>
        )}
      </div>
      <span style={{
        fontFamily: 'inherit', fontSize:11, fontWeight: active?700:500,
        color: t.id==='cartoon'||t.id==='dark' ? '#fff' : t.ink,
      }}>{theme.zh}</span>
    </button>
  );
}

function ThemePicker({ t, themeId, onChange }) {
  return (
    <div>
      <div style={{
        display:'flex', alignItems:'center', justifyContent:'space-between',
        padding:'12px 14px 8px', fontFamily:t.fontBody,
      }}>
        <span style={{fontWeight:700, fontSize:13, color:t.ink}}>主題風格</span>
        <span style={{fontSize:10, color:t.mute, fontWeight:600}}>挑一個你喜歡的</span>
      </div>
      <div style={{
        display:'flex', gap:6, padding:'2px 10px 12px',
        overflowX:'auto', overflowY:'visible',
      }}>
        {window.THEMES.map(theme => (
          <ThemeSwatch key={theme.id} theme={theme} currentTheme={t} active={theme.id===themeId} onPick={onChange}/>
        ))}
      </div>
    </div>
  );
}

const ICONS = {
  cloud: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 10h-1.3a8 8 0 10-13.7 7H18a4 4 0 000-7z"/></svg>,
  user: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0116 0"/></svg>,
  download: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></svg>,
  upload: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 21V9M7 14l5-5 5 5M5 3h14"/></svg>,
  palette: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="8" cy="9" r="1.2" fill="currentColor"/><circle cx="12" cy="6" r="1.2" fill="currentColor"/><circle cx="16" cy="9" r="1.2" fill="currentColor"/><circle cx="17" cy="14" r="1.2" fill="currentColor"/></svg>,
  moon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z"/></svg>,
  info: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 8h0M11 12h1v5"/></svg>,
  trash: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/></svg>,
};

function Toggle({ t, on, onChange }) {
  return (
    <div onClick={()=>onChange(!on)} style={{
      width:42, height:24, borderRadius:99, padding:2,
      background: on ? t.accent : (t.id==='neon' ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.18)'),
      border: t.id==='retro' ? `2px solid ${t.border}` : 'none',
      transition:'background .2s', cursor:'pointer',
    }}>
      <div style={{
        width:20, height:20, borderRadius:'50%',
        background:'#fff',
        transform: on ? 'translateX(18px)' : 'translateX(0)',
        transition:'transform .2s',
        boxShadow:'0 1px 3px rgba(0,0,0,0.2)',
      }}/>
    </div>
  );
}

function SettingsScreen({ t, themeId, onPickTheme }) {
  const [dark, setDark] = React.useState(t.id === 'dark');
  React.useEffect(() => { setDark(t.id === 'dark'); }, [t.id]);

  return (
    <div style={{position:'relative', zIndex:1, padding:'4px 16px 24px'}}>
      <ThemedAppBar t={t} title="設定 ⚙️"/>

      {/* THEME PICKER — highlighted */}
      <SectionLabel t={t} color={t.id==='cartoon' ? '#FFD60A' : t.accent}>🎨 外觀主題</SectionLabel>
      <ThemedCard t={t} padding={0} style={{overflow:'hidden'}}>
        <ThemePicker t={t} themeId={themeId} onChange={onPickTheme}/>
        <div style={{
          padding:'10px 14px', fontFamily:t.fontBody, fontSize:11, color:t.mute,
          background: t.surfaceAlt, borderTop: t.borderW? `1.5px solid ${t.border}`:'none',
        }}>
          目前:&nbsp;
          <span style={{color:t.accent, fontWeight:700}}>{t.name} · {t.zh}</span>
        </div>
      </ThemedCard>

      {/* Account */}
      <SectionLabel t={t}>帳戶與同步</SectionLabel>
      <ThemedCard t={t} padding={0}>
        <Row t={t} icon={{svg:ICONS.user, color:t.accent}} label="登入 Google 帳戶" sub="啟用雲端備份與多裝置同步"
          trailing={
            <div style={{
              padding:'5px 12px', fontSize:11, fontWeight:700,
              background: t.action, color: t.actionInk,
              border: t.borderW?`1.5px solid ${t.border}`:'none',
              borderRadius: t.chipRadius>50?999:8,
            }}>登入</div>
          }/>
        <Row t={t} icon={{svg:ICONS.cloud, color:t.accent}} label="手動強制同步" sub="本機 84 筆 · 雲端 84 筆" last/>
      </ThemedCard>

      {/* Customization */}
      <SectionLabel t={t}>客製化外觀</SectionLabel>
      <ThemedCard t={t} padding={0}>
        <Row t={t} icon={{svg:ICONS.palette, color:t.accent}} label="計時器文字顏色"
          trailing={<div style={{
            display:'flex', alignItems:'center', gap:6, padding:'4px 10px',
            background: `${t.accent}1f`, borderRadius:8, fontSize:11, fontWeight:700, color:t.accent,
            border: `1.5px solid ${t.accent}40`,
          }}><div style={{width:10, height:10, borderRadius:'50%', background:t.accent}}/>{`#${t.accent.replace('#','').toUpperCase().slice(0,6)}`}</div>}/>
        <Row t={t} icon={{svg:ICONS.moon, color:t.accent}} label="深色模式" sub="切換主題到 Dark"
          trailing={<Toggle t={t} on={dark} onChange={(v)=>{ setDark(v); onPickTheme(v?'dark':'cartoon'); }}/>} last/>
      </ThemedCard>

      {/* Data */}
      <SectionLabel t={t}>資料管理與備份</SectionLabel>
      <ThemedCard t={t} padding={0}>
        <Row t={t} icon={{svg:ICONS.download, color:t.accent}} label="匯出完整備份 (JSON)" sub="包含分類、紀錄、目標"/>
        <Row t={t} icon={{svg:ICONS.upload, color:t.accent}} label="匯入備份檔" sub="支援 Elite / Jiffy 格式"/>
        <Row t={t} icon={{svg:ICONS.trash, color:'#FF5252', bg:'rgba(255,82,82,0.12)'}} label="清除全部資料" sub="此動作無法復原" last/>
      </ThemedCard>

      {/* Version */}
      <SectionLabel t={t}>關於</SectionLabel>
      <ThemedCard t={t} padding={0}>
        <Row t={t} icon={{svg:ICONS.info, color:t.accent}} label="目前版本" sub="v1.1.0 (Build 85) · 已是最新"
          trailing={<div style={{fontSize:11, color:t.mute, fontWeight:600}}>檢查更新</div>} last/>
      </ThemedCard>

      <div style={{
        textAlign:'center', padding:'24px 0 8px',
        fontFamily: t.fontDisplay, fontSize: 13, fontWeight: 700,
        color: t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.5)' : t.mute,
        letterSpacing: 1,
      }}>Me Time · 把時間留給自己</div>
    </div>
  );
}

window.SettingsScreen = SettingsScreen;
