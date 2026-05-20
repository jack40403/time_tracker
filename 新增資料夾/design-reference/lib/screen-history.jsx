// HistoryScreen — filter chips, heatmap-ish strip, day entries

const SAMPLE_HISTORY = [
  { date:'2025-05-19', total: 8423, sessions:[
    { cat:'閱讀', color:'#FF8FA3', start:'21:32', dur: 1547, note:'看完《原子習慣》第 3 章' },
    { cat:'學日文', color:'#7BB3E0', start:'19:00', dur: 1680 },
    { cat:'運動', color:'#6B8E4E', start:'07:15', dur: 1920 },
  ]},
  { date:'2025-05-18', total: 6510, sessions:[
    { cat:'寫程式', color:'#C5B7FF', start:'22:10', dur: 3200, note:'修 dark mode 對比度' },
    { cat:'閱讀', color:'#FF8FA3', start:'20:30', dur: 1700 },
  ]},
];

function HistoryScreen({ t }) {
  return (
    <div style={{position:'relative', zIndex:1, padding:'4px 16px 24px'}}>
      <ThemedAppBar t={t} title="歷史紀錄 📅"
        action={
          <div style={{
            padding:'6px 10px', display:'flex', alignItems:'center', gap:4,
            background: t.action, color: t.actionInk,
            border: t.borderW ? `2px solid ${t.border}` : 'none',
            borderRadius: t.chipRadius>50? 999 : 10,
            boxShadow: t.shadow!=='transparent'? `2px 2px 0 ${t.shadow}` : 'none',
            fontFamily: t.fontBody, fontSize: 11, fontWeight: 700,
          }}>
            <svg width="12" height="12" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>
            手動新增
          </div>
        }/>

      <div style={{padding:'6px 4px 4px'}}>
        <FilterTabs t={t}
          options={[{value:'d', label:'每日'},{value:'w', label:'每週'},{value:'m', label:'每月'},{value:'y', label:'每年'}]}
          value="m" onChange={()=>{}}/>
      </div>

      {/* mini month heatmap */}
      <div style={{margin:'12px 0 6px', fontFamily:t.fontBody, fontSize:11, color:t.id==='cartoon'||t.id==='dark'?'rgba(255,255,255,0.6)':t.mute, fontWeight:700, letterSpacing:0.5}}>
        本月達成概覽
      </div>
      <ThemedCard t={t} padding={10}>
        <div style={{display:'grid', gridTemplateColumns:'repeat(7, 1fr)', gap:3}}>
          {Array.from({length:35}).map((_,i) => {
            const v = (i*131 + 17) % 100;
            const filled = v > 35;
            const success = v > 60;
            const c = filled ? (success ? '#4caf50' : '#ef9a9a') : 'rgba(0,0,0,0.06)';
            return <div key={i} style={{
              aspectRatio:'1/1', borderRadius: t.id==='retro'? 0 : 3,
              background: c, opacity: filled? 0.75 : 1,
              border: t.id==='retro' ? `1px solid ${t.border}` : 'none',
            }}/>;
          })}
        </div>
      </ThemedCard>

      {/* day entries */}
      {SAMPLE_HISTORY.map(day => (
        <div key={day.date} style={{marginTop:16}}>
          <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline',
            color: t.id==='cartoon'||t.id==='dark' ? '#fff' : t.ink,
            fontFamily:t.fontBody, padding:'6px 2px 8px'}}>
            <span style={{fontWeight:700, fontSize:14}}>{day.date}</span>
            <span style={{fontFamily:t.fontTimer, fontSize:12, fontWeight:700, color:t.accent}}>總計 {fmtHMS(day.total)}</span>
          </div>
          <div style={{display:'flex', flexDirection:'column', gap:8}}>
            {day.sessions.map((s,i)=>(
              <ThemedCard key={i} t={t} padding={12}>
                <div style={{display:'flex', alignItems:'center', gap:10, fontFamily:t.fontBody}}>
                  <div style={{width:8, height:8, borderRadius:'50%', background:s.color}}/>
                  <div style={{flex:1}}>
                    <div style={{fontWeight:700, fontSize:13, color:t.ink}}>{s.cat}</div>
                    <div style={{fontSize:11, color:t.mute, marginTop:1}}>{s.start}</div>
                  </div>
                  <div style={{fontFamily:t.fontTimer, fontWeight:700, fontSize:13, color:t.ink}}>{fmtHMS(s.dur)}</div>
                </div>
                {s.note && (
                  <div style={{
                    marginTop:8, padding:8,
                    background: t.surfaceAlt, borderRadius: t.id==='retro'? 0 : 6,
                    fontFamily:t.fontBody, fontSize:11, fontStyle:'italic', color:t.mute,
                    border: t.id==='retro' ? `1px solid ${t.border}` : 'none',
                  }}>{s.note}</div>
                )}
              </ThemedCard>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

window.HistoryScreen = HistoryScreen;
